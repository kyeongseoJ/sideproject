import 'package:flutter/material.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/world/world_bridge_controller.dart';
import 'package:novelty_app/world/world_models.dart';
import 'package:novelty_app/world/world_renderer_view.dart';

typedef WorldPreviewRendererBuilder =
    Widget Function(
      WorldBridgeController controller,
      WorldBridgeMessageCallback onMessage,
    );

class WorldPreview extends StatefulWidget {
  const WorldPreview({
    super.key,
    required this.gateway,
    required this.userKey,
    required this.worldName,
    required this.baseCategoryCodes,
    required this.onOpen,
    this.rendererBuilder,
  });

  final WorldGateway gateway;
  final String userKey;
  final String worldName;
  final Set<String> baseCategoryCodes;
  final VoidCallback onOpen;
  final WorldPreviewRendererBuilder? rendererBuilder;

  @override
  State<WorldPreview> createState() => _WorldPreviewState();
}

class _WorldPreviewState extends State<WorldPreview> {
  final _controller = WorldBridgeController();
  WorldSnapshot? _snapshot;
  String? _error;
  bool _rendererReady = false;
  bool _helpExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<WorldObjectProgress> _visibleObjects(WorldSnapshot snapshot) {
    final selected = snapshot.objects
        .where(
          (object) =>
              object.exp > 0 ||
              widget.baseCategoryCodes.contains(object.categoryCode),
        )
        .toList();
    return selected.isEmpty ? snapshot.objects.take(1).toList() : selected;
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.gateway.getSnapshot(widget.userKey);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
      await _initialize();
    } on WorldApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '3D 공간을 불러오지 못했습니다.');
    }
  }

  Future<void> _initialize() async {
    final snapshot = _snapshot;
    if (!_rendererReady || snapshot == null) return;
    await _controller.send('initializeWorld', {
      'objects': _visibleObjects(
        snapshot,
      ).map((object) => object.toBridgeJson()).toList(),
    });
  }

  void _onMessage(Map<String, Object?> message) {
    switch (message['type']) {
      case 'rendererReady':
        _rendererReady = true;
        _initialize();
      case 'objectSelected':
      case 'sceneTapped':
        widget.onOpen();
      case 'rendererError':
        final payload = message['payload'];
        final text = payload is Map<String, Object?>
            ? payload['message']
            : null;
        if (mounted)
          setState(
            () => _error = text is String ? text : '3D Renderer 오류가 발생했습니다.',
          );
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('world-inline-preview'),
    decoration: BoxDecoration(
      color: NoveltyColors.surfaceAlt,
      border: Border.all(color: NoveltyColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('world-preview-open-header'),
          onTap: widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.view_in_ar_rounded,
                  color: NoveltyColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.worldName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Text('전체 화면'),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_full_rounded, size: 18),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 320,
          child: Stack(
            children: [
              Positioned.fill(
                child:
                    widget.rendererBuilder?.call(_controller, _onMessage) ??
                    WorldRendererView(
                      controller: _controller,
                      onMessage: _onMessage,
                    ),
              ),
              if (_snapshot == null && _error == null)
                const Center(child: CircularProgressIndicator()),
              if (_error case final error?)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _load,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                bottom: 10,
                right: 12,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: InkWell(
                    key: const Key('world-help-toggle'),
                    onTap: () => setState(() => _helpExpanded = !_helpExpanded),
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      constraints: const BoxConstraints(minHeight: 32),
                      padding: EdgeInsets.symmetric(
                        horizontal: _helpExpanded ? 12 : 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: _helpExpanded
                          ? const Text('드래그 회전 · 휠/핀치 확대 · 공간 탭 전체보기')
                          : const Icon(Icons.question_mark_rounded, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
