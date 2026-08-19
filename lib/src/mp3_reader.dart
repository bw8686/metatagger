import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'metadata_reader.dart';
import 'metadata_tag.dart';

/// MP3 ID3v2 metadata reader
class Mp3Reader extends MetadataReader {
  @override
  List<String> get supportedExtensions => ['.mp3'];

  @override
  bool supportsFile(String filePath) {
    return filePath.toLowerCase().endsWith('.mp3');
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
    return _parseId3v2Tag(bytes);
  }

  @override
  bool supportsBytes(Uint8List bytes) {
    if (bytes.length < 3) return false;
    // Check for ID3v2 header
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) return true;
    
    // Check for MP3 frame sync word (11 bits set to 1)
    if (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) return true;
    
    return false;
  }

  /// Parses ID3v2 tag from MP3 data
  List<MetadataTag> _parseId3v2Tag(Uint8List bytes) {
    final tags = <MetadataTag>[];

    if (bytes.length < 10) return tags;

    // Check for ID3v2 header
    if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
      return tags; // No ID3v2 tag found
    }

    final majorVersion = bytes[3];
    // final minorVersion = bytes[4];
    final flags = bytes[5];
    final tagSize = _readSynchsafeInt(bytes, 6);

    // We support ID3v2.3 and ID3v2.4
    if (majorVersion < 3 || majorVersion > 4) {
      return tags; // Unsupported version
    }

    // Check for extended header
    int frameOffset = 10;
    if ((flags & 0x40) != 0) {
      // Extended header present
      final extHeaderSize = majorVersion == 4
          ? _readSynchsafeInt(bytes, frameOffset)
          : _readInt32BE(bytes, frameOffset);
      frameOffset += extHeaderSize;
    }

    // Parse frames
    final tagEnd = 10 + tagSize;
    while (frameOffset + 10 <= tagEnd) {
      // Read frame header
      final frameId = String.fromCharCodes(bytes.skip(frameOffset).take(4));

      // Check for padding (null bytes)
      if (frameId[0] == '\x00') break;

      final frameSize = majorVersion == 4
          ? _readSynchsafeInt(bytes, frameOffset + 4)
          : _readInt32BE(bytes, frameOffset + 4);

      // final frameFlags = (bytes[frameOffset + 8] << 8) | bytes[frameOffset + 9];

      frameOffset += 10;

      if (frameOffset + frameSize > bytes.length ||
          frameOffset + frameSize > tagEnd) {
        break;
      }

      final frameData = bytes.sublist(frameOffset, frameOffset + frameSize);

      // Parse frame content
      final tag = _parseFrame(frameId, frameData, majorVersion);
      if (tag != null) {
        tags.add(tag);
      }

      frameOffset += frameSize;
    }

    return tags;
  }

  /// Parses an individual ID3v2 frame
  MetadataTag? _parseFrame(String frameId, Uint8List frameData, int version) {
    if (frameData.isEmpty) return null;

    // Handle text frames
    if (frameId.startsWith('T') && frameId != 'TXXX') {
      return _parseTextFrame(frameId, frameData);
    }

    // Handle custom text frames (TXXX)
    if (frameId == 'TXXX') {
      return _parseTXXXFrame(frameData);
    }

    // Handle comment frames (COMM)
    if (frameId == 'COMM') {
      return _parseCommentFrame(frameData);
    }

    // Handle picture frames (APIC)
    if (frameId == 'APIC') {
      return _parsePictureFrame(frameData);
    }

    return null;
  }

  /// Parses a text frame
  MetadataTag? _parseTextFrame(String frameId, Uint8List frameData) {
    if (frameData.isEmpty) return null;

    final encoding = frameData[0];
    final textBytes = frameData.sublist(1);

    final text = _decodeText(textBytes, encoding);
    if (text.isEmpty) return null;

    final tagKey = _frameIdToTagKey(frameId);
    return MetadataTag.text(tagKey, text);
  }

  /// Parses a TXXX (custom text) frame
  MetadataTag? _parseTXXXFrame(Uint8List frameData) {
    if (frameData.length < 2) return null;

    final encoding = frameData[0];
    final data = frameData.sublist(1);

    // Find the null separator between description and value
    int separatorIndex = -1;
    if (encoding == 0 || encoding == 3) {
      // ISO-8859-1 or UTF-8: single-byte null
      separatorIndex = data.indexOf(0);
    } else if (encoding == 1 || encoding == 2) {
      // UTF-16: double-byte null
      for (int i = 0; i < data.length - 1; i++) {
        if (data[i] == 0 && data[i + 1] == 0) {
          separatorIndex = i;
          break;
        }
      }
    }

    if (separatorIndex == -1) return null;

    final descriptionBytes = data.sublist(0, separatorIndex);
    final nullSize = (encoding == 1 || encoding == 2) ? 2 : 1;
    final valueBytes = data.sublist(separatorIndex + nullSize);

    final description = _decodeText(descriptionBytes, encoding);
    final value = _decodeText(valueBytes, encoding);

    if (description.isEmpty || value.isEmpty) return null;

    return MetadataTag.text(description, value);
  }

  /// Parses a COMM (comment) frame
  MetadataTag? _parseCommentFrame(Uint8List frameData) {
    if (frameData.length < 4) return null;

    final encoding = frameData[0];
    // Skip language (3 bytes)
    final data = frameData.sublist(4);

    // Find the null separator between description and actual comment
    int separatorIndex = -1;
    if (encoding == 0 || encoding == 3) {
      separatorIndex = data.indexOf(0);
    } else if (encoding == 1 || encoding == 2) {
      for (int i = 0; i < data.length - 1; i++) {
        if (data[i] == 0 && data[i + 1] == 0) {
          separatorIndex = i;
          break;
        }
      }
    }

    if (separatorIndex == -1) {
      // No separator, treat all as comment
      final comment = _decodeText(data, encoding);
      return comment.isEmpty
          ? null
          : MetadataTag.text(CommonTags.comment, comment);
    }

    final nullSize = (encoding == 1 || encoding == 2) ? 2 : 1;
    final commentBytes = data.sublist(separatorIndex + nullSize);
    final comment = _decodeText(commentBytes, encoding);

    return comment.isEmpty
        ? null
        : MetadataTag.text(CommonTags.comment, comment);
  }

  /// Parses an APIC (picture) frame
  MetadataTag? _parsePictureFrame(Uint8List frameData) {
    if (frameData.length < 2) return null;

    try {
      final encoding = frameData[0];
      int offset = 1;

      // Read MIME type (null-terminated)
      int mimeEnd = offset;
      while (mimeEnd < frameData.length && frameData[mimeEnd] != 0) {
        mimeEnd++;
      }
      // final mimeType = String.fromCharCodes(frameData.sublist(offset, mimeEnd));
      offset = mimeEnd + 1; // Skip null terminator

      if (offset >= frameData.length) return null;

      // Read picture type
      // final pictureType = frameData[offset];
      offset++;

      if (offset >= frameData.length) return null;

      // Read description (null-terminated based on encoding)
      int descEnd = offset;
      if (encoding == 0 || encoding == 3) {
        // Single-byte encoding
        while (descEnd < frameData.length && frameData[descEnd] != 0) {
          descEnd++;
        }
        offset = descEnd + 1;
      } else {
        // UTF-16
        while (descEnd < frameData.length - 1) {
          if (frameData[descEnd] == 0 && frameData[descEnd + 1] == 0) {
            break;
          }
          descEnd += 2;
        }
        offset = descEnd + 2;
      }

      if (offset >= frameData.length) return null;

      // Rest is picture data
      final pictureData = Uint8List.fromList(frameData.sublist(offset));

      return MetadataTag.binary(CommonTags.albumArt, pictureData);
    } catch (e) {
      return null;
    }
  }

  /// Decodes text based on encoding
  String _decodeText(Uint8List bytes, int encoding) {
    if (bytes.isEmpty) return '';

    try {
      switch (encoding) {
        case 0: // ISO-8859-1
          return latin1.decode(bytes).trim();
        case 1: // UTF-16 with BOM
          return _decodeUtf16(bytes);
        case 2: // UTF-16BE without BOM
          return _decodeUtf16BE(bytes);
        case 3: // UTF-8
          return utf8.decode(bytes).trim();
        default:
          return latin1.decode(bytes).trim();
      }
    } catch (e) {
      return '';
    }
  }

  /// Decodes UTF-16 with BOM
  String _decodeUtf16(Uint8List bytes) {
    if (bytes.length < 2) return '';

    // Check BOM
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // Little-endian
      return _decodeUtf16LE(bytes.sublist(2));
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // Big-endian
      return _decodeUtf16BE(bytes.sublist(2));
    } else {
      // No BOM, assume little-endian
      return _decodeUtf16LE(bytes);
    }
  }

  /// Decodes UTF-16LE
  String _decodeUtf16LE(Uint8List bytes) {
    final units = <int>[];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      units.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return String.fromCharCodes(units).trim();
  }

  /// Decodes UTF-16BE
  String _decodeUtf16BE(Uint8List bytes) {
    final units = <int>[];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      units.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units).trim();
  }

  /// Maps ID3v2 frame IDs to common tag keys
  String _frameIdToTagKey(String frameId) {
    switch (frameId) {
      case 'TIT2':
        return CommonTags.title;
      case 'TPE1':
        return CommonTags.artist;
      case 'TALB':
        return CommonTags.album;
      case 'TPE2':
        return CommonTags.albumArtist;
      case 'TDRC':
      case 'TYER': // ID3v2.3
        return CommonTags.year;
      case 'TCON':
        return CommonTags.genre;
      case 'TRCK':
        return CommonTags.track;
      case 'TPOS':
        return CommonTags.disc;
      case 'TCOM':
        return CommonTags.composer;
      case 'TPE3':
        return CommonTags.performer;
      case 'TEXT':
        return CommonTags.lyricist;
      case 'TCOP':
        return CommonTags.copyright;
      case 'TENC':
        return CommonTags.encodedBy;
      case 'TBPM':
        return CommonTags.bpm;
      case 'TMOO':
        return CommonTags.mood;
      case 'TSRC':
        return CommonTags.isrc;
      default:
        return frameId;
    }
  }

  /// Reads a synchsafe integer (ID3v2 format)
  int _readSynchsafeInt(Uint8List bytes, int offset) {
    return (bytes[offset] << 21) |
        (bytes[offset + 1] << 14) |
        (bytes[offset + 2] << 7) |
        bytes[offset + 3];
  }

  /// Reads a 32-bit big-endian integer
  int _readInt32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}
