import 'package:metatagger/metatagger.dart';
import 'dart:io';
import 'dart:typed_data';

/// Example demonstrating MP4/M4A metadata operations
void main() async {
  final tagger = MetaTagger();

  print('=== MP4/M4A MetaTagger Example ===\n');

  // Check if we have the example files
  final mp4File = File('example.mp4');
  final artFile = File('example.jpg');

  if (!await mp4File.exists()) {
    print(
      'Please add an example.mp4 file to the example/ directory to run this demo.',
    );
    return;
  }

  // Create a test copy so we don't modify the original
  final testFile = File('mp4_test.m4a');
  await mp4File.copy(testFile.path);

  try {
    print('📹 Working with: ${testFile.path}\n');

    // READ: Display current metadata
    print('1. Reading existing metadata...');
    final existingTags = await tagger.readCommonTags(testFile.path);
    if (existingTags.isEmpty) {
      print('   ℹ No existing metadata found\n');
    } else {
      print('   ✓ Current metadata:');
      existingTags.forEach((key, value) {
        print('     $key: $value');
      });
      print('');
    }

    // WRITE: Add new metadata including album art
    print('2. Writing new metadata with album art...');

    final tags = <MetadataTag>[
      MetadataTag.text(CommonTags.title, 'My MP4 Video'),
      MetadataTag.text(CommonTags.artist, 'Content Creator'),
      MetadataTag.text(CommonTags.album, 'Video Collection'),
      MetadataTag.text(CommonTags.year, '2024'),
      MetadataTag.text(CommonTags.genre, 'Documentary'),
      MetadataTag.text(CommonTags.track, '3/10'),
      MetadataTag.text(CommonTags.comment, 'Tagged with MetaTagger'),
    ];

    // Add album art if available
    if (await artFile.exists()) {
      final artBytes = await artFile.readAsBytes();
      tags.add(
        MetadataTag.binary(CommonTags.albumArt, Uint8List.fromList(artBytes)),
      );
      print('   📸 Album art: ${artBytes.length} bytes');
    }

    await tagger.writeTags(testFile.path, tags);
    print('   ✓ Metadata written\n');

    // READ: Verify the written metadata
    print('3. Reading back the new metadata...');
    final newTags = await tagger.readCommonTags(testFile.path);
    final allNewTags = await tagger.readTags(testFile.path);
    final hasAlbumArt = allNewTags.any((t) => t.key == CommonTags.albumArt);
    print('   ✓ Verified metadata:\n');

    print('   Title:   ${newTags[CommonTags.title]}');
    print('   Artist:  ${newTags[CommonTags.artist]}');
    print('   Album:   ${newTags[CommonTags.album]}');
    print('   Year:    ${newTags[CommonTags.year]}');
    print('   Genre:   ${newTags[CommonTags.genre]}');
    print('   Track:   ${newTags[CommonTags.track]}');
    print('   Comment: ${newTags[CommonTags.comment]}');
    print('   Album Art: ${hasAlbumArt ? "✓ Present" : "✗ Not found"}\n');

    // UPDATE: Change specific tags
    print('4. Updating the title and year...');
    final allTags = await tagger.readTags(testFile.path);
    final updatedTags = allTags
        .where((t) => t.key != CommonTags.title && t.key != CommonTags.year)
        .toList();
    updatedTags.add(MetadataTag.text(CommonTags.title, 'Updated Video Title'));
    updatedTags.add(MetadataTag.text(CommonTags.year, '2025'));

    await tagger.writeTags(testFile.path, updatedTags);
    print('   ✓ Tags updated\n');

    // READ: Verify updates
    print('5. Reading updated metadata...');
    final finalTags = await tagger.readCommonTags(testFile.path);
    print('   Title: ${finalTags[CommonTags.title]}');
    print('   Year:  ${finalTags[CommonTags.year]}\n');

    // CUSTOM TAGS: Add custom metadata
    print('6. Adding custom tags...');
    final customTags = await tagger.readTags(testFile.path);
    customTags.add(MetadataTag.text('©des', 'Video description'));
    customTags.add(MetadataTag.text('©pub', 'Publisher Name'));

    await tagger.writeTags(testFile.path, customTags);
    print('   ✓ Custom tags added\n');

    // READ ALL: Display all tags including custom ones
    print('7. Reading all tags (including custom)...');
    final allFinalTags = await tagger.readTags(testFile.path);
    print('   ✓ All tags (${allFinalTags.length} total):');
    for (final tag in allFinalTags) {
      final displayValue = tag.value is List<int>
          ? '<binary data>'
          : tag.value.toString();
      print('     ${tag.key}: $displayValue');
    }

    print('\n✅ MP4 example completed successfully!');
    print('📁 Test file saved as: ${testFile.path}');
  } catch (e) {
    print('❌ Error: $e');
  }
}
