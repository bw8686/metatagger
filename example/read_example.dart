import 'package:metatagger/metatagger.dart';
import 'dart:io';

void main() async {
  // Create a MetaTagger instance
  final tagger = MetaTagger();

  print('=== MetaTagger Read Example ===\n');

  // Example 1: Reading metadata from an MP3 file
  await readMp3Example(tagger);

  // Example 2: Reading metadata from a FLAC file
  await readFlacExample(tagger);

  // Example 3: Reading metadata from an OGG file
  await readOggExample(tagger);

  // Example 4: Reading specific tags
  await readSpecificTagsExample(tagger);

  // Example 5: Reading and displaying all tags
  await readAllTagsExample(tagger);
}

/// Example: Reading metadata from an MP3 file
Future<void> readMp3Example(MetaTagger tagger) async {
  print('--- Reading MP3 File ---');

  final mp3File = File('example/example_with_metadata.mp3');

  if (!await mp3File.exists()) {
    print(
      '✗ MP3 file not found. Run metatagger_example.dart first to create it.\n',
    );
    return;
  }

  try {
    // Read all tags using the convenient map interface
    final tags = await tagger.readCommonTags(mp3File.path);

    print('✓ Successfully read MP3 metadata:');
    print('  Title: ${tags[CommonTags.title] ?? 'N/A'}');
    print('  Artist: ${tags[CommonTags.artist] ?? 'N/A'}');
    print('  Album: ${tags[CommonTags.album] ?? 'N/A'}');
    print('  Year: ${tags[CommonTags.year] ?? 'N/A'}');
    print('  Genre: ${tags[CommonTags.genre] ?? 'N/A'}');
    print('  Track: ${tags[CommonTags.track] ?? 'N/A'}');
    print('  BPM: ${tags[CommonTags.bpm] ?? 'N/A'}');

    // Check for custom fields
    final customField = tags['CUSTOM_FIELD'];
    if (customField != null) {
      print('  Custom Field: $customField');
    }

    // Check for album art
    if (tags.containsKey(CommonTags.albumArt)) {
      final artData = tags[CommonTags.albumArt];
      print('  Album Art: ${artData.length} bytes');
    }

    print('');
  } catch (e) {
    print('✗ Error reading MP3: $e\n');
  }
}

/// Example: Reading metadata from a FLAC file
Future<void> readFlacExample(MetaTagger tagger) async {
  print('--- Reading FLAC File ---');

  final flacFile = File('example/example_with_metadata.flac');

  if (!await flacFile.exists()) {
    print(
      '✗ FLAC file not found. Run metatagger_example.dart first to create it.\n',
    );
    return;
  }

  try {
    // Read all tags
    final tags = await tagger.readCommonTags(flacFile.path);

    print('✓ Successfully read FLAC metadata:');
    print('  Title: ${tags[CommonTags.title] ?? 'N/A'}');
    print('  Artist: ${tags[CommonTags.artist] ?? 'N/A'}');
    print('  Album: ${tags[CommonTags.album] ?? 'N/A'}');
    print('  Year: ${tags[CommonTags.year] ?? 'N/A'}');
    print('  Genre: ${tags[CommonTags.genre] ?? 'N/A'}');

    // Check for album art
    if (tags.containsKey(CommonTags.albumArt)) {
      final artData = tags[CommonTags.albumArt];
      print('  Album Art: ${artData.length} bytes');
    }

    print('');
  } catch (e) {
    print('✗ Error reading FLAC: $e\n');
  }
}

/// Example: Reading metadata from an OGG file
Future<void> readOggExample(MetaTagger tagger) async {
  print('--- Reading OGG File ---');

  final oggFile = File('example/example.ogg');

  if (!await oggFile.exists()) {
    print(
      '✗ OGG file not found. Please ensure example.ogg exists in the example/ directory.\n',
    );
    return;
  }

  try {
    // Read all tags
    final tags = await tagger.readCommonTags(oggFile.path);

    print('✓ Successfully read OGG metadata:');
    print('  Title: ${tags[CommonTags.title] ?? 'N/A'}');
    print('  Artist: ${tags[CommonTags.artist] ?? 'N/A'}');
    print('  Album: ${tags[CommonTags.album] ?? 'N/A'}');
    print('  Year: ${tags[CommonTags.year] ?? 'N/A'}');
    print('  Genre: ${tags[CommonTags.genre] ?? 'N/A'}');

    // Check for album art
    if (tags.containsKey(CommonTags.albumArt)) {
      final artData = tags[CommonTags.albumArt];
      print('  Album Art: ${artData.length} bytes');
    }

    print('');
  } catch (e) {
    print('✗ Error reading OGG: $e\n');
  }
}

/// Example: Reading specific tags
Future<void> readSpecificTagsExample(MetaTagger tagger) async {
  print('--- Reading Specific Tags ---');

  final mp3File = File('example/example_with_metadata.mp3');

  if (!await mp3File.exists()) {
    print('✗ MP3 file not found.\n');
    return;
  }

  try {
    // Read individual tags
    final title = await tagger.readTag(mp3File.path, CommonTags.title);
    final artist = await tagger.readTag(mp3File.path, CommonTags.artist);
    final album = await tagger.readTag(mp3File.path, CommonTags.album);

    print('✓ Read specific tags:');
    if (title != null) print('  Title: ${title.value}');
    if (artist != null) print('  Artist: ${artist.value}');
    if (album != null) print('  Album: ${album.value}');

    // Try to read a tag that might not exist
    final rating = await tagger.readTag(mp3File.path, 'RATING');
    if (rating != null) {
      print('  Rating: ${rating.value}');
    } else {
      print('  Rating: Not found');
    }

    print('');
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Example: Reading and displaying all tags
Future<void> readAllTagsExample(MetaTagger tagger) async {
  print('--- Reading All Tags ---');

  final mp3File = File('example/example_with_metadata.mp3');

  if (!await mp3File.exists()) {
    print('✗ MP3 file not found.\n');
    return;
  }

  try {
    // Read all tags as MetadataTag objects
    final tags = await tagger.readTags(mp3File.path);

    print('✓ Found ${tags.length} tags:');

    // Group tags by type
    final textTags = tags.where((t) => t.type == TagType.text).toList();
    final binaryTags = tags.where((t) => t.type == TagType.binary).toList();

    if (textTags.isNotEmpty) {
      print('\n  Text Tags:');
      for (final tag in textTags) {
        final value = tag.value.toString();
        final displayValue = value.length > 50
            ? '${value.substring(0, 47)}...'
            : value;
        print('    ${tag.key}: $displayValue');
      }
    }

    if (binaryTags.isNotEmpty) {
      print('\n  Binary Tags:');
      for (final tag in binaryTags) {
        print('    ${tag.key}: ${tag.value.length} bytes');
      }
    }

    print('');
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Example: Extracting album art
Future<void> extractAlbumArt(
  MetaTagger tagger,
  String audioFile,
  String outputImage,
) async {
  try {
    final artTag = await tagger.readTag(audioFile, CommonTags.albumArt);

    if (artTag != null && artTag.type == TagType.binary) {
      final artFile = File(outputImage);
      await artFile.writeAsBytes(artTag.value);
      print('✓ Album art extracted to $outputImage');
    } else {
      print('✗ No album art found in file');
    }
  } catch (e) {
    print('✗ Error extracting album art: $e');
  }
}
