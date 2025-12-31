import 'package:metatagger/metatagger.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

void main() {
  group('MetaTagger Tests', () {
    late MetaTagger tagger;
    late Directory tempDir;

    setUp(() async {
      tagger = MetaTagger();
      tempDir = await Directory.systemTemp.createTemp('metatagger_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should support MP3 and FLAC formats', () {
      expect(tagger.supportedExtensions, contains('.mp3'));
      expect(tagger.supportedExtensions, contains('.flac'));
      expect(tagger.supportedExtensions, contains('.mp4'));
      expect(tagger.supportedExtensions, contains('.m4a'));
    });

    test('should detect supported file formats', () {
      expect(tagger.isSupported('test.mp3'), isTrue);
      expect(tagger.isSupported('test.flac'), isTrue);
      expect(tagger.isSupported('test.mp4'), isTrue);
      expect(tagger.isSupported('test.m4a'), isTrue);
      expect(tagger.isSupported('test.wav'), isFalse);
    });

    test('should create metadata tags correctly', () {
      final textTag = MetadataTag.text('TITLE', 'Test Song');
      expect(textTag.key, equals('TITLE'));
      expect(textTag.value, equals('Test Song'));
      expect(textTag.type, equals(TagType.text));

      final numberTag = MetadataTag.number('TRACK', 1);
      expect(numberTag.key, equals('TRACK'));
      expect(numberTag.value, equals(1));
      expect(numberTag.type, equals(TagType.number));
    });

    test('should have common tag constants', () {
      expect(CommonTags.title, equals('TITLE'));
      expect(CommonTags.artist, equals('ARTIST'));
      expect(CommonTags.album, equals('ALBUM'));
    });

    group('MP3 Read/Write Tests', () {
      test('should write and read text tags from MP3', () async {
        final testFile = File('${tempDir.path}/test.mp3');

        // Create a minimal valid MP3 file
        await _createMinimalMp3(testFile);

        // Write tags
        final writeTags = [
          MetadataTag.text(CommonTags.title, 'Test Title'),
          MetadataTag.text(CommonTags.artist, 'Test Artist'),
          MetadataTag.text(CommonTags.album, 'Test Album'),
          MetadataTag.text(CommonTags.year, '2024'),
          MetadataTag.text(CommonTags.genre, 'Rock'),
          MetadataTag.text(CommonTags.track, '5'),
        ];

        await tagger.writeTags(testFile.path, writeTags);

        // Read tags back
        final readTags = await tagger.readTags(testFile.path);

        expect(
          readTags.any(
            (t) => t.key == CommonTags.title && t.value == 'Test Title',
          ),
          isTrue,
        );
        expect(
          readTags.any(
            (t) => t.key == CommonTags.artist && t.value == 'Test Artist',
          ),
          isTrue,
        );
        expect(
          readTags.any(
            (t) => t.key == CommonTags.album && t.value == 'Test Album',
          ),
          isTrue,
        );
        expect(
          readTags.any((t) => t.key == CommonTags.year && t.value == '2024'),
          isTrue,
        );
      });

      test('should write and read custom tags from MP3', () async {
        final testFile = File('${tempDir.path}/test_custom.mp3');
        await _createMinimalMp3(testFile);

        final customTag = MetadataTag.text('CUSTOM_FIELD', 'Custom Value');
        await tagger.writeTag(testFile.path, customTag);

        final readTags = await tagger.readTags(testFile.path);
        expect(
          readTags.any(
            (t) => t.key == 'CUSTOM_FIELD' && t.value == 'Custom Value',
          ),
          isTrue,
        );
      });

      test('should write and read album art from MP3', () async {
        final testFile = File('${tempDir.path}/test_art.mp3');
        await _createMinimalMp3(testFile);

        // Create a minimal JPEG (valid header)
        final albumArt = Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xE0,
          0x00,
          0x10,
          0x4A,
          0x46,
          0x49,
          0x46,
          0x00,
          0x01,
        ]);

        final artTag = MetadataTag.binary(CommonTags.albumArt, albumArt);
        await tagger.writeTag(testFile.path, artTag);

        final readTags = await tagger.readTags(testFile.path);
        final readArt = readTags.firstWhere(
          (t) => t.key == CommonTags.albumArt,
        );

        expect(readArt.type, equals(TagType.binary));
        expect((readArt.value as Uint8List).length, greaterThan(0));
      });

      test('should use writeCommonTags and readCommonTags for MP3', () async {
        final testFile = File('${tempDir.path}/test_common.mp3');
        await _createMinimalMp3(testFile);

        await tagger.writeCommonTags(testFile.path, {
          CommonTags.title: 'Common Title',
          CommonTags.artist: 'Common Artist',
          CommonTags.track: '3',
        });

        final tags = await tagger.readCommonTags(testFile.path);
        expect(tags[CommonTags.title], equals('Common Title'));
        expect(tags[CommonTags.artist], equals('Common Artist'));
        expect(tags[CommonTags.track], equals('3'));
      });

      test('should clear all tags from MP3', () async {
        final testFile = File('${tempDir.path}/test_clear.mp3');
        await _createMinimalMp3(testFile);

        // Write some tags
        await tagger.writeTag(
          testFile.path,
          MetadataTag.text(CommonTags.title, 'Title'),
        );

        // Verify tags exist
        var tags = await tagger.readTags(testFile.path);
        expect(tags.isNotEmpty, isTrue);

        // Clear tags
        await tagger.clearTags(testFile.path);

        // Verify tags are cleared
        tags = await tagger.readTags(testFile.path);
        expect(tags.isEmpty, isTrue);
      });
    });

    group('FLAC Read/Write Tests', () {
      test('should write and read text tags from FLAC', () async {
        final testFile = File('${tempDir.path}/test.flac');
        await _createMinimalFlac(testFile);

        final writeTags = [
          MetadataTag.text(CommonTags.title, 'FLAC Title'),
          MetadataTag.text(CommonTags.artist, 'FLAC Artist'),
          MetadataTag.text(CommonTags.album, 'FLAC Album'),
          MetadataTag.text(CommonTags.year, '2024'),
        ];

        await tagger.writeTags(testFile.path, writeTags);

        final readTags = await tagger.readTags(testFile.path);
        expect(
          readTags.any(
            (t) => t.key == CommonTags.title && t.value == 'FLAC Title',
          ),
          isTrue,
        );
        expect(
          readTags.any(
            (t) => t.key == CommonTags.artist && t.value == 'FLAC Artist',
          ),
          isTrue,
        );
      });

      test('should write and read custom tags from FLAC', () async {
        final testFile = File('${tempDir.path}/test_custom.flac');
        await _createMinimalFlac(testFile);

        final customTag = MetadataTag.text(
          'MY_CUSTOM_TAG',
          'Custom FLAC Value',
        );
        await tagger.writeTag(testFile.path, customTag);

        final readTags = await tagger.readTags(testFile.path);
        expect(
          readTags.any(
            (t) => t.key == 'MY_CUSTOM_TAG' && t.value == 'Custom FLAC Value',
          ),
          isTrue,
        );
      });

      test('should write and read album art from FLAC', () async {
        final testFile = File('${tempDir.path}/test_art.flac');
        await _createMinimalFlac(testFile);

        final albumArt = Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xE0,
          0x00,
          0x10,
        ]);

        final artTag = MetadataTag.binary(CommonTags.albumArt, albumArt);
        await tagger.writeTag(testFile.path, artTag);

        final readTags = await tagger.readTags(testFile.path);
        final readArt = readTags.firstWhere(
          (t) => t.key == CommonTags.albumArt,
        );

        expect(readArt.type, equals(TagType.binary));
        expect((readArt.value as Uint8List).length, greaterThan(0));
      });

      test('should use writeCommonTags and readCommonTags for FLAC', () async {
        final testFile = File('${tempDir.path}/test_common.flac');
        await _createMinimalFlac(testFile);

        await tagger.writeCommonTags(testFile.path, {
          CommonTags.title: 'FLAC Common Title',
          CommonTags.artist: 'FLAC Common Artist',
        });

        final tags = await tagger.readCommonTags(testFile.path);
        expect(tags[CommonTags.title], equals('FLAC Common Title'));
        expect(tags[CommonTags.artist], equals('FLAC Common Artist'));
      });
    });

    group('MP4 Read/Write Tests', () {
      test('should write and read text tags from MP4', () async {
        final testFile = File('${tempDir.path}/test.mp4');
        await _createMinimalMp4(testFile);

        final writeTags = [
          MetadataTag.text(CommonTags.title, 'MP4 Title'),
          MetadataTag.text(CommonTags.artist, 'MP4 Artist'),
          MetadataTag.text(CommonTags.album, 'MP4 Album'),
          MetadataTag.text(CommonTags.year, '2024'),
          MetadataTag.text(CommonTags.genre, 'Pop'),
        ];

        await tagger.writeTags(testFile.path, writeTags);

        final readTags = await tagger.readTags(testFile.path);

        // Debug: print what we got
        print('Read ${readTags.length} tags from MP4:');
        for (final tag in readTags) {
          print('  ${tag.key}: ${tag.value}');
        }

        expect(
          readTags.any(
            (t) => t.key == CommonTags.title && t.value == 'MP4 Title',
          ),
          isTrue,
        );
        expect(
          readTags.any(
            (t) => t.key == CommonTags.artist && t.value == 'MP4 Artist',
          ),
          isTrue,
        );
      });

      test('should write and read track numbers from MP4', () async {
        final testFile = File('${tempDir.path}/test_track.mp4');
        await _createMinimalMp4(testFile);

        await tagger.writeTag(
          testFile.path,
          MetadataTag.text(CommonTags.track, '5/12'),
        );

        final readTags = await tagger.readTags(testFile.path);
        expect(
          readTags.any((t) => t.key == CommonTags.track && t.value == '5/12'),
          isTrue,
        );
      });

      test('should write and read album art from MP4', () async {
        final testFile = File('${tempDir.path}/test_art.mp4');
        await _createMinimalMp4(testFile);

        final albumArt = Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xE0,
          0x00,
          0x10,
        ]);

        final artTag = MetadataTag.binary(CommonTags.albumArt, albumArt);
        await tagger.writeTag(testFile.path, artTag);

        final readTags = await tagger.readTags(testFile.path);
        final readArt = readTags.firstWhere(
          (t) => t.key == CommonTags.albumArt,
        );

        expect(readArt.type, equals(TagType.binary));
        expect((readArt.value as Uint8List).length, greaterThan(0));
      });

      test('should use writeCommonTags and readCommonTags for MP4', () async {
        final testFile = File('${tempDir.path}/test_common.mp4');
        await _createMinimalMp4(testFile);

        await tagger.writeCommonTags(testFile.path, {
          CommonTags.title: 'MP4 Common Title',
          CommonTags.artist: 'MP4 Common Artist',
        });

        final tags = await tagger.readCommonTags(testFile.path);
        expect(tags[CommonTags.title], equals('MP4 Common Title'));
        expect(tags[CommonTags.artist], equals('MP4 Common Artist'));
      });
    });

    group('Error Handling Tests', () {
      test('should throw exception for non-existent file', () async {
        expect(
          () => tagger.readTags('nonexistent.mp3'),
          throwsA(isA<MetadataException>()),
        );
      });

      test('should throw exception for unsupported format', () async {
        final testFile = File('${tempDir.path}/test.wav');
        await testFile.writeAsBytes([0x52, 0x49, 0x46, 0x46]); // WAV header

        expect(
          () => tagger.readTags(testFile.path),
          throwsA(isA<MetadataException>()),
        );
      });
    });
  });
}

