# MetaTagger

A pure Dart library for reading and writing metadata to MP3, MP4/M4A, FLAC, and OGG files with custom tag support.

## Features

- **Read & Write Support**: Both read and write metadata tags
- **MP3 Support**: Read and write ID3v2 tags to MP3 files
- **MP4/M4A Support**: Read and write iTunes-style metadata to MP4/M4A files
- **FLAC Support**: Read and write Vorbis Comments to FLAC files  
- **OGG Support**: Read and write Vorbis Comments to OGG files  
- **Custom Tags**: Support for custom metadata fields
- **Album Art**: Support for reading and embedding album artwork
- **Pure Dart**: No native dependencies required
- **Simple API**: Easy-to-use interface for metadata operations

## Supported Formats

| Format | Metadata Standard | File Extensions | Read | Write |
|--------|------------------|-----------------|------|-------|
| MP3    | ID3v2.3/2.4      | `.mp3`          | ✓    | ✓     |
| MP4/M4A | iTunes Metadata | `.mp4`, `.m4a`, `.m4v`, `.m4b` | ✓ | ✓ |
| FLAC   | Vorbis Comments  | `.flac`         | ✓    | ✓     |
| OGG    | Vorbis Comments  | `.ogg`          | ✓    | ✓     |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  metatagger: ^1.0.0
```

## Usage

### Reading Metadata

#### Basic Reading

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Read all metadata as a map
  final tags = await tagger.readCommonTags('song.mp3');
  
  print('Title: ${tags[CommonTags.title]}');
  print('Artist: ${tags[CommonTags.artist]}');
  print('Album: ${tags[CommonTags.album]}');
  print('Year: ${tags[CommonTags.year]}');
}
```

#### Reading Specific Tags

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Read a specific tag
  final titleTag = await tagger.readTag('song.mp3', CommonTags.title);
  if (titleTag != null) {
    print('Title: ${titleTag.value}');
  }
  
  // Read all tags as MetadataTag objects
  final allTags = await tagger.readTags('song.mp3');
  for (final tag in allTags) {
    print('${tag.key}: ${tag.value}');
  }
}
```

#### Reading Album Art

```dart
import 'package:metatagger/metatagger.dart';
import 'dart:io';

void main() async {
  final tagger = MetaTagger();
  
  // Read album art
  final artTag = await tagger.readTag('song.mp3', CommonTags.albumArt);
  if (artTag != null && artTag.type == TagType.binary) {
    // Save album art to file
    await File('cover.jpg').writeAsBytes(artTag.value);
    print('Album art extracted!');
  }
}
```

### Writing Metadata

#### Basic Writing

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

#### Writing Individual Tags

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

All formats support custom tags for storing application-specific metadata.

#### MP3 Custom Tags

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // MP3 stores custom tags as TXXX frames
  await tagger.writeTag('song.mp3', 
    MetadataTag.text('CUSTOM_FIELD', 'Custom Value'));
}
```

#### MP4/M4A Custom Tags

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // MP4 stores custom tags as freeform (----) atoms
  // with namespace com.apple.iTunes
  await tagger.writeTag('song.m4a', 
    MetadataTag.text('MOOD', 'Energetic'));
  
  await tagger.writeTag('song.m4a', 
    MetadataTag.text('PRODUCER', 'John Producer'));
  
  await tagger.writeTag('song.m4a', 
    MetadataTag.text('ISRC', 'USIR12345678'));
}
```

#### FLAC Custom Tags

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // FLAC stores custom tags as Vorbis comments
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

### In-Memory Parsing (No Disk I/O)

You can read and write metadata directly from/to `Uint8List` byte buffers without needing physical file paths. The format is automatically detected from the buffer's magic header.

```dart
import 'dart:typed_data';
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Assume we have an audio file loaded into a Uint8List from network/memory
  Uint8List audioBytes = ...;
  
  // Read tags directly from bytes
  final tags = await tagger.readTagsFromBytes(audioBytes);
  
  // Modify tags in memory (returns a new modified Uint8List)
  final modifiedBytes = await tagger.writeTagsToBytes(audioBytes, [
    MetadataTag.text(CommonTags.title, 'In-Memory Song'),
  ]);
}
```

### Advanced Examples

#### Copy Metadata Between Files

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Read metadata from one file
  final tags = await tagger.readTags('source.mp3');
  
  // Write to another file
  await tagger.writeTags('destination.mp3', tags);
}
```

#### Update Specific Tags

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Read existing tags
  final existingTags = await tagger.readTags('song.mp3');
  
  // Filter out the tag you want to update
  final updatedTags = existingTags.where((t) => t.key != CommonTags.year).toList();
  
  // Add the new value
  updatedTags.add(MetadataTag.text(CommonTags.year, '2025'));
  
  // Write back
  await tagger.writeTags('song.mp3', updatedTags);
}
```

#### Migrate Metadata Between Formats

```dart
import 'package:metatagger/metatagger.dart';

void main() async {
  final tagger = MetaTagger();
  
  // Read from MP3
  final tags = await tagger.readTags('song.mp3');
  
  // Write to FLAC or MP4
  await tagger.writeTags('song.flac', tags);
  await tagger.writeTags('song.m4a', tags);
  
  print('Metadata migrated across formats!');
}
```

### Checking File Support

```dart
import 'package:metatagger/metatagger.dart';

void main() {
  final tagger = MetaTagger();
  
  // Check if a file format is supported
  print('MP3 supported: ${tagger.isSupported('test.mp3')}'); // true
  print('MP4 supported: ${tagger.isSupported('test.m4a')}'); // true
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
