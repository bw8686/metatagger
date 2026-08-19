import 'dart:typed_data';

/// Generates CRC32 checksums for Ogg pages
class OggCrc32 {
  static final Uint32List _table = _generateTable();

  static Uint32List _generateTable() {
    final table = Uint32List(256);
    for (int i = 0; i < 256; i++) {
      int crc = i << 24;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x80000000) != 0) {
          crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF;
        } else {
          crc = (crc << 1) & 0xFFFFFFFF;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  /// Calculates the OGG CRC32 of the given bytes.
  static int calculate(Uint8List data, [int initialCrc = 0]) {
    int crc = initialCrc;
    for (int i = 0; i < data.length; i++) {
      int index = ((crc >> 24) ^ data[i]) & 0xFF;
      crc = ((crc << 8) ^ _table[index]) & 0xFFFFFFFF;
    }
    return crc;
  }
}
