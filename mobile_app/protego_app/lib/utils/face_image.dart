import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Resolve e exibe rostos vindos de base64, URL ou data-URI.
class FaceImage {
  FaceImage._();

  static Uint8List? decodeBase64(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      var data = raw;
      if (data.contains(',')) {
        data = data.split(',').last;
      }
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  static bool isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  static Widget build({
    String? frameB64,
    String? fotoUrl,
    double height = 200,
    double? width,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    final bytes = decodeBase64(frameB64);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              placeholder ?? _placeholder(height: height, width: width),
        ),
      );
    }

    if (isHttpUrl(fotoUrl)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          fotoUrl!,
          height: height,
          width: width,
          fit: fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _placeholder(height: height, width: width);
          },
          errorBuilder: (context, error, stackTrace) =>
              placeholder ?? _placeholder(height: height, width: width),
        ),
      );
    }

    return placeholder ?? _placeholder(height: height, width: width);
  }

  static Widget thumbnail({
    String? frameB64,
    String? fotoUrl,
    double size = 48,
    IconData fallbackIcon = Icons.face,
    Color? fallbackColor,
  }) {
    final bytes = decodeBase64(frameB64);
    if (bytes != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: MemoryImage(bytes),
      );
    }

    if (isHttpUrl(fotoUrl)) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(fotoUrl!),
        onBackgroundImageError: (exception, stackTrace) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: fallbackColor ?? Colors.blueGrey.shade700,
      child: Icon(fallbackIcon, color: Colors.white, size: size * 0.5),
    );
  }

  static Widget _placeholder({double height = 200, double? width}) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.face_retouching_natural, size: 48, color: Colors.grey),
      ),
    );
  }
}
