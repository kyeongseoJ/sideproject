import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WorldAssetServer {
  HttpServer? _server;

  Future<Uri> start() async {
    final existing = _server;
    if (existing != null) {
      return Uri.parse('http://127.0.0.1:${existing.port}/index.html');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(_serve(server));
    return Uri.parse('http://127.0.0.1:${server.port}/index.html');
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        final rawPath = request.uri.path == '/'
            ? '/index.html'
            : request.uri.path;
        final path = Uri.decodeComponent(
          rawPath,
        ).replaceFirst(RegExp(r'^/+'), '');
        if (path.contains('..')) {
          request.response.statusCode = HttpStatus.badRequest;
        } else {
          final data = await rootBundle.load('assets/world3d/$path');
          request.response.headers.contentType = _contentType(path);
          request.response.add(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        }
      } on FlutterError {
        request.response.statusCode = HttpStatus.notFound;
      } catch (_) {
        request.response.statusCode = HttpStatus.internalServerError;
      } finally {
        await request.response.close();
      }
    }
  }

  ContentType _contentType(String path) {
    if (path.endsWith('.html')) return ContentType.html;
    if (path.endsWith('.js'))
      return ContentType('application', 'javascript', charset: 'utf-8');
    if (path.endsWith('.css'))
      return ContentType('text', 'css', charset: 'utf-8');
    if (path.endsWith('.glb')) return ContentType('model', 'gltf-binary');
    return ContentType.binary;
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }
}
