import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'metadata_writer.dart';
import 'metadata_tag.dart';

/// MP4/M4A metadata writer (iTunes-style metadata)
class Mp4Writer extends MetadataWriter {
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
  Future<void> writeTags(String filePath, List<MetadataTag> tags) async {
    await validateFile(filePath);

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final newBytes = await writeTagsToBytes(bytes, tags);
    await file.writeAsBytes(newBytes);
  }

  @override
  Future<Uint8List> writeTagsToBytes(Uint8List bytes, List<MetadataTag> tags) async {
    // Parse MP4 structure
    final mp4Data = _parseMp4File(bytes);
    if (mp4Data == null) {
      throw MetadataException('Invalid MP4 file format', 'MemoryBuffer');
    }

    // Create new metadata atom
    final metaAtom = _createMetadataAtom(tags);

    // Replace or add metadata in moov.udta
    return _replaceMetadata(mp4Data, metaAtom);
  }

  @override
  Future<void> clearTags(String filePath) async {
    await writeTags(filePath, []);
  }

  @override
  bool supportsBytes(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // Check for ftyp atom at offset 4
    return bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70;
  }

  /// Parses MP4 file structure
  _Mp4Data? _parseMp4File(Uint8List bytes) {
    final atoms = <_Atom>[];
    int offset = 0;

    while (offset < bytes.length) {
      if (offset + 8 > bytes.length) break;

      final size = _readUint32(bytes, offset);
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));

      if (size < 8 || offset + size > bytes.length) break;

      final data = bytes.sublist(offset + 8, offset + size);
      atoms.add(_Atom(type: type, data: data, size: size));

