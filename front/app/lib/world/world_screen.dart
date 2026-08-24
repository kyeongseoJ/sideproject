import 'package:flutter/material.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/world/world_bridge_controller.dart';
import 'package:novelty_app/world/world_models.dart';
import 'package:novelty_app/world/world_renderer_view.dart';

typedef WorldRendererBuilder =
    Widget Function(
      WorldBridgeController controller,
      WorldBridgeMessageCallback onMessage,
    );

class WorldScreen extends StatefulWidget {
  const WorldScreen({
    super.key,
    required this.gateway,
    required this.userKey,
    required this.onBack,
    required this.worldName,
    this.pendingGrowth,
    this.baseCategoryCodes = const <String>{},
    this.rendererBuilder,
  });

  final WorldGateway gateway;
  final String userKey;
  final VoidCallback onBack;
  final String worldName;
  final WorldGrowth? pendingGrowth;
  final Set<String> baseCategoryCodes;
  final WorldRendererBuilder? rendererBuilder;

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  final _controller = WorldBridgeController();
  WorldSnapshot? _snapshot;
  WorldObjectProgress? _selected;
  String? _error;
  bool _rendererReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final snapshot = await widget.gateway.getSnapshot(widget.userKey);
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
      await _initializeRenderer();
    } on WorldApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'World를 불러오지 못했습니다.');
    }
  }

  Future<void> _initializeRenderer() async {
    final snapshot = _snapshot;
    if (!_rendererReady || snapshot == null) return;
    final visibleObjects = snapshot.objects.where(
      (object) =>
          object.exp > 0 ||
          widget.baseCategoryCodes.isEmpty ||
          widget.baseCategoryCodes.contains(object.categoryCode),
    );
    await _controller.send('initializeWorld', {
      'objects': visibleObjects.map((object) => object.toBridgeJson()).toList(),
    });
    final growth = widget.pendingGrowth;
    if (growth != null && growth.rewardApplied) {
      await _controller.send('updateObjectLevel', {
        'objectCode': growth.objectCode,
        'level': growth.currentLevel,
      });
      if (growth.levelUp) {
        await _controller.send('playLevelUp', {
          'objectCode': growth.objectCode,
        });
      }
    }
  }

  void _onMessage(Map<String, Object?> message) {
    final type = message['type'];
    final payload = message['payload'];
    if (type == 'rendererReady') {
      _rendererReady = true;
      _initializeRenderer();
    } else if (type == 'rendererError') {
      final text = payload is Map<String, Object?> ? payload['message'] : null;
      setState(
        () => _error = text is String ? text : '3D Renderer 오류가 발생했습니다.',
      );
    } else if (type == 'objectSelected' && payload is Map<String, Object?>) {
      final code = payload['objectCode'];
      final matches = _snapshot?.objects.where(
        (item) => item.objectCode == code,
      );
      setState(
        () => _selected = matches == null || matches.isEmpty
            ? null
            : matches.first,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.worldName),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child:
                widget.rendererBuilder?.call(_controller, _onMessage) ??
                WorldRendererView(
                  controller: _controller,
                  onMessage: _onMessage,
                ),
          ),
          if (snapshot == null && _error == null)
            const Center(
              child: CircularProgressIndicator(key: Key('world-loading')),
            ),
          if (_error case final error?)
            Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_selected case final object?)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                child: ListTile(
                  title: Text(object.objectCode),
                  subtitle: Text(
                    '${object.categoryCode} · Lv.${object.level} · ${object.exp} EXP',
                  ),
                  trailing: object.nextLevelRequiredExp == null
                      ? const Text('MAX')
                      : Text('다음 ${object.nextLevelRequiredExp}'),
                ),
              ),
            ),
          if (widget.pendingGrowth case final growth?)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    growth.levelUp
                        ? '${growth.objectCode} Lv.${growth.currentLevel} 달성!'
                        : '${growth.objectCode} +${growth.awardedExp} EXP',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
