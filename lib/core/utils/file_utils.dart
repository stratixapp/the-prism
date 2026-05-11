// lib/core/utils/file_utils.dart
// File type helpers, MIME detection, and size formatting.

import 'dart:io';
import 'package:mime/mime.dart';
import '../../core/constants/app_constants.dart';

abstract class FileUtils {
  /// Returns the file extension in lowercase, without the dot.
  static String extension(String filePath) {
    final name = filePath.split('/').last;
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  /// Returns human-readable file size string.
  static String sizeLabel(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Returns MIME type for a file path, with fallback.
  static String mimeType(String filePath) {
    return lookupMimeType(filePath) ?? 'application/octet-stream';
  }

  /// Returns true if the file extension is supported by The Prism.
  static bool isSupported(String filePath) {
    final ext = extension(filePath);
    return AppConstants.supportedExtensions.contains(ext);
  }

  /// Returns true if the file size is within the limit.
  static bool isWithinSizeLimit(File file) {
    try {
      return file.lengthSync() <= AppConstants.maxFileSizeBytes;
    } catch (_) {
      return false;
    }
  }

  /// Returns a category label for the file type (for UI grouping).
  static String categoryLabel(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'Document';
      case 'docx':
      case 'doc':
        return 'Word Document';
      case 'xlsx':
      case 'xls':
        return 'Spreadsheet';
      case 'csv':
        return 'Data File';
      case 'zip':
        return 'Archive';
      case 'apk':
        return 'Android App';
      case 'json':
        return 'JSON Data';
      case 'xml':
        return 'XML File';
      case 'txt':
      case 'md':
        return 'Text File';
      case 'pptx':
        return 'Presentation';
      case 'png':
      case 'jpg':
      case 'jpeg':
        return 'Image';
      case 'py':
      case 'js':
      case 'ts':
      case 'dart':
      case 'kt':
      case 'java':
      case 'swift':
        return 'Source Code';
      default:
        return 'File';
    }
  }
}
