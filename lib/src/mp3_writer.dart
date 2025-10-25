import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'metadata_writer.dart';
import 'metadata_tag.dart';

/// MP3 ID3v2 metadata writer
class Mp3Writer extends MetadataWriter {
  @override
  List<String> get supportedExtensions => ['.mp3'];

  @override
  bool supportsFile(String filePath) {
    return filePath.toLowerCase().endsWith('.mp3');
  }

  @override
  Future<void> writeTags(String filePath, List<MetadataTag> tags) async {
    await validateFile(filePath);

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Remove existing ID3v2 tag if present
    final audioData = _removeExistingId3v2Tag(bytes);

    // Create new ID3v2 tag
    final id3v2Tag = _createId3v2Tag(tags);

    // Write new file with ID3v2 tag at the beginning
    final newBytes = Uint8List.fromList([...id3v2Tag, ...audioData]);
    await file.writeAsBytes(newBytes);
  }

  @override
  Future<void> clearTags(String filePath) async {
    await validateFile(filePath);

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Remove existing ID3v2 tag
    final audioData = _removeExistingId3v2Tag(bytes);

    // Write file without ID3v2 tag
    await file.writeAsBytes(audioData);
  }

  /// Removes existing ID3v2 tag from MP3 data
  Uint8List _removeExistingId3v2Tag(Uint8List bytes) {
    if (bytes.length < 10) return bytes;

    // Check for ID3v2 header
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      // ID3v2 tag found, calculate its size
      final size = _readSynchsafeInt(bytes, 6) + 10;

      // Check for footer (ID3v2.4)
      final hasFooter = (bytes[5] & 0x10) != 0;
      final totalSize = hasFooter ? size + 10 : size;

      if (totalSize < bytes.length) {
        return Uint8List.fromList(bytes.skip(totalSize).toList());
      }
    }

    return bytes;
  }

  /// Creates an ID3v2.4 tag from metadata tags
  List<int> _createId3v2Tag(List<MetadataTag> tags) {
    final frames = <List<int>>[];

    for (final tag in tags) {
      final frame = _createFrame(tag);
      if (frame.isNotEmpty) {
        frames.add(frame);
      }
    }

    // Calculate total frames size
    final framesSize = frames.fold<int>(0, (sum, frame) => sum + frame.length);

    // Create ID3v2.4 header
    final header = <int>[
      0x49, 0x44, 0x33, // "ID3"
      0x04, 0x00, // Version 2.4.0
      0x00, // Flags
      ..._writeSynchsafeInt(framesSize), // Size
    ];

    // Combine header and frames
    final result = <int>[...header];
    for (final frame in frames) {
      result.addAll(frame);
    }

    return result;
  }

  /// Creates an ID3v2 frame from a metadata tag
  List<int> _createFrame(MetadataTag tag) {
    final frameId = _getFrameId(tag.key);
    if (frameId.isEmpty) return [];

    List<int> frameData;

    // Handle custom tags with TXXX frame
    if (frameId == 'TXXX') {
      frameData = _createTXXXFrame(tag.key, tag.value.toString());
    } else {
      switch (tag.type) {
        case TagType.text:
          frameData = _createTextFrame(tag.value.toString());
          break;
        case TagType.binary:
          if (tag.key == CommonTags.albumArt && tag.value is Uint8List) {
            frameData = _createPictureFrame(tag.value as Uint8List);
          } else {
            return []; // Unsupported binary type
          }
          break;
        case TagType.number:
          frameData = _createTextFrame(tag.value.toString());
          break;
      }
    }

    // Create frame header
    final frameIdBytes = utf8.encode(frameId);
    // ID3v2.4 uses synchsafe integers for frame sizes too
    final frameSizeBytes = _writeSynchsafeInt(frameData.length);
    final frameHeader = <int>[
      ...frameIdBytes,
      ...frameSizeBytes, // Frame size (synchsafe)
      0x00, 0x00, // Frame flags
    ];

    return [...frameHeader, ...frameData];
  }

  /// Creates text frame data
  List<int> _createTextFrame(String text) {
    final utf8Bytes = utf8.encode(text);
    return [0x03, ...utf8Bytes]; // 0x03 = UTF-8 encoding
  }

  /// Creates TXXX frame data for custom tags
  List<int> _createTXXXFrame(String key, String value) {
    final keyBytes = utf8.encode(key);
    final valueBytes = utf8.encode(value);

    return [
      0x03, // UTF-8 encoding
      ...keyBytes,
      0x00, // Null separator
      ...valueBytes,
    ];
  }

  /// Creates picture frame data (APIC)
  List<int> _createPictureFrame(Uint8List imageData) {
    final mimeType = _detectMimeType(imageData);
    final mimeBytes = utf8.encode(mimeType);
    
    return [
      0x00, // Text encoding: ISO-8859-1 (simpler than UTF-8 for description)
      ...mimeBytes,
      0x00, // Null terminator for MIME type
      0x03, // Picture type: Cover (front)
      0x00, // Empty description (null-terminated for ISO-8859-1)
      ...imageData,
    ];
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

  /// Maps common tag keys to ID3v2 frame IDs
  String _getFrameId(String tagKey) {
    switch (tagKey.toUpperCase()) {
      case 'TITLE':
        return 'TIT2';
      case 'ARTIST':
        return 'TPE1';
      case 'ALBUM':
        return 'TALB';
      case 'ALBUMARTIST':
        return 'TPE2';
      case 'DATE':
      case 'YEAR':
        return 'TDRC';
      case 'GENRE':
        return 'TCON';
      case 'TRACKNUMBER':
        return 'TRCK';
      case 'DISCNUMBER':
        return 'TPOS';
      case 'COMMENT':
        return 'COMM';
      case 'COMPOSER':
        return 'TCOM';
      case 'PERFORMER':
        return 'TPE3';
      case 'CONDUCTOR':
        return 'TPE3';
      case 'LYRICIST':
        return 'TEXT';
      case 'COPYRIGHT':
        return 'TCOP';
      case 'ENCODEDBY':
        return 'TENC';
      case 'BPM':
        return 'TBPM';
      case 'MOOD':
        return 'TMOO';
      case 'ISRC':
        return 'TSRC';
      case 'ALBUMART':
        return 'APIC';
      default:
        // For custom tags, use TXXX frame
        return 'TXXX';
    }
  }

  /// Reads a synchsafe integer (ID3v2 format)
  int _readSynchsafeInt(Uint8List bytes, int offset) {
    return (bytes[offset] << 21) |
        (bytes[offset + 1] << 14) |
        (bytes[offset + 2] << 7) |
        bytes[offset + 3];
  }

  /// Writes a synchsafe integer (ID3v2 format)
  List<int> _writeSynchsafeInt(int value) {
    return [
      (value >> 21) & 0x7F,
      (value >> 14) & 0x7F,
      (value >> 7) & 0x7F,
      value & 0x7F,
    ];
  }

}
