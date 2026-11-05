import 'package:metatagger/metatagger.dart';
import 'dart:io';

void main() async {
  // Create a MetaTagger instance
  final tagger = MetaTagger();

  // NOTE: Place your source audio files in this directory:
  // - example.mp3 (source MP3 file)
  // - example.flac (source FLAC file)
  // - example.mp4 (source MP4/M4A file)
  // - example.webm (source WebM audio file)
  // - example.opus (source Opus audio file)
  // - example.aac (source AAC audio file)
  // The script will create new files with metadata

  // Example: Writing metadata to an MP3 file
  print('Processing MP3 file...');

  try {
    // First, copy the source file to preserve the original
    final sourceMP3 = File('example/example.mp3');
    final outputMP3 = File('example/example_with_metadata.mp3');

    if (await sourceMP3.exists()) {
      await sourceMP3.copy(outputMP3.path);
      print('✓ Copied example.mp3 → example_with_metadata.mp3');

      // Prepare all metadata tags
      final tags = <MetadataTag>[
        // Basic metadata
        MetadataTag.text(CommonTags.title, 'My Awesome Song'),
        MetadataTag.text(CommonTags.album, 'Great Album'),
        MetadataTag.text(CommonTags.artist, 'Amazing Artist, Featured Artist'),
        MetadataTag.text(CommonTags.albumArtist, 'Amazing Artist'),

        // Track and disc information
        MetadataTag.text(CommonTags.track, '3'),
        MetadataTag.text(CommonTags.disc, '1'),
        MetadataTag.text(CommonTags.trackTotal, '12'),
        MetadataTag.text(CommonTags.discTotal, '2'),

        // Release information
        MetadataTag.text(CommonTags.year, '2024'),
        MetadataTag.text(CommonTags.genre, 'Progressive Rock'),

        // Additional metadata
        MetadataTag.text(CommonTags.bpm, '128'),
        MetadataTag.text(
          CommonTags.lyrics,
          'This is my awesome song\nWith multiple lines of lyrics\nShowing how great it sounds',
        ),

        // Custom fields
        MetadataTag.text(CommonTags.composer, 'John Doe'),
        MetadataTag.text('CUSTOM_FIELD', 'Custom Value'),
      ];

      // Add album art if available
      final albumArtFile = File('example/example.jpg');
      if (await albumArtFile.exists()) {
        final albumArtBytes = await albumArtFile.readAsBytes();
        tags.add(MetadataTag.binary(CommonTags.albumArt, albumArtBytes));
        print('✓ Album art prepared for MP3 (${albumArtBytes.length} bytes)');
      } else {
        print('⚠ Album art file not found');
      }

      // Write all metadata in a single operation
      await tagger.writeTags(outputMP3.path, tags);

      print('✓ Successfully wrote metadata to MP3 file!');
    } else {
      print(
        '✗ Source file example.mp3 not found. Please add an MP3 file to test.',
      );
    }
  } catch (e) {
    print('✗ Error processing MP3: $e');
  }

  // Example: Writing metadata to a FLAC file
  print('\nProcessing FLAC file...');

  try {
    final sourceFLAC = File('example/example.flac');
    final outputFLAC = File('example/example_with_metadata.flac');

    if (await sourceFLAC.exists()) {
      await sourceFLAC.copy(outputFLAC.path);
      print('✓ Copied example.flac → example_with_metadata.flac');

      final tags = <MetadataTag>[
        // Basic metadata
        MetadataTag.text(CommonTags.title, 'My Awesome Song'),
        MetadataTag.text(CommonTags.album, 'Great Album'),
        MetadataTag.text(CommonTags.artist, 'Amazing Artist, Featured Artist'),
        MetadataTag.text(CommonTags.albumArtist, 'Amazing Artist'),

        // Track and disc information
        MetadataTag.text(CommonTags.track, '3'),
        MetadataTag.text(CommonTags.disc, '1'),
        MetadataTag.text(CommonTags.trackTotal, '12'),
        MetadataTag.text(CommonTags.discTotal, '2'),

        // Release information
        MetadataTag.text(CommonTags.year, '2024'),
        MetadataTag.text(CommonTags.genre, 'Progressive Rock'),

        // Additional metadata
        MetadataTag.text(CommonTags.bpm, '128'),
        MetadataTag.text(
          CommonTags.lyrics,
          'This is my awesome song\nWith multiple lines of lyrics\nShowing how great it sounds',
        ),

        // Custom fields
        MetadataTag.text(CommonTags.composer, 'John Doe'),
        MetadataTag.text('CUSTOM_FIELD', 'Custom Value'),
      ];

      // Add album art if available
      final albumArtFile = File('example/example.jpg');
      if (await albumArtFile.exists()) {
        final albumArtBytes = await albumArtFile.readAsBytes();
        tags.add(MetadataTag.binary(CommonTags.albumArt, albumArtBytes));
        print('✓ Album art prepared for FLAC (${albumArtBytes.length} bytes)');
      } else {
        print('⚠ Album art file not found');
      }

      // Write all metadata in a single operation
      await tagger.writeTags(outputFLAC.path, tags);

      print('✓ Successfully wrote metadata to FLAC file!');
    } else {
      print(
        '✗ Source file example.flac not found. Please add a FLAC file to test.',
      );
    }
  } catch (e) {
    print('✗ Error processing FLAC: $e');
  }

  // Example: Writing metadata to an OGG file
  print('\nProcessing OGG file...');

  try {
    final sourceOGG = File('example/example.ogg');
    final outputOGG = File('example/example_with_metadata.ogg');

    if (await sourceOGG.exists()) {
      await sourceOGG.copy(outputOGG.path);
      print('✓ Copied example.ogg → example_with_metadata.ogg');

      final tags = <MetadataTag>[
        // Basic metadata
        MetadataTag.text(CommonTags.title, 'My Awesome Song'),
        MetadataTag.text(CommonTags.album, 'Great Album'),
        MetadataTag.text(CommonTags.artist, 'Amazing Artist, Featured Artist'),
        MetadataTag.text(CommonTags.albumArtist, 'Amazing Artist'),

        // Track and disc information
        MetadataTag.text(CommonTags.track, '3'),
        MetadataTag.text(CommonTags.disc, '1'),
        MetadataTag.text(CommonTags.trackTotal, '12'),
        MetadataTag.text(CommonTags.discTotal, '2'),

        // Release information
        MetadataTag.text(CommonTags.year, '2024'),
        MetadataTag.text(CommonTags.genre, 'Progressive Rock'),

        // Additional metadata
        MetadataTag.text(CommonTags.bpm, '128'),
        MetadataTag.text(
          CommonTags.lyrics,
          'This is my awesome song\nWith multiple lines of lyrics\nShowing how great it sounds',
        ),

        // Custom fields
        MetadataTag.text(CommonTags.composer, 'John Doe'),
        MetadataTag.text('CUSTOM_FIELD', 'Custom Value'),
      ];

      // Add album art if available
      final albumArtFile = File('example/example.jpg');
      if (await albumArtFile.exists()) {
        final albumArtBytes = await albumArtFile.readAsBytes();
        tags.add(MetadataTag.binary(CommonTags.albumArt, albumArtBytes));
        print('✓ Album art prepared for OGG (${albumArtBytes.length} bytes)');
      } else {
        print('⚠ Album art file not found');
      }

      // Write all metadata in a single operation
      await tagger.writeTags(outputOGG.path, tags);

      print('✓ Successfully wrote metadata to OGG file!');
    } else {
      print(
        '✗ Source file example.ogg not found. Please add an OGG file to test.',
      );
    }
  } catch (e) {
    print('✗ Error processing OGG: $e');
  }

  // Example: Writing metadata to an Opus file
  print('\nProcessing Opus file...');

  try {
    final sourceOpus = File('example/example.opus');
    final outputOpus = File('example/example_with_metadata.opus');

    if (await sourceOpus.exists()) {
      await sourceOpus.copy(outputOpus.path);
      print('✓ Copied example.opus → example_with_metadata.opus');

      await tagger.writeCommonTags(outputOpus.path, {
        CommonTags.title: 'My Awesome Opus Audio',
        CommonTags.album: 'Great Album',
        CommonTags.artist: 'Amazing Artist',
        CommonTags.year: '2024',
        CommonTags.genre: 'Progressive Rock',
      });

      final albumArtFile = File('example/example.jpg');
      if (await albumArtFile.exists()) {
        await tagger.writeTag(
          outputOpus.path,
          MetadataTag.binary(
            CommonTags.albumArt,
            await albumArtFile.readAsBytes(),
          ),
        );
        print('✓ Album art written to Opus');
      }

      final writtenTags = await tagger.readCommonTags(outputOpus.path);
      print('✓ Successfully wrote metadata to Opus file!');
      print('  Title: ${writtenTags[CommonTags.title]}');
      print('  Artist: ${writtenTags[CommonTags.artist]}');
    } else {
      print(
        '✗ Source file example.opus not found. Please add an Opus file to test.',
      );
    }
  } catch (e) {
    print('✗ Error processing Opus: $e');
  }

  // Example: Writing ID3v2 metadata to an AAC ADTS file
  print('\nProcessing AAC file...');

  try {
    final sourceAAC = File('example/example.aac');
    final outputAAC = File('example/example_with_metadata.aac');

    if (await sourceAAC.exists()) {
      await sourceAAC.copy(outputAAC.path);
      print('✓ Copied example.aac → example_with_metadata.aac');

      await tagger.writeCommonTags(outputAAC.path, {
        CommonTags.title: 'My Awesome AAC Audio',
        CommonTags.album: 'Great Album',
        CommonTags.artist: 'Amazing Artist',
        CommonTags.year: '2024',
      });

      final albumArtFile = File('example/example.jpg');
      if (await albumArtFile.exists()) {
        await tagger.writeTag(
          outputAAC.path,
          MetadataTag.binary(
            CommonTags.albumArt,
            await albumArtFile.readAsBytes(),
          ),
        );
        print('✓ Album art written to AAC');
      }

      final writtenTags = await tagger.readCommonTags(outputAAC.path);
      print('✓ Successfully wrote metadata to AAC file!');
      print('  Title: ${writtenTags[CommonTags.title]}');
      print('  Artist: ${writtenTags[CommonTags.artist]}');
    } else {
      print('✗ Source file example.aac not found.');
    }
  } catch (e) {
    print('✗ Error processing AAC: $e');
  }

  // Example: Writing metadata to a WebM file
  print('\nProcessing WebM file...');

  try {
    final sourceWebM = File('example/example.webm');
    final outputWebM = File('example/example_with_metadata.webm');

    if (await sourceWebM.exists()) {
      await sourceWebM.copy(outputWebM.path);
      print('✓ Copied example.webm → example_with_metadata.webm');

      // WebM stores these values as EBML SimpleTag entries.
      final tags = <MetadataTag>[
        MetadataTag.text(CommonTags.title, 'My Awesome WebM Audio'),
        MetadataTag.text(CommonTags.album, 'Great Album'),
        MetadataTag.text(CommonTags.artist, 'Amazing Artist'),
        MetadataTag.text(CommonTags.year, '2024'),
        MetadataTag.text(CommonTags.genre, 'Progressive Rock'),
        MetadataTag.text('CUSTOM_FIELD', 'Custom Value'),
      ];

      await tagger.writeTags(outputWebM.path, tags);
      final writtenTags = await tagger.readCommonTags(outputWebM.path);

      print('✓ Successfully wrote metadata to WebM file!');
      print('  Title: ${writtenTags[CommonTags.title]}');
      print('  Artist: ${writtenTags[CommonTags.artist]}');
    } else {
      print(
        '✗ Source file example.webm not found. Please add a WebM file to test.',
      );
    }
  } catch (e) {
    print('✗ Error processing WebM: $e');
  }

  // Check supported formats
  print('\nSupported file formats: ${tagger.supportedExtensions.join(', ')}');

  // Check if a file is supported
  print('Is MP3 supported? ${tagger.isSupported('test.mp3')}');
  print('Is WAV supported? ${tagger.isSupported('test.wav')}');
}
