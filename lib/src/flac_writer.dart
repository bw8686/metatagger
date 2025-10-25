import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'metadata_writer.dart';
import 'metadata_tag.dart';

/// FLAC Vorbis Comment metadata writer
class FlacWriter extends MetadataWriter {
  @override
  List<String> get supportedExtensions => ['.flac'];

  @override
  bool supportsFile(String filePath) {
    return filePath.toLowerCase().endsWith('.flac');
  }

  @override
  Future<void> writeTags(String filePath, List<MetadataTag> tags) async {
    await validateFile(filePath);
    
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    
    // Parse FLAC structure
    final flacData = _parseFlacFile(bytes);
    if (flacData == null) {
      throw MetadataException('Invalid FLAC file format', filePath);
    }
    
    // Separate text tags from album art
    final textTags = tags.where((tag) => tag.key != CommonTags.albumArt).toList();
    final albumArtTags = tags.where((tag) => tag.key == CommonTags.albumArt).toList();
    
    // Create new Vorbis comment block (text metadata only)
    final vorbisComment = _createVorbisComment(textTags);
    
    // Replace or add Vorbis comment block
    var newFlacData = _replaceVorbisComment(flacData, vorbisComment);
    
    // Add PICTURE blocks for album art
    for (final artTag in albumArtTags) {
      if (artTag.value is Uint8List) {
        final pictureBlock = _createPictureBlock(artTag.value as Uint8List);
        newFlacData = _addPictureBlock(newFlacData, pictureBlock);
      }
    }
    
    // Write updated file
    await file.writeAsBytes(newFlacData);
  }

  @override
  Future<void> clearTags(String filePath) async {
    await writeTags(filePath, []);
  }

  /// Parses a FLAC file and returns its structure
  _FlacData? _parseFlacFile(Uint8List bytes) {
    if (bytes.length < 8) return null;
    
    // Check FLAC signature
    if (bytes[0] != 0x66 || bytes[1] != 0x4C || bytes[2] != 0x61 || bytes[3] != 0x43) {
      return null; // Not a FLAC file
    }
    
    final blocks = <_MetadataBlock>[];
    int offset = 4;
    
    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) break;
      
      final header = bytes[offset];
      final isLast = (header & 0x80) != 0;
      final blockType = header & 0x7F;
      
      final blockSize = (bytes[offset + 1] << 16) |
                       (bytes[offset + 2] << 8) |
                       bytes[offset + 3];
      
      offset += 4;
      
      if (offset + blockSize > bytes.length) break;
      
      final blockData = Uint8List.fromList(
        bytes.skip(offset).take(blockSize).toList()
      );
      
      blocks.add(_MetadataBlock(
        type: blockType,
        isLast: isLast,
        data: blockData,
      ));
      
      offset += blockSize;
      
