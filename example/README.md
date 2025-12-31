# MetaTagger Examples

This directory contains example scripts demonstrating how to use MetaTagger with different audio/video formats.

## Example Files Included

- `example.mp3` - Sample MP3 file
- `example.flac` - Sample FLAC file  
- `example.mp4` - Sample MP4 video file
- `example.jpg` - Sample album art image

## Example Scripts

### 🎯 Basic Examples

#### `simple_example.dart`
The simplest way to get started. Shows basic read and write operations using MP3 files.

```bash
cd example
dart run simple_example.dart
```

#### `mp4_example.dart`
Complete MP4/M4A metadata handling including:
- Reading existing metadata
- Writing new tags
- Updating specific fields
- Adding custom tags
- Working with video files

```bash
cd example
dart run mp4_example.dart
```

### 🔄 Advanced Examples

#### `read_write_example.dart`
Advanced operations including:
- Copying metadata between files
- Updating specific tags
- Migrating metadata between formats

```bash
cd example
dart run read_write_example.dart
```

#### `format_migration_example.dart`
Cross-format metadata migration:
- MP3 → MP4
- FLAC → MP4
- MP4 → MP3
- Universal metadata to all formats

```bash
cd example
dart run format_migration_example.dart
```

### 📚 Reference Examples

#### `metatagger_example.dart`
Comprehensive example showing all features for MP3 and FLAC.

```bash
dart run example/metatagger_example.dart
```

#### `read_example.dart`
Detailed examples of reading metadata from files.

```bash
dart run example/read_example.dart
```

#### `demo_without_files.dart`
Demonstrates API usage without requiring actual media files.

```bash
dart run example/demo_without_files.dart
```

## Output Files

The examples create test files with modified metadata. These are safe to delete:

- `*_test.*` - Test copies used by examples
- `migrated_from_*.*` - Files created by migration examples
- `universal_test.*` - Universal metadata test files
- `*_with_metadata.*` - Files with added metadata

## Supported Formats

| Format | Extensions | Read | Write |
|--------|-----------|------|-------|
| MP3 | `.mp3` | ✓ | ✓ |
| MP4/M4A | `.mp4`, `.m4a`, `.m4v`, `.m4b` | ✓ | ✓ |
| FLAC | `.flac` | ✓ | ✓ |

## Tips

- Examples are designed to run from the `example/` directory
- Original example files are never modified (copies are made)
- You can add your own media files to test with
- All examples handle missing files gracefully
