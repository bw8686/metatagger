import 'dart:io';
import 'dart:typed_data';

import 'package:metatagger/metatagger.dart';
import 'package:test/test.dart';

void main() {
  group('Opus support', () {
    test('recognizes .opus files', () {
      expect(OggReader().supportsFile('audio.opus'), isTrue);
      expect(OggWriter().supportsFile('audio.opus'), isTrue);
      expect(OggReader().supportedExtensions, contains('.opus'));
      expect(OggWriter().supportedExtensions, contains('.opus'));
      expect(MetaTagger().isSupported('audio.opus'), isTrue);
    });

    test('writes and reads tags and artwork in example.opus', () async {
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

        final image = await File('example/example.jpg').readAsBytes();
        await tagger.writeTag(
          testFile.path,
          MetadataTag.binary(CommonTags.albumArt, Uint8List.fromList(image)),
        );

        final tags = await tagger.readCommonTags(testFile.path);
        expect(tags[CommonTags.title], equals('Opus Test Title'));
        expect(tags[CommonTags.artist], equals('Opus Test Artist'));
        expect(tags[CommonTags.album], equals('Opus Test Album'));
        expect(tags[CommonTags.year], equals('2026'));
        expect(tags[CommonTags.albumArt], isA<Uint8List>());
        expect((tags[CommonTags.albumArt] as Uint8List).length, image.length);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
