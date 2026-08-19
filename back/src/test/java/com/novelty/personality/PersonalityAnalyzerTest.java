package com.novelty.personality;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.MethodSource;

class PersonalityAnalyzerTest {

    private final PersonalityAnalyzer analyzer = new PersonalityAnalyzer();

    @ParameterizedTest
    @MethodSource("personalityTypes")
    void mapsAllNineAxisCombinationsToTheirPersonalityType(
            IndoorOutdoor indoorOutdoor,
            SocialLevel socialLevel,
            PersonalityType expectedType,
            String expectedName,
            String expectedSummary) {
        PersonalityAnalysis result = analyzer.analyze(validAnswers(indoorOutdoor, socialLevel));

        assertThat(result.type()).isEqualTo(expectedType);
        assertThat(result.type().displayName()).isEqualTo(expectedName);
        assertThat(result.type().summary()).isEqualTo(expectedSummary);
    }

    @ParameterizedTest
    @EnumSource(IndoorOutdoor.class)
    void mapsIndoorOutdoorScores(IndoorOutdoor value) {
        PersonalityAnalysis result = analyzer.analyze(validAnswers(value, SocialLevel.MEDIUM));

        assertThat(result.indoorOutdoorScore()).isEqualTo(value.score());
    }

    @ParameterizedTest
    @EnumSource(SocialLevel.class)
    void mapsSocialLevelScores(SocialLevel value) {
        PersonalityAnalysis result = analyzer.analyze(validAnswers(IndoorOutdoor.MIXED, value));

        assertThat(result.socialLevelScore()).isEqualTo(value.score());
    }

