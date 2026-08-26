import 'dart:async';

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
    this.pendingGrowth,
    this.rendererBuilder,
  });

  final WorldGateway gateway;
  final String userKey;
  final String worldName;
  final Set<String> baseCategoryCodes;
  final VoidCallback onOpen;
  final WorldGrowth? pendingGrowth;
  final WorldPreviewRendererBuilder? rendererBuilder;

  @override
  State<WorldPreview> createState() => _WorldPreviewState();
}

class _WorldPreviewState extends State<WorldPreview> {
  final _controller = WorldBridgeController();
  WorldSnapshot? _snapshot;
  String? _error;
  bool _rendererReady = false;
  bool _worldInitialized = false;
  bool _helpExpanded = false;
  Timer? _helpTimer;
  Timer? _initializeRetryTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorldPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingGrowth != oldWidget.pendingGrowth) {
      _applyPendingGrowth();
    }
  }

  @override
  void dispose() {
    _helpTimer?.cancel();
    _initializeRetryTimer?.cancel();
    super.dispose();
  }

  void _showHelp() {
    _helpTimer?.cancel();
    setState(() => _helpExpanded = true);
    _helpTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _helpExpanded = false);
    });
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
      if (snapshot.objects.isEmpty) {
        setState(() {
          _snapshot = snapshot;
          _error = 'World 오브젝트 정보를 불러오지 못했습니다.';
        });
        return;
      }
      _worldInitialized = false;
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
    if (snapshot == null) return;
    final objects = _visibleObjects(snapshot);
    if (objects.isEmpty) {
      if (mounted) {
        setState(() => _error = 'World 오브젝트 정보를 불러오지 못했습니다.');
      }
      return;
    }
    _initializeRetryTimer?.cancel();
    _initializeRetryTimer = Timer.periodic(const Duration(milliseconds: 350), (
      timer,
    ) {
      if (!mounted || _worldInitialized) {
        timer.cancel();
        return;
      }
      unawaited(_sendInitializeWorld(objects));
    });
    await _sendInitializeWorld(objects);
  }

  Future<void> _sendInitializeWorld(List<WorldObjectProgress> objects) async {
    await _controller.send('initializeWorld', {
      'objectCount': objects.length,
      'objects': objects.map((object) => object.toBridgeJson()).toList(),
    });
    if (_rendererReady) {
      await _applyPendingGrowth();
    }
  }

  Future<void> _applyPendingGrowth() async {
    final growth = widget.pendingGrowth;
    if (!_rendererReady || growth == null || !growth.rewardApplied) return;
    await _controller.send('updateObjectLevel', {
      'objectCode': growth.objectCode,
      'level': growth.currentLevel,
    });
    if (growth.levelUp) {
      await _controller.send('playLevelUp', {'objectCode': growth.objectCode});
    }
  }

  void _onMessage(Map<String, Object?> message) {
    switch (message['type']) {
      case 'rendererReady':
        _rendererReady = true;
        unawaited(_initialize());
        break;
      case 'worldInitialized':
        _worldInitialized = true;
        _initializeRetryTimer?.cancel();
        break;
      case 'objectSelected':
      case 'sceneTapped':
        widget.onOpen();
        break;
      case 'rendererError':
        final payload = message['payload'];
        final text = payload is Map<String, Object?>
            ? payload['message']
            : null;
        if (mounted) {
          setState(
            () => _error = text is String ? text : '3D Renderer 오류가 발생했습니다.',
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('world-inline-preview'),
    decoration: BoxDecoration(
      color: NoveltyColors.surfaceAlt,
      border: Border.all(color: NoveltyColors.line),
      borderRadius: BorderRadius.circular(NoveltyRadii.card),
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
            ],
          ),
        ),
        Material(
          color: NoveltyColors.canvas,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  key: const Key('world-help-toggle'),
                  tooltip: '공간 조작 안내',
                  onPressed: _showHelp,
                  icon: const Icon(Icons.help_outline_rounded),
                  color: NoveltyColors.primary,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(40),
                    backgroundColor: NoveltyColors.canvas,
                    side: const BorderSide(color: NoveltyColors.line),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: NoveltyMotion.slow,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _helpExpanded
                        ? const Text(
                            '드래그 회전 · 휠 또는 터치 확대 · 공간 클릭 시 전체 보기',
                            key: Key('world-help-text'),
                          )
                        : const SizedBox(key: Key('world-help-hidden')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
