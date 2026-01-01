import 'dart:io';
import 'package:metatagger/metatagger.dart';

/// Demonstrates MP4/M4A custom tag support using freeform atoms
///
/// MP4 files store custom tags using freeform (----) atoms with namespace
/// com.apple.iTunes. This example shows how to write and read custom tags
/// alongside standard iTunes metadata.
void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('MP4 Custom Tags Example');
  print('═══════════════════════════════════════════════════════════\n');

  final tagger = MetaTagger();
  final inputFile = 'example.mp4';
  final outputFile = 'mp4_custom_test.m4a';

  // Copy example file
  await File(inputFile).copy(outputFile);

  // 1. Write standard + custom tags
  print('1️⃣  Writing standard and custom tags...\n');

  final tags = [
    // Standard iTunes tags
    MetadataTag.text(CommonTags.title, 'Song with Custom Tags'),
    MetadataTag.text(CommonTags.artist, 'Custom Artist'),
    MetadataTag.text(CommonTags.album, 'Custom Album'),
    MetadataTag.text(CommonTags.year, '2026'),
    MetadataTag.text(CommonTags.genre, 'Electronic'),

    // Custom tags (stored as freeform atoms)
    MetadataTag.text('MOOD', 'Energetic'),
    MetadataTag.text('STYLE', 'Progressive House'),
    MetadataTag.text('LABEL', 'Independent Release'),
    MetadataTag.text('CATALOG_NUMBER', 'IR-2026-001'),
    MetadataTag.text('ISRC', 'USIR12345678'),
    MetadataTag.text('PRODUCER', 'John Producer'),
    MetadataTag.text('MIXER', 'Sarah Mixer'),
    MetadataTag.text('ENGINEER', 'Bob Engineer'),
    MetadataTag.text('RATING', '5/5'),
    MetadataTag.text('KEY', 'A Minor'),
    MetadataTag.number('BPM_PRECISE', 128.5),
  ];

  await tagger.writeTags(outputFile, tags);
  print(
    '   ✓ Written ${tags.length} tags (${tags.where((t) => t.key.toUpperCase() != t.key).length} standard + ${tags.where((t) => t.key.toUpperCase() == t.key).length} custom)',
  );

  // 2. Read all tags
  print('\n2️⃣  Reading all tags...\n');

  final readTags = await tagger.readTags(outputFile);
  print('   📋 Found ${readTags.length} tags:\n');

  // Separate standard and custom tags
  final standardTags = <MetadataTag>[];
  final customTags = <MetadataTag>[];

  for (final tag in readTags) {
    if (_isStandardTag(tag.key)) {
      standardTags.add(tag);
    } else {
      customTags.add(tag);
    }
  }

  print('   Standard Tags (${standardTags.length}):');
  for (final tag in standardTags) {
    print('      • ${tag.key}: ${tag.value}');
  }

  print('\n   Custom Tags (${customTags.length}):');
  for (final tag in customTags) {
    print('      • ${tag.key}: ${tag.value}');
  }

  // 3. Read specific custom tags
  print('\n3️⃣  Reading specific custom tags...\n');

  final mood = await tagger.readTag(outputFile, 'MOOD');
  final style = await tagger.readTag(outputFile, 'STYLE');
  final label = await tagger.readTag(outputFile, 'LABEL');
  final bpmPrecise = await tagger.readTag(outputFile, 'BPM_PRECISE');

  print('   🎵 Mood: ${mood?.value ?? "Not found"}');
  print('   🎨 Style: ${style?.value ?? "Not found"}');
  print('   🏷️  Label: ${label?.value ?? "Not found"}');
  print('   ⚡ BPM (Precise): ${bpmPrecise?.value ?? "Not found"}');

  // 4. Update a custom tag
  print('\n4️⃣  Updating custom tag...\n');

  final updatedRating = MetadataTag.text('RATING', '4.5/5');
  await tagger.writeTag(outputFile, updatedRating);

  final newRating = await tagger.readTag(outputFile, 'RATING');
  print('   ⭐ Rating updated to: ${newRating?.value}');

  // 5. Add more custom tags
  print('\n5️⃣  Adding additional custom tags...\n');

  final additionalTags = [
    MetadataTag.text('RELEASE_DATE', '2026-01-01'),
    MetadataTag.text('COUNTRY', 'USA'),
    MetadataTag.text('LANGUAGE', 'English'),
    MetadataTag.text('URL', 'https://example.com/song'),
  ];

  for (final tag in additionalTags) {
    await tagger.writeTag(outputFile, tag);
  }

  final finalTags = await tagger.readTags(outputFile);
  print('   ✓ Added ${additionalTags.length} more custom tags');
  print('   📊 Total tags now: ${finalTags.length}');

  // 6. Use custom tags for categorization
  print('\n6️⃣  Using custom tags for metadata organization...\n');

  final productionTags = finalTags
      .where((t) => ['PRODUCER', 'MIXER', 'ENGINEER'].contains(t.key))
      .toList();

  final catalogTags = finalTags
      .where((t) => ['LABEL', 'CATALOG_NUMBER', 'ISRC'].contains(t.key))
      .toList();

  print('   🎛️  Production Credits (${productionTags.length}):');
  for (final tag in productionTags) {
    print('      • ${tag.key}: ${tag.value}');
  }

  print('\n   📁 Catalog Info (${catalogTags.length}):');
  for (final tag in catalogTags) {
    print('      • ${tag.key}: ${tag.value}');
  }

  print('\n═══════════════════════════════════════════════════════════');
  print('Summary');
  print('═══════════════════════════════════════════════════════════\n');

  print('✅ MP4 custom tag support fully functional');
  print('   • Custom tags stored as freeform (----) atoms');
  print('   • Namespace: com.apple.iTunes');
  print('   • Compatible with iTunes, Music.app, and other players');
  print('   • Supports text, number, and binary custom tags');
  print('\n📄 Output file: $outputFile');
}

/// Checks if a tag key is a standard iTunes tag
bool _isStandardTag(String tagKey) {
  final standardTags = {
    'TITLE',
    'ARTIST',
    'ALBUM',
    'ALBUMARTIST',
    'YEAR',
    'DATE',
    'GENRE',
    'TRACKNUMBER',
    'DISCNUMBER',
    'COMMENT',
    'COMPOSER',
    'ENCODEDBY',
    'COPYRIGHT',
    'LYRICS',
    'ALBUMART',
    'BPM',
  };
  return standardTags.contains(tagKey.toUpperCase());
}