    @ParameterizedTest
    @EnumSource(PhysicalActivityLevel.class)
    void mapsPhysicalActivityLevelScores(PhysicalActivityLevel value) {
        PersonalityAnswers answers = new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                value,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE),
                ExecutionStyle.FLEXIBLE);

        PersonalityAnalysis result = analyzer.analyze(answers);

        assertThat(result.physicalActivityLevelScore()).isEqualTo(value.score());
    }

    @ParameterizedTest
    @EnumSource(NoveltyLevel.class)
    void mapsNoveltyLevelScores(NoveltyLevel value) {
        PersonalityAnswers answers = new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                value,
                List.of(Interest.CREATIVE),
                ExecutionStyle.FLEXIBLE);

        PersonalityAnalysis result = analyzer.analyze(answers);

        assertThat(result.noveltyLevelScore()).isEqualTo(value.score());
    }

    @Test
    void supportingAnswersDoNotChangeTheTypeSelectedByThePrimaryAxes() {
        PersonalityAnalysis quiet = analyzer.analyze(new PersonalityAnswers(
                IndoorOutdoor.OUTDOOR,
                SocialLevel.HIGH,
                PhysicalActivityLevel.LOW,
                NoveltyLevel.LOW,
                List.of(Interest.ORGANIZING),
                ExecutionStyle.PLANNED));
        PersonalityAnalysis active = analyzer.analyze(new PersonalityAnswers(
                IndoorOutdoor.OUTDOOR,
                SocialLevel.HIGH,
                PhysicalActivityLevel.HIGH,
                NoveltyLevel.HIGH,
                List.of(Interest.MOVEMENT, Interest.SOCIAL, Interest.OUTDOOR),
                ExecutionStyle.SPONTANEOUS));

        assertThat(quiet.type()).isEqualTo(PersonalityType.ACTIVE_CONNECTOR);
        assertThat(active.type()).isEqualTo(PersonalityType.ACTIVE_CONNECTOR);
    }

    @Test
    void sameAnswersProduceTheSameAnalysis() {
        PersonalityAnswers answers = validAnswers(IndoorOutdoor.MIXED, SocialLevel.LOW);

        assertThat(analyzer.analyze(answers)).isEqualTo(analyzer.analyze(answers));
    }

    @Test
    void reportsTheCurrentAnalysisVersion() {
        PersonalityAnalysis result = analyzer.analyze(validAnswers(IndoorOutdoor.MIXED, SocialLevel.MEDIUM));

        assertThat(result.analysisVersion()).isEqualTo("PERSONALITY_V2");
    }

    @Test
    void defensivelyCopiesInterestsFromTheCaller() {
        List<Interest> interests = new ArrayList<>(List.of(Interest.CREATIVE));
        PersonalityAnswers answers = new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                interests,
                ExecutionStyle.FLEXIBLE);

        interests.add(Interest.CULTURE);
        PersonalityAnalysis result = analyzer.analyze(answers);

        assertThat(result.interests()).containsExactly(Interest.CREATIVE);
        assertThatThrownBy(() -> result.interests().add(Interest.CULTURE))
                .isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void rejectsMissingAnswersObject() {
        assertValidationError(null, PersonalityValidationError.ANSWERS_REQUIRED);
    }

    @Test
    void rejectsMissingIndoorOutdoor() {
        assertValidationError(new PersonalityAnswers(
                null,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE),
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.INDOOR_OUTDOOR_REQUIRED);
    }

    @Test
    void rejectsMissingSocialLevel() {
        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                null,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE),
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.SOCIAL_LEVEL_REQUIRED);
    }

    @Test
    void rejectsMissingPhysicalActivityLevel() {
        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                null,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE),
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.PHYSICAL_ACTIVITY_LEVEL_REQUIRED);
    }

    @Test
    void rejectsMissingNoveltyLevel() {
        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                null,
                List.of(Interest.CREATIVE),
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.NOVELTY_LEVEL_REQUIRED);
    }

    @Test
    void rejectsNullInterests() {
        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                null,
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.INTERESTS_REQUIRED);
    }

    @Test
    void rejectsEmptyInterests() {
        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                List.of(),
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.INTERESTS_REQUIRED);
    }

    @Test
    void rejectsMoreThanThreeInterests() {
        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                List.of(Interest.MOVEMENT, Interest.CREATIVE, Interest.FOOD, Interest.CULTURE),
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.TOO_MANY_INTERESTS);
    }

    @Test
    void rejectsNullInterestElementWithoutLeakingNullPointerException() {
        List<Interest> interests = new ArrayList<>();
        interests.add(Interest.CREATIVE);
        interests.add(null);

        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                interests,
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.INVALID_INTEREST);
    }

    @Test
    void rejectsDuplicateInterests() {
        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE, Interest.CREATIVE),
                ExecutionStyle.FLEXIBLE), PersonalityValidationError.DUPLICATE_INTERESTS);
    }

    @Test
    void rejectsMissingExecutionStyle() {
        assertValidationError(new PersonalityAnswers(
                IndoorOutdoor.MIXED,
                SocialLevel.MEDIUM,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE),
                null), PersonalityValidationError.EXECUTION_STYLE_REQUIRED);
    }

    private void assertValidationError(
            PersonalityAnswers answers,
            PersonalityValidationError expectedError) {
        assertThatThrownBy(() -> analyzer.analyze(answers))
                .isInstanceOf(InvalidPersonalityAnswersException.class)
                .extracting(exception -> ((InvalidPersonalityAnswersException) exception).error())
                .isEqualTo(expectedError);
    }

    private PersonalityAnswers validAnswers(IndoorOutdoor indoorOutdoor, SocialLevel socialLevel) {
        return new PersonalityAnswers(
                indoorOutdoor,
                socialLevel,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE, Interest.LEARNING),
                ExecutionStyle.FLEXIBLE);
    }

    private static Stream<Arguments> personalityTypes() {
        return Stream.of(
                Arguments.of(
                        IndoorOutdoor.INDOOR,
                        SocialLevel.LOW,
                        PersonalityType.QUIET_FOCUSER,
                        "고요한 몰입가",
                        "익숙하고 조용한 공간에서 혼자 집중할 때 편안해요."),
                Arguments.of(
                        IndoorOutdoor.INDOOR,
                        SocialLevel.MEDIUM,
                        PersonalityType.COZY_EXPLORER,
                        "아늑한 탐색가",
                        "편안한 공간을 중심으로 가끔 새로운 연결을 즐겨요."),
                Arguments.of(
                        IndoorOutdoor.INDOOR,
                        SocialLevel.HIGH,
                        PersonalityType.WARM_HOST,
                        "다정한 아지트지기",
                        "편안한 공간에서 사람들과 온기를 나누는 것을 좋아해요."),
                Arguments.of(
                        IndoorOutdoor.MIXED,
                        SocialLevel.LOW,
                        PersonalityType.FLEXIBLE_INDEPENDENT,
                        "유연한 독립가",
                        "장소에 얽매이지 않고 혼자만의 리듬을 지키는 편이에요."),
                Arguments.of(
                        IndoorOutdoor.MIXED,
                        SocialLevel.MEDIUM,
                        PersonalityType.BALANCED_COORDINATOR,
                        "균형 조율가",
                        "혼자와 함께, 실내와 실외 사이를 상황에 맞게 조율해요."),
                Arguments.of(
                        IndoorOutdoor.MIXED,
                        SocialLevel.HIGH,
                        PersonalityType.OPEN_CONNECTOR,
                        "열린 연결가",
                        "다양한 장소에서 사람과 자연스럽게 어울리는 편이에요."),
                Arguments.of(
                        IndoorOutdoor.OUTDOOR,
                        SocialLevel.LOW,
                        PersonalityType.SOLO_EXPLORER,
                        "독립 탐험가",
                        "바깥에서 혼자 발견하고 경험하는 시간을 좋아해요."),
                Arguments.of(
                        IndoorOutdoor.OUTDOOR,
                        SocialLevel.MEDIUM,
                        PersonalityType.FREE_PIONEER,
                        "자유로운 개척자",
                        "바깥 활동을 즐기며 필요할 때 사람과 연결돼요."),
                Arguments.of(
                        IndoorOutdoor.OUTDOOR,
                        SocialLevel.HIGH,
                        PersonalityType.ACTIVE_CONNECTOR,
                        "활기찬 연결가",
                        "바깥에서 사람들과 함께 움직일 때 활력을 느껴요."));
    }
}
