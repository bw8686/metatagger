import 'package:metatagger/metatagger.dart';

void main() {
  // Create a MetaTagger instance
  final tagger = MetaTagger();
  
  print('=== MetaTagger Library Demo ===\n');
  
  // Show supported formats
  print('Supported file formats: ${tagger.supportedExtensions.join(', ')}');
  
  // Test file format detection
  print('\nFile format detection:');
  print('  test.mp3 supported: ${tagger.isSupported('test.mp3')}');
  print('  test.flac supported: ${tagger.isSupported('test.flac')}');
  print('  test.wav supported: ${tagger.isSupported('test.wav')}');
  print('  test.m4a supported: ${tagger.isSupported('test.m4a')}');
  
  // Show how to create different types of tags
  print('\nCreating metadata tags:');
  
  final textTag = MetadataTag.text(CommonTags.title, 'My Song');
  print('  Text tag: ${textTag.key} = "${textTag.value}" (${textTag.type})');
  
  final numberTag = MetadataTag.number(CommonTags.track, 5);
  print('  Number tag: ${numberTag.key} = ${numberTag.value} (${numberTag.type})');
  
  final customTag = MetadataTag.text('CUSTOM_FIELD', 'Custom Value');
  print('  Custom tag: ${customTag.key} = "${customTag.value}" (${customTag.type})');
  
  // Show common tag constants
  print('\nCommon tag constants available:');
  final commonTags = [
    'TITLE: ${CommonTags.title}',
    'ARTIST: ${CommonTags.artist}',
    'ALBUM: ${CommonTags.album}',
    'YEAR: ${CommonTags.year}',
    'GENRE: ${CommonTags.genre}',
    'TRACK: ${CommonTags.track}',
    'COMPOSER: ${CommonTags.composer}',
    'ALBUMART: ${CommonTags.albumArt}',
  ];
  
  for (final tag in commonTags) {
    print('  $tag');
  }
  
  print('\n=== To test with actual files ===');
  print('1. Copy an MP3 file to this directory and name it "example.mp3"');
  print('2. Copy a FLAC file to this directory and name it "example.flac"');
  print('3. Run: dart run example/metatagger_example.dart');
  print('\nOr modify the file paths in metatagger_example.dart to point to existing files.');
}
