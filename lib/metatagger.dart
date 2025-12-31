/// A pure Dart library for reading and writing metadata to MP3, MP4/M4A, and FLAC files with custom tag support.
///
/// This library provides a simple interface for reading and writing metadata tags to audio files.
/// It supports MP3 (ID3v2), MP4/M4A (iTunes-style), and FLAC (Vorbis Comments) formats with custom tag support.
library;

export 'src/metatagger_base.dart';
export 'src/metadata_tag.dart';
export 'src/metadata_writer.dart';
export 'src/metadata_reader.dart';
export 'src/mp3_writer.dart';
export 'src/mp3_reader.dart';
export 'src/mp4_writer.dart';
export 'src/mp4_reader.dart';
export 'src/flac_writer.dart';
export 'src/flac_reader.dart';
