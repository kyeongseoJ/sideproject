import 'package:flutter/material.dart';
import 'package:novelty_app/api/survey_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/survey/survey_models.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key, this.submitter});

  final SurveySubmitter? submitter;

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  static const int _questionCount = 5;

  final SurveyAnswers _answers = SurveyAnswers();
  late final SurveySubmitter _submitter;
  SurveyApi? _ownedApi;
  int _step = -1;
  bool _isSubmitting = false;
  SurveySaveResult? _saveResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.submitter case final submitter?) {
      _submitter = submitter;
    } else {
      final api = SurveyApi();
      _ownedApi = api;
      _submitter = api;
    }
  }

  @override
  void dispose() {
    _ownedApi?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useCardLayout = constraints.maxWidth >= 720;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: useCardLayout ? 24 : 0,
                vertical: useCardLayout ? 24 : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
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
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: _saveResult != null
                            ? _buildCompletion()
                            : _step < 0
                            ? _buildIntroduction()
                            : _buildQuestion(),
                      ),
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

  Widget _buildIntroduction() {
    return Padding(
      key: const ValueKey<String>('introduction'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: NoveltyColors.primaryFaint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 32,
                color: NoveltyColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Novelty',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 24),
          Text(
            '평소의 나를 조금만 알려주세요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '딱 5개만 고르면\n오늘 해볼 만한 새로운 일을 준비할 수 있어요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          FilledButton(
            key: const Key('start-button'),
            onPressed: () => setState(() => _step = 0),
            child: const Text('시작하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Padding(
      key: ValueKey<int>(_step),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (_step + 1) / _questionCount,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_step + 1} / $_questionCount',
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
              child: SingleChildScrollView(child: _questionContent()),
            ),
          ),
          if (_step == 4 && _errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildSubmissionError(),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton(
                key: const Key('back-button'),
                onPressed: _isSubmitting ? null : _goBack,
                child: const Text('이전'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: Key(_step == 4 ? 'complete-button' : 'next-button'),
                  onPressed: _answers.isStepComplete(_step) && !_isSubmitting
                      ? _goNext
                      : null,
                  child: _isSubmitting && _step == 4
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('저장 중...'),
                          ],
                        )
                      : Text(_step == 4 ? '저장하기' : '다음'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionContent() {
    return switch (_step) {
      0 => _singleChoiceQuestion<ActivityLevel>(
        title: '쉬는 날의 나는?',
        value: _answers.activityLevel,
        options: const [
          _SurveyOption(ActivityLevel.indoor, Icons.chair_rounded, '집에서 보내는 편'),
          _SurveyOption(
            ActivityLevel.mixed,
            Icons.local_cafe_rounded,
            '필요하면 나가는 편',
          ),
          _SurveyOption(
            ActivityLevel.outdoor,
            Icons.directions_walk_rounded,
            '밖에서 보내는 편',
          ),
        ],
        onSelected: (value) => setState(() => _answers.activityLevel = value),
      ),
      1 => _singleChoiceQuestion<SocialActivity>(
        title: '시간이 남는다면?',
        value: _answers.socialActivity,
        options: const [
          _SurveyOption(
            SocialActivity.low,
            Icons.headphones_rounded,
            '혼자 시간을 보낸다',
          ),
          _SurveyOption(
            SocialActivity.medium,
            Icons.chat_bubble_rounded,
            '아는 사람에게 연락한다',
          ),
          _SurveyOption(SocialActivity.high, Icons.groups_rounded, '사람을 만난다'),
        ],
        onSelected: (value) => setState(() => _answers.socialActivity = value),
      ),
      2 => _singleChoiceQuestion<NoveltyTolerance>(
        title: '새로운 일을 해본다면?',
        value: _answers.noveltyTolerance,
        options: const [
          _SurveyOption(
            NoveltyTolerance.low,
            Icons.spa_rounded,
            '익숙한 것에 작은 변화',
          ),
          _SurveyOption(
            NoveltyTolerance.medium,
            Icons.eco_rounded,
            '안 해본 것 하나쯤',
          ),
          _SurveyOption(
            NoveltyTolerance.high,
            Icons.park_rounded,
            '완전히 새로운 것도 좋아요',
          ),
        ],
        onSelected: (value) =>
            setState(() => _answers.noveltyTolerance = value),
      ),
      3 => _interestQuestion(),
      4 => _singleChoiceQuestion<EnergyLevel>(
        title: '오늘은 어느 정도 움직일 수 있을까요?',
        value: _answers.energyLevel,
        options: const [
          _SurveyOption(EnergyLevel.low, Icons.spa_rounded, '5분 정도'),
          _SurveyOption(EnergyLevel.medium, Icons.eco_rounded, '10~30분'),
          _SurveyOption(EnergyLevel.high, Icons.park_rounded, '조금 귀찮아도 괜찮아요'),
        ],
        onSelected: (value) => setState(() => _answers.energyLevel = value),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _singleChoiceQuestion<T>({
    required String title,
    required T? value,
    required List<_SurveyOption<T>> options,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionHeader(title: title),
        const SizedBox(height: 24),
        for (final option in options) ...[
          _ChoiceCard<T>(
            option: option,
            selected: option.value == value,
            onTap: () => onSelected(option.value),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _interestQuestion() {
    const options = [
      _SurveyOption(Interest.movement, Icons.directions_walk_rounded, '움직이기'),
      _SurveyOption(Interest.creative, Icons.palette_rounded, '만들기'),
      _SurveyOption(Interest.food, Icons.restaurant_rounded, '먹기'),
      _SurveyOption(Interest.learning, Icons.menu_book_rounded, '배우기'),
      _SurveyOption(Interest.social, Icons.groups_rounded, '사람'),
      _SurveyOption(Interest.outdoor, Icons.park_rounded, '바깥'),
      _SurveyOption(Interest.organizing, Icons.auto_fix_high_rounded, '정리'),
      _SurveyOption(Interest.culture, Icons.music_note_rounded, '문화'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _QuestionHeader(
          title: '그나마 끌리는 걸 골라주세요.',
          helper: '1개 이상, 최대 3개',
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.25,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final option in options)
              _ChoiceCard<Interest>(
                option: option,
                selected: _answers.interests.contains(option.value),
                compact: true,
                onTap: () => _toggleInterest(option.value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${_answers.interests.length} / 3 선택',
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _answers.interests.isEmpty
                ? NoveltyColors.gray040
                : NoveltyColors.primaryStrong,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletion() {
    final saveResult = _saveResult!;
    return Padding(
      key: const ValueKey<String>('completion'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: NoveltyColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 36,
                color: NoveltyColors.success,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '설문이 저장됐어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '저장 번호 ${saveResult.surveyId}\n이 번호로 다음 미션을 준비할 수 있어요.',
            key: const Key('survey-id'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionError() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NoveltyColors.errorFaint,
        border: Border.all(color: NoveltyColors.error),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _errorMessage!,
              key: const Key('submission-error'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('retry-button'),
                onPressed: _isSubmitting ? null : _submit,
                child: const Text('다시 시도'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleInterest(Interest interest) {
    setState(() {
      if (_answers.interests.remove(interest)) {
        return;
      }

      if (_answers.interests.length < 3) {
        _answers.interests.add(interest);
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('관심 활동은 최대 3개까지 선택할 수 있어요.')),
        );
    });
  }

  void _goBack() {
    setState(() {
      if (_step == 0) {
        _step = -1;
      } else {
        _step--;
      }
    });
  }

  void _goNext() {
    if (!_answers.isStepComplete(_step)) {
      return;
    }

    if (_step == _questionCount - 1) {
      _submit();
      return;
    }

    setState(() => _step++);
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_answers.isComplete) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _submitter.submit(_answers);
      if (!mounted) {
        return;
      }
      setState(() => _saveResult = result);
    } on SurveyApiException catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = exception.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = '선택을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.title, this.helper});

  final String title;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (helper != null) ...[
          const SizedBox(height: 8),
          Text(
            helper!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SurveyOption<T> {
  const _SurveyOption(this.value, this.icon, this.label);

  final T value;
  final IconData icon;
  final String label;
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.option,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final _SurveyOption<T> option;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final code = switch (option.value) {
      ActivityLevel value => value.code,
      SocialActivity value => value.code,
      NoveltyTolerance value => value.code,
      Interest value => value.code,
      EnergyLevel value => value.code,
      _ => option.value.toString(),
    };

    return Semantics(
      key: Key('option-$code'),
      button: true,
      selected: selected,
      child: Material(
        color: selected ? NoveltyColors.primaryFaint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? NoveltyColors.primary : NoveltyColors.line,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 20,
              vertical: compact ? 14 : 18,
            ),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  color: selected
                      ? NoveltyColors.primary
                      : NoveltyColors.gray025,
                ),
                SizedBox(width: compact ? 10 : 16),
                Expanded(
                  child: Text(
                    option.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? NoveltyColors.primaryStrong
                          : NoveltyColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_rounded, color: NoveltyColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
