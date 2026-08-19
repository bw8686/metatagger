import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'metadata_writer.dart';
import 'metadata_tag.dart';
import 'crc32.dart';

class _OggPage {
  int version;
  int headerType;
  Uint8List granulePosition; // 8 bytes
  Uint8List serialNumber; // 4 bytes
  int sequenceNumber; // 4 bytes
  Uint8List crcChecksum; // 4 bytes
  int pageSegments;
  List<int> segmentTable;
  Uint8List packetData;

  _OggPage({
    required this.version,
    required this.headerType,
    required this.granulePosition,
    required this.serialNumber,
    required this.sequenceNumber,
    required this.crcChecksum,
    required this.pageSegments,
    required this.segmentTable,
    required this.packetData,
  });

  Uint8List serialize() {
    final bytes = BytesBuilder();
    bytes.add([0x4F, 0x67, 0x67, 0x53]); // OggS
    bytes.addByte(version);
    bytes.addByte(headerType);
    bytes.add(granulePosition);
    bytes.add(serialNumber);
    bytes.add(_writeInt32LE(sequenceNumber));
    bytes.add([0, 0, 0, 0]); // Blank CRC
    bytes.addByte(segmentTable.length);
    bytes.add(segmentTable);
    bytes.add(packetData);

    final pageBytes = bytes.toBytes();
    final crc = OggCrc32.calculate(pageBytes);
    final crcBytes = _writeInt32LE(crc);

    // Patch CRC
    pageBytes[22] = crcBytes[0];
    pageBytes[23] = crcBytes[1];
    pageBytes[24] = crcBytes[2];
    pageBytes[25] = crcBytes[3];

    return pageBytes;
  }

  static List<int> _writeInt32LE(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }
}

/// OGG Vorbis Comment metadata writer
class OggWriter extends MetadataWriter {
  @override
  List<String> get supportedExtensions => ['.ogg'];

  @override
  bool supportsFile(String filePath) {
    return filePath.toLowerCase().endsWith('.ogg');
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
    final textTags = tags
        .where((tag) => tag.key != CommonTags.albumArt)
        .toList();
    final albumArtTags = tags
        .where((tag) => tag.key == CommonTags.albumArt)
        .toList();

    final vorbisComment = _createVorbisCommentPacket(textTags, albumArtTags);
    final newOggData = _replaceVorbisCommentInOgg(bytes, vorbisComment);

    if (newOggData != null) {
      return newOggData;
    } else {
      throw MetadataException(
        'Failed to write Ogg tags: Could not parse Ogg stream.',
        'MemoryBuffer',
      );
    }
  }

  @override
  Future<void> clearTags(String filePath) async {
    await writeTags(filePath, []);
  }