      if (isLast) break;
    }
    
    // Audio data starts after metadata blocks
    final audioData = Uint8List.fromList(bytes.skip(offset).toList());
    
    return _FlacData(blocks: blocks, audioData: audioData);
  }

  /// Creates a Vorbis comment block from metadata tags
  Uint8List _createVorbisComment(List<MetadataTag> tags) {
    final comments = <String>[];
    
    // Add vendor string (required)
    final vendor = 'MetaTagger Dart Library';
    
    // Convert tags to Vorbis comments
    for (final tag in tags) {
      if (tag.type == TagType.binary && tag.key != CommonTags.albumArt) {
        continue; // Skip unsupported binary tags
      }
      
      final fieldName = _getVorbisFieldName(tag.key);
      
      if (fieldName.isNotEmpty) {
        if (tag.type == TagType.binary && tag.key == CommonTags.albumArt) {
          // Skip album art in Vorbis comments - it will be handled as separate PICTURE block
          continue;
        } else {
          comments.add('$fieldName=${tag.value}');
        }
      }
    }
    
    // Build Vorbis comment structure
    final vendorBytes = utf8.encode(vendor);
    final commentData = <int>[];
    
    // Vendor string length and data
    commentData.addAll(_writeInt32LE(vendorBytes.length));
    commentData.addAll(vendorBytes);
    
    // User comment list length
    commentData.addAll(_writeInt32LE(comments.length));
    
    // User comments
    for (final comment in comments) {
      final commentBytes = utf8.encode(comment);
      commentData.addAll(_writeInt32LE(commentBytes.length));
      commentData.addAll(commentBytes);
    }
    
    // Note: No framing bit in FLAC (that's only for Ogg Vorbis)
    
    return Uint8List.fromList(commentData);
  }

  /// Creates a METADATA_BLOCK_PICTURE for album art
  List<int> _createPictureBlock(Uint8List imageData) {
    final mimeType = _detectMimeType(imageData);
    final mimeBytes = utf8.encode(mimeType);
    final description = utf8.encode(''); // Empty description
    
    final pictureData = <int>[];
    
    // Picture type (3 = Cover (front))
    pictureData.addAll(_writeInt32BE(3));
    
    // MIME type length and data
    pictureData.addAll(_writeInt32BE(mimeBytes.length));
    pictureData.addAll(mimeBytes);
    
    // Description length and data
    pictureData.addAll(_writeInt32BE(description.length));
    pictureData.addAll(description);
    
    // Width, height, color depth, colors used (all 0 for unknown)
    pictureData.addAll(_writeInt32BE(0)); // Width
    pictureData.addAll(_writeInt32BE(0)); // Height
    pictureData.addAll(_writeInt32BE(0)); // Color depth
    pictureData.addAll(_writeInt32BE(0)); // Colors used
    
    // Picture data length and data
    pictureData.addAll(_writeInt32BE(imageData.length));
    pictureData.addAll(imageData);
    
    return pictureData;
  }

  /// Detects MIME type from image data
  String _detectMimeType(Uint8List imageData) {
    if (imageData.length >= 2) {
      // JPEG
      if (imageData[0] == 0xFF && imageData[1] == 0xD8) {
        return 'image/jpeg';
      }
      // PNG
      if (imageData.length >= 8 &&
          imageData[0] == 0x89 &&
          imageData[1] == 0x50 &&
          imageData[2] == 0x4E &&
          imageData[3] == 0x47) {
        return 'image/png';
      }
    }
    return 'image/jpeg'; // Default
  }

  /// Replaces or adds Vorbis comment block in FLAC data
  Uint8List _replaceVorbisComment(_FlacData flacData, Uint8List vorbisComment) {
    final newBlocks = <_MetadataBlock>[];
    bool hasVorbisComment = false;
    
    // Process existing blocks
    for (int i = 0; i < flacData.blocks.length; i++) {
      final block = flacData.blocks[i];
      
      if (block.type == 4) { // VORBIS_COMMENT block
        // Replace with new Vorbis comment
        newBlocks.add(_MetadataBlock(
          type: 4,
          isLast: block.isLast,
          data: vorbisComment,
        ));
        hasVorbisComment = true;
      } else {
        // Keep other blocks, but clear isLast flag if we need to add Vorbis comment
        newBlocks.add(_MetadataBlock(
          type: block.type,
          isLast: hasVorbisComment ? block.isLast : false,
          data: block.data,
        ));
      }
    }
    
    // Add Vorbis comment if it didn't exist
    if (!hasVorbisComment) {
      // Clear isLast flag from previous last block
      if (newBlocks.isNotEmpty) {
        final lastIndex = newBlocks.length - 1;
        newBlocks[lastIndex] = _MetadataBlock(
          type: newBlocks[lastIndex].type,
          isLast: false,
          data: newBlocks[lastIndex].data,
        );
      }
      
      // Add new Vorbis comment block
      newBlocks.add(_MetadataBlock(
        type: 4,
        isLast: true,
        data: vorbisComment,
      ));
    }
    
    // Rebuild FLAC file
    final result = <int>[0x66, 0x4C, 0x61, 0x43]; // FLAC signature
    
    for (final block in newBlocks) {
      final header = (block.isLast ? 0x80 : 0x00) | block.type;
      result.add(header);
      result.addAll(_writeInt24BE(block.data.length));
      result.addAll(block.data);
    }
    
    result.addAll(flacData.audioData);
    
    return Uint8List.fromList(result);
  }

  /// Adds a PICTURE metadata block to FLAC data
  Uint8List _addPictureBlock(Uint8List flacData, List<int> pictureBlockData) {
    // Parse the existing FLAC data to get blocks
    final parsedData = _parseFlacFile(flacData);
    if (parsedData == null) return flacData;
    
    final newBlocks = <_MetadataBlock>[];
    
    // Add all existing blocks (clear isLast flag from the last one)
    for (int i = 0; i < parsedData.blocks.length; i++) {
      final block = parsedData.blocks[i];
      newBlocks.add(_MetadataBlock(
        type: block.type,
        isLast: false, // Clear isLast flag
        data: block.data,
      ));
    }
    
    // Add new PICTURE block as the last one
    newBlocks.add(_MetadataBlock(
      type: 6, // PICTURE block type
      isLast: true,
      data: Uint8List.fromList(pictureBlockData),
    ));
    
    // Rebuild FLAC file
    final result = <int>[0x66, 0x4C, 0x61, 0x43]; // FLAC signature
    
    for (final block in newBlocks) {
      final header = (block.isLast ? 0x80 : 0x00) | block.type;
      result.add(header);
      result.addAll(_writeInt24BE(block.data.length));
      result.addAll(block.data);
    }
    
    // Add audio data
    result.addAll(parsedData.audioData);
    
    return Uint8List.fromList(result);
  }

  /// Maps common tag keys to Vorbis comment field names
  String _getVorbisFieldName(String tagKey) {
    switch (tagKey.toUpperCase()) {
      case 'TITLE':
        return 'TITLE';
      case 'ARTIST':
        return 'ARTIST';
      case 'ALBUM':
        return 'ALBUM';
      case 'ALBUMARTIST':
        return 'ALBUMARTIST';
      case 'DATE':
        return 'DATE';
      case 'YEAR':
        return 'DATE';
      case 'GENRE':
        return 'GENRE';
      case 'TRACKNUMBER':
        return 'TRACKNUMBER';
      case 'TRACKTOTAL':
        return 'TRACKTOTAL';
      case 'DISCNUMBER':
        return 'DISCNUMBER';
      case 'DISCTOTAL':
        return 'DISCTOTAL';
      case 'COMMENT':
        return 'COMMENT';
      case 'COMPOSER':
        return 'COMPOSER';
      case 'PERFORMER':
        return 'PERFORMER';
      case 'CONDUCTOR':
        return 'CONDUCTOR';
      case 'LYRICIST':
        return 'LYRICIST';
      case 'COPYRIGHT':
        return 'COPYRIGHT';
      case 'ENCODEDBY':
        return 'ENCODEDBY';
      case 'BPM':
        return 'BPM';
      case 'MOOD':
        return 'MOOD';
      case 'ISRC':
        return 'ISRC';
      case 'BARCODE':
        return 'BARCODE';
      case 'CATALOGNUMBER':
        return 'CATALOGNUMBER';
      case 'LABEL':
        return 'LABEL';
      case 'LYRICS':
        return 'LYRICS';
      case 'ALBUMART':
        return 'METADATA_BLOCK_PICTURE';
      default:
        // Custom tags are supported directly in Vorbis comments
        return tagKey.toUpperCase();
    }
  }

  /// Writes a 32-bit little-endian integer
  List<int> _writeInt32LE(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  /// Writes a 32-bit big-endian integer
  List<int> _writeInt32BE(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Writes a 24-bit big-endian integer
  List<int> _writeInt24BE(int value) {
    return [
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}

/// Represents FLAC file structure
class _FlacData {
  final List<_MetadataBlock> blocks;
  final Uint8List audioData;

  _FlacData({required this.blocks, required this.audioData});
}

/// Represents a FLAC metadata block
class _MetadataBlock {
  final int type;
  final bool isLast;
  final Uint8List data;

  _MetadataBlock({
    required this.type,
    required this.isLast,
    required this.data,
  });
}
