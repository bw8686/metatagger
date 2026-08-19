import 'dart:io';
import 'package:metatagger/metatagger.dart';

/// This example demonstrates how to read and write metadata tags
/// directly from/to byte arrays in memory without using files.
void main() async {
  // 1. Setup
  final tagger = MetaTagger();
  final sourceFile = File('example/example.ogg');
  
  if (!await sourceFile.exists()) {
    print('Example file not found: ${sourceFile.path}');
    return;
  }

  print('=== MetaTagger In-Memory Parsing Example ===\n');

  // 2. Read the audio file into memory as bytes
  print('Loading audio file into memory...');
  var audioBytes = await sourceFile.readAsBytes();
  print('Loaded ${audioBytes.length} bytes.\n');

  // 3. Read tags from memory
  print('--- Existing Tags (from memory) ---');
  final existingTags = await tagger.readTagsFromBytes(audioBytes);
  if (existingTags.isEmpty) {
    print('No tags found.');
  } else {
    for (final tag in existingTags) {
      if (tag.type == TagType.text || tag.type == TagType.number) {
        print('${tag.key}: ${tag.value}');
      } else {
        print('${tag.key}: <Binary Data>');
      }
    }
  }
  print('');

  // 4. Modify tags in memory
  print('--- Writing Tags (in memory) ---');
  final newTags = [
    MetadataTag.text(CommonTags.title, 'In-Memory Modified Title'),
    MetadataTag.text(CommonTags.artist, 'The Byte Arrays'),
    MetadataTag.text(CommonTags.album, 'Memory Allocation'),
    MetadataTag.text(CommonTags.year, '2025'),
    MetadataTag.text(CommonTags.genre, 'Electronic'),
  ];

  print('Writing new tags...');
  // This detects the format automatically and returns the modified bytes!
  final modifiedBytes = await tagger.writeTagsToBytes(audioBytes, newTags);
  print('Success! The modified byte array is now ${modifiedBytes.length} bytes.\n');

  // 5. Verify the modifications
  print('--- Verifying Modified Tags ---');
  final verifiedTags = await tagger.readTagsFromBytes(modifiedBytes);
  for (final tag in verifiedTags) {
    if (tag.type == TagType.text || tag.type == TagType.number) {
      print('${tag.key}: ${tag.value}');
    } else {
      print('${tag.key}: <Binary Data>');
    }
  }
  print('\nOperation complete! No files were harmed (or written to) on disk.');
}
