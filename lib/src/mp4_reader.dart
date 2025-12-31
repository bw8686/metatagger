import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'metadata_reader.dart';
import 'metadata_tag.dart';

/// MP4/M4A metadata reader (iTunes-style metadata)
class Mp4Reader extends MetadataReader {
  @override
  List<String> get supportedExtensions => ['.mp4', '.m4a', '.m4v', '.m4b'];

  @override
  bool supportsFile(String filePath) {
    final lower = filePath.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.m4b');
  }

  @override
  Future<List<MetadataTag>> readTags(String filePath) async {
    await validateFile(filePath);

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    return _parseMp4Metadata(bytes);
  }

  /// Parses MP4 metadata
  List<MetadataTag> _parseMp4Metadata(Uint8List bytes) {
    final tags = <MetadataTag>[];

    // Find moov atom
    final moovAtom = _findAtom(bytes, 'moov');
    if (moovAtom == null) return tags;

    // Find udta atom within moov
    final udtaAtom = _findAtom(moovAtom, 'udta');
    if (udtaAtom == null) return tags;

    // Find meta atom within udta
    final metaAtom = _findAtom(udtaAtom, 'meta');
    if (metaAtom == null) return tags;

    // Skip version + flags (4 bytes) and any atoms before ilst
    final metaContent = metaAtom.sublist(4);

    // Find ilst atom within meta
    final ilstAtom = _findAtom(metaContent, 'ilst');
    if (ilstAtom == null) return tags;

    // Parse items in ilst
    tags.addAll(_parseIlstItems(ilstAtom));

    return tags;
  }

  /// Finds an atom by type in data
  Uint8List? _findAtom(Uint8List data, String atomType) {
    int offset = 0;

    while (offset + 8 <= data.length) {
      final size = _readUint32(data, offset);
      if (size < 8) break;
      if (offset + size > data.length) break;

      // Use Latin-1 to properly read atom names
      final type = latin1.decode(data.sublist(offset + 4, offset + 8));

      if (type == atomType) {
        // Return atom data (without size and type header)
        return data.sublist(offset + 8, offset + size);
      }

      offset += size;
    }

    return null;
  }

  /// Parses items in ilst atom
  List<MetadataTag> _parseIlstItems(Uint8List ilstData) {
    final tags = <MetadataTag>[];
    int offset = 0;

    while (offset + 8 <= ilstData.length) {
      final size = _readUint32(ilstData, offset);

      if (size < 8) break;
      if (offset + size > ilstData.length) break;

      // Use Latin-1 to properly read the atom name (© is 0xA9 in Latin-1)
      final atomName = latin1.decode(ilstData.sublist(offset + 4, offset + 8));
      final atomData = ilstData.sublist(offset + 8, offset + size);

      final tag = _parseMetadataItem(atomName, atomData);
      if (tag != null) {
        tags.add(tag);
      }

      offset += size;
    }

    return tags;
  }

  /// Parses a metadata item
  MetadataTag? _parseMetadataItem(String atomName, Uint8List data) {
    // Find data atom within the item
    final dataAtom = _findAtom(data, 'data');
    if (dataAtom == null || dataAtom.length < 8) return null;

    // Data atom format: version(1) + flags(3) + type indicator + locale(4) + actual data
    final dataType = dataAtom[3]; // Type is in the flags field
    final content = dataAtom.sublist(8); // Skip version, flags, locale

    final tagKey = _atomNameToTagKey(atomName);
    if (tagKey.isEmpty) return null;

    // Parse based on data type
    if (atomName == 'covr') {
      // Album art
      return MetadataTag.binary(CommonTags.albumArt, content);
    } else if (atomName == 'trkn' || atomName == 'disk') {
      // Track/disc number
      return _parseTrackDiscNumber(tagKey, content);
    } else if (dataType == 0x01 || dataType == 0x00) {
      // UTF-8 or UTF-16 text
      try {
        final text = utf8.decode(content).trim();
        return text.isNotEmpty ? MetadataTag.text(tagKey, text) : null;
      } catch (e) {
        return null;
      }
    } else if (dataType == 0x15) {
      // Signed integer
      if (content.length >= 4) {
        final value = _readUint32(content, 0);
        return MetadataTag.number(tagKey, value);
      }
    }

    // Try to decode as text for other types
    try {
      final text = utf8.decode(content).trim();
      return text.isNotEmpty ? MetadataTag.text(tagKey, text) : null;
    } catch (e) {
      return null;
    }
  }

  /// Parses track or disc number
  MetadataTag? _parseTrackDiscNumber(String tagKey, Uint8List data) {
    if (data.length < 6) return null;

    try {
      // Format: 2 bytes reserved, 2 bytes current, 2 bytes total, 2 bytes reserved
      final current = (data[2] << 8) | data[3];
      final total = data.length >= 6 ? ((data[4] << 8) | data[5]) : 0;

      if (current == 0) return null;

      final value = total > 0 ? '$current/$total' : '$current';
      return MetadataTag.text(tagKey, value);
    } catch (e) {
      return null;
    }
  }

  /// Maps MP4 atom names to common tag keys
  String _atomNameToTagKey(String atomName) {
    switch (atomName) {
      case '©nam':
        return CommonTags.title;
      case '©ART':
        return CommonTags.artist;
      case '©alb':
        return CommonTags.album;
      case 'aART':
        return CommonTags.albumArtist;
      case '©day':
        return CommonTags.year;
      case '©gen':
        return CommonTags.genre;
      case 'trkn':
        return CommonTags.track;
      case 'disk':
        return CommonTags.disc;
      case '©cmt':
        return CommonTags.comment;
      case '©wrt':
        return CommonTags.composer;
      case '©too':
        return CommonTags.encodedBy;
      case 'cprt':
        return CommonTags.copyright;
      case '©lyr':
        return CommonTags.lyrics;
      case 'covr':
        return CommonTags.albumArt;
      case 'tmpo':
        return CommonTags.bpm;
      default:
        return atomName; // Return atom name for unknown tags
    }
  }

  /// Reads a 32-bit unsigned integer (big-endian)
  int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}
