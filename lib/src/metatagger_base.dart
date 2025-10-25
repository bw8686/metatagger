import 'dart:io';
import 'metadata_tag.dart';
import 'metadata_writer.dart';
import 'mp3_writer.dart';
import 'flac_writer.dart';

/// Main class for writing metadata to audio files
class MetaTagger {
  final List<MetadataWriter> _writers;

  /// Creates a MetaTagger instance with default writers for MP3 and FLAC
  MetaTagger() : _writers = [Mp3Writer(), FlacWriter()];

  /// Creates a MetaTagger instance with custom writers
  MetaTagger.withWriters(this._writers);

  /// Writes metadata tags to an audio file
  /// 
  /// Automatically detects the file format and uses the appropriate writer.
  /// Throws [MetadataException] if the file format is not supported or if writing fails.
  Future<void> writeTags(String filePath, List<MetadataTag> tags) async {
    final writer = _getWriterForFile(filePath);
    await writer.writeTags(filePath, tags);
  }

  /// Writes a single metadata tag to an audio file
  Future<void> writeTag(String filePath, MetadataTag tag) async {
    await writeTags(filePath, [tag]);
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
  Future<void> writeCommonTags(String filePath, Map<String, dynamic> tags) async {
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

  /// Gets the file extension from a file path
  String _getFileExtension(String filePath) {
    final file = File(filePath);
    final name = file.path.toLowerCase();
    final lastDot = name.lastIndexOf('.');
    return lastDot >= 0 ? name.substring(lastDot) : '';
  }
}
