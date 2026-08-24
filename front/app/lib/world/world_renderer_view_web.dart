import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:novelty_app/world/world_bridge_controller.dart';
import 'package:web/web.dart' as web;

class WorldRendererView extends StatefulWidget {
  const WorldRendererView({
    super.key,
    required this.controller,
    required this.onMessage,
  });

  final WorldBridgeController controller;
  final WorldBridgeMessageCallback onMessage;

  @override
  State<WorldRendererView> createState() => _WorldRendererViewState();
}

class _WorldRendererViewState extends State<WorldRendererView> {
  static int _nextViewId = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _frame;
  late final JSFunction _messageListener;

  @override
  void initState() {
    super.initState();
    _viewType = 'novelty-world-${_nextViewId++}';
    _frame = web.HTMLIFrameElement()
      ..src = 'assets/assets/world3d/index.html'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
    _messageListener = ((web.Event event) {
      final messageEvent = event as web.MessageEvent;
      if (messageEvent.origin != web.window.location.origin) return;
      final raw = messageEvent.data?.dartify();
      if (raw is! String) return;
      final decoded = decodeWorldBridgeMessage(raw);
      if (decoded != null) widget.onMessage(decoded);
    }).toJS;
    web.window.addEventListener('message', _messageListener);
    _frame.addEventListener(
      'load',
      ((web.Event _) {
        unawaited(widget.controller.attach(_sendToRenderer));
      }).toJS,
      <String, Object?>{'once': true}.jsify()!,
    );
  }

  Future<void> _sendToRenderer(String message) async {
    _frame.contentWindow?.postMessage(
      message.toJS,
      web.window.location.origin.toJS,
    );
  }

  @override
  void dispose() {
    widget.controller.send('dispose');
    widget.controller.detach();
    web.window.removeEventListener('message', _messageListener);
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
