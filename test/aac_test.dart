import 'dart:io';
import 'dart:typed_data';

import 'package:metatagger/metatagger.dart';
import 'package:test/test.dart';

void main() {
  group('AAC support', () {
    test('recognizes .aac files and ADTS bytes', () {
      expect(AacReader().supportsFile('audio.aac'), isTrue);
      expect(AacWriter().supportsFile('audio.aac'), isTrue);
      expect(AacReader().supportedExtensions, contains('.aac'));
      expect(AacWriter().supportedExtensions, contains('.aac'));
      expect(MetaTagger().isSupported('audio.aac'), isTrue);
      expect(
        AacReader().supportsBytes(Uint8List.fromList([0xFF, 0xF1, 0, 0])),
        isTrue,
      );
    });

    test('writes and reads ID3 metadata in example.aac', () async {
      final sourceFile = File('example/example.aac');
      if (!await sourceFile.exists()) {
        markTestSkipped('example/example.aac not found');
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'metatagger_aac_test_',
      );
      final testFile = File('${tempDir.path}/example.aac');
      try {
        await sourceFile.copy(testFile.path);
        final tagger = MetaTagger();
        await tagger.writeCommonTags(testFile.path, {
          CommonTags.title: 'AAC Test Title',
          CommonTags.artist: 'AAC Test Artist',
          CommonTags.album: 'AAC Test Album',
          CommonTags.year: '2026',
        });

        final image = await File('example/example.jpg').readAsBytes();
        await tagger.writeTag(
          testFile.path,
          MetadataTag.binary(CommonTags.albumArt, Uint8List.fromList(image)),
        );

        final tags = await tagger.readCommonTags(testFile.path);
        expect(tags[CommonTags.title], equals('AAC Test Title'));
        expect(tags[CommonTags.artist], equals('AAC Test Artist'));
        expect(tags[CommonTags.album], equals('AAC Test Album'));
        expect(tags[CommonTags.year], equals('2026'));
        expect(tags[CommonTags.albumArt], isA<Uint8List>());
        expect((tags[CommonTags.albumArt] as Uint8List).length, image.length);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
