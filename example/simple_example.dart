import 'package:metatagger/metatagger.dart';
import 'dart:io';

/// Simple example showing basic read and write operations
void main() async {
  final tagger = MetaTagger();

  print('=== Simple MetaTagger Example ===\n');

  // Check if we have the example files
  final mp3File = File('example/example.mp3');

  if (!await mp3File.exists()) {
    print(
      'Please add an example.mp3 file to the example/ directory to run this demo.',
    );
    return;
  }

  final testFile = File('example/simple_test.mp3');
  await mp3File.copy(testFile.path);

  try {
    // WRITE: Add metadata to the file
    print('1. Writing metadata...');
    await tagger.writeCommonTags(testFile.path, {
      CommonTags.title: 'Simple Test Song',
      CommonTags.artist: 'Test Artist',
      CommonTags.album: 'Test Album',
      CommonTags.year: '2024',
      CommonTags.genre: 'Electronic',
      CommonTags.track: '1',
    });
    print('   ✓ Metadata written\n');

    // READ: Read the metadata back
    print('2. Reading metadata...');
    final tags = await tagger.readCommonTags(testFile.path);
    print('   ✓ Metadata read:\n');

    print('   Title:  ${tags[CommonTags.title]}');
    print('   Artist: ${tags[CommonTags.artist]}');
    print('   Album:  ${tags[CommonTags.album]}');
    print('   Year:   ${tags[CommonTags.year]}');
    print('   Genre:  ${tags[CommonTags.genre]}');
    print('   Track:  ${tags[CommonTags.track]}\n');

    // UPDATE: Change a specific tag
    print('3. Updating the year...');
    final allTags = await tagger.readTags(testFile.path);
    final updatedTags = allTags.where((t) => t.key != CommonTags.year).toList();
    updatedTags.add(MetadataTag.text(CommonTags.year, '2025'));
    await tagger.writeTags(testFile.path, updatedTags);
    print('   ✓ Year updated to 2025\n');

    // VERIFY: Read the updated value
    print('4. Verifying update...');
    final verifyTag = await tagger.readTag(testFile.path, CommonTags.year);
    print('   ✓ Year is now: ${verifyTag?.value}\n');

    print('✓ All operations completed successfully!');
    print('  Output file: ${testFile.path}');
  } catch (e) {
    print('✗ Error: $e');
  }
}
