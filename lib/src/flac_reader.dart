import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'metadata_reader.dart';
import 'metadata_tag.dart';

/// FLAC Vorbis Comment metadata reader
class FlacReader extends MetadataReader {
  @override
  List<String> get supportedExtensions => ['.flac'];

  @override
  bool supportsFile(String filePath) {
    return filePath.toLowerCase().endsWith('.flac');
  }

  @override
  Future<List<MetadataTag>> readTags(String filePath) async {
    await validateFile(filePath);

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    return readTagsFromBytes(bytes);
  }

  @override
  Future<List<MetadataTag>> readTagsFromBytes(Uint8List bytes) async {
    return _parseFlacMetadata(bytes);
  }

  @override
  bool supportsBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Check for fLaC signature
    return bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43;
  }

  /// Parses FLAC metadata blocks
  List<MetadataTag> _parseFlacMetadata(Uint8List bytes) {
    final tags = <MetadataTag>[];

    if (bytes.length < 8) return tags;

    // Check FLAC signature
    if (bytes[0] != 0x66 ||
        bytes[1] != 0x4C ||
        bytes[2] != 0x61 ||
        bytes[3] != 0x43) {
      return tags; // Not a FLAC file
    }

    int offset = 4;

    // Parse metadata blocks
    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) break;

      final header = bytes[offset];
      final isLast = (header & 0x80) != 0;
      final blockType = header & 0x7F;

      final blockSize =
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];

      offset += 4;

      if (offset + blockSize > bytes.length) break;

      final blockData = bytes.sublist(offset, offset + blockSize);

      // Parse Vorbis Comment block (type 4)
      if (blockType == 4) {
        tags.addAll(_parseVorbisComment(blockData));
      }

      // Parse Picture block (type 6)
      if (blockType == 6) {
        final pictureTag = _parsePictureBlock(blockData);
        if (pictureTag != null) {
          tags.add(pictureTag);
        }
      }

      offset += blockSize;

      if (isLast) break;
    }

    return tags;
  }

  /// Parses a Vorbis Comment metadata block
  List<MetadataTag> _parseVorbisComment(Uint8List blockData) {
    final tags = <MetadataTag>[];

    if (blockData.length < 8) return tags;

    int offset = 0;

    // Read vendor string length
    final vendorLength = _readInt32LE(blockData, offset);
    offset += 4;

    if (offset + vendorLength > blockData.length) return tags;

    // Skip vendor string
    // final vendor = utf8.decode(blockData.sublist(offset, offset + vendorLength));
    offset += vendorLength;

    if (offset + 4 > blockData.length) return tags;

    // Read user comment list length
    final commentCount = _readInt32LE(blockData, offset);
    offset += 4;

    // Parse user comments
    for (int i = 0; i < commentCount; i++) {
      if (offset + 4 > blockData.length) break;

      final commentLength = _readInt32LE(blockData, offset);
      offset += 4;

      if (offset + commentLength > blockData.length) break;

      final commentBytes = blockData.sublist(offset, offset + commentLength);
      final comment = utf8.decode(commentBytes);

      // Parse field=value format
      final separatorIndex = comment.indexOf('=');
      if (separatorIndex > 0) {
        final fieldName = comment.substring(0, separatorIndex).toUpperCase();
        final value = comment.substring(separatorIndex + 1);

        final tagKey = _vorbisFieldToTagKey(fieldName);
        tags.add(MetadataTag.text(tagKey, value));
      }

      offset += commentLength;
    }

    return tags;
  }

  /// Parses a PICTURE metadata block
  MetadataTag? _parsePictureBlock(Uint8List blockData) {
    if (blockData.length < 32) return null;

    try {
      int offset = 0;

      // Read picture type
      // final pictureType = _readInt32BE(blockData, offset);
      offset += 4;

      // Read MIME type length
      final mimeLength = _readInt32BE(blockData, offset);
      offset += 4;

      if (offset + mimeLength > blockData.length) return null;

      // Read MIME type
      // final mimeType = utf8.decode(blockData.sublist(offset, offset + mimeLength));
      offset += mimeLength;

      // Read description length
      final descLength = _readInt32BE(blockData, offset);
      offset += 4;

      if (offset + descLength > blockData.length) return null;

      // Skip description
      offset += descLength;

      // Skip width, height, color depth, colors used (4 * 4 bytes)
      offset += 16;

      if (offset + 4 > blockData.length) return null;

      // Read picture data length
      final pictureLength = _readInt32BE(blockData, offset);
      offset += 4;

      if (offset + pictureLength > blockData.length) return null;

      // Read picture data
      final pictureData = Uint8List.fromList(
        blockData.sublist(offset, offset + pictureLength),
      );

      return MetadataTag.binary(CommonTags.albumArt, pictureData);
    } catch (e) {
      return null;
    }
  }

  /// Maps Vorbis field names to common tag keys
  String _vorbisFieldToTagKey(String fieldName) {
    switch (fieldName) {
      case 'TITLE':
        return CommonTags.title;
      case 'ARTIST':
        return CommonTags.artist;
      case 'ALBUM':
        return CommonTags.album;
      case 'ALBUMARTIST':
        return CommonTags.albumArtist;
      case 'DATE':
        return CommonTags.year;
      case 'GENRE':
        return CommonTags.genre;
      case 'TRACKNUMBER':
        return CommonTags.track;
      case 'TRACKTOTAL':
        return CommonTags.trackTotal;
      case 'DISCNUMBER':
        return CommonTags.disc;
      case 'DISCTOTAL':
        return CommonTags.discTotal;
      case 'COMMENT':
        return CommonTags.comment;
      case 'COMPOSER':
        return CommonTags.composer;
      case 'PERFORMER':
        return CommonTags.performer;
      case 'CONDUCTOR':
        return CommonTags.conductor;
      case 'LYRICIST':
        return CommonTags.lyricist;
      case 'COPYRIGHT':
        return CommonTags.copyright;
      case 'ENCODEDBY':
        return CommonTags.encodedBy;
      case 'BPM':
        return CommonTags.bpm;
      case 'MOOD':
        return CommonTags.mood;
      case 'ISRC':
        return CommonTags.isrc;
      case 'BARCODE':
        return CommonTags.barcode;
      case 'CATALOGNUMBER':
        return CommonTags.catalogNumber;
      case 'LABEL':
        return CommonTags.label;
      case 'LYRICS':
        return CommonTags.lyrics;
      default:
        // Return custom tags as-is
        return fieldName;
    }
  }

  /// Reads a 32-bit little-endian integer
  int _readInt32LE(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  /// Reads a 32-bit big-endian integer
  int _readInt32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}
