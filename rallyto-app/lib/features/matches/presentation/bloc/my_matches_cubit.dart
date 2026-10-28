import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../domain/entities/match.dart';
import '../../domain/match_repository.dart';
import '../match_labels.dart';

/// The player's games: upcoming soonest first and past newest first (spec match-lifecycle › Match history). Both
/// lists load together; each has its own state.
@injectable
class MyMatchesCubit extends Cubit<MyMatchesState> {
  MyMatchesCubit(this._matches, this._catalog) : super(const MyMatchesState());

  final MatchRepository _matches;
  final CatalogRepository _catalog;

  Future<void> load() async {
    emit(state.copyWith(upcoming: const MatchList(), past: const MatchList()));
    final sports = _catalog.getSports();
    final upcoming = _matches.getMine(upcoming: true);
    final past = _matches.getMine(upcoming: false);
    final upcomingResult = await upcoming;
    final pastResult = await past;
    // Sports only name the levels: without them the shared tier names are shown.
    final catalog = (await sports).fold((_) => const <Sport>[], (s) => s);
    if (isClosed) return;
    emit(MyMatchesState(upcoming: _listOf(upcomingResult), past: _listOf(pastResult), sports: catalog));
  }

  static MatchList _listOf(Either<Failure, List<Match>> result) => result.fold(
    (failure) => MatchList(status: ViewStatus.error, errorMessage: MatchLabels.error(failure)),
    (matches) => MatchList(status: matches.isEmpty ? ViewStatus.empty : ViewStatus.content, matches: matches),
  );
}

/// One tab's games.
class MatchList extends Equatable {
  const MatchList({this.status = ViewStatus.loading, this.matches = const [], this.errorMessage});

  final ViewStatus status;
  final List<Match> matches;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, matches, errorMessage];
}

class MyMatchesState extends Equatable {
  const MyMatchesState({this.upcoming = const MatchList(), this.past = const MatchList(), this.sports = const []});

  final MatchList upcoming;
  final MatchList past;

  /// The catalog's sports, for level names.
  final List<Sport> sports;

  Sport? sportById(String id) {
    for (final sport in sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  MyMatchesState copyWith({MatchList? upcoming, MatchList? past}) =>
      MyMatchesState(upcoming: upcoming ?? this.upcoming, past: past ?? this.past, sports: sports);

  @override
  List<Object?> get props => [upcoming, past, sports];
}
