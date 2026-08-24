import 'package:flutter/material.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/novelty_theme.dart';
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
  WorldObjectProgress? _hovered;
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
      if (snapshot.objects.isEmpty) {
        setState(() {
          _snapshot = snapshot;
          _error = 'World 오브젝트 정보를 불러오지 못했습니다.';
        });
        return;
      }
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
    final filteredObjects = snapshot.objects
        .where(
          (object) =>
              object.exp > 0 ||
              widget.baseCategoryCodes.isEmpty ||
              widget.baseCategoryCodes.contains(object.categoryCode),
        )
        .toList();
    // 성향 필터가 모든 오브젝트를 제외하면 전체 목록을 사용해 빈 방을 방지한다.
    final visibleObjects = filteredObjects.isEmpty
        ? snapshot.objects
        : filteredObjects;
    if (visibleObjects.isEmpty) {
      if (mounted) {
        setState(() => _error = 'World 오브젝트 정보를 불러오지 못했습니다.');
      }
      return;
    }
    await _controller.send('initializeWorld', {
      'objectCount': visibleObjects.length,
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
    } else if ((type == 'objectSelected' || type == 'objectHovered') &&
        payload is Map<String, Object?>) {
      final code = payload['objectCode'];
      final matches = _snapshot?.objects.where(
        (item) => item.objectCode == code,
      );
      final object = matches == null || matches.isEmpty ? null : matches.first;
      setState(() {
        if (type == 'objectHovered') {
          _hovered = object;
        } else {
          _selected = object;
        }
      });
    } else if (type == 'sceneTapped') {
      setState(() {
        _selected = null;
        _hovered = null;
      });
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
          if ((_hovered ?? _selected) case final object?)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _WorldObjectTooltip(
                    object: object,
                    pinned: _selected == object,
                    onClose: () => setState(() {
                      _selected = null;
                      _hovered = null;
                    }),
                  ),
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
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: NoveltyColors.primarySubtle),
                  borderRadius: BorderRadius.circular(NoveltyRadii.card),
                ),
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

class _WorldObjectTooltip extends StatelessWidget {
  const _WorldObjectTooltip({
    required this.object,
    required this.pinned,
    required this.onClose,
  });

  final WorldObjectProgress object;
  final bool pinned;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('world-object-tooltip'),
    color: NoveltyColors.canvas,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: NoveltyColors.line),
      borderRadius: BorderRadius.circular(NoveltyRadii.card),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: NoveltyColors.primaryFaint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: NoveltyColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pinned ? '선택한 성장 오브젝트' : '성장 오브젝트',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: NoveltyColors.primaryStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  object.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  '${object.categoryDisplayName} 성향 · 현재 ${object.level}단계 / ${object.maxLevel}단계',
                ),
                const SizedBox(height: 2),
                Text(
                  object.nextLevelRequiredExp == null
                      ? '${object.exp} EXP · 최고 단계 달성'
                      : '${object.exp} EXP · 다음 단계 ${object.nextLevelRequiredExp} EXP',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: NoveltyColors.gray040),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('world-object-tooltip-close'),
            tooltip: '오브젝트 정보 닫기',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(40),
              backgroundColor: NoveltyColors.canvas,
              side: const BorderSide(color: NoveltyColors.line),
            ),
          ),
        ],
      ),
    ),
  );
}
