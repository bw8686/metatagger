import 'dart:typed_data';

/// Represents a metadata tag with a key-value pair
class MetadataTag {
  final String key;
  final dynamic value;
  final TagType type;

  const MetadataTag({
    required this.key,
    required this.value,
    this.type = TagType.text,
  });

  /// Creates a text tag
  factory MetadataTag.text(String key, String value) {
    return MetadataTag(key: key, value: value, type: TagType.text);
  }

  /// Creates a binary tag (for album art, etc.)
  factory MetadataTag.binary(String key, Uint8List value) {
    return MetadataTag(key: key, value: value, type: TagType.binary);
  }

  /// Creates a number tag
  factory MetadataTag.number(String key, num value) {
    return MetadataTag(key: key, value: value, type: TagType.number);
  }

  @override
  String toString() => 'MetadataTag($key: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetadataTag &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          type == other.type;

  @override
  int get hashCode => key.hashCode ^ value.hashCode ^ type.hashCode;
}

/// Types of metadata tags
enum TagType {
  text,
  binary,
  number,
}

/// Common metadata tag keys
class CommonTags {
  static const String title = 'TITLE';
  static const String artist = 'ARTIST';
  static const String album = 'ALBUM';
  static const String albumArtist = 'ALBUMARTIST';
  static const String date = 'DATE';
  static const String year = 'YEAR';
  static const String genre = 'GENRE';
  static const String track = 'TRACKNUMBER';
  static const String trackTotal = 'TRACKTOTAL';
  static const String disc = 'DISCNUMBER';
  static const String discTotal = 'DISCTOTAL';
  static const String comment = 'COMMENT';
  static const String composer = 'COMPOSER';
  static const String performer = 'PERFORMER';
  static const String conductor = 'CONDUCTOR';
  static const String lyricist = 'LYRICIST';
  static const String copyright = 'COPYRIGHT';
  static const String encodedBy = 'ENCODEDBY';
  static const String bpm = 'BPM';
  static const String mood = 'MOOD';
  static const String isrc = 'ISRC';
  static const String barcode = 'BARCODE';
  static const String catalogNumber = 'CATALOGNUMBER';
  static const String label = 'LABEL';
  static const String lyrics = 'LYRICS';
  static const String albumArt = 'ALBUMART';
}

/// Exception thrown when metadata writing fails
class MetadataException implements Exception {
  final String message;
  final String? filePath;

  const MetadataException(this.message, [this.filePath]);

  @override
  String toString() {
    if (filePath != null) {
      return 'MetadataException: $message (File: $filePath)';
    }
    return 'MetadataException: $message';
  }
}
