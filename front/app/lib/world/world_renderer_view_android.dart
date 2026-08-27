import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:novelty_app/world/world_bridge_controller.dart';
import 'package:novelty_app/world/world_asset_server.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WorldRendererView extends StatefulWidget {
  const WorldRendererView({
    super.key,
    required this.controller,
    required this.onMessage,
    this.interactive = true,
  });

  final WorldBridgeController controller;
  final WorldBridgeMessageCallback onMessage;
  final bool interactive;

  @override
  State<WorldRendererView> createState() => _WorldRendererViewState();
}

class _WorldRendererViewState extends State<WorldRendererView> {
  late final WebViewController _webViewController;
  final WorldAssetServer _assetServer = WorldAssetServer();
  Uri? _assetOrigin;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xfff2f2f3))
      ..addJavaScriptChannel(
        'NoveltyWorldBridge',
        onMessageReceived: (message) {
          final decoded = decodeWorldBridgeMessage(message.message);
          if (decoded != null) widget.onMessage(decoded);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => widget.controller.attach(_sendToRenderer),
          onNavigationRequest: (request) {
            final origin = _assetOrigin;
            return origin != null && request.url.startsWith(origin.origin)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) => widget.onMessage(<String, Object?>{
            'version': 1,
            'type': 'rendererError',
            'payload': <String, Object?>{'message': error.description},
          }),
        ),
      );
    _loadRenderer();
  }

  Future<void> _loadRenderer() async {
    try {
      final uri = await _assetServer.start();
      _assetOrigin = uri;
      await _webViewController.loadRequest(uri);
    } catch (error) {
      widget.onMessage(<String, Object?>{
        'version': 1,
        'type': 'rendererError',
        'payload': <String, Object?>{'message': '$error'},
      });
    }
  }

  Future<void> _sendToRenderer(String message) =>
      _webViewController.runJavaScript(
        'window.NoveltyWorld.receiveFromFlutter(${jsonEncode(message)});',
      );

  @override
  void dispose() {
    widget.controller.send('dispose');
    widget.controller.detach();
    _assetServer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.interactive,
    child: WebViewWidget(controller: _webViewController),
  );
}
