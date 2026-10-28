import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/domain/match_rules.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_detail_cubit.dart';

import '../../../../helpers/fake_chat.dart';
import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/fake_share.dart';

/// After the game: the attendance answer (played with no-shows, or did not happen), each refusal in the app's words;
/// sharing a public post's link; and the group conversation, as the server reports it.
void main() {
  late FakeMatchRepository matches;
  late FakeChatRepository chat;
  late FakeShareService share;

  setUp(() {
    matches = FakeMatchRepository();
    chat = FakeChatRepository()..matchGroups = {};
    share = FakeShareService();
  });

  Future<MatchDetailCubit> open([Match? match]) async {
    if (match != null) matches.match = match;
    final cubit = matchDetailCubit(matches, chat: chat, share: share);
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  group('attendance', () {
    test('this player is known among the participants, and the others are who may be flagged', () async {
      final cubit = await open(testEndedMatch());

      expect(cubit.state.myId, 'u-me');
      expect(cubit.state.match!.canAnswerAttendance, isTrue);
      expect(cubit.state.match!.otherPlayers(cubit.state.myId).map((p) => p.userId), ['u-1', 'u-3', 'u-4']);
    });

    test('"played", flagging a no-show: the updated game replaces the one shown', () async {
      final cubit = await open(testEndedMatch());
      final answered = testEndedMatch(
        attendance: MatchAttendance(
          open: true,
          closesAt: testEndedAt.add(const Duration(hours: 72)),
          myAnswer: AttendanceAnswer.played,
        ),
      );
      matches.next = answered;

      await cubit.answerAttendance(AttendanceAnswer.played, noShows: {'u-4'});

      expect(matches.calls.last, 'attendance:m-1:Played:u-4');
      expect(cubit.state.match, answered);
      expect(cubit.state.match!.canAnswerAttendance, isFalse);
      expect(cubit.state.feedback?.message, AppStrings.attendanceSaved);
      expect(cubit.state.feedback?.isError, isFalse);
    });

    test('"did not happen", with no no-shows', () async {
      final cubit = await open(testEndedMatch());

      await cubit.answerAttendance(AttendanceAnswer.didNotHappen);

      expect(matches.calls.last, 'attendance:m-1:DidNotHappen:');
    });

    test('no-shows with "did not happen", or flagging oneself, are refused before asking the server', () async {
      final cubit = await open(testEndedMatch());

      await cubit.answerAttendance(AttendanceAnswer.didNotHappen, noShows: {'u-3'});
      expect(cubit.state.feedback?.code, MatchErrorCodes.invalidNoShow);
      expect(cubit.state.feedback?.message, AppStrings.invalidNoShow);

      await cubit.answerAttendance(AttendanceAnswer.played, noShows: {'u-me'});
      expect(cubit.state.feedback?.code, MatchErrorCodes.invalidNoShow);
      expect(matches.calls.where((c) => c.startsWith('attendance')), isEmpty);
    });

    const refusals = {
      MatchErrorCodes.attendanceNotOpen: AppStrings.attendanceNotOpen,
      MatchErrorCodes.attendanceClosed: AppStrings.attendanceClosed,
      MatchErrorCodes.alreadyAnswered: AppStrings.alreadyAnswered,
      MatchErrorCodes.invalidNoShow: AppStrings.invalidNoShow,
      MatchErrorCodes.notAParticipant: AppStrings.notAParticipant,
    };
    for (final MapEntry(key: code, value: message) in refusals.entries) {
      test('$code is said in the app\'s words; the game shown is unchanged', () async {
        final cubit = await open(testEndedMatch());
        final before = cubit.state.match;
        matches.failure = ServerFailure('server words', code: code, statusCode: 409);

        await cubit.answerAttendance(AttendanceAnswer.played);

        expect(cubit.state.match, before);
        expect(cubit.state.busy, isFalse);
        expect(cubit.state.feedback?.message, message);
        expect(cubit.state.feedback?.isError, isTrue);
        expect(cubit.state.feedback?.code, code);
      });
    }
  });

  group('sharing', () {
    test('a public post goes to the share sheet with its sport, club, day and time, and the link', () async {
      final cubit = await open(testMatch());

      await cubit.share();

      expect(share.shared, hasLength(1));
      final (text, subject) = share.shared.single;
      expect(text, contains('تنیس ‏•‏ انفرادی'));
      expect(text, contains('باشگاه انقلاب'));
      expect(text, contains('شنبه ۲ آبان ۱۴۰۵، ۱۹:۰۰ تا ۲۰:۳۰'));
      expect(text, endsWith('https://rallyto.ir/m/abc123def456'));
      expect(subject, AppStrings.shareSubject);
      expect(cubit.state.feedback, isNull, reason: 'the share sheet is its own feedback');
    });

    test('a private game has no link to share', () async {
      final cubit = await open(testMatch(visibility: MatchVisibility.private));

      await cubit.share();

      expect(share.shared, isEmpty);
    });

    test('a platform that cannot share says so', () async {
      share.failure = Exception('no share sheet');
      final cubit = await open(testMatch());

      await cubit.share();

      expect(cubit.state.feedback?.message, AppStrings.shareFailed);
      expect(cubit.state.feedback?.isError, isTrue);
    });
  });

  group('the group conversation', () {
    test('found for a player in the game', () async {
      chat.matchGroups = {'m-1': testConversation(id: 'c-group', kind: ConversationKind.match)};

      final cubit = await open(testHostedMatch());

      expect(chat.calls, ['match:m-1']);
      expect(cubit.state.groupChatId, 'c-group');
    });

    test('none (CONVERSATION_NOT_FOUND) leaves no link, and is asked again after an action', () async {
      final cubit = await open(testHostedMatch());
      expect(cubit.state.groupChatId, isNull);

      chat.matchGroups = {'m-1': testConversation(id: 'c-group', kind: ConversationKind.match)};
      await cubit.acceptRequest('u-3');

      expect(chat.calls, ['match:m-1', 'match:m-1']);
      expect(cubit.state.groupChatId, 'c-group');
    });

    test('a failed lookup only leaves the link out', () async {
      chat.loadFailure = const NetworkFailure(AppStrings.offlineActionError);

      final cubit = await open(testHostedMatch());

      expect(cubit.state.match, isNotNull);
      expect(cubit.state.groupChatId, isNull);
      expect(cubit.state.feedback, isNull);
    });
  });
}
