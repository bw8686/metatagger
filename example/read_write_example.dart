import 'package:metatagger/metatagger.dart';
import 'dart:io';

void main() async {
  // Create a MetaTagger instance
  final tagger = MetaTagger();

  print('=== MetaTagger Read & Write Example ===\n');

  // Example 1: Copy metadata from one file to another
  await copyMetadataExample(tagger);

  // Example 2: Update specific tags while keeping others
  await updateSpecificTagsExample(tagger);

  // Example 3: Migrate metadata between formats (MP3 to FLAC)
  await migrateMetadataExample(tagger);

  // Example 4: Write metadata to an OGG file
  await writeOggExample(tagger);
}

/// Example: Copy metadata from one file to another
Future<void> copyMetadataExample(MetaTagger tagger) async {
  print('--- Copying Metadata Between Files ---');

  final sourceFile = File('example/example_with_metadata.mp3');
  final destFile = File('example/example_copy.mp3');
  final originalFile = File('example/example.mp3');

  if (!await sourceFile.exists()) {
    print('✗ Source file not found. Run metatagger_example.dart first.\n');
    return;
  }

  if (!await originalFile.exists()) {
    print('✗ Original MP3 file not found.\n');
    return;
  }

  try {
    // Copy the original file (without metadata)
    await originalFile.copy(destFile.path);
    print('✓ Copied original file to destination');

    // Read all metadata from source
    final tags = await tagger.readTags(sourceFile.path);
    print('✓ Read ${tags.length} tags from source file');

    // Write all metadata to destination
    await tagger.writeTags(destFile.path, tags);
    print('✓ Wrote all tags to destination file');

    // Verify by reading back
    final verifyTags = await tagger.readCommonTags(destFile.path);
    print('✓ Verification:');
    print('  Title: ${verifyTags[CommonTags.title]}');
    print('  Artist: ${verifyTags[CommonTags.artist]}');

    print('');
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Example: Update specific tags while keeping others
Future<void> updateSpecificTagsExample(MetaTagger tagger) async {
  print('--- Updating Specific Tags ---');

  final testFile = File('example/example_update.mp3');
  final originalFile = File('example/example_with_metadata.mp3');

  if (!await originalFile.exists()) {
    print('✗ Source file not found.\n');
    return;
  }

  try {
    // Copy the file with metadata
    await originalFile.copy(testFile.path);
    print('✓ Created test file');

    // Read existing metadata
    final existingTags = await tagger.readTags(testFile.path);
    print('✓ Read ${existingTags.length} existing tags');

    // Create updated tags list
    final updatedTags = <MetadataTag>[];

    // Keep all existing tags except the ones we want to update
    for (final tag in existingTags) {
      if (tag.key != CommonTags.year && tag.key != CommonTags.track) {
        updatedTags.add(tag);
      }
    }

    // Add the updated tags
    updatedTags.add(MetadataTag.text(CommonTags.year, '2025'));
    updatedTags.add(MetadataTag.text(CommonTags.track, '7'));

    // Write the updated tags
    await tagger.writeTags(testFile.path, updatedTags);
    print('✓ Updated year to 2025 and track to 7');

    // Verify the update
    final verifyTags = await tagger.readCommonTags(testFile.path);
    print('✓ Verification:');
    print('  Title: ${verifyTags[CommonTags.title]} (unchanged)');
    print('  Year: ${verifyTags[CommonTags.year]} (updated)');
    print('  Track: ${verifyTags[CommonTags.track]} (updated)');

    print('');
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Example: Migrate metadata between formats
Future<void> migrateMetadataExample(MetaTagger tagger) async {
  print('--- Migrating Metadata Between Formats ---');

  final mp3File = File('example/example_with_metadata.mp3');
  final flacFile = File('example/example_migrated.flac');
  final originalFlac = File('example/example.flac');

  if (!await mp3File.exists()) {
    print('✗ MP3 file not found.\n');
    return;
  }

  if (!await originalFlac.exists()) {
    print('✗ Original FLAC file not found.\n');
    return;
  }

  try {
    // Read metadata from MP3
    final mp3Tags = await tagger.readTags(mp3File.path);
    print('✓ Read ${mp3Tags.length} tags from MP3');

    // Copy original FLAC file
    await originalFlac.copy(flacFile.path);
    print('✓ Created FLAC destination file');

    // Write metadata to FLAC
    // Note: Some MP3-specific frames might not transfer perfectly,
    // but common tags will work
    await tagger.writeTags(flacFile.path, mp3Tags);
    print('✓ Wrote metadata to FLAC file');

    // Verify
    final flacTags = await tagger.readCommonTags(flacFile.path);
    print('✓ Migrated tags verification:');
    print('  Title: ${flacTags[CommonTags.title]}');
    print('  Artist: ${flacTags[CommonTags.artist]}');
    print('  Album: ${flacTags[CommonTags.album]}');

    print('\n✓ Metadata successfully migrated from MP3 to FLAC!');
    print('');
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Example: Edit metadata in place
Future<void> editInPlaceExample(MetaTagger tagger, String filePath) async {
  print('--- Editing Metadata In Place ---');

  final file = File(filePath);

  if (!await file.exists()) {
    print('✗ File not found: $filePath\n');
    return;
  }

  try {
    // Read current metadata
    final currentTags = await tagger.readCommonTags(filePath);
    print('Current metadata:');
    print('  Title: ${currentTags[CommonTags.title]}');
    print('  Artist: ${currentTags[CommonTags.artist]}');

    // Update just the title
    final allTags = await tagger.readTags(filePath);
    final updatedTags = allTags
        .where((t) => t.key != CommonTags.title)
        .toList();
    updatedTags.add(MetadataTag.text(CommonTags.title, 'Updated Title'));

    await tagger.writeTags(filePath, updatedTags);

    // Read back
    final newTags = await tagger.readCommonTags(filePath);
    print('\nUpdated metadata:');
    print('  Title: ${newTags[CommonTags.title]}');
    print('  Artist: ${newTags[CommonTags.artist]}');

    print('');
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Example: Write metadata to an OGG file
Future<void> writeOggExample(MetaTagger tagger) async {
  print('--- Writing Metadata to OGG File ---');

  final oggFile = File('example/example.ogg');
  final testFile = File('example/example_write_test.ogg');

  if (!await oggFile.exists()) {
    print(
      '✗ OGG file not found. Please ensure example.ogg exists in the example/ directory.\n',
    );
    return;
  }

  try {
    // Copy to a test file so we don't modify the original
    await oggFile.copy(testFile.path);

    // Read artwork image
    final artworkFile = File('example/example.jpg');
    List<int>? artworkData;
    if (await artworkFile.exists()) {
      artworkData = await artworkFile.readAsBytes();
    }

    final tags = [
      MetadataTag.text(CommonTags.title, 'Test OGG Title'),
      MetadataTag.text(CommonTags.artist, 'Test OGG Artist'),
      MetadataTag.text(CommonTags.album, 'Test OGG Album'),
      MetadataTag.number(CommonTags.year, 2026),
      MetadataTag.text(CommonTags.genre, 'Test Genre'),
    ];

    if (artworkData != null) {
      tags.add(MetadataTag.binary(CommonTags.albumArt, artworkData as dynamic));
    }

    await tagger.writeTags(testFile.path, tags);
    print('✓ Successfully wrote tags to ${testFile.path}');

    // Read back to verify
    final verifyTags = await tagger.readCommonTags(testFile.path);
    print('✓ Verification:');
    print('  Title: ${verifyTags[CommonTags.title]}');
    print('  Artist: ${verifyTags[CommonTags.artist]}');
    print('  Year: ${verifyTags[CommonTags.year]}');

    if (verifyTags.containsKey(CommonTags.albumArt)) {
      final artData = verifyTags[CommonTags.albumArt];
      print('  Album Art: ${artData.length} bytes');
    }

    print('');
  } catch (e) {
    print('✗ Error: $e\n');
  }
}
