import 'package:metatagger/metatagger.dart';
import 'dart:io';
import 'dart:typed_data';

/// Example demonstrating metadata migration between different formats
void main() async {
  final tagger = MetaTagger();

  print('=== Format Migration Example ===\n');

  // Check available files
  final mp3File = File('example.mp3');
  final flacFile = File('example.flac');
  final mp4File = File('example.mp4');
  final artFile = File('example.jpg');

  final hasMP3 = await mp3File.exists();
  final hasFLAC = await flacFile.exists();
  final hasMP4 = await mp4File.exists();

  print('Available files:');
  print('  MP3:  ${hasMP3 ? "✓" : "✗"}');
  print('  FLAC: ${hasFLAC ? "✓" : "✗"}');
  print('  MP4:  ${hasMP4 ? "✓" : "✗"}\n');

  if (!hasMP3 && !hasFLAC && !hasMP4) {
    print(
      'Please add at least one example file (example.mp3, example.flac, or example.mp4)',
    );
    return;
  }

  try {
    // Example 1: MP3 → MP4
    if (hasMP3) {
      print('1️⃣  Migrating metadata from MP3 to MP4...');
      final mp3Tags = await tagger.readCommonTags(mp3File.path);
      print('   Read ${mp3Tags.length} tags from MP3:');
      mp3Tags.forEach((key, value) => print('     $key: $value'));

      final outputMP4 = File('migrated_from_mp3.m4a');
      if (hasMP4) {
        await mp4File.copy(outputMP4.path);
      } else {
        print('   (Creating minimal MP4 file...)');
        await _createMinimalMP4(outputMP4);
      }

      await tagger.writeCommonTags(outputMP4.path, mp3Tags);
      print('   ✓ Metadata written to ${outputMP4.path}\n');
    }

    // Example 2: FLAC → MP4
    if (hasFLAC) {
      print('2️⃣  Migrating metadata from FLAC to MP4...');
      final flacTags = await tagger.readCommonTags(flacFile.path);
      print('   Read ${flacTags.length} tags from FLAC:');
      flacTags.forEach((key, value) => print('     $key: $value'));

      final outputMP4 = File('migrated_from_flac.m4a');
      if (hasMP4) {
        await mp4File.copy(outputMP4.path);
      } else {
        await _createMinimalMP4(outputMP4);
      }

      await tagger.writeCommonTags(outputMP4.path, flacTags);
      print('   ✓ Metadata written to ${outputMP4.path}\n');
    }

    // Example 3: MP4 → MP3
    if (hasMP4 && hasMP3) {
      print('3️⃣  Migrating metadata from MP4 to MP3...');
      final mp4Tags = await tagger.readCommonTags(mp4File.path);
      print('   Read ${mp4Tags.length} tags from MP4:');
      mp4Tags.forEach((key, value) => print('     $key: $value'));

      final outputMP3 = File('migrated_from_mp4.mp3');
      await mp3File.copy(outputMP3.path);
      await tagger.writeCommonTags(outputMP3.path, mp4Tags);
      print('   ✓ Metadata written to ${outputMP3.path}\n');
    }

    // Example 4: Universal metadata - write to all formats
    print('4️⃣  Writing universal metadata with album art to all formats...');

    // Prepare universal tags
    final universalTags = <MetadataTag>[
      MetadataTag.text(CommonTags.title, 'Universal Song'),
      MetadataTag.text(CommonTags.artist, 'Cross-Format Artist'),
      MetadataTag.text(CommonTags.album, 'Multi-Format Album'),
      MetadataTag.text(CommonTags.year, '2024'),
      MetadataTag.text(CommonTags.genre, 'Electronic'),
      MetadataTag.text(CommonTags.track, '1/10'),
    ];

    // Add album art if available
    if (await artFile.exists()) {
      final artBytes = await artFile.readAsBytes();
      universalTags.add(
        MetadataTag.binary(CommonTags.albumArt, Uint8List.fromList(artBytes)),
      );
      print('   📸 Including album art: ${artBytes.length} bytes');
    }

    if (hasMP3) {
      final testMP3 = File('universal_test.mp3');
      await mp3File.copy(testMP3.path);
      await tagger.writeTags(testMP3.path, universalTags);
      print('   ✓ Written to MP3: ${testMP3.path}');
    }

    if (hasFLAC) {
      final testFLAC = File('universal_test.flac');
      await flacFile.copy(testFLAC.path);
      await tagger.writeTags(testFLAC.path, universalTags);
      print('   ✓ Written to FLAC: ${testFLAC.path}');
    }

    if (hasMP4) {
      final testMP4 = File('universal_test.m4a');
      await mp4File.copy(testMP4.path);
      await tagger.writeTags(testMP4.path, universalTags);
      print('   ✓ Written to MP4: ${testMP4.path}');
    }

    print('\n✅ Format migration examples completed!');
    print('💡 Tip: MetaTagger automatically handles format-specific details,');
    print('   so you can work with metadata the same way across all formats.');
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Creates a minimal valid MP4 file for testing
Future<void> _createMinimalMP4(File file) async {
  // ftyp atom
  final ftypData = [
    // size
    0x00, 0x00, 0x00, 0x20,
    // type 'ftyp'
    0x66, 0x74, 0x79, 0x70,
    // major brand 'isom'
    0x69, 0x73, 0x6F, 0x6D,
    // minor version
    0x00, 0x00, 0x02, 0x00,
    // compatible brands
    0x69, 0x73, 0x6F, 0x6D, // isom
    0x69, 0x73, 0x6F, 0x32, // iso2
    0x6D, 0x70, 0x34, 0x31, // mp41
  ];

  // moov atom (minimal)
  final moovData = [
    // size
    0x00, 0x00, 0x00, 0x6C,
    // type 'moov'
    0x6D, 0x6F, 0x6F, 0x76,
    // mvhd atom
    0x00, 0x00, 0x00, 0x64,
    0x6D, 0x76, 0x68, 0x64,
    0x00, 0x00, 0x00, 0x00, // version + flags
    ...List.filled(88, 0x00), // minimal mvhd data
  ];

  await file.writeAsBytes([...ftypData, ...moovData]);
}
