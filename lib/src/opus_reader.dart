import 'dart:typed_data';

import 'metadata_reader.dart';
import 'metadata_tag.dart';
import 'ogg_reader.dart';
import 'webm_reader.dart';

/// Opus reader that supports both Ogg Opus and WebM-contained Opus files.
class OpusReader extends MetadataReader {
  final OggReader _oggReader = OggReader();
  final WebmReader _webmReader = WebmReader();

  @override
  List<String> get supportedExtensions => ['.opus'];

  @override
  bool supportsFile(String filePath) =>
      filePath.toLowerCase().endsWith('.opus');

  @override
  Future<List<MetadataTag>> readTagsFromBytes(Uint8List bytes) {
    return _isEbml(bytes)
        ? _webmReader.readTagsFromBytes(bytes)
        : _oggReader.readTagsFromBytes(bytes);
  }

  @override
  bool supportsBytes(Uint8List bytes) =>
      _isEbml(bytes) || _oggReader.supportsBytes(bytes);

  bool _isEbml(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x1A &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xDF &&
      bytes[3] == 0xA3;
}
