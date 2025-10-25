import 'package:metatagger/metatagger.dart';
import 'package:test/test.dart';

void main() {
  group('MetaTagger Tests', () {
    late MetaTagger tagger;

    setUp(() {
      tagger = MetaTagger();
    });

    test('should support MP3 and FLAC formats', () {
      expect(tagger.supportedExtensions, contains('.mp3'));
      expect(tagger.supportedExtensions, contains('.flac'));
    });

    test('should detect supported file formats', () {
      expect(tagger.isSupported('test.mp3'), isTrue);
      expect(tagger.isSupported('test.flac'), isTrue);
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
  });
}
