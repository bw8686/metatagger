import 'dart:io';
import 'dart:typed_data';

import 'package:metatagger/metatagger.dart';
import 'package:test/test.dart';

void main() {
  group('WebM support', () {
    test('reader and writer recognize .webm files', () {
      expect(WebmReader().supportsFile('audio.webm'), isTrue);
      expect(WebmReader().supportsFile('audio.WEBM'), isTrue);
      expect(WebmWriter().supportsFile('audio.webm'), isTrue);
      expect(WebmReader().supportedExtensions, contains('.webm'));
      expect(WebmWriter().supportedExtensions, contains('.webm'));
    });

    test('writes and reads tags in the example WebM file', () async {
      final sourceFile = File('example/example.webm');
      if (!await sourceFile.exists()) {
        markTestSkipped('example/example.webm not found');
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'metatagger_webm_test_',
      );
      final testFile = File('${tempDir.path}/example.webm');
      try {
        await sourceFile.copy(testFile.path);
        final tagger = MetaTagger();

        await tagger.writeCommonTags(testFile.path, {
          CommonTags.title: 'WebM Test Title',
          CommonTags.artist: 'WebM Test Artist',
          CommonTags.album: 'WebM Test Album',
          CommonTags.year: '2026',
        });

        final tags = await tagger.readCommonTags(testFile.path);
        expect(tags[CommonTags.title], equals('WebM Test Title'));
        expect(tags[CommonTags.artist], equals('WebM Test Artist'));
        expect(tags[CommonTags.album], equals('WebM Test Album'));
        expect(tags[CommonTags.year], equals('2026'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects embedded artwork', () async {
      final sourceFile = File('example/example.webm');
      if (!await sourceFile.exists()) {
        markTestSkipped('example/example.webm not found');
        return;
      }

      final bytes = await sourceFile.readAsBytes();
      final image = await File('example/example.jpg').readAsBytes();
      expect(
        () => WebmWriter().writeTagsToBytes(bytes, [
          MetadataTag.binary(CommonTags.albumArt, Uint8List.fromList(image)),
        ]),
        throwsA(isA<MetadataException>()),
      );
    });
  });
}