      offset += size;
    }

    return _Mp4Data(atoms: atoms);
  }

  /// Creates metadata atom (moov.udta.meta.ilst)
  Uint8List _createMetadataAtom(List<MetadataTag> tags) {
    final items = <List<int>>[];

    for (final tag in tags) {
      final item = _createMetadataItem(tag);
      if (item.isNotEmpty) {
        items.add(item);
      }
    }

    // Build ilst atom
    final ilst = <int>[];
    for (final item in items) {
      ilst.addAll(item);
    }

    // Wrap in meta atom structure
    // meta atom has: version(1) + flags(3) + hdlr atom + ilst atom
    final hdlr = _createHdlrAtom();
    final metaContent = <int>[
      0x00, 0x00, 0x00, 0x00, // version + flags
      ...hdlr,
      ..._wrapAtom('ilst', Uint8List.fromList(ilst)),
    ];

    return Uint8List.fromList(
      _wrapAtom('meta', Uint8List.fromList(metaContent)),
    );
  }

  /// Creates hdlr atom (required in meta atom)
  List<int> _createHdlrAtom() {
    final hdlrData = <int>[
      0x00, 0x00, 0x00, 0x00, // version + flags
      0x00, 0x00, 0x00, 0x00, // pre_defined
      ...latin1.encode('mdir'), // handler_type - use Latin-1
      ...latin1.encode('appl'), // manufacturer - use Latin-1
      0x00, 0x00, 0x00, 0x00, // reserved
      0x00, 0x00, 0x00, 0x00, // reserved
      0x00, 0x00, 0x00, 0x00, // reserved
      0x00, // name (empty, null-terminated)
    ];
    return _wrapAtom('hdlr', Uint8List.fromList(hdlrData));
  }

  /// Creates a metadata item
  List<int> _createMetadataItem(MetadataTag tag) {
    final atomName = _getAtomName(tag.key);

    // Check if this is a custom tag (not in standard iTunes atoms)
    final isCustomTag = _isCustomTag(tag.key);

    if (isCustomTag) {
      // Use freeform ---- atom for custom tags
      return _createFreeformAtom(tag);
    }

    List<int> dataAtom;

    // For track/disc numbers, always use special binary format
    if (tag.key == CommonTags.track || tag.key == CommonTags.disc) {
      dataAtom = _createTrackDiscData(tag.value.toString());
    } else if (tag.type == TagType.binary && tag.key == CommonTags.albumArt) {
      dataAtom = _createDataAtom(tag.value as Uint8List, 0x0D); // 0x0D = JPEG
    } else if (tag.type == TagType.number) {
      dataAtom = _createDataAtom(
        Uint8List.fromList(utf8.encode(tag.value.toString())),
        0x01, // UTF-8 text
      );
    } else {
      // Text data
      dataAtom = _createDataAtom(
        Uint8List.fromList(utf8.encode(tag.value.toString())),
        0x01, // UTF-8 text
      );
    }

    return _wrapAtom(atomName, Uint8List.fromList(dataAtom));
  }

  /// Creates data atom
  List<int> _createDataAtom(Uint8List content, int dataType) {
    final dataContent = <int>[
      0x00, 0x00, 0x00, dataType, // version + flags + data type
      0x00, 0x00, 0x00, 0x00, // locale
      ...content,
    ];
    return _wrapAtom('data', Uint8List.fromList(dataContent));
  }

  /// Creates track/disc number data
  List<int> _createTrackDiscData(String value) {
    // Parse "3" or "3/12" format
    final parts = value.split('/');
    final current = int.tryParse(parts[0].trim()) ?? 0;
    final total = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;

    // Data atom format: version(1) + flags(3) + locale(4) + actual data
    final dataContent = <int>[
      0x00, 0x00, 0x00, 0x00, // version + flags (with type 0x00 for implicit)
      0x00, 0x00, 0x00, 0x00, // locale
      0x00, 0x00, // reserved
      (current >> 8) & 0xFF, current & 0xFF, // current track/disc
      (total >> 8) & 0xFF, total & 0xFF, // total tracks/discs
      0x00, 0x00, // reserved
    ];
    return _wrapAtom('data', Uint8List.fromList(dataContent));
  }

  /// Wraps content in an atom with size and type
  List<int> _wrapAtom(String type, Uint8List content) {
    final size = 8 + content.length;
    return [
      ..._writeUint32(size),
      ...latin1.encode(type), // Use Latin-1 for atom names (© is 0xA9)
      ...content,
    ];
  }

  /// Replaces metadata in MP4 structure
  Uint8List _replaceMetadata(_Mp4Data mp4Data, Uint8List metaAtom) {
    final result = <int>[];
    bool foundMoov = false;

    for (final atom in mp4Data.atoms) {
      if (atom.type == 'moov') {
        foundMoov = true;
        final newMoov = _updateMoovAtom(atom.data, metaAtom);
        result.addAll(_wrapAtom('moov', newMoov));
      } else {
        // Copy atom with its original header (size + type + data)
        result.addAll([
          (atom.size >> 24) & 0xFF,
          (atom.size >> 16) & 0xFF,
          (atom.size >> 8) & 0xFF,
          atom.size & 0xFF,
        ]);
        result.addAll(latin1.encode(atom.type)); // Use Latin-1
        result.addAll(atom.data);
      }
    }

    if (!foundMoov) {
      throw MetadataException('Invalid MP4: moov atom not found');
    }

    return Uint8List.fromList(result);
  }

  /// Updates moov atom with new metadata
  Uint8List _updateMoovAtom(Uint8List moovData, Uint8List metaAtom) {
    final atoms = _parseAtoms(moovData);
    final result = <int>[];
    bool foundUdta = false;

    for (final atom in atoms) {
      if (atom.type == 'udta') {
        foundUdta = true;
        final newUdta = _updateUdtaAtom(atom.data, metaAtom);
        result.addAll(_wrapAtom('udta', newUdta));
      } else {
        // Keep existing atom with its data
        result.addAll([
          (atom.size >> 24) & 0xFF,
          (atom.size >> 16) & 0xFF,
          (atom.size >> 8) & 0xFF,
          atom.size & 0xFF,
        ]);
        result.addAll(latin1.encode(atom.type)); // Use Latin-1
        result.addAll(atom.data);
      }
    }

    // If no udta, create one
    if (!foundUdta) {
      result.addAll(_wrapAtom('udta', metaAtom));
    }

    return Uint8List.fromList(result);
  }

  /// Updates udta atom with new metadata
  Uint8List _updateUdtaAtom(Uint8List udtaData, Uint8List metaAtom) {
    final atoms = _parseAtoms(udtaData);
    final result = <int>[];
    bool foundMeta = false;

    for (final atom in atoms) {
      if (atom.type == 'meta') {
        foundMeta = true;
        // Replace with new meta
        result.addAll(metaAtom);
      } else {
        // Keep existing atom with its data
        result.addAll([
          (atom.size >> 24) & 0xFF,
          (atom.size >> 16) & 0xFF,
          (atom.size >> 8) & 0xFF,
          atom.size & 0xFF,
        ]);
        result.addAll(latin1.encode(atom.type)); // Use Latin-1
        result.addAll(atom.data);
      }
    }

    // If no meta, add it
    if (!foundMeta) {
      result.addAll(metaAtom);
    }

    return Uint8List.fromList(result);
  }

  /// Parses atoms from data
  List<_Atom> _parseAtoms(Uint8List data) {
    final atoms = <_Atom>[];
    int offset = 0;

    while (offset < data.length) {
      if (offset + 8 > data.length) break;

      final size = _readUint32(data, offset);
      if (size < 8 || offset + size > data.length) break;

      final type = String.fromCharCodes(data.sublist(offset + 4, offset + 8));
      final atomData = data.sublist(offset + 8, offset + size);

      atoms.add(_Atom(type: type, data: atomData, size: size));
      offset += size;
    }

    return atoms;
  }

  /// Checks if a tag is a custom tag (not a standard iTunes atom)
  bool _isCustomTag(String tagKey) {
    final standardTags = {
      'TITLE',
      'ARTIST',
      'ALBUM',
      'ALBUMARTIST',
      'DATE',
      'YEAR',
      'GENRE',
      'TRACKNUMBER',
      'DISCNUMBER',
      'COMMENT',
      'COMPOSER',
      'ENCODEDBY',
      'COPYRIGHT',
      'LYRICS',
      'ALBUMART',
      'BPM',
    };
    return !standardTags.contains(tagKey.toUpperCase());
  }

  /// Creates a freeform ---- atom for custom tags
  List<int> _createFreeformAtom(MetadataTag tag) {
    // Freeform atom structure:
    // ---- atom
    //   mean atom (namespace)
    //   name atom (tag name)
    //   data atom (value)

    final namespace = 'com.apple.iTunes';

    // Create mean atom (namespace)
    final meanContent = <int>[
      0x00, 0x00, 0x00, 0x00, // version + flags
      ...utf8.encode(namespace),
    ];
    final meanAtom = _wrapAtom('mean', Uint8List.fromList(meanContent));

    // Create name atom (tag name)
    final nameContent = <int>[
      0x00, 0x00, 0x00, 0x00, // version + flags
      ...utf8.encode(tag.key),
    ];
    final nameAtom = _wrapAtom('name', Uint8List.fromList(nameContent));

    // Create data atom (value)
    List<int> dataAtom;
    if (tag.type == TagType.binary) {
      dataAtom = _createDataAtom(tag.value as Uint8List, 0x00);
    } else if (tag.type == TagType.number) {
      dataAtom = _createDataAtom(
        Uint8List.fromList(utf8.encode(tag.value.toString())),
        0x01,
      );
    } else {
      dataAtom = _createDataAtom(
        Uint8List.fromList(utf8.encode(tag.value.toString())),
        0x01,
      );
    }

    // Combine into ---- atom
    final freeformContent = <int>[...meanAtom, ...nameAtom, ...dataAtom];

    return _wrapAtom('----', Uint8List.fromList(freeformContent));
  }

  /// Maps common tag keys to MP4 atom names
  String _getAtomName(String tagKey) {
    switch (tagKey.toUpperCase()) {
      case 'TITLE':
        return '©nam';
      case 'ARTIST':
        return '©ART';
      case 'ALBUM':
        return '©alb';
      case 'ALBUMARTIST':
        return 'aART';
      case 'DATE':
      case 'YEAR':
        return '©day';
      case 'GENRE':
        return '©gen';
      case 'TRACKNUMBER':
        return 'trkn';
      case 'DISCNUMBER':
        return 'disk';
      case 'COMMENT':
        return '©cmt';
      case 'COMPOSER':
        return '©wrt';
      case 'ENCODEDBY':
        return '©too';
      case 'COPYRIGHT':
        return 'cprt';
      case 'LYRICS':
        return '©lyr';
      case 'ALBUMART':
        return 'covr';
      case 'BPM':
        return 'tmpo';
      default:
        // Return the tag key itself for custom tags (will use freeform atom)
        return tagKey;
    }
  }

  /// Reads a 32-bit unsigned integer (big-endian)
  int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  /// Writes a 32-bit unsigned integer (big-endian)
  List<int> _writeUint32(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}

/// Represents MP4 file structure
class _Mp4Data {
  final List<_Atom> atoms;

  _Mp4Data({required this.atoms});
}

/// Represents an MP4 atom
class _Atom {
  final String type;
  final Uint8List data;
  final int size;

  _Atom({required this.type, required this.data, required this.size});
}
