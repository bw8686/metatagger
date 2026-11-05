import 'dart:io';
import 'dart:typed_data';

import 'package:metatagger/metatagger.dart';
import 'package:test/test.dart';

void main() {
  group('Opus support', () {
    test('recognizes .opus files', () {
      expect(OpusReader().supportsFile('audio.opus'), isTrue);
      expect(OpusWriter().supportsFile('audio.opus'), isTrue);
      expect(OpusReader().supportedExtensions, contains('.opus'));
      expect(OpusWriter().supportedExtensions, contains('.opus'));
      expect(MetaTagger().isSupported('audio.opus'), isTrue);
    });

    test('writes and reads tags in example.opus', () async {
      final sourceFile = File('example/example.opus');
      if (!await sourceFile.exists()) {
        markTestSkipped('example/example.opus not found');
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'metatagger_opus_test_',
      );
      final testFile = File('${tempDir.path}/example.opus');
      try {
        await sourceFile.copy(testFile.path);
        final tagger = MetaTagger();
        await tagger.writeCommonTags(testFile.path, {
          CommonTags.title: 'Opus Test Title',
          CommonTags.artist: 'Opus Test Artist',
          CommonTags.album: 'Opus Test Album',
          CommonTags.year: '2026',
        });

        final tags = await tagger.readCommonTags(testFile.path);
        expect(tags[CommonTags.title], equals('Opus Test Title'));
        expect(tags[CommonTags.artist], equals('Opus Test Artist'));
        expect(tags[CommonTags.album], equals('Opus Test Album'));
        expect(tags[CommonTags.year], equals('2026'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects artwork for WebM-contained Opus files', () async {
      final sourceFile = File('example/example.opus');
      if (!await sourceFile.exists()) {
        markTestSkipped('example/example.opus not found');
        return;
      }
      final bytes = await sourceFile.readAsBytes();
      if (!OpusReader().supportsBytes(bytes) || bytes[0] != 0x1A) {
        markTestSkipped('example.opus is not WebM-contained Opus');
        return;
      }
      expect(
        () => OpusWriter().writeTagsToBytes(bytes, [
          MetadataTag.binary(
            CommonTags.albumArt,
            Uint8List.fromList([1, 2, 3]),
          ),
        ]),
        throwsA(isA<MetadataException>()),
      );
    });
  });
}
