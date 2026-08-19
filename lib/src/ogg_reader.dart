import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'metadata_reader.dart';
import 'metadata_tag.dart';

/// OGG Vorbis Comment metadata reader
class OggReader extends MetadataReader {
  @override
  List<String> get supportedExtensions => ['.ogg'];

  @override
  bool supportsFile(String filePath) {
    return filePath.toLowerCase().endsWith('.ogg');
  }

  @override
  Future<List<MetadataTag>> readTags(String filePath) async {
    await validateFile(filePath);

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    return _parseOggMetadata(bytes);
  }

  List<MetadataTag> _parseOggMetadata(Uint8List bytes) {
    // Find the Vorbis Comment packet
    final commentPacket = _extractVorbisCommentPacket(bytes);
    if (commentPacket == null) return [];

    return _parseVorbisComment(commentPacket);
  }

  Uint8List? _extractVorbisCommentPacket(Uint8List bytes) {
    int offset = 0;
    List<int> currentPacket = [];
    bool isVorbisComment = false;

    while (offset < bytes.length - 27) {
      if (bytes[offset] != 0x4F ||
          bytes[offset + 1] != 0x67 ||
          bytes[offset + 2] != 0x67 ||
          bytes[offset + 3] != 0x53) {
        // Not OggS, search for next OggS
        offset++;
        continue;
      }

      int headerType = bytes[offset + 5];
      int pageSegments = bytes[offset + 26];
      int segmentTableOffset = offset + 27;

      if (segmentTableOffset + pageSegments > bytes.length) break;

      int dataOffset = segmentTableOffset + pageSegments;

      for (int i = 0; i < pageSegments; i++) {
        int segmentLength = bytes[segmentTableOffset + i];

        if (dataOffset + segmentLength > bytes.length) return null;

        // If it's a new packet
        if (currentPacket.isEmpty) {
          if (segmentLength > 7 &&
              bytes[dataOffset] == 0x03 &&
              bytes[dataOffset + 1] == 0x76 && // v
              bytes[dataOffset + 2] == 0x6F && // o
              bytes[dataOffset + 3] == 0x72 && // r
              bytes[dataOffset + 4] == 0x62 && // b
              bytes[dataOffset + 5] == 0x69 && // i
              bytes[dataOffset + 6] == 0x73) {
            // s
            isVorbisComment = true;
          } else {
            isVorbisComment = false;
          }
        }

        if (isVorbisComment) {
          currentPacket.addAll(
            bytes.sublist(dataOffset, dataOffset + segmentLength),
          );
        }

        dataOffset += segmentLength;

        // If segment length is < 255, it's the end of the packet
        if (segmentLength < 255) {
          if (isVorbisComment) {
            // Strip the 7-byte header (0x03 'vorbis') before returning
            return Uint8List.fromList(currentPacket.sublist(7));
          }
          currentPacket.clear();
        }
      }

      offset = dataOffset;
    }

    return null;
  }

  List<MetadataTag> _parseVorbisComment(Uint8List blockData) {
    final tags = <MetadataTag>[];

    if (blockData.length < 8) return tags;

    int offset = 0;

    // Read vendor string length
    final vendorLength = _readInt32LE(blockData, offset);
    offset += 4;

    if (offset + vendorLength > blockData.length) return tags;

    // Skip vendor string
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
      final comment = utf8.decode(commentBytes, allowMalformed: true);

      // Parse field=value format
      final separatorIndex = comment.indexOf('=');
      if (separatorIndex > 0) {
        final fieldName = comment.substring(0, separatorIndex).toUpperCase();
        final value = comment.substring(separatorIndex + 1);

        final tagKey = _vorbisFieldToTagKey(fieldName);

        // Handle METADATA_BLOCK_PICTURE for Album Art
        if (fieldName == 'METADATA_BLOCK_PICTURE') {
          try {
            final decodedPicture = base64Decode(value);
            final pictureTag = _parsePictureBlock(decodedPicture);
            if (pictureTag != null) {
              tags.add(pictureTag);
            }
          } catch (_) {
            // Invalid base64 or picture block, ignore
          }
        } else {
          tags.add(MetadataTag.text(tagKey, value));
        }
      }

      offset += commentLength;
    }

    return tags;
  }

  MetadataTag? _parsePictureBlock(Uint8List blockData) {
    if (blockData.length < 32) return null;

    try {
      int offset = 0;

      // Skip picture type
      offset += 4;

      // Read MIME type length
      final mimeLength = _readInt32BE(blockData, offset);
      offset += 4;

      if (offset + mimeLength > blockData.length) return null;

      // Skip MIME type
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
        return fieldName;
    }
  }

  int _readInt32LE(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  int _readInt32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}
