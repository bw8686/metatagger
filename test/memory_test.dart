import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:metatagger/metatagger.dart';

void main() {
  group('Memory Parsing (Uint8List)', () {
    late MetaTagger tagger;

    setUp(() {
      tagger = MetaTagger();
    });

    test('MP3 Memory Read/Write', () async {
      final mp3Data = Uint8List.fromList([
        0xFF, 0xFB, 0x90, 0x00,
        ...List.filled(100, 0),
      ]);
      var bytes = mp3Data;

      // Add tags to memory
      final newTags = [
        MetadataTag.text(CommonTags.title, 'Memory Title MP3'),
        MetadataTag.text(CommonTags.artist, 'Memory Artist'),
      ];
      bytes = await tagger.writeTagsToBytes(bytes, newTags);

      // Read tags from memory
      final readTags = await tagger.readTagsFromBytes(bytes);
      expect(readTags.any((t) => t.key == CommonTags.title && t.value == 'Memory Title MP3'), isTrue);
      expect(readTags.any((t) => t.key == CommonTags.artist && t.value == 'Memory Artist'), isTrue);
    });

    test('FLAC Memory Read/Write', () async {
      final flacData = <int>[
        0x66, 0x4C, 0x61, 0x43, // fLaC
        0x80, // Last block flag + type 0
        0x00, 0x00, 0x22, // Block size
        0x00, 0x10, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x0A, 0xC4, 0x42, 0xF0, 0x00, 0x00, 0x00, 0x00,
        ...List.filled(16, 0),
      ];
      var bytes = Uint8List.fromList(flacData);

      final newTags = [
        MetadataTag.text(CommonTags.title, 'Memory Title FLAC'),
        MetadataTag.text(CommonTags.artist, 'Memory Artist'),
      ];
      bytes = await tagger.writeTagsToBytes(bytes, newTags);

      final readTags = await tagger.readTagsFromBytes(bytes);
      expect(readTags.any((t) => t.key == CommonTags.title && t.value == 'Memory Title FLAC'), isTrue);
      expect(readTags.any((t) => t.key == CommonTags.artist && t.value == 'Memory Artist'), isTrue);
    });

    test('MP4 Memory Read/Write', () async {
      final mp4Data = <int>[];
      final ftypData = [
        ...utf8.encode('isom'),
        0x00, 0x00, 0x02, 0x00,
        ...utf8.encode('isom'),
        ...utf8.encode('iso2'),
        ...utf8.encode('mp41'),
      ];
      mp4Data.addAll(_wrapAtom('ftyp', ftypData));

      final moovContent = <int>[];
      final mvhdData = [
        0x00, 0x00, 0x00, 0x00,
        ...List.filled(24, 0),
        0x00, 0x01, 0x00, 0x00,
        0x01, 0x00,
        0x00, 0x00,
        ...List.filled(8, 0),
        ...List.filled(36, 0),
        ...List.filled(24, 0),
        0x00, 0x00, 0x00, 0x02,
      ];
      moovContent.addAll(_wrapAtom('mvhd', mvhdData));
      mp4Data.addAll(_wrapAtom('moov', moovContent));
      mp4Data.addAll(_wrapAtom('mdat', []));
      var bytes = Uint8List.fromList(mp4Data);

      final newTags = [
        MetadataTag.text(CommonTags.title, 'Memory Title MP4'),
        MetadataTag.text(CommonTags.artist, 'Memory Artist'),
      ];
      bytes = await tagger.writeTagsToBytes(bytes, newTags);

      final readTags = await tagger.readTagsFromBytes(bytes);
      expect(readTags.any((t) => t.key == CommonTags.title && t.value == 'Memory Title MP4'), isTrue);
      expect(readTags.any((t) => t.key == CommonTags.artist && t.value == 'Memory Artist'), isTrue);
    });

    test('OGG Memory Read/Write', () async {
      final oggFile = File('example/example.ogg');
      if (!await oggFile.exists()) {
        markTestSkipped('example/example.ogg not found');
        return;
      }
      var bytes = await oggFile.readAsBytes();

      final newTags = [
        MetadataTag.text(CommonTags.title, 'Memory Title OGG'),
        MetadataTag.text(CommonTags.artist, 'Memory Artist'),
      ];
      bytes = await tagger.writeTagsToBytes(bytes, newTags);

      final readTags = await tagger.readTagsFromBytes(bytes);
      expect(readTags.any((t) => t.key == CommonTags.title && t.value == 'Memory Title OGG'), isTrue);
      expect(readTags.any((t) => t.key == CommonTags.artist && t.value == 'Memory Artist'), isTrue);
    });
  });
}

List<int> _wrapAtom(String type, List<int> data) {
  final size = 8 + data.length;
  return [
    (size >> 24) & 0xFF,
    (size >> 16) & 0xFF,
    (size >> 8) & 0xFF,
    size & 0xFF,
    ...utf8.encode(type),
    ...data,
  ];
}
