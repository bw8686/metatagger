## 2.3.1 - 2026-11-05

- **Opus Container Detection**: Added content-aware dispatch for `.opus` files.
  - Ogg Opus files use `OpusTags` metadata and support embedded artwork.
  - WebM-contained Opus files use WebM/EBML metadata handling.
  - Prevents WebM-contained Opus files from being incorrectly sent to the Ogg parser.
- Updated the all-in-one and Opus examples to handle both container types correctly.
- Added regression coverage for WebM-contained Opus metadata and artwork limitations.

## 2.3.0

- **AAC Support**: Added read and write support for raw ADTS `.aac` files using ID3v2 metadata.
  - Supports text, numeric, custom metadata, and embedded album artwork.
  - Added AAC-specific detection so ADTS frames are not misclassified as MP3.
  - Added file and in-memory read/write tests using `example.aac`.
- Added AAC standalone and all-in-one examples and updated format documentation.
- **Opus Support**: Added read and write support for `.opus` files using Ogg Opus `OpusTags` comments.
  - Supports text, numeric, custom metadata, and embedded album artwork.
  - Added valid Opus packet repagination while preserving the audio stream.
  - Added file and in-memory format detection through the existing OGG APIs.
- Added `example.opus`, an Opus example script, all-in-one example coverage, and integration tests.
- Verified rewritten Opus files with standard media probing tools.

## 2.2.0

- **WebM Support**: Added read and write support for EBML metadata in `.webm` files.
  - Supports text, numeric, and custom metadata through `Tags`/`SimpleTag` elements.
  - Supports file-based and in-memory operations with automatic WebM detection.
  - Added `WebmReader` and `WebmWriter` exports.
- WebM embedded artwork is explicitly rejected because attachments are not part of the compliant WebM profile. Use OGG/Opus or MKV/MKA for embedded artwork.
- **MP3 Reliability**: Added valid ID3 padding to prevent “Missing ID3 terminating frame” warnings.
- Added real-file WebM integration tests using `example/example.webm`.
- Added WebM examples and updated format documentation.

## 2.1.0

- **In-Memory Parsing**: Added support for parsing and writing metadata directly from/to `Uint8List` byte arrays without using physical files.
  - Added `readTagsFromBytes(Uint8List bytes)` method
  - Added `writeTagsToBytes(Uint8List bytes, List<MetadataTag> tags)` method
  - Added `clearTagsFromBytes(Uint8List bytes)` method
  - Magic number detection automatically routes the buffer to the correct parser without needing file extensions
- Backwards compatible: File-based methods use the byte-level methods internally
- Added comprehensive in-memory parsing integration tests
- Added `memory_example.dart` example script
- **OGG Support**: Added read and write support for Ogg Vorbis metadata
  - Implemented `OggReader` for extracting Vorbis Comments and Album Art from `.ogg` files
  - Implemented a pure Dart Ogg multiplexer (`OggWriter`) capable of repaginating files to safely modify tags without breaking the container stream
  - Implemented an Ogg-specific CRC32 checksum generator for compliant file manipulation
- Added comprehensive OGG read/write integration tests
- Updated example scripts (`read_example.dart`, `read_write_example.dart`, `metatagger_example.dart`) to demonstrate Ogg capabilities

## 2.0.1
- **MP4 Custom Tags**: Added full support for custom metadata in MP4/M4A files
  - Custom tags stored as freeform (----) atoms with `com.apple.iTunes` namespace
  - Compatible with iTunes, Music.app, and other players
  - Supports text, number, and binary custom tags
- Fixed `writeTag()` method to properly merge with existing tags instead of replacing all metadata
- Added `mp4_custom_tags_example.dart` demonstrating advanced custom tag usage
- Added test coverage for MP4 custom tags 

## 2.0.0

- **BREAKING**: Added read functionality - major feature addition
- Added `MetadataReader` abstract class for reading metadata
- Implemented `Mp3Reader` for reading ID3v2.3 and ID3v2.4 tags from MP3 files
- Implemented `FlacReader` for reading Vorbis Comments and PICTURE blocks from FLAC files
- Implemented `Mp4Writer` for writing iTunes-style metadata to MP4/M4A files
- Implemented `Mp4Reader` for reading iTunes-style metadata from MP4/M4A files
- Added support for `.mp4`, `.m4a`, `.m4v`, and `.m4b` file extensions
- Added `readTags()` method to read all metadata from a file
- Added `readTag()` method to read a specific tag from a file
- Added `readCommonTags()` method to read metadata as a convenient Map
- Enhanced `MetaTagger` constructor to support both readers and writers
- Added comprehensive tests for read and write functionality (19 tests covering MP3, FLAC, and MP4)
- Added `read_example.dart` demonstrating metadata reading
- Added `read_write_example.dart` demonstrating advanced operations (copy, update, migrate)
- Updated README with extensive read functionality documentation
- Technical note: MP4 atom names use Latin-1 encoding for proper handling of © character (0xA9)
- All existing write functionality remains unchanged and compatible

## 1.0.0

- Initial version.
