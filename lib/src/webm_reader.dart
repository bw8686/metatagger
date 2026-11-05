// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:typed_data';

import 'metadata_reader.dart';
import 'metadata_tag.dart';

/// WebM/Matroska metadata reader.
///
/// WebM stores user metadata in EBML `Tags`/`SimpleTag` elements. This reader
/// intentionally ignores the media elements and only parses those tags.
class WebmReader extends MetadataReader {
  @override
  List<String> get supportedExtensions => ['.webm'];

  @override
  bool supportsFile(String filePath) =>
      filePath.toLowerCase().endsWith('.webm');

  @override
  Future<List<MetadataTag>> readTagsFromBytes(Uint8List bytes) async {
    final tags = <MetadataTag>[];
    final segment = _findElement(bytes, 0, bytes.length, const [
      0x18,
      0x53,
      0x80,
      0x67,
    ]);
    if (segment == null) return tags;

    _walk(bytes, segment.dataStart, segment.dataEnd, tags);
    // A Cluster may use an unknown EBML size, so a strictly hierarchical
    // walk can consume the remainder of the Segment. Fall back to locating
    // the well-known Tags element directly for those files.
    if (tags.isEmpty) {
      for (
        var offset = segment.dataStart;
        offset + 4 <= segment.dataEnd;
        offset++
      ) {
        if (_sameId(bytes.sublist(offset, offset + 4), const [
          0x12,
          0x54,
          0xC3,
          0x67,
        ])) {
          final element = _readElement(bytes, offset, segment.dataEnd);
          if (element != null)
            _parseTags(bytes, element.dataStart, element.dataEnd, tags);
        } else if (_sameId(bytes.sublist(offset, offset + 4), const [
          0x19,
          0x41,
          0xA4,
          0x69,
        ])) {
          final element = _readElement(bytes, offset, segment.dataEnd);
          if (element != null) {
            _parseAttachments(bytes, element.dataStart, element.dataEnd, tags);
          }
        }
      }
    }
    return tags;
  }

  @override
  bool supportsBytes(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3;
  }

  void _walk(Uint8List bytes, int start, int end, List<MetadataTag> result) {
    var offset = start;
    while (offset < end) {
      final element = _readElement(bytes, offset, end);
      if (element == null) break;
      if (_sameId(element.id, const [0x12, 0x54, 0xC3, 0x67])) {
        _parseTags(bytes, element.dataStart, element.dataEnd, result);
      } else if (_sameId(element.id, const [0x19, 0x41, 0xA4, 0x69])) {
        _parseAttachments(bytes, element.dataStart, element.dataEnd, result);
      }
      offset = element.end;
    }
  }

  void _parseAttachments(
    Uint8List bytes,
    int start,
    int end,
    List<MetadataTag> result,
  ) {
    var offset = start;
    while (offset < end) {
      final attachedFile = _readElement(bytes, offset, end);
      if (attachedFile == null) break;
      if (_sameId(attachedFile.id, const [0x61, 0xA7])) {
        var childOffset = attachedFile.dataStart;
        while (childOffset < attachedFile.dataEnd) {
          final child = _readElement(bytes, childOffset, attachedFile.dataEnd);
          if (child == null) break;
          if (_sameId(child.id, const [0x46, 0x5C])) {
            result.add(
              MetadataTag.binary(
                CommonTags.albumArt,
                Uint8List.fromList(
                  bytes.sublist(child.dataStart, child.dataEnd),
                ),
              ),
            );
            break;
          }
          childOffset = child.end;
        }
      }
      offset = attachedFile.end;
    }
  }

  void _parseTags(
    Uint8List bytes,
    int start,
    int end,
    List<MetadataTag> result,
  ) {
    var offset = start;
    while (offset < end) {
      final tag = _readElement(bytes, offset, end);
      if (tag == null) break;
      if (_sameId(tag.id, const [0x73, 0x73])) {
        var childOffset = tag.dataStart;
        while (childOffset < tag.dataEnd) {
          final simple = _readElement(bytes, childOffset, tag.dataEnd);
          if (simple == null) break;
          if (_sameId(simple.id, const [0x67, 0xC8])) {
            final parsed = _parseSimpleTag(
              bytes,
              simple.dataStart,
              simple.dataEnd,
            );
            if (parsed != null) result.add(parsed);
          }
          childOffset = simple.end;
        }
      }
      offset = tag.end;
    }
  }

