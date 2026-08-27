import 'package:flutter/material.dart';
import 'package:novelty_app/world/world_bridge_controller.dart';

class WorldRendererView extends StatelessWidget {
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
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xfff2f2f3),
    child: Center(child: Text('이 플랫폼에서는 3D Renderer를 지원하지 않습니다.')),
  );
}
