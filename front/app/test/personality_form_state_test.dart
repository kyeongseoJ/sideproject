import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/personality/personality_form_state.dart';
import 'package:novelty_app/personality/personality_models.dart';

void main() {
  test('requires all six answers before creating the V2 answer model', () {
    final state = PersonalityFormState();

    expect(state.isComplete, isFalse);
    expect(state.isStepComplete(0), isFalse);
    expect(state.toAnswers, throwsStateError);

    _complete(state);

    expect(state.isComplete, isTrue);
    expect(state.toAnswers().toJson(), {
      'indoorOutdoor': 'INDOOR',
      'socialLevel': 'LOW',
      'physicalActivityLevel': 'MEDIUM',
      'noveltyLevel': 'HIGH',
      'interests': ['CREATIVE'],
      'executionStyle': 'PLANNED',
    });
  });

  test('allows one to three unique interests and rejects a fourth', () {
    final state = PersonalityFormState();

    expect(
      state.toggleInterest(PersonalityInterest.creative),
      InterestSelectionResult.added,
    );
    expect(
      state.toggleInterest(PersonalityInterest.learning),
      InterestSelectionResult.added,
    );
    expect(
      state.toggleInterest(PersonalityInterest.culture),
      InterestSelectionResult.added,
    );
    expect(
      state.toggleInterest(PersonalityInterest.food),
      InterestSelectionResult.limitReached,
    );
    expect(state.interests, hasLength(3));
    expect(
      state.toggleInterest(PersonalityInterest.learning),
      InterestSelectionResult.removed,
    );
    expect(state.interests, [
      PersonalityInterest.creative,
      PersonalityInterest.culture,
    ]);
  });
}

void _complete(PersonalityFormState state) {
  state
    ..indoorOutdoor = IndoorOutdoor.indoor
    ..socialLevel = SocialLevel.low
    ..physicalActivityLevel = PhysicalActivityLevel.medium
    ..noveltyLevel = NoveltyLevel.high
    ..toggleInterest(PersonalityInterest.creative)
    ..executionStyle = ExecutionStyle.planned;
}
