package com.novelty.personality;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.transaction.annotation.Transactional;

import com.novelty.user.UserAuthenticationException;
import com.novelty.user.UserService;

class PersonalityServiceTest {

    private static final String SUBMISSION_KEY = "2c3ed6f9-5780-4da8-9c73-830ce137b899";
    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-08-19T17:15:00+09:00");

    private PersonalityRepository repository;
    private UserService userService;
    private PersonalityService service;

    @BeforeEach
    void setUp() {
        repository = mock(PersonalityRepository.class);
        userService = mock(UserService.class);
        Clock clock = Clock.fixed(
                Instant.parse("2026-08-19T08:15:00Z"),
                ZoneId.of("Asia/Seoul"));
        service = new PersonalityService(repository, userService, clock);

        when(userService.requireUserId(any())).thenReturn(7L);
        when(repository.findSubmission(anyLong(), anyString())).thenReturn(Optional.empty());
        when(repository.nextAnalysisId()).thenReturn(42L);
    }

    @Test
    void savesInitialAnalysisInTransactionOrder() {
        when(repository.profileExists(7L)).thenReturn(false);

        PersonalitySubmissionResult result = service.analyze("user-key", validRequest(AnalysisMode.INITIAL));

        assertThat(result.created()).isTrue();
        assertThat(result.response().analysisId()).isEqualTo(42L);
        assertThat(result.response().status()).isEqualTo("ANALYZED");
        assertThat(result.response().personality().typeCode()).isEqualTo("QUIET_FOCUSER");
        assertThat(result.response().personality().interests())
                .containsExactly(Interest.CREATIVE, Interest.LEARNING);
        assertThat(result.response().personality().analyzedAt()).isEqualTo(NOW);

        InOrder order = inOrder(repository);
        order.verify(repository).lockUser(7L);
        order.verify(repository).findSubmission(7L, SUBMISSION_KEY);
        order.verify(repository).profileExists(7L);
        order.verify(repository).nextAnalysisId();
        order.verify(repository).insertSubmission(
                anyLong(), anyLong(), anyString(), any(), any(), any());
        order.verify(repository).insertProfile(anyLong(), anyLong(), any(), any());
        order.verify(repository).replaceProfileInterests(
                7L, List.of(Interest.CREATIVE, Interest.LEARNING));
        order.verify(repository).touchUser(7L, NOW);
        verify(repository, never()).updateProfile(anyLong(), anyLong(), any(), any());
    }

    @Test
    void returnsExistingResultForIdempotentRetryWithoutNewWrites() {
        PersonalityAnswers storedAnswers = canonicalAnswers();
        when(repository.findSubmission(7L, SUBMISSION_KEY))
                .thenReturn(Optional.of(new StoredPersonalitySubmission(
                        31L,
                        AnalysisMode.INITIAL,
                        storedAnswers,
                        "PERSONALITY_V2",
                        NOW.minusHours(1))));

        PersonalitySubmissionResult result = service.analyze("user-key", validRequest(AnalysisMode.INITIAL));

        assertThat(result.created()).isFalse();
        assertThat(result.response().analysisId()).isEqualTo(31L);
        assertThat(result.response().personality().analyzedAt()).isEqualTo(NOW.minusHours(1));
        verify(repository).touchUser(7L, NOW);
        verify(repository, never()).profileExists(anyLong());
        verify(repository, never()).nextAnalysisId();
        verify(repository, never()).insertSubmission(anyLong(), anyLong(), anyString(), any(), any(), any());
    }

    @Test
    void treatsDifferentInterestOrderAsTheSameIdempotentRequest() {
        when(repository.findSubmission(7L, SUBMISSION_KEY))
                .thenReturn(Optional.of(new StoredPersonalitySubmission(
                        31L,
                        AnalysisMode.INITIAL,
                        canonicalAnswers(),
                        "PERSONALITY_V2",
                        NOW)));
        PersonalityAnalysisRequest request = new PersonalityAnalysisRequest(
                SUBMISSION_KEY,
                AnalysisMode.INITIAL,
                IndoorOutdoor.INDOOR,
                SocialLevel.LOW,
                PhysicalActivityLevel.LOW,
                NoveltyLevel.MEDIUM,
                List.of(Interest.LEARNING, Interest.CREATIVE),
                ExecutionStyle.PLANNED);

        assertThat(service.analyze("user-key", request).created()).isFalse();
    }

    @Test
    void rejectsDifferentAnswersForExistingSubmissionKey() {
        when(repository.findSubmission(7L, SUBMISSION_KEY))
                .thenReturn(Optional.of(new StoredPersonalitySubmission(
                        31L,
                        AnalysisMode.INITIAL,
                        canonicalAnswers(),
                        "PERSONALITY_V2",
                        NOW)));
        PersonalityAnalysisRequest changed = new PersonalityAnalysisRequest(
                SUBMISSION_KEY,
                AnalysisMode.INITIAL,
                IndoorOutdoor.OUTDOOR,
                SocialLevel.LOW,
                PhysicalActivityLevel.LOW,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE, Interest.LEARNING),
                ExecutionStyle.PLANNED);

