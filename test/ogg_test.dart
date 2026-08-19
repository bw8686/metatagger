import 'package:metatagger/metatagger.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() {
  group('OggReader', () {
    test('supportsFile returns true for .ogg files', () {
      final reader = OggReader();
      expect(reader.supportsFile('test.ogg'), isTrue);
      expect(reader.supportsFile('test.OGG'), isTrue);
      expect(reader.supportsFile('test.mp3'), isFalse);
    });

    test('supportedExtensions includes .ogg', () {
      final reader = OggReader();
      expect(reader.supportedExtensions, contains('.ogg'));
    });
  });

  group('OggWriter', () {
    test('supportsFile returns true for .ogg files', () {
      final writer = OggWriter();
      expect(writer.supportsFile('test.ogg'), isTrue);
      expect(writer.supportsFile('test.OGG'), isTrue);
      expect(writer.supportsFile('test.mp3'), isFalse);
    });

    test('supportedExtensions includes .ogg', () {
      final writer = OggWriter();
      expect(writer.supportedExtensions, contains('.ogg'));
    });
  });

  group('Ogg Integration', () {
    late File sourceFile;
    late File testFile;
    final tagger = MetaTagger();

    setUp(() async {
      sourceFile = File('example/example.ogg');
      testFile = File('example/test_integration.ogg');
      if (await sourceFile.exists()) {
        await sourceFile.copy(testFile.path);
      }
    });

    tearDown(() async {
      if (await testFile.exists()) {
        await testFile.delete();
      }
    });

    test('write and read tags successfully', () async {
      if (!await sourceFile.exists()) {
        markTestSkipped('example/example.ogg not found');
        return;
      }

      await tagger.writeCommonTags(testFile.path, {
        CommonTags.title: 'Test Title',
        CommonTags.artist: 'Test Artist',
        CommonTags.album: 'Test Album',
        CommonTags.year: '2024',
        CommonTags.genre: 'Test Genre',
      });

      final tags = await tagger.readCommonTags(testFile.path);

      expect(tags[CommonTags.title], equals('Test Title'));
      expect(tags[CommonTags.artist], equals('Test Artist'));
      expect(tags[CommonTags.album], equals('Test Album'));
      expect(tags[CommonTags.year], equals('2024'));
      expect(tags[CommonTags.genre], equals('Test Genre'));
    });
  });

  group('MetaTagger', () {
    test('recognizes .ogg format', () {
      final tagger = MetaTagger();
      expect(tagger.supportedExtensions, contains('.ogg'));
    });
  });
}
