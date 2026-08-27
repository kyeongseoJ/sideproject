import 'dart:async';

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
    this.roomAssetCode = 'room',
    this.pendingGrowth,
    this.baseCategoryCodes = const <String>{},
    this.debugOverlay,
    this.rendererBuilder,
  });

  final WorldGateway gateway;
  final String userKey;
  final VoidCallback onBack;
  final String worldName;
  final String roomAssetCode;
  final WorldGrowth? pendingGrowth;
  final Set<String> baseCategoryCodes;
  final Widget? debugOverlay;
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
  bool _worldInitialized = false;
  bool _growthPresentationSent = false;
  bool _showGrowthSummary = false;
  Timer? _initializeRetryTimer;
  Timer? _growthSummaryTimer;

  @override
  void initState() {
    super.initState();
    _showGrowthSummary = widget.pendingGrowth?.rewardApplied ?? false;
    if (_showGrowthSummary) _scheduleGrowthSummaryDismissal();
    _load();
  }

  @override
  void dispose() {
    _initializeRetryTimer?.cancel();
    _growthSummaryTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WorldScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingGrowth != oldWidget.pendingGrowth) {
      _growthPresentationSent = false;
      _growthSummaryTimer?.cancel();
      _showGrowthSummary = false;
      if (_rendererReady) unawaited(_initializeRenderer());
    }
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
      _worldInitialized = false;
      setState(() => _snapshot = snapshot);
      await _initializeRenderer();
    } on WorldApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'World를 불러오지 못했습니다.');
    }
  }

  List<WorldObjectProgress>? _visibleObjects() {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    // Before the first completion only the base room is rendered. The first
    // category object becomes visible once it has received EXP.
    return snapshot.objects.where((object) => object.exp > 0).toList();
  }

  Future<void> _initializeRenderer() async {
    final visibleObjects = _visibleObjects();
    if (visibleObjects == null) return;
    _initializeRetryTimer?.cancel();
    _initializeRetryTimer = Timer.periodic(const Duration(milliseconds: 350), (
      timer,
    ) {
      if (!mounted || _worldInitialized) {
        timer.cancel();
        return;
      }
      unawaited(_sendInitializeWorld(visibleObjects));
    });
    await _sendInitializeWorld(visibleObjects);
  }

  Future<void> _sendInitializeWorld(
    List<WorldObjectProgress> visibleObjects,
  ) async {
    await _controller.send('initializeWorld', {
      'objectCount': visibleObjects.length,
      'objects': visibleObjects.map((object) => object.toBridgeJson()).toList(),
      'roomAssetCode': widget.roomAssetCode,
      'roomDecorationLevel': worldRoomDecorationLevel(visibleObjects),
    });
    if (!_rendererReady) return;
    final growth = widget.pendingGrowth;
    if (growth != null && growth.rewardApplied && !_growthPresentationSent) {
      _growthPresentationSent = true;
      await _controller.send('updateObjectLevel', {
        'objectCode': growth.objectCode,
        'level': growth.currentLevel,
      });
      if (growth.levelUp) {
        await _controller.send('playLevelUp', {
          'objectCode': growth.objectCode,
        });
      }
      await _controller.send('focusGrowthObject', {
        'objectCode': growth.objectCode,
        'levelUp': growth.levelUp,
      });
      _showGrowthSummaryFor(growth);
    }
  }

  void _showGrowthSummaryFor(WorldGrowth growth) {
    if (!mounted) return;
    setState(() => _showGrowthSummary = true);
    _scheduleGrowthSummaryDismissal();
  }

  void _scheduleGrowthSummaryDismissal() {
    _growthSummaryTimer?.cancel();
    _growthSummaryTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showGrowthSummary = false);
    });
  }

  WorldObjectProgress? _objectForGrowth(WorldGrowth growth) {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    for (final object in snapshot.objects) {
      if (object.objectCode == growth.objectCode) return object;
    }
    return null;
  }

  void _onMessage(Map<String, Object?> message) {
    final type = message['type'];
    final payload = message['payload'];
    if (type == 'rendererReady') {
      _rendererReady = true;
      unawaited(_initializeRenderer());
    } else if (type == 'worldInitialized') {
      _worldInitialized = true;
      _initializeRetryTimer?.cancel();
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
    final growth = widget.pendingGrowth;
    final roomLevel = snapshot == null
        ? null
        : worldRoomDecorationLevel(snapshot.objects);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.worldName),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (roomLevel case final level?)
            Tooltip(
              message: _roomLevelTooltip(level),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: NoveltyColors.primaryFaint,
                      border: Border.all(color: NoveltyColors.primarySubtle),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '노벨티 Lv.$level',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: NoveltyColors.primaryStrong),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: widget.debugOverlay == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(116),
                child: widget.debugOverlay!,
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
          if (_showGrowthSummary && growth != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _WorldGrowthSummary(
                    growth: growth,
                    object: _objectForGrowth(growth),
                    onClose: () {
                      _growthSummaryTimer?.cancel();
                      setState(() => _showGrowthSummary = false);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _roomLevelTooltip(int level) => switch (level) {
  1 => '노벨티 성장 Lv.1\n바닥·벽·문·창문 기본 구조가 보입니다.',
  2 => '노벨티 성장 Lv.2\n기본 구조 + 나머지 장식 25%가 보입니다.',
  3 => '노벨티 성장 Lv.3\n기본 구조 + 나머지 장식 50%가 보입니다.',
  4 => '노벨티 성장 Lv.4\n기본 구조 + 나머지 장식 75%가 보입니다.',
  _ => '노벨티 성장 Lv.5\n기본 구조 + 나머지 장식 100%가 보입니다.',
};

class _WorldGrowthSummary extends StatelessWidget {
  const _WorldGrowthSummary({
    required this.growth,
    required this.object,
    required this.onClose,
  });

  final WorldGrowth growth;
  final WorldObjectProgress? object;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final objectName = object?.displayName ?? growth.categoryCode;
    final categoryName = object?.categoryDisplayName ?? growth.categoryCode;
    final headline = growth.levelUp
        ? '$objectName Lv.${growth.currentLevel} 달성!'
        : '$objectName 성장 진행 중';

    return Material(
      key: const Key('world-growth-summary'),
      color: NoveltyColors.canvas,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NoveltyColors.primarySubtle),
        borderRadius: BorderRadius.circular(NoveltyRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                    '미션 완료로 공간이 변화했어요',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: NoveltyColors.primaryStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$categoryName · 노벨티 경험치 + ${growth.awardedExp} EXP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NoveltyColors.gray040,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('world-growth-summary-close'),
              tooltip: '성장 결과 닫기',
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
