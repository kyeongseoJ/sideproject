import 'package:flutter/material.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/mission/behavior_preference_change.dart';
import 'package:novelty_app/mission/mission_models.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/personality/personality_form_screen.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/personality/submission_key.dart';
import 'package:novelty_app/profile/personality_profile_screen.dart';
import 'package:novelty_app/world/world_spike_screen.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/world/world_models.dart';
import 'package:novelty_app/world/world_screen.dart';
import 'package:novelty_app/world/world_name.dart';

class PersonalityExperienceScreen extends StatefulWidget {
  const PersonalityExperienceScreen({
    super.key,
    required this.gateway,
    required this.userKey,
    required this.initialUser,
    this.missionGateway,
    this.submissionSession,
    this.worldGateway,
  });

  final PersonalityGateway gateway;
  final String userKey;
  final UserProfile initialUser;
  final MissionGateway? missionGateway;
  final PersonalitySubmissionSession? submissionSession;
  final WorldGateway? worldGateway;

  @override
  State<PersonalityExperienceScreen> createState() =>
      _PersonalityExperienceScreenState();
}

class _PersonalityExperienceScreenState
    extends State<PersonalityExperienceScreen> {
  late UserProfile _user;
  late bool _showingForm;
  AnalysisMode _analysisMode = AnalysisMode.initial;
  bool _showingWorld = false;
  WorldGrowth? _pendingWorldGrowth;
  BehaviorPreferenceChange? _lastPreferenceChange;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _showingForm = !_user.personalityCompleted;
  }

  @override
  Widget build(BuildContext context) {
    if (_showingWorld) {
      final gateway = widget.worldGateway;
      if (gateway == null) {
        return WorldSpikeScreen(
          onBack: () => setState(() => _showingWorld = false),
        );
      }
      return WorldScreen(
        gateway: gateway,
        userKey: widget.userKey,
        worldName: personalityWorldName(_user.personality!),
        roomAssetCode: personalityWorldRoomAssetCode(_user.personality!),
        baseCategoryCodes: personalityWorldCategories(_user.personality!),
        pendingGrowth: _pendingWorldGrowth,
        onBack: () => setState(() => _showingWorld = false),
      );
    }
    if (_showingForm) {
      return PersonalityFormScreen(
        key: ValueKey<String>('personality-form-${_analysisMode.code}'),
        gateway: widget.gateway,
        userKey: widget.userKey,
        nickname: _user.nickname,
        analysisMode: _analysisMode,
        submissionSession: widget.submissionSession,
        onCompleted: _handleCompleted,
        onCancel: _analysisMode == AnalysisMode.reanalysis
            ? _returnToCurrentProfile
            : null,
      );
    }

    return PersonalityProfileScreen(
      user: _user,
      onReanalyze: _confirmReanalysis,
      onOpenWorld: () => setState(() => _showingWorld = true),
      missionGateway: widget.missionGateway,
      worldGateway: widget.worldGateway,
      userKey: widget.userKey,
      lastPreferenceChange: _lastPreferenceChange,
      pendingWorldGrowth: _pendingWorldGrowth,
      onWorldGrowth: (growth) => setState(() => _pendingWorldGrowth = growth),
      onMissionCompleted: _handleMissionCompleted,
    );
  }

  void _handleMissionCompleted(MissionActionResult result) {
    final personalityChange = result.personalityChange;
    setState(() {
      _lastPreferenceChange = personalityChange == null
          ? null
          : BehaviorPreferenceChange.fromCompletion(personalityChange);
    });
    if (result.personalityUpdated) _refreshUser();
  }

  Future<void> _refreshUser() async {
    try {
      final refreshed = await widget.gateway.getCurrentUser(widget.userKey);
      if (mounted) setState(() => _user = refreshed);
    } catch (_) {
      // 완료 결과는 유지하고 다음 앱 복원 시 최신 프로필을 다시 조회한다.
    }
  }

  Future<void> _confirmReanalysis() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('personality-reanalysis-dialog'),
        title: const Text('성향 분석을 다시 할까요?'),
        content: const Text('새 분석이 완료되기 전까지 현재 프로필은 그대로 유지됩니다.'),
        actions: [
          TextButton(
            key: const Key('personality-reanalysis-dialog-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('personality-reanalysis-dialog-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('다시 분석하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _analysisMode = AnalysisMode.reanalysis;
      _showingForm = true;
    });
  }

  void _handleCompleted(PersonalityAnalysisResult result) {
    setState(() {
      _user = UserProfile(
        userId: _user.userId,
        nickname: _user.nickname,
        personalityCompleted: true,
        personality: result.personality,
      );
      _showingForm = false;
    });
  }

  void _returnToCurrentProfile() {
    if (!_user.personalityCompleted) return;
    setState(() => _showingForm = false);
  }
}
