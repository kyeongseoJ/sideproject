import 'package:flutter/material.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_form_state.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/personality/submission_key.dart';

class PersonalityFormScreen extends StatefulWidget {
  const PersonalityFormScreen({
    super.key,
    required this.gateway,
    required this.userKey,
    required this.nickname,
    this.analysisMode = AnalysisMode.initial,
    this.onCompleted,
    this.onCancel,
    this.submissionSession,
  });

  final PersonalityGateway gateway;
  final String userKey;
  final String nickname;
  final AnalysisMode analysisMode;
  final ValueChanged<PersonalityAnalysisResult>? onCompleted;
  final VoidCallback? onCancel;
  final PersonalitySubmissionSession? submissionSession;

  @override
  State<PersonalityFormScreen> createState() => _PersonalityFormScreenState();
}

class _PersonalityFormScreenState extends State<PersonalityFormScreen> {
  static const int _questionCount = 6;

  final PersonalityFormState _answers = PersonalityFormState();
  late final PersonalitySubmissionSession _submissionSession;
  int _step = 0;
  bool _isSubmitting = false;
  String? _errorMessage;
  PersonalityAnalysisResult? _result;

  @override
  void initState() {
    super.initState();
    _submissionSession =
        widget.submissionSession ?? PersonalitySubmissionSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useCardLayout = constraints.maxWidth >= 720;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(useCardLayout ? 24 : 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: useCardLayout
                          ? Border.all(color: NoveltyColors.line)
                          : null,
                      borderRadius: BorderRadius.circular(
                        useCardLayout ? 16 : 0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        useCardLayout ? 16 : 0,
                      ),
                      child: _result == null
                          ? _buildForm()
                          : _buildResultBoundary(_result!),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      key: const Key('personality-form'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.nickname,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (widget.onCancel != null)
                TextButton(
                  key: const Key('personality-form-cancel'),
                  onPressed: _isSubmitting ? null : widget.onCancel,
                  child: const Text('기존 프로필로 돌아가기'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '성향 분석 진행률 ${_step + 1}단계, 총 $_questionCount단계',
                  child: LinearProgressIndicator(
                    key: const Key('personality-progress'),
                    value: (_step + 1) / _questionCount,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_step + 1} / $_questionCount',
                key: const Key('personality-step-label'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(
            child: AbsorbPointer(
              absorbing: _isSubmitting,
              child: SingleChildScrollView(
                key: ValueKey<int>(_step),
                child: _questionContent(),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _SubmissionError(
              message: _errorMessage!,
              onRetry: _isSubmitting ? null : _submit,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton(
                key: const Key('personality-back-button'),
                onPressed: _step == 0 || _isSubmitting ? null : _goBack,
                child: const Text('이전'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: Key(
                    _step == _questionCount - 1
                        ? 'personality-submit-button'
                        : 'personality-next-button',
                  ),
                  onPressed:
                      _answers.isStepComplete(_step) &&
                          !_isSubmitting &&
                          _errorMessage == null
                      ? _goNext
                      : null,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('분석 중...'),
                          ],
                        )
                      : Text(_step == _questionCount - 1 ? '분석하기' : '다음'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionContent() => switch (_step) {
    0 => _singleChoiceQuestion<IndoorOutdoor>(
      title: '쉬는 날의 나는?',
      description: '평소 더 편하게 느끼는 장소를 골라주세요.',
      value: _answers.indoorOutdoor,
      options: const [
        _FormOption(IndoorOutdoor.indoor, 'INDOOR', '집이나 실내에서 보내는 편'),
        _FormOption(IndoorOutdoor.mixed, 'MIXED', '상황에 따라 달라지는 편'),
        _FormOption(IndoorOutdoor.outdoor, 'OUTDOOR', '밖으로 나가는 편'),
      ],
      onSelected: (value) => _update(() => _answers.indoorOutdoor = value),
    ),
    1 => _singleChoiceQuestion<SocialLevel>(
      title: '시간이 생겼을 때 더 편한 쪽은?',
      description: '사람들과 함께하는 정도를 알려주세요.',
      value: _answers.socialLevel,
      options: const [
        _FormOption(SocialLevel.low, 'LOW', '혼자 시간을 보낸다'),
        _FormOption(SocialLevel.medium, 'MEDIUM', '가끔 아는 사람과 함께한다'),
        _FormOption(SocialLevel.high, 'HIGH', '사람을 만나거나 함께한다'),
      ],
      onSelected: (value) => _update(() => _answers.socialLevel = value),
    ),
    2 => _singleChoiceQuestion<PhysicalActivityLevel>(
      title: '새로운 활동을 고를 때 편한 움직임은?',
      description: '장소가 아니라 평소 편한 움직임의 강도를 골라주세요.',
      value: _answers.physicalActivityLevel,
      options: const [
        _FormOption(PhysicalActivityLevel.low, 'LOW', '앉아서 하거나 거의 움직이지 않는 활동'),
        _FormOption(PhysicalActivityLevel.medium, 'MEDIUM', '가볍게 걷고 움직이는 활동'),
        _FormOption(PhysicalActivityLevel.high, 'HIGH', '땀이 나거나 몸을 많이 쓰는 활동'),
      ],
      onSelected: (value) =>
          _update(() => _answers.physicalActivityLevel = value),
    ),
    3 => _singleChoiceQuestion<NoveltyLevel>(
      title: '새로운 일을 해본다면?',
      description: '부담 없이 시도할 수 있는 변화의 크기를 골라주세요.',
      value: _answers.noveltyLevel,
      options: const [
        _FormOption(NoveltyLevel.low, 'LOW', '익숙한 것에 작은 변화를 주는 정도'),
        _FormOption(NoveltyLevel.medium, 'MEDIUM', '안 해본 것 하나쯤 시도하는 정도'),
        _FormOption(NoveltyLevel.high, 'HIGH', '완전히 새로운 것도 시도하는 정도'),
      ],
      onSelected: (value) => _update(() => _answers.noveltyLevel = value),
    ),
    4 => _interestQuestion(),
    5 => _singleChoiceQuestion<ExecutionStyle>(
      title: '새로운 일을 시작할 때 나는?',
      description: '평소 시작하는 방식과 가장 가까운 것을 골라주세요.',
      value: _answers.executionStyle,
      options: const [
        _FormOption(ExecutionStyle.planned, 'PLANNED', '순서와 준비물을 먼저 확인하는 편'),
        _FormOption(
          ExecutionStyle.flexible,
          'FLEXIBLE',
          '큰 방향만 정하고 상황에 맞춰 바꾸는 편',
        ),
        _FormOption(
          ExecutionStyle.spontaneous,
          'SPONTANEOUS',
          '일단 시작하면서 다음을 정하는 편',
        ),
      ],
      onSelected: (value) => _update(() => _answers.executionStyle = value),
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _singleChoiceQuestion<T>({
    required String title,
    required String description,
    required T? value,
    required List<_FormOption<T>> options,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionHeader(title: title, description: description),
        const SizedBox(height: 24),
        for (final option in options) ...[
          _ChoiceTile(
            key: Key('personality-option-${_step + 1}-${option.code}'),
            label: option.label,
            selected: value == option.value,
            onTap: () => onSelected(option.value),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _interestQuestion() {
    const options = <_FormOption<PersonalityInterest>>[
      _FormOption(PersonalityInterest.movement, 'MOVEMENT', '움직이기'),
      _FormOption(PersonalityInterest.creative, 'CREATIVE', '만들기'),
      _FormOption(PersonalityInterest.food, 'FOOD', '음식'),
      _FormOption(PersonalityInterest.learning, 'LEARNING', '배우기'),
      _FormOption(PersonalityInterest.social, 'SOCIAL', '사람'),
      _FormOption(PersonalityInterest.outdoor, 'OUTDOOR', '바깥'),
      _FormOption(PersonalityInterest.organizing, 'ORGANIZING', '정리'),
      _FormOption(PersonalityInterest.culture, 'CULTURE', '문화'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _QuestionHeader(
          title: '어떤 활동에 관심이 있나요?',
          description: '한 개 이상, 세 개 이하로 골라주세요.',
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            '${_answers.interests.length} / 3 선택',
            key: const Key('personality-interest-count'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _answers.interests.length == 3
                  ? NoveltyColors.primaryStrong
                  : NoveltyColors.gray040,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (_answers.interests.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '계속하려면 관심 분야를 한 개 이상 선택해 주세요.',
            key: const Key('personality-interest-required'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 520 ? 2 : 1,
          childAspectRatio: 4.5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final option in options)
              _ChoiceTile(
                key: Key('personality-option-5-${option.code}'),
                label: option.label,
                selected: _answers.interests.contains(option.value),
                compact: true,
                onTap: () => _toggleInterest(option.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultBoundary(PersonalityAnalysisResult result) {
    return Padding(
      key: const Key('personality-analysis-result'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 40,
            color: NoveltyColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            '성향 분석이 완료됐어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            result.personality.typeName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '전체 성향 프로필과 다시 하기는 다음 단계에서 연결됩니다.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: NoveltyColors.gray040),
          ),
        ],
      ),
    );
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _errorMessage = null;
    });
  }

  void _toggleInterest(PersonalityInterest interest) {
    final result = _answers.toggleInterest(interest);
    setState(() {
      _errorMessage = null;
      if (result == InterestSelectionResult.limitReached) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              key: Key('personality-interest-limit-error'),
              content: Text('관심 분야는 최대 3개까지 선택할 수 있어요.'),
            ),
          );
      }
    });
  }

  void _goBack() {
    if (_step <= 0 || _isSubmitting) return;
    setState(() {
      _step--;
      _errorMessage = null;
    });
  }

  void _goNext() {
    if (!_answers.isStepComplete(_step) || _isSubmitting) return;
    if (_step < _questionCount - 1) {
      setState(() {
        _step++;
        _errorMessage = null;
      });
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    if (!_answers.isComplete || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final request = PersonalityAnalysisRequest(
      submissionKey: _submissionSession.keyForAttempt(),
      analysisMode: widget.analysisMode,
      answers: _answers.toAnswers(),
    );
    try {
      final result = await widget.gateway.submitAnalysis(
        widget.userKey,
        request,
      );
      if (!mounted) return;
      _submissionSession.complete();
      if (widget.onCompleted case final onCompleted?) {
        onCompleted(result);
        return;
      }
      setState(() {
        _isSubmitting = false;
        _result = result;
      });
    } on PersonalityApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = exception.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = '성향 분석을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? NoveltyColors.primaryFaint : NoveltyColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? NoveltyColors.primary : NoveltyColors.line,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 12 : 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected
                      ? NoveltyColors.primary
                      : NoveltyColors.gray075,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmissionError extends StatelessWidget {
  const _SubmissionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('personality-submit-error'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NoveltyColors.errorFaint,
          border: Border.all(color: NoveltyColors.error),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: NoveltyColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton(
              key: const Key('personality-retry-button'),
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormOption<T> {
  const _FormOption(this.value, this.code, this.label);

  final T value;
  final String code;
  final String label;
}
