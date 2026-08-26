import 'package:flutter/material.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/world/world_models.dart';
import 'package:novelty_app/world/world_screen.dart';

const _testRooms = <String, String>{
  'classroom_2': '고요한 몰입가',
  'art_gallery_4': '아늑한 탐색가',
  'cafe_5': '다정한 아지트지기',
  'music_store_20': '유연한 독립가',
  'flower_shop_26': '균형 조율가',
  'Theatre_32': '열린 연결가',
  'Gym_25': '독립 탐험가',
  'bookshop_7': '자유로운 개척자',
  'stadium_40': '활기찬 연결가',
};

class WorldLevelTestScreen extends StatefulWidget {
  const WorldLevelTestScreen({super.key});

  @override
  State<WorldLevelTestScreen> createState() => _WorldLevelTestScreenState();
}

class _WorldLevelTestScreenState extends State<WorldLevelTestScreen> {
  int _level = 1;
  String _roomAssetCode = _testRooms.keys.first;

  void _increaseLevel() {
    setState(() => _level = (_level + 1).clamp(1, 5));
  }

  void _reset() {
    setState(() => _level = 1);
  }

  @override
  Widget build(BuildContext context) {
    final gateway = _TestWorldGateway(_level);
    return WorldScreen(
      key: ValueKey<String>('world-test-$_roomAssetCode-$_level'),
      gateway: gateway,
      userKey: 'world-test-user',
      onBack: () {},
      worldName: 'World 테스트 · $_level단계',
      roomAssetCode: _roomAssetCode,
      debugOverlay: _TestControls(
        level: _level,
        roomAssetCode: _roomAssetCode,
        onRoomChanged: (value) => setState(() => _roomAssetCode = value),
        onIncrease: _increaseLevel,
        onReset: _reset,
      ),
    );
  }
}

class _TestControls extends StatelessWidget {
  const _TestControls({
    required this.level,
    required this.roomAssetCode,
    required this.onRoomChanged,
    required this.onIncrease,
    required this.onReset,
  });

  final int level;
  final String roomAssetCode;
  final ValueChanged<String> onRoomChanged;
  final VoidCallback onIncrease;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Material(
    color: NoveltyColors.canvas,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: NoveltyColors.line),
      borderRadius: BorderRadius.circular(NoveltyRadii.card),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => _showRoomPicker(context),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(_testRooms[roomAssetCode]!),
          ),
          Text('장식 단계 Lv.$level'),
          FilledButton(
            onPressed: level < 5 ? onIncrease : null,
            child: const Text('전체 +1'),
          ),
          OutlinedButton(onPressed: onReset, child: const Text('초기화')),
        ],
      ),
    ),
  );

  Future<void> _showRoomPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final entry in _testRooms.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == roomAssetCode
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null) onRoomChanged(selected);
  }
}

class _TestWorldGateway implements WorldGateway {
  _TestWorldGateway(this.level);

  final int level;

  @override
  Future<WorldSnapshot> getSnapshot(String userKey) async => WorldSnapshot([
    for (final object in _testObjects)
      WorldObjectProgress(
        objectCode: object.$1,
        categoryCode: object.$2,
        displayName: object.$3,
        level: level,
        exp: level == 1 ? 0 : 1,
        nextLevelRequiredExp: level < 5 ? 10 : null,
        maxLevel: 5,
      ),
  ]);
}

const _testObjects = [
  ('TRAINING_CORNER', 'MOVEMENT', 'Training Corner'),
  ('ART_EASEL', 'CREATIVE', 'Art Easel'),
  ('KITCHEN_TABLE', 'FOOD', 'Kitchen Table'),
  ('BOOKSHELF', 'LEARNING', 'Bookshelf'),
  ('MESSAGE_BOARD', 'SOCIAL', 'Message Board'),
  ('INDOOR_GARDEN', 'OUTDOOR', 'Indoor Garden'),
  ('STORAGE_CABINET', 'ORGANIZING', 'Storage Cabinet'),
  ('RECORD_PLAYER', 'CULTURE', 'Record Player'),
];