  @override
  bool supportsBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Check for OggS signature
    return bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53;
  }

  Uint8List _createVorbisCommentPacket(
    List<MetadataTag> textTags,
    List<MetadataTag> albumArtTags,
  ) {
    final comments = <String>[];
    final vendor = 'MetaTagger Dart Library';

    for (final tag in textTags) {
      if (tag.type == TagType.binary) continue;
      final fieldName = _getVorbisFieldName(tag.key);
      if (fieldName.isNotEmpty) {
        comments.add('$fieldName=${tag.value}');
      }
    }

    for (final artTag in albumArtTags) {
      if (artTag.value is Uint8List) {
        final pictureBlock = _createPictureBlock(artTag.value as Uint8List);
        final base64Picture = base64Encode(pictureBlock);
        comments.add('METADATA_BLOCK_PICTURE=$base64Picture');
      }
    }

    final vendorBytes = utf8.encode(vendor);
    final commentData = <int>[];

    commentData.add(0x03);
    commentData.addAll(utf8.encode('vorbis'));

    commentData.addAll(_writeInt32LE(vendorBytes.length));
    commentData.addAll(vendorBytes);

    commentData.addAll(_writeInt32LE(comments.length));

    for (final comment in comments) {
      final commentBytes = utf8.encode(comment);
      commentData.addAll(_writeInt32LE(commentBytes.length));
      commentData.addAll(commentBytes);
    }

    commentData.add(1); // Framing bit

    return Uint8List.fromList(commentData);
  }

  List<int> _createPictureBlock(Uint8List imageData) {
    final mimeType = _detectMimeType(imageData);
    final mimeBytes = utf8.encode(mimeType);
    final description = utf8.encode('');

    final pictureData = <int>[];

    pictureData.addAll(_writeInt32BE(3));
    pictureData.addAll(_writeInt32BE(mimeBytes.length));
    pictureData.addAll(mimeBytes);
    pictureData.addAll(_writeInt32BE(description.length));
    pictureData.addAll(description);
    pictureData.addAll(_writeInt32BE(0));
    pictureData.addAll(_writeInt32BE(0));
    pictureData.addAll(_writeInt32BE(0));
    pictureData.addAll(_writeInt32BE(0));
    pictureData.addAll(_writeInt32BE(imageData.length));
    pictureData.addAll(imageData);

    return pictureData;
  }

  String _detectMimeType(Uint8List imageData) {
    if (imageData.length >= 2) {
      if (imageData[0] == 0xFF && imageData[1] == 0xD8) return 'image/jpeg';
      if (imageData.length >= 8 && imageData[0] == 0x89 && imageData[1] == 0x50)
        return 'image/png';
    }
    return 'image/jpeg';
  }

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
        return tagKey.toUpperCase();
    }
  }

  List<int> _writeInt32LE(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  List<int> _writeInt32BE(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  int _readInt32LE(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  Uint8List? _replaceVorbisCommentInOgg(
    Uint8List bytes,
    Uint8List newVorbisComment,
  ) {
    final pages = _parseOggPages(bytes);
    if (pages.isEmpty) return null;

    // We only process the first logical bitstream.
    final serialNumber = pages.first.serialNumber;

    // Find packets in the first few pages
    // Packet 0: Identification (1 page usually)
    // Packet 1: Comment (1 or more pages)
    // Packet 2: Setup (1 or more pages, but often shares a page with Comment)

    int packetCount = 0;
    int headerPagesCount = 0;
    List<int> setupPacketBytes = [];

    bool foundSetupPacket = false;

    // Extract setup packet and identify how many pages make up the headers
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      // Only process our stream
      if (!_listEquals(page.serialNumber, serialNumber)) continue;

      int dataOffset = 0;
      for (int segIdx = 0; segIdx < page.segmentTable.length; segIdx++) {
        int segLen = page.segmentTable[segIdx];

        // If it's a new packet start
        if (segIdx == 0 && (page.headerType & 0x01) == 0 && packetCount > 0) {
          // Packet started on this page (if packetCount > 0)
        }

        if (packetCount == 2) {
          setupPacketBytes.addAll(
            page.packetData.sublist(dataOffset, dataOffset + segLen),
          );
        }

        dataOffset += segLen;

        if (segLen < 255) {
          packetCount++;
          if (packetCount == 3) {
            foundSetupPacket = true;
            headerPagesCount = i + 1; // All pages up to here are headers
            break;
          }
        }
      }

      if (foundSetupPacket) {
        if (dataOffset < page.packetData.length) {
          // The setup packet finished, but there's more data on this page (audio packets).
          // To safely rewrite, we would need to extract those audio packets and re-paginate them.
          // In Vorbis, the setup packet usually ends a page, but if it doesn't, we must preserve the trailing data.
          // For simplicity, we assume audio packets start on the next page. If not, this simple writer might fail.
          // A robust implementation would extract all packets and re-paginate.
        }
        break;
      }
    }

    if (!foundSetupPacket) return null;

    final setupPacket = Uint8List.fromList(setupPacketBytes);

    // Keep page 0 (Identification)
    final idPage = pages[0];

    // Generate new header pages for Comment + Setup
    final newHeaderPages = _createHeaderPages(
      serialNumber,
      idPage.sequenceNumber + 1,
      newVorbisComment,
      setupPacket,
    );

    int nextSequenceNumber = idPage.sequenceNumber + 1 + newHeaderPages.length;

    // Update sequence numbers for audio pages
    final audioPages = pages.sublist(headerPagesCount);
    for (final page in audioPages) {
      if (_listEquals(page.serialNumber, serialNumber)) {
        page.sequenceNumber = nextSequenceNumber++;
      }
    }

    // Build the final stream
    final outBytes = BytesBuilder();
    outBytes.add(idPage.serialize());
    for (final p in newHeaderPages) {
      outBytes.add(p.serialize());
    }
    for (final p in audioPages) {
      outBytes.add(p.serialize());
    }

    return outBytes.toBytes();
  }

  List<_OggPage> _createHeaderPages(
    Uint8List serialNumber,
    int startSequence,
    Uint8List commentPacket,
    Uint8List setupPacket,
  ) {
    final List<_OggPage> pages = [];
    int sequenceNumber = startSequence;

    // We can combine Comment and Setup into pages.
    // Each segment is max 255 bytes. Max segments per page is 255 (65025 bytes).

    List<int> currentSegmentTable = [];
    List<int> currentPacketData = [];
    int currentHeaderType = 0; // 0 for normal, 1 for continuation

    void flushPage([bool force = false]) {
      if (currentSegmentTable.isEmpty) return;

      pages.add(
        _OggPage(
          version: 0,
          headerType: currentHeaderType,
          granulePosition: Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0]),
          serialNumber: serialNumber,
          sequenceNumber: sequenceNumber++,
          crcChecksum: Uint8List(4),
          pageSegments: currentSegmentTable.length,
          segmentTable: List.from(currentSegmentTable),
          packetData: Uint8List.fromList(currentPacketData),
        ),
      );

      currentSegmentTable.clear();
      currentPacketData.clear();
      currentHeaderType =
          1; // Next page will be a continuation if we are in the middle of a packet
    }

    void writePacket(Uint8List packet) {
      int offset = 0;
      currentHeaderType = 0; // New packet starts
      if (currentSegmentTable.isNotEmpty && currentSegmentTable.last < 255) {
        // If the previous packet ended on this page, the new packet starts on the same page.
        // We don't need headerType = 1.
      } else if (currentSegmentTable.isNotEmpty) {
        // Should not happen if we manage segments correctly
      }

      while (offset < packet.length) {
        int remaining = packet.length - offset;
        int chunk = remaining >= 255 ? 255 : remaining;

        currentSegmentTable.add(chunk);
        currentPacketData.addAll(packet.sublist(offset, offset + chunk));
        offset += chunk;

        if (currentSegmentTable.length == 255) {
          flushPage();
        }
      }

      // Add a 0-length segment if the packet length is an exact multiple of 255
      if (packet.length % 255 == 0) {
        if (currentSegmentTable.length == 255) flushPage();
        currentSegmentTable.add(0);
      }
    }

    writePacket(commentPacket);
    writePacket(setupPacket);
    flushPage(); // Flush the last page

    return pages;
  }

  List<_OggPage> _parseOggPages(Uint8List bytes) {
    final pages = <_OggPage>[];
    int offset = 0;

    while (offset < bytes.length - 27) {
      if (bytes[offset] != 0x4F ||
          bytes[offset + 1] != 0x67 ||
          bytes[offset + 2] != 0x67 ||
          bytes[offset + 3] != 0x53) {
        offset++;
        continue;
      }

      int version = bytes[offset + 4];
      int headerType = bytes[offset + 5];
      Uint8List granulePos = bytes.sublist(offset + 6, offset + 14);
      Uint8List serial = bytes.sublist(offset + 14, offset + 18);
      int seqNum = _readInt32LE(bytes, offset + 18);
      Uint8List crc = bytes.sublist(offset + 22, offset + 26);
      int pageSegments = bytes[offset + 26];

      int segmentTableOffset = offset + 27;
      if (segmentTableOffset + pageSegments > bytes.length) break;

      List<int> segmentTable = [];
      int dataLength = 0;
      for (int i = 0; i < pageSegments; i++) {
        int segLen = bytes[segmentTableOffset + i];
        segmentTable.add(segLen);
        dataLength += segLen;
      }

      int dataOffset = segmentTableOffset + pageSegments;
      if (dataOffset + dataLength > bytes.length) break;

      Uint8List packetData = bytes.sublist(dataOffset, dataOffset + dataLength);

      pages.add(
        _OggPage(
          version: version,
          headerType: headerType,
          granulePosition: granulePos,
          serialNumber: serial,
          sequenceNumber: seqNum,
          crcChecksum: crc,
          pageSegments: pageSegments,
          segmentTable: segmentTable,
          packetData: packetData,
        ),
      );

      offset = dataOffset + dataLength;
    }

    return pages;
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
