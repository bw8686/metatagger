import 'package:metatagger/metatagger.dart';
import 'dart:io';

/// Test reading metadata from files created by other tools
void main() async {
  final tagger = MetaTagger();

  print('=== Reading Metadata from External Tools ===\n');

  // Test files that may have metadata from other applications
  final testFiles = [
    'ExampleWithMeta.mp4',
    'exampleWithMeta.mp4',
    'example.mp4',
    'example.mp3',
    'example.flac',
  ];

  for (final filename in testFiles) {
    final file = File(filename);

    if (!await file.exists()) {
      print('⊘ $filename - Not found\n');
      continue;
    }

    print('📁 File: $filename');
    print('   Size: ${await file.length()} bytes');

    try {
      // Read all tags
      final allTags = await tagger.readTags(file.path);
      final commonTags = await tagger.readCommonTags(file.path);

      if (allTags.isEmpty) {
        print('   ℹ No metadata found\n');
        continue;
      }

      print('   ✓ Found ${allTags.length} tags\n');

      // Display common tags
      if (commonTags.isNotEmpty) {
        print('   Common Tags:');
        commonTags.forEach((key, value) {
          print('     • $key: $value');
        });
      }

      // Display all tags including custom ones
      print('\n   All Tags:');
      for (final tag in allTags) {
        if (tag.type == TagType.binary) {
          final bytes = tag.value as List<int>;
          print('     • ${tag.key}: <binary: ${bytes.length} bytes>');
        } else {
          print('     • ${tag.key}: ${tag.value}');
        }
      }

      // Check for album art
      final albumArtTag = allTags.where((t) => t.key == CommonTags.albumArt);
      if (albumArtTag.isNotEmpty) {
        final artBytes = albumArtTag.first.value as List<int>;
        print('\n   🖼️  Album Art: ${artBytes.length} bytes');

        // Optionally save the album art
        final artFile = File('${filename}_extracted_art.jpg');
        await artFile.writeAsBytes(artBytes);
        print('      Saved to: ${artFile.path}');
      }

      print('\n' + '─' * 60 + '\n');
    } catch (e, stack) {
      print('   ❌ Error reading metadata: $e\n');
      if (e.toString().contains('Unsupported')) {
        print('   (File format not supported)\n');
      }
    }
  }

  // Summary and compatibility test
  print('═' * 60);
  print('Compatibility Test Summary');
  print('═' * 60);
  print('\nThis test verifies that MetaTagger can read metadata written by:');
  print('  • Other metadata editing tools');
  print('  • Video editing software');
  print('  • Music players and libraries');
  print('  • Mobile apps');
  print('\nSupported formats: MP3 (ID3v2), MP4/M4A (iTunes), FLAC (Vorbis)\n');
}
