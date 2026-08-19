import 'dart:io';
import 'dart:typed_data';
import 'metadata_tag.dart';

/// Abstract base class for metadata readers
abstract class MetadataReader {
  /// Reads all metadata tags from the specified file
  Future<List<MetadataTag>> readTags(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return readTagsFromBytes(bytes);
  }

  /// Reads all metadata tags directly from a byte array
  Future<List<MetadataTag>> readTagsFromBytes(Uint8List bytes);

  /// Reads a specific metadata tag from the specified file
  Future<MetadataTag?> readTag(String filePath, String key) async {
    final tags = await readTags(filePath);
    try {
      return tags.firstWhere(
        (tag) => tag.key.toUpperCase() == key.toUpperCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Checks if the file format is supported by this reader
  bool supportsFile(String filePath);

  /// Checks if the raw byte array has a magic header supported by this reader
  bool supportsBytes(Uint8List bytes);

  /// Gets the file extension(s) supported by this reader
  List<String> get supportedExtensions;

  /// Validates that the file exists and is readable
  Future<void> validateFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw MetadataException('File does not exist', filePath);
    }

    try {
      // Check if we can read the file
      await file.openRead().take(1).drain();
    } catch (e) {
      throw MetadataException('Cannot read file: $e', filePath);
    }
  }
}
