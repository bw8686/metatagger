import 'dart:convert';
import 'dart:typed_data';

import 'metadata_tag.dart';
import 'metadata_writer.dart';

/// WebM/Matroska metadata writer for text and numeric tags.
class WebmWriter extends MetadataWriter {
  @override
  List<String> get supportedExtensions => ['.webm'];

  @override
  bool supportsFile(String filePath) =>
      filePath.toLowerCase().endsWith('.webm');

  @override
  bool supportsBytes(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x1A &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xDF &&
      bytes[3] == 0xA3;

  @override
  Future<Uint8List> writeTagsToBytes(
    Uint8List bytes,
    List<MetadataTag> tags,
  ) async {
    if (!supportsBytes(bytes)) {
      throw const MetadataException('Not a WebM/EBML file');
    }
    if (tags.any((tag) => tag.type == TagType.binary)) {
      throw const MetadataException(
        'WebM does not support embedded artwork. Use OGG/Opus or MKV/MKA.',
      );
    }
    final segment = _find(
      bytes,
      const [0x18, 0x53, 0x80, 0x67],
      0,
      bytes.length,
    );
    if (segment == null) {
      throw const MetadataException('WebM segment not found');
    }
    final oldMetadata = <_Element>[];
    var scanOffset = segment.dataStart;
    var insertionOffset = segment.dataEnd;
    while (scanOffset < segment.dataEnd) {
      final element = _readElement(bytes, scanOffset, segment.dataEnd);
      if (element == null) break;
      if (_sameId(element.id, const [0x12, 0x54, 0xC3, 0x67])) {
        oldMetadata.add(element);
      } else if (_sameId(element.id, const [0x19, 0x41, 0xA4, 0x69])) {
        oldMetadata.add(element);
      }
      if (_sameId(element.id, const [0x1F, 0x43, 0xB6, 0x75])) {
        insertionOffset = element.offset;
        break;
      }
      scanOffset = element.end;
    }

    // Remove only tags found as valid top-level EBML elements. Searching raw
    // media payload for the Tags ID would mistake coincidental byte patterns
    // for metadata.
    final cleanData = <int>[];
    var offset = segment.dataStart;
    for (final oldElement in oldMetadata) {
      cleanData.addAll(bytes.sublist(offset, oldElement.offset));
      offset = oldElement.end;
    }
    cleanData.addAll(bytes.sublist(offset, segment.dataEnd));

    var removedBeforeInsertion = 0;
    for (final oldElement in oldMetadata) {
      if (oldElement.offset < insertionOffset) {
        removedBeforeInsertion +=
            (oldElement.end < insertionOffset
                ? oldElement.end
                : insertionOffset) -
            oldElement.offset;
      }
    }
    final insertionIndex =
        insertionOffset - segment.dataStart - removedBeforeInsertion;
    final metadata = <int>[];
    metadata.addAll(
      _element(const [0x12, 0x54, 0xC3, 0x67], _createTags(tags)),
    );
    cleanData.insertAll(insertionIndex, metadata);
    final segmentData = Uint8List.fromList(cleanData);
    final segmentHeader = _header(
      segment.id,
      segmentData.length,
      unknownSize: segment.size < 0,
    );
    return Uint8List.fromList([
      ...bytes.sublist(0, segment.offset),
      ...segmentHeader,
      ...segmentData,
      ...bytes.sublist(segment.end),
    ]);
  }

  List<int> _createTags(List<MetadataTag> tags) {
    final tagChildren = <int>[];
    final artwork = tags.where(
      (tag) =>
          tag.key.toUpperCase() == CommonTags.albumArt &&
          tag.type == TagType.binary &&
          tag.value is Uint8List,
    );
    for (final tag in tags) {
      if (tag.type == TagType.binary) {
        continue;
      }
      final name = utf8.encode(tag.key);
      final value = utf8.encode(tag.value.toString());
      final simpleTag = _element(
        const [0x67, 0xC8],
        [
          ..._element(const [0x45, 0xA3], name),
          ..._element(const [0x44, 0x87], value),
        ],
      );
      tagChildren.addAll(_element(const [0x73, 0x73], simpleTag));
    }
    if (artwork.isNotEmpty) {
      final image = artwork.first.value as Uint8List;
      final picture = base64.encode(_createPictureBlock(image));
      final simpleTag = _element(
        const [0x67, 0xC8],
        [
          ..._element(const [
            0x45,
            0xA3,
          ], utf8.encode('METADATA_BLOCK_PICTURE')),
          ..._element(const [0x44, 0x87], utf8.encode(picture)),
        ],
      );
      tagChildren.addAll(_element(const [0x73, 0x73], simpleTag));
    }
    return tagChildren;
  }

  List<int> _createPictureBlock(Uint8List image) {
    final mime = utf8.encode(_detectMimeType(image));
    final block = <int>[];
    block.addAll(_uint32(3)); // Front cover.
    block.addAll(_uint32(mime.length));
    block.addAll(mime);
    block.addAll(_uint32(0)); // Empty description.
    block.addAll(_uint32(0)); // Width (unknown).
    block.addAll(_uint32(0)); // Height (unknown).
    block.addAll(_uint32(0)); // Colour depth (unknown).
    block.addAll(_uint32(0)); // Number of colours (unknown).
    block.addAll(_uint32(image.length));
    block.addAll(image);
    return block;
  }

  List<int> _uint32(int value) => [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];

  String _detectMimeType(Uint8List image) {
    if (image.length >= 8 &&
        image[0] == 0x89 &&
        image[1] == 0x50 &&
        image[2] == 0x4E &&
        image[3] == 0x47) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  List<int> _element(List<int> id, List<int> data) => [
    ...id,
    ..._size(data.length),
    ...data,
  ];

  List<int> _header(List<int> id, int size, {required bool unknownSize}) => [
    ...id,
    ...(unknownSize
        ? [0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        : _size(size)),
  ];

  List<int> _size(int value) {
    for (var length = 1; length <= 8; length++) {
      final max = (1 << (7 * length)) - 2;
      if (value <= max) {
        final result = List.filled(length, 0);
        var remaining = value;
        for (var i = length - 1; i >= 0; i--) {
          result[i] = remaining & 0xFF;
          remaining >>= 8;
        }
        result[0] |= 1 << (8 - length);
        return result;
      }
    }
    throw ArgumentError('EBML element is too large');
  }

  _Element? _find(Uint8List bytes, List<int> id, int start, int end) {
    var offset = start;
    while (offset < end) {
      final element = _readElement(bytes, offset, end);
      if (element == null) return null;
      if (_sameId(element.id, id)) return element;
      offset = element.end;
    }
    return null;
  }

  _Element? _readElement(Uint8List bytes, int offset, int limit) {
    final idLength = _vintLength(bytes, offset, limit);
    if (idLength == 0) return null;
    final sizeOffset = offset + idLength;
    final sizeLength = _vintLength(bytes, sizeOffset, limit);
    if (sizeLength == 0) return null;
    final size = _vintValue(bytes, sizeOffset, sizeLength);
    final dataStart = sizeOffset + sizeLength;
    final dataEnd = size < 0 ? limit : dataStart + size;
    if (dataEnd > limit) return null;
    return _Element(
      bytes.sublist(offset, sizeOffset),
      offset,
      dataStart,
      dataEnd,
      size,
    );
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
    for (var i = 1; i < length; i++) {
      value = (value << 8) | bytes[offset + i];
    }
    return value == (1 << (7 * length)) - 1 ? -1 : value;
  }

  bool _sameId(List<int> a, List<int> b) =>
      a.length == b.length &&
      a.asMap().entries.every((entry) => entry.value == b[entry.key]);
}

class _Element {
  final List<int> id;
  final int offset;
  final int dataStart;
  final int dataEnd;
  final int end;
  final int size;
  const _Element(this.id, this.offset, this.dataStart, this.dataEnd, this.size)
    : end = dataEnd;
}