        assertThatThrownBy(() -> service.analyze("user-key", changed))
                .isInstanceOf(SubmissionKeyConflictException.class);
        verify(repository, never()).nextAnalysisId();
    }

    @Test
    void rejectsInitialAnalysisWhenProfileAlreadyExists() {
        when(repository.profileExists(7L)).thenReturn(true);

        assertThatThrownBy(() -> service.analyze("user-key", validRequest(AnalysisMode.INITIAL)))
                .isInstanceOf(PersonalityAlreadyAnalyzedException.class);

        verify(repository, never()).nextAnalysisId();
    }

    @Test
    void rejectsReanalysisWhenProfileDoesNotExist() {
        when(repository.profileExists(7L)).thenReturn(false);

        assertThatThrownBy(() -> service.analyze("user-key", validRequest(AnalysisMode.REANALYSIS)))
                .isInstanceOf(PersonalityNotAnalyzedException.class);

        verify(repository, never()).nextAnalysisId();
    }

    @Test
    void updatesExistingProfileForReanalysis() {
        when(repository.profileExists(7L)).thenReturn(true);

        PersonalitySubmissionResult result = service.analyze(
                "user-key",
                validRequest(AnalysisMode.REANALYSIS));

        assertThat(result.created()).isTrue();
        verify(repository).updateProfile(anyLong(), anyLong(), any(), any());
        verify(repository, never()).insertProfile(anyLong(), anyLong(), any(), any());
    }

    @Test
    void rejectsMissingOrMalformedSubmissionKeyBeforeAuthentication() {
        PersonalityAnalysisRequest missing = new PersonalityAnalysisRequest(
                null,
                AnalysisMode.INITIAL,
                IndoorOutdoor.INDOOR,
                SocialLevel.LOW,
                PhysicalActivityLevel.LOW,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE),
                ExecutionStyle.PLANNED);
        PersonalityAnalysisRequest malformed = new PersonalityAnalysisRequest(
                "not-a-uuid",
                AnalysisMode.INITIAL,
                IndoorOutdoor.INDOOR,
                SocialLevel.LOW,
                PhysicalActivityLevel.LOW,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE),
                ExecutionStyle.PLANNED);

        assertThatThrownBy(() -> service.analyze("user-key", missing))
                .isInstanceOf(InvalidSubmissionKeyException.class);
        assertThatThrownBy(() -> service.analyze("user-key", malformed))
                .isInstanceOf(InvalidSubmissionKeyException.class);
        verifyNoInteractions(userService);
        verifyNoInteractions(repository);
    }

    @Test
    void rejectsInvalidAnswersBeforeLockingOrWriting() {
        PersonalityAnalysisRequest invalid = new PersonalityAnalysisRequest(
                SUBMISSION_KEY,
                AnalysisMode.INITIAL,
                null,
                SocialLevel.LOW,
                PhysicalActivityLevel.LOW,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE),
                ExecutionStyle.PLANNED);

        assertThatThrownBy(() -> service.analyze("user-key", invalid))
                .isInstanceOf(InvalidPersonalityAnswersException.class);
        verify(repository, never()).lockUser(anyLong());
    }

    @Test
    void propagatesInvalidUserAuthenticationWithoutDatabaseWrites() {
        when(userService.requireUserId("invalid")).thenThrow(new UserAuthenticationException());

        assertThatThrownBy(() -> service.analyze("invalid", validRequest(AnalysisMode.INITIAL)))
                .isInstanceOf(UserAuthenticationException.class);
        verifyNoInteractions(repository);
    }

    @Test
    void propagatesDatabaseFailureSoTransactionCanRollBack() {
        when(repository.profileExists(7L)).thenReturn(true);
        org.mockito.Mockito.doThrow(new DataAccessResourceFailureException("database unavailable"))
                .when(repository)
                .replaceProfileInterests(anyLong(), any());

        assertThatThrownBy(() -> service.analyze("user-key", validRequest(AnalysisMode.REANALYSIS)))
                .isInstanceOf(DataAccessResourceFailureException.class);
        verify(repository, never()).touchUser(anyLong(), any());
    }

    @Test
    void analyzeMethodDefinesTransactionalBoundary() throws Exception {
        Transactional transactional = PersonalityService.class
                .getMethod("analyze", String.class, PersonalityAnalysisRequest.class)
                .getAnnotation(Transactional.class);

        assertThat(transactional).isNotNull();
    }

    private PersonalityAnalysisRequest validRequest(AnalysisMode mode) {
        return new PersonalityAnalysisRequest(
                UUID.fromString(SUBMISSION_KEY).toString(),
                mode,
                IndoorOutdoor.INDOOR,
                SocialLevel.LOW,
                PhysicalActivityLevel.LOW,
                NoveltyLevel.MEDIUM,
                List.of(Interest.LEARNING, Interest.CREATIVE),
                ExecutionStyle.PLANNED);
    }

    private PersonalityAnswers canonicalAnswers() {
        return new PersonalityAnswers(
                IndoorOutdoor.INDOOR,
                SocialLevel.LOW,
                PhysicalActivityLevel.LOW,
                NoveltyLevel.MEDIUM,
                List.of(Interest.CREATIVE, Interest.LEARNING),
                ExecutionStyle.PLANNED);
    }
}
