import 'dart:io';

import 'package:metatagger/metatagger.dart';

Future<void> main() async {
  final source = File('example/example.webm');
  final output = File('example/example_webm_with_metadata.webm');

  if (!await source.exists()) {
    print('WebM example file not found: ${source.path}');
    return;
  }

  await source.copy(output.path);
  final tagger = MetaTagger();

  await tagger.writeCommonTags(output.path, {
    CommonTags.title: 'WebM Example',
    CommonTags.artist: 'MetaTagger',
    CommonTags.album: 'Metadata Examples',
    CommonTags.year: '2026',
  });

  final tags = await tagger.readCommonTags(output.path);
  print('Wrote and read WebM metadata:');
  print('  Title: ${tags[CommonTags.title]}');
  print('  Artist: ${tags[CommonTags.artist]}');
  print('  Album: ${tags[CommonTags.album]}');
  print('  Year: ${tags[CommonTags.year]}');
}
