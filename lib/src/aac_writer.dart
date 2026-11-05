import 'dart:typed_data';

import 'mp3_writer.dart';

/// AAC ADTS metadata writer using ID3v2 tags.
class AacWriter extends Mp3Writer {
  @override
  List<String> get supportedExtensions => ['.aac'];

  @override
  bool supportsFile(String filePath) => filePath.toLowerCase().endsWith('.aac');

  @override
  bool supportsBytes(Uint8List bytes) {
    var offset = 0;
    if (bytes.length >= 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      final size =
          (bytes[6] << 21) | (bytes[7] << 14) | (bytes[8] << 7) | bytes[9];
      offset = 10 + size + ((bytes[5] & 0x10) != 0 ? 10 : 0);
    }
    return offset + 2 <= bytes.length &&
        bytes[offset] == 0xFF &&
        (bytes[offset + 1] & 0xF0) == 0xF0 &&
        (bytes[offset + 1] & 0x06) == 0;
  }
}