/// Creates a minimal valid MP3 file for testing
Future<void> _createMinimalMp3(File file) async {
  // Minimal MP3: MPEG-1 Layer 3, 128kbps, 44.1kHz, Mono
  // This is a valid MP3 frame header followed by some data
  final mp3Data = Uint8List.fromList([
    // MP3 Frame header
    0xFF, 0xFB, 0x90, 0x00,
    // Padding with zeros (minimal audio data)
    ...List.filled(100, 0),
  ]);

  await file.writeAsBytes(mp3Data);
}

/// Creates a minimal valid FLAC file for testing
Future<void> _createMinimalFlac(File file) async {
  final flacData = <int>[];

  // FLAC signature
  flacData.addAll([0x66, 0x4C, 0x61, 0x43]); // "fLaC"

  // STREAMINFO block (type 0, required, last block for now)
  flacData.add(0x80); // Last block flag + type 0

  // Block size (34 bytes for STREAMINFO)
  flacData.addAll([0x00, 0x00, 0x22]);

  // STREAMINFO data (simplified)
  flacData.addAll([
    0x00, 0x10, // Min block size
    0x00, 0x10, // Max block size
    0x00, 0x00, 0x00, // Min frame size (0 = unknown)
    0x00, 0x00, 0x00, // Max frame size (0 = unknown)
    0x0A,
    0xC4,
    0x42,
    0xF0,
    0x00,
    0x00,
    0x00,
    0x00, // Sample rate, channels, etc.
    ...List.filled(16, 0), // MD5 signature
  ]);

  await file.writeAsBytes(Uint8List.fromList(flacData));
}

