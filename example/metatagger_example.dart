import 'package:metatagger/metatagger.dart';
import 'dart:io';

void main() async {
  // Create a MetaTagger instance
  final tagger = MetaTagger();

  // NOTE: Place your source audio files in this directory:
  // - example.mp3 (source MP3 file)
  // - example.flac (source FLAC file)
  // The script will create new files with metadata: example_with_metadata.mp3 and example_with_metadata.flac

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
        MetadataTag.text(CommonTags.lyrics, 'This is my awesome song\nWith multiple lines of lyrics\nShowing how great it sounds'),
        
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
        MetadataTag.text(CommonTags.lyrics, 'This is my awesome song\nWith multiple lines of lyrics\nShowing how great it sounds'),
        
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

  // Check supported formats
  print('\nSupported file formats: ${tagger.supportedExtensions.join(', ')}');

  // Check if a file is supported
  print('Is MP3 supported? ${tagger.isSupported('test.mp3')}');
  print('Is WAV supported? ${tagger.isSupported('test.wav')}');
}
