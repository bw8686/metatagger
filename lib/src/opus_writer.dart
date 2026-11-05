import 'dart:typed_data';

import 'metadata_tag.dart';
import 'metadata_writer.dart';
import 'ogg_writer.dart';
import 'webm_writer.dart';

/// Opus writer that supports both Ogg Opus and WebM-contained Opus files.
class OpusWriter extends MetadataWriter {
  final OggWriter _oggWriter = OggWriter();
  final WebmWriter _webmWriter = WebmWriter();

  @override
  List<String> get supportedExtensions => ['.opus'];

  @override
  bool supportsFile(String filePath) =>
      filePath.toLowerCase().endsWith('.opus');

  @override
  Future<Uint8List> writeTagsToBytes(Uint8List bytes, List<MetadataTag> tags) {
    return _isEbml(bytes)
        ? _webmWriter.writeTagsToBytes(bytes, tags)
        : _oggWriter.writeTagsToBytes(bytes, tags);
  }

  @override
  bool supportsBytes(Uint8List bytes) =>
      _isEbml(bytes) || _oggWriter.supportsBytes(bytes);

  bool _isEbml(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x1A &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xDF &&
      bytes[3] == 0xA3;
}
