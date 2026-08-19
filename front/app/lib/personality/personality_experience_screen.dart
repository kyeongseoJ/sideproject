import 'package:flutter/material.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/personality/personality_form_screen.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/personality/submission_key.dart';
import 'package:novelty_app/profile/personality_profile_screen.dart';

class PersonalityExperienceScreen extends StatefulWidget {
  const PersonalityExperienceScreen({
    super.key,
    required this.gateway,
    required this.userKey,
    required this.initialUser,
    this.submissionSession,
  });

  final PersonalityGateway gateway;
  final String userKey;
  final UserProfile initialUser;
  final PersonalitySubmissionSession? submissionSession;

  @override
  State<PersonalityExperienceScreen> createState() =>
      _PersonalityExperienceScreenState();
}

class _PersonalityExperienceScreenState
    extends State<PersonalityExperienceScreen> {
  late UserProfile _user;
  late bool _showingForm;
  AnalysisMode _analysisMode = AnalysisMode.initial;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _showingForm = !_user.personalityCompleted;
  }

  @override
  Widget build(BuildContext context) {
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
    );
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
