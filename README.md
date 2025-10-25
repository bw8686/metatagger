# MetaTagger

A pure Dart library for writing metadata to MP3 and FLAC files with custom tag support.

## Features

- **MP3 Support**: Write ID3v2.4 tags to MP3 files
- **FLAC Support**: Write Vorbis Comments to FLAC files  
- **Custom Tags**: Support for custom metadata fields
- **Album Art**: Support for embedding album artwork
- **Pure Dart**: No native dependencies required
- **Simple API**: Easy-to-use interface for metadata operations

## Supported Formats

| Format | Metadata Standard | File Extensions |
|--------|------------------|-----------------|
| MP3    | ID3v2.4          | `.mp3`          |
| FLAC   | Vorbis Comments  | `.flac`         |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  metatagger: ^1.0.0
```

## Usage

### Basic Usage

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Write metadata using the convenient map interface
  await tagger.writeCommonTags('song.mp3', {
    CommonTags.title: 'My Song',
    CommonTags.artist: 'My Artist',
    CommonTags.album: 'My Album',
    CommonTags.year: '2024',
    CommonTags.genre: 'Rock',
    CommonTags.track: '1',
  });
}
```

### Writing Individual Tags

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Write individual tags
  await tagger.writeTag('song.mp3', 
    MetadataTag.text(CommonTags.composer, 'John Doe'));
  
  await tagger.writeTag('song.mp3', 
    MetadataTag.number(CommonTags.bpm, 120));
}
```

### Custom Tags

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Write custom tags
  await tagger.writeTag('song.mp3', 
    MetadataTag.text('CUSTOM_FIELD', 'Custom Value'));
  
  await tagger.writeTag('song.flac', 
    MetadataTag.text('MY_CUSTOM_TAG', 'Some custom data'));
}
```

### Album Art

```dart
import 'package:metatagger/metatagger.dart';
import 'dart:io';

void main() async {
  final tagger = MetaTagger();
  final imageBytes = await File('album_art.jpg').readAsBytes();
  
  // Add album art
  await tagger.writeTag('song.mp3', 
    MetadataTag.binary(CommonTags.albumArt, imageBytes));
}
```

### Multiple Tags at Once

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  final tags = [
    MetadataTag.text(CommonTags.title, 'Song Title'),
    MetadataTag.text(CommonTags.artist, 'Artist Name'),
    MetadataTag.text(CommonTags.album, 'Album Name'),
    MetadataTag.number(CommonTags.track, 1),
    MetadataTag.text('CUSTOM_TAG', 'Custom Value'),
  ];
  
  await tagger.writeTags('song.flac', tags);
}
```

### Clearing Metadata

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Remove all metadata from a file
  await tagger.clearTags('song.mp3');
}
```

### Checking File Support

```dart
import 'package:metatagger/metatagger.dart';

void main() {
  final tagger = MetaTagger();
  
  // Check if a file format is supported
  print('MP3 supported: ${tagger.isSupported('test.mp3')}'); // true
  print('WAV supported: ${tagger.isSupported('test.wav')}'); // false
  
  // Get all supported extensions
  print('Supported formats: ${tagger.supportedExtensions}'); // [.mp3, .flac]
}
```

## Common Tags

The library provides constants for common metadata tags:

```dart
CommonTags.title          // Song title
CommonTags.artist         // Artist name
CommonTags.album          // Album name
CommonTags.albumArtist    // Album artist
CommonTags.date           // Release date
CommonTags.year           // Release year
CommonTags.genre          // Music genre
CommonTags.track          // Track number
CommonTags.trackTotal     // Total tracks
CommonTags.disc           // Disc number
CommonTags.discTotal      // Total discs
CommonTags.comment        // Comment
CommonTags.composer       // Composer
CommonTags.performer      // Performer
CommonTags.conductor      // Conductor
CommonTags.lyricist       // Lyricist
CommonTags.copyright      // Copyright
CommonTags.encodedBy      // Encoded by
CommonTags.bpm            // Beats per minute
CommonTags.mood           // Mood
CommonTags.isrc           // ISRC code
CommonTags.barcode        // Barcode
CommonTags.catalogNumber  // Catalog number
CommonTags.label          // Record label
CommonTags.lyrics         // Song lyrics
CommonTags.albumArt       // Album artwork
```

## Tag Types

The library supports different types of metadata:

- **Text Tags**: `MetadataTag.text(key, value)`
- **Number Tags**: `MetadataTag.number(key, value)`
- **Binary Tags**: `MetadataTag.binary(key, bytes)` (for album art)

## Error Handling

The library throws `MetadataException` for various error conditions:

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  try {
    await tagger.writeTag('nonexistent.mp3', 
      MetadataTag.text(CommonTags.title, 'Test'));
  } catch (e) {
    if (e is MetadataException) {
      print('Metadata error: ${e.message}');
      if (e.filePath != null) {
        print('File: ${e.filePath}');
      }
    }
  }
}
```

## Format-Specific Notes

### MP3 (ID3v2.4)
- Uses ID3v2.4 format for maximum compatibility
- Supports UTF-8 encoding for international characters
- Album art stored as APIC frames
- Custom tags use TXXX frames

### FLAC (Vorbis Comments)
- Uses standard Vorbis Comment format
- All text is UTF-8 encoded
- Album art stored as METADATA_BLOCK_PICTURE
- Custom tags supported natively

## License

This project is licensed under the GPLv3 License - see the LICENSE file for details.