  MetadataTag? _parseSimpleTag(Uint8List bytes, int start, int end) {
    var offset = start;
    String? name;
    String? value;
    while (offset < end) {
      final element = _readElement(bytes, offset, end);
      if (element == null) break;
      if (_sameId(element.id, const [0x45, 0xA3])) {
        name = utf8.decode(
          bytes.sublist(element.dataStart, element.dataEnd),
          allowMalformed: true,
        );
      } else if (_sameId(element.id, const [0x44, 0x87])) {
        value = utf8.decode(
          bytes.sublist(element.dataStart, element.dataEnd),
          allowMalformed: true,
        );
      }
      offset = element.end;
    }
    if (name == null || value == null || name.isEmpty) return null;
    if (name.toUpperCase() == 'METADATA_BLOCK_PICTURE') {
      try {
        final picture = base64.decode(value);
        return MetadataTag.binary(
          CommonTags.albumArt,
          Uint8List.fromList(_extractPictureData(picture)),
        );
      } catch (_) {
        return null;
      }
    }
    return MetadataTag.text(_normaliseName(name), value);
  }

  List<int> _extractPictureData(List<int> picture) {
    var offset = 0;
    final type = _readUint32(picture, offset);
    if (type == null) throw const FormatException('Invalid picture block');
    offset += 4;
    final mimeLength = _readUint32(picture, offset);
    if (mimeLength == null)
      throw const FormatException('Invalid picture block');
    offset += 4 + mimeLength;
    final descriptionLength = _readUint32(picture, offset);
    if (descriptionLength == null)
      throw const FormatException('Invalid picture block');
    offset += 4 + descriptionLength;
    offset += 16; // width, height, depth, and colour count
    final dataLength = _readUint32(picture, offset);
    if (dataLength == null || offset + 4 + dataLength > picture.length) {
      throw const FormatException('Invalid picture block');
    }
    offset += 4;
    return picture.sublist(offset, offset + dataLength);
  }

  int? _readUint32(List<int> bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) return null;
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  String _normaliseName(String name) {
    switch (name.toUpperCase()) {
      case 'TITLE':
        return CommonTags.title;
      case 'ARTIST':
        return CommonTags.artist;
      case 'ALBUM':
        return CommonTags.album;
      case 'ALBUMARTIST':
        return CommonTags.albumArtist;
      case 'DATE':
      case 'YEAR':
        return CommonTags.year;
      case 'GENRE':
        return CommonTags.genre;
      case 'TRACK':
      case 'TRACKNUMBER':
        return CommonTags.track;
      case 'DISC':
      case 'DISCNUMBER':
        return CommonTags.disc;
      case 'COMMENT':
        return CommonTags.comment;
      case 'COMPOSER':
        return CommonTags.composer;
      case 'PERFORMER':
        return CommonTags.performer;
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
      case 'LYRICS':
        return CommonTags.lyrics;
      default:
        return name;
    }
  }

  _EbmlElement? _findElement(
    Uint8List bytes,
    int start,
    int end,
    List<int> id,
  ) {
    var offset = start;
    while (offset < end) {
      final element = _readElement(bytes, offset, end);
      if (element == null) return null;
      if (_sameId(element.id, id)) return element;
      offset = element.end;
    }
    return null;
  }

  _EbmlElement? _readElement(Uint8List bytes, int offset, int limit) {
    final idLength = _vintLength(bytes, offset, limit);
    if (idLength == 0 || offset + idLength >= limit) return null;
    final id = bytes.sublist(offset, offset + idLength);
    final sizeLength = _vintLength(bytes, offset + idLength, limit);
    if (sizeLength == 0) return null;
    final size = _vintValue(bytes, offset + idLength, sizeLength);
    final dataStart = offset + idLength + sizeLength;
    final dataEnd = size < 0 ? limit : dataStart + size;
    if (dataEnd > limit) return null;
    return _EbmlElement(id, dataStart, dataEnd, dataEnd);
  }

  int _vintLength(Uint8List bytes, int offset, int limit) {
    if (offset >= limit) return 0;
    var mask = 0x80;
    for (var length = 1; length <= 8; length++, mask >>= 1) {
      if ((bytes[offset] & mask) != 0) return length;
    }
    return 0;
  }

  int _vintValue(Uint8List bytes, int offset, int length) {
    var value = bytes[offset] & (0xFF >> length);
    for (var i = 1; i < length; i++) value = (value << 8) | bytes[offset + i];
    final allOnes = (1 << (7 * length)) - 1;
    return value == allOnes ? -1 : value;
  }

  bool _sameId(List<int> a, List<int> b) =>
      a.length == b.length &&
      a.asMap().entries.every((entry) => entry.value == b[entry.key]);
}

class _EbmlElement {
  final List<int> id;
  final int dataStart;
  final int dataEnd;
  final int end;
  const _EbmlElement(this.id, this.dataStart, this.dataEnd, this.end);
}
