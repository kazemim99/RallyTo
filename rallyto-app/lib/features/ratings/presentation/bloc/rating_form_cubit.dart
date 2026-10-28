import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/entities/rating.dart';
import '../../domain/rating_repository.dart';
import '../../domain/rating_rules.dart';
import '../rating_labels.dart';

/// Rating one other player of a Completed game: 1 to 5 stars, up to 3 tags, the required level accuracy and an
/// optional private note for admins. The rating is hidden until the other side rates (or 7 days pass) and cannot be
/// edited, so it is sent once.
@injectable
class RatingFormCubit extends Cubit<RatingFormState> {
  RatingFormCubit(this._ratings, @factoryParam RatingTarget target) : super(RatingFormState(target: target));

  final RatingRepository _ratings;

  void setStars(int stars) {
    if (stars < RatingRules.minStars || stars > RatingRules.maxStars) return;
    emit(state.copyWith(stars: stars));
  }

  /// Picks or drops [tag]; a fourth is refused with the server's words for it.
  void toggleTag(RatingTag tag) {
    if (state.tags.contains(tag)) {
      emit(state.copyWith(tags: [...state.tags.where((t) => t != tag)]));
    } else if (state.tags.length >= RatingRules.maxTags) {
      _refuse(RatingErrorCodes.tooManyTags);
    } else {
      emit(state.copyWith(tags: [...state.tags, tag]));
    }
  }

  void setLevelAccuracy(LevelAccuracy accuracy) => emit(state.copyWith(levelAccuracy: accuracy));

  void setNote(String note) => emit(state.copyWith(note: note));

  /// Sends the rating once; what is missing is said first, without asking the server.
  Future<void> submit() async {
    if (state.submitting || state.done) return;
    final draft = state.draft;
    final problem = RatingRules.check(draft);
    if (problem != null) {
      _refuse(problem);
      return;
    }
    emit(state.copyWith(submitting: true));
    final result = await _ratings.rate(state.target.matchId, draft);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          submitting: false,
          feedback: ProfileFeedback(RatingLabels.error(failure), isError: true, code: failure.code),
        ),
      ),
      (_) => emit(
        state.copyWith(submitting: false, done: true, feedback: const ProfileFeedback(AppStrings.ratingSubmitted)),
      ),
    );
  }

  void _refuse(String code) =>
      emit(state.copyWith(feedback: ProfileFeedback(RatingLabels.rule(code), isError: true, code: code)));
}

class RatingFormState extends Equatable {
  const RatingFormState({
    required this.target,
    this.stars = 0,
    this.tags = const [],
    this.levelAccuracy,
    this.note = '',
    this.submitting = false,
    this.done = false,
    this.feedback,
  });

  final RatingTarget target;

  /// 0 until picked.
  final int stars;
  final List<RatingTag> tags;
  final LevelAccuracy? levelAccuracy;
  final String note;
  final bool submitting;

  /// The rating was stored: the form closes.
  final bool done;
  final ProfileFeedback? feedback;

  RatingDraft get draft =>
      RatingDraft(rateeId: target.rateeId, stars: stars, tags: tags, levelAccuracy: levelAccuracy, privateNote: note);

  RatingFormState copyWith({
    int? stars,
    List<RatingTag>? tags,
    LevelAccuracy? levelAccuracy,
    String? note,
    bool? submitting,
    bool? done,
    ProfileFeedback? feedback,
  }) => RatingFormState(
    target: target,
    stars: stars ?? this.stars,
    tags: tags ?? this.tags,
    levelAccuracy: levelAccuracy ?? this.levelAccuracy,
    note: note ?? this.note,
    submitting: submitting ?? this.submitting,
    done: done ?? this.done,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [target, stars, tags, levelAccuracy, note, submitting, done, feedback];
}
