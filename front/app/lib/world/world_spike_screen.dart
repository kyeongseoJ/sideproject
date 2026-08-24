import 'package:flutter/material.dart';
import 'package:novelty_app/world/world_bridge_controller.dart';
import 'package:novelty_app/world/world_renderer_view.dart';

class WorldSpikeScreen extends StatefulWidget {
  const WorldSpikeScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<WorldSpikeScreen> createState() => _WorldSpikeScreenState();
}

class _WorldSpikeScreenState extends State<WorldSpikeScreen> {
  final WorldBridgeController _controller = WorldBridgeController();
  String _status = 'Renderer 준비 중';
  int _level = 1;

  void _onMessage(Map<String, Object?> message) {
    debugPrint('WORLD_BRIDGE ${message['type']}');
    if (!mounted) return;
    if (message['type'] == 'rendererReady') {
      _controller.send('setSpikeLevel', <String, Object?>{'level': _level});
    }
    setState(
      () => _status = switch (message['type']) {
        'rendererReady' => 'Renderer 준비 완료',
        'rendererError' => 'Renderer 오류',
        'objectLevelChanged' => 'Lv$_level 모델 적용 완료',
        _ => _status,
      },
    );
  }

  void _setLevel(int level) {
    setState(() {
      _level = level;
      _status = 'Lv$level 모델 불러오는 중';
    });
    _controller.send('setSpikeLevel', <String, Object?>{'level': level});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('3D World 기술 검증'),
      leading: IconButton(
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: WorldRendererView(
            controller: _controller,
            onMessage: _onMessage,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: Text(_status)),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Lv1')),
                  ButtonSegment(value: 2, label: Text('Lv2')),
                ],
                selected: {_level},
                onSelectionChanged: (levels) => _setLevel(levels.first),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
