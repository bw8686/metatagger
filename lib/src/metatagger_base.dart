import 'dart:io';
import 'dart:typed_data';
import 'metadata_tag.dart';
import 'metadata_writer.dart';
import 'metadata_reader.dart';
import 'mp3_writer.dart';
import 'mp3_reader.dart';
import 'mp4_writer.dart';
import 'mp4_reader.dart';
import 'flac_writer.dart';
import 'flac_reader.dart';
import 'ogg_writer.dart';
import 'ogg_reader.dart';

/// Main class for reading and writing metadata to audio files
class MetaTagger {
  final List<MetadataWriter> _writers;
  final List<MetadataReader> _readers;

  /// Creates a MetaTagger instance with default writers and readers for MP3, MP4/M4A, FLAC, and OGG
  MetaTagger()
    : _writers = [Mp3Writer(), Mp4Writer(), FlacWriter(), OggWriter()],
      _readers = [Mp3Reader(), Mp4Reader(), FlacReader(), OggReader()];

  /// Creates a MetaTagger instance with custom writers and readers
  MetaTagger.withWritersAndReaders(this._writers, this._readers);

  /// Creates a MetaTagger instance with custom writers (deprecated - use withWritersAndReaders)
  @Deprecated('Use withWritersAndReaders instead')
  MetaTagger.withWriters(List<MetadataWriter> writers)
    : _writers = writers,
      _readers = [Mp3Reader(), Mp4Reader(), FlacReader(), OggReader()];

  /// Writes metadata tags to an audio file
  ///
  /// Automatically detects the file format and uses the appropriate writer.
  /// Throws [MetadataException] if the file format is not supported or if writing fails.
  Future<void> writeTags(String filePath, List<MetadataTag> tags) async {
    final writer = _getWriterForFile(filePath);
    await writer.writeTags(filePath, tags);
  }

  /// Writes a single metadata tag to an audio file
  ///
  /// This method merges the tag with existing tags rather than replacing all tags.
  /// If a tag with the same key exists, it will be replaced.
  Future<void> writeTag(String filePath, MetadataTag tag) async {
    // Read existing tags
    final existingTags = await readTags(filePath);

    // Remove any existing tag with the same key
    final filteredTags = existingTags.where((t) => t.key != tag.key).toList();

    // Add the new tag
    filteredTags.add(tag);

    // Write all tags back
    await writeTags(filePath, filteredTags);
  }

  /// Writes common metadata tags using a convenient map interface
  ///
  /// Example:
  /// ```dart
  /// await tagger.writeCommonTags('song.mp3', {
  ///   CommonTags.title: 'My Song',
  ///   CommonTags.artist: 'My Artist',
  ///   CommonTags.album: 'My Album',
  /// });
  /// ```
  Future<void> writeCommonTags(
    String filePath,
    Map<String, dynamic> tags,
  ) async {
    final metaTags = tags.entries.map((entry) {
      final value = entry.value;
      if (value is String) {
        return MetadataTag.text(entry.key, value);
      } else if (value is num) {
        return MetadataTag.number(entry.key, value);
      } else {
        return MetadataTag.text(entry.key, value.toString());
      }
    }).toList();

    await writeTags(filePath, metaTags);
  }

  /// Removes all metadata from an audio file
  Future<void> clearTags(String filePath) async {
    final writer = _getWriterForFile(filePath);
    await writer.clearTags(filePath);
  }

  /// Reads all metadata tags from an audio file
  ///
  /// Automatically detects the file format and uses the appropriate reader.
  /// Throws [MetadataException] if the file format is not supported or if reading fails.
  Future<List<MetadataTag>> readTags(String filePath) async {
    final reader = _getReaderForFile(filePath);
    return await reader.readTags(filePath);
  }

  /// Reads a single metadata tag from an audio file
  ///
  /// Returns null if the tag is not found.
  Future<MetadataTag?> readTag(String filePath, String key) async {
    final reader = _getReaderForFile(filePath);
    return await reader.readTag(filePath, key);
  }

