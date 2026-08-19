import 'dart:io';
import 'dart:typed_data';
import 'metadata_tag.dart';

/// Abstract base class for metadata writers
abstract class MetadataWriter {
  /// Writes metadata tags to the specified file
  Future<void> writeTags(String filePath, List<MetadataTag> tags) async {
    await validateFile(filePath);
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final newBytes = await writeTagsToBytes(bytes, tags);
    await file.writeAsBytes(newBytes);
  }

  /// Writes metadata tags directly to a byte array and returns the new byte array
  Future<Uint8List> writeTagsToBytes(Uint8List bytes, List<MetadataTag> tags);

  /// Writes a single metadata tag to the specified file
  Future<void> writeTag(String filePath, MetadataTag tag) async {
    await writeTags(filePath, [tag]);
  }

  /// Removes all metadata from the specified file
  Future<void> clearTags(String filePath) async {
    await writeTags(filePath, []);
  }

  /// Removes all metadata from a byte array and returns the new byte array
  Future<Uint8List> clearTagsFromBytes(Uint8List bytes) async {
    return writeTagsToBytes(bytes, []);
  }

  /// Checks if the file format is supported by this writer
  bool supportsFile(String filePath);

  /// Checks if the raw byte array has a magic header supported by this writer
  bool supportsBytes(Uint8List bytes);

  /// Gets the file extension(s) supported by this writer
  List<String> get supportedExtensions;

  /// Validates that the file exists and is readable/writable
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

    // Check if we can write to the file
    final stat = await file.stat();
    if (stat.mode & 0x80 == 0) {
      // Check write permission
      throw MetadataException('File is not writable', filePath);
    }
  }
}