/// Creates a minimal valid MP4 file for testing
Future<void> _createMinimalMp4(File file) async {
  final mp4Data = <int>[];

  // ftyp atom (file type)
  final ftypData = [
    ...utf8.encode('isom'), // major brand
    0x00, 0x00, 0x02, 0x00, // minor version
    ...utf8.encode('isom'), // compatible brand
    ...utf8.encode('iso2'),
    ...utf8.encode('mp41'),
  ];
  mp4Data.addAll(_wrapAtom('ftyp', ftypData));

  // moov atom (movie header)
  final moovContent = <int>[];

  // mvhd atom (movie header)
  final mvhdData = [
    0x00, 0x00, 0x00, 0x00, // version + flags
    ...List.filled(24, 0), // creation/modification time, timescale, duration
    0x00, 0x01, 0x00, 0x00, // rate
    0x01, 0x00, // volume
    0x00, 0x00, // reserved
    ...List.filled(8, 0), // reserved
    ...List.filled(36, 0), // matrix
    ...List.filled(24, 0), // pre_defined
    0x00, 0x00, 0x00, 0x02, // next_track_ID
  ];
  moovContent.addAll(_wrapAtom('mvhd', mvhdData));

  mp4Data.addAll(_wrapAtom('moov', moovContent));

  // mdat atom (media data) - empty for testing
  mp4Data.addAll(_wrapAtom('mdat', []));

  await file.writeAsBytes(Uint8List.fromList(mp4Data));
}

/// Wraps data in an MP4 atom
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