  /// Reads common metadata tags and returns them as a convenient map
  ///
  /// Example:
  /// ```dart
  /// final tags = await tagger.readCommonTags('song.mp3');
  /// print('Title: ${tags[CommonTags.title]}');
  /// print('Artist: ${tags[CommonTags.artist]}');
  /// ```
  Future<Map<String, dynamic>> readCommonTags(String filePath) async {
    final tags = await readTags(filePath);
    final result = <String, dynamic>{};

    for (final tag in tags) {
      if (tag.type == TagType.binary) {
        result[tag.key] = tag.value;
      } else {
        result[tag.key] = tag.value.toString();
      }
    }

    return result;
  }

  /// Checks if a file format is supported
  bool isSupported(String filePath) {
    try {
      _getWriterForFile(filePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets all supported file extensions
  List<String> get supportedExtensions {
    final extensions = <String>[];
    for (final writer in _writers) {
      extensions.addAll(writer.supportedExtensions);
    }
    return extensions;
  }

  /// Gets the appropriate writer for a file
  MetadataWriter _getWriterForFile(String filePath) {
    for (final writer in _writers) {
      if (writer.supportsFile(filePath)) {
        return writer;
      }
    }

    final extension = _getFileExtension(filePath);
    throw MetadataException(
      'Unsupported file format: $extension. Supported formats: ${supportedExtensions.join(', ')}',
      filePath,
    );
  }

  /// Gets the appropriate reader for a file
  MetadataReader _getReaderForFile(String filePath) {
    for (final reader in _readers) {
      if (reader.supportsFile(filePath)) {
        return reader;
      }
    }

    final extension = _getFileExtension(filePath);
    throw MetadataException(
      'Unsupported file format: $extension. Supported formats: ${supportedExtensions.join(', ')}',
      filePath,
    );
  }

  /// Gets the file extension from a file path
  String _getFileExtension(String filePath) {
    final file = File(filePath);
    final name = file.path.toLowerCase();
    final lastDot = name.lastIndexOf('.');
    return lastDot >= 0 ? name.substring(lastDot) : '';
  }

  /// Writes metadata tags directly to a byte array and returns the modified byte array
  /// 
  /// Automatically detects the audio format from the bytes magic header.
  /// Throws [MetadataException] if the format is not supported or if writing fails.
  Future<Uint8List> writeTagsToBytes(Uint8List bytes, List<MetadataTag> tags) async {
    final writer = _getWriterForBytes(bytes);
    return await writer.writeTagsToBytes(bytes, tags);
  }

  /// Removes all metadata from a byte array and returns the modified byte array
  Future<Uint8List> clearTagsFromBytes(Uint8List bytes) async {
    final writer = _getWriterForBytes(bytes);
    return await writer.clearTagsFromBytes(bytes);
  }

  /// Reads all metadata tags directly from a byte array
  /// 
  /// Automatically detects the audio format from the bytes magic header.
  /// Throws [MetadataException] if the format is not supported or if reading fails.
  Future<List<MetadataTag>> readTagsFromBytes(Uint8List bytes) async {
    final reader = _getReaderForBytes(bytes);
    return await reader.readTagsFromBytes(bytes);
  }

  /// Gets the appropriate writer for a byte array
  MetadataWriter _getWriterForBytes(Uint8List bytes) {
    for (final writer in _writers) {
      if (writer.supportsBytes(bytes)) {
        return writer;
      }
    }
    throw MetadataException(
      'Unsupported file format in byte array. Supported formats: ${supportedExtensions.join(', ')}',
      'MemoryBuffer',
    );
  }

  /// Gets the appropriate reader for a byte array
  MetadataReader _getReaderForBytes(Uint8List bytes) {
    for (final reader in _readers) {
      if (reader.supportsBytes(bytes)) {
        return reader;
      }
    }
    throw MetadataException(
      'Unsupported file format in byte array. Supported formats: ${supportedExtensions.join(', ')}',
      'MemoryBuffer',
    );
  }
}
