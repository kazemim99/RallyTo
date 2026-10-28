import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/catalog_repository.dart';
import '../../domain/entities/venue.dart';
import 'catalog_load_status.dart';

/// One venue's page: the venue, and the sport names for its courts.
@injectable
class VenueDetailCubit extends Cubit<VenueDetailState> {
  VenueDetailCubit(this._repository, @factoryParam String venueId)
    : _venueId = venueId,
      super(const VenueDetailState());

  final CatalogRepository _repository;
  final String _venueId;

  Future<void> load() async {
    emit(const VenueDetailState());
    final sports = _repository.getSports();
    final result = await _repository.getVenue(_venueId);
    // Sport names only label the courts: a failure there shows codes, not an error.
    final names = (await sports).fold((_) => const <String, String>{}, (s) => {for (final x in s) x.code: x.nameFa});
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        VenueDetailState(
          status: CatalogLoadStatus.failure,
          notFound: failure is NotFoundFailure,
          errorMessage: failure.message,
        ),
      ),
      (venue) => emit(VenueDetailState(status: CatalogLoadStatus.ready, venue: venue, sportNames: names)),
    );
  }
}

class VenueDetailState extends Equatable {
  const VenueDetailState({
    this.status = CatalogLoadStatus.loading,
    this.venue,
    this.sportNames = const {},
    this.notFound = false,
    this.errorMessage,
  });

  final CatalogLoadStatus status;
  final Venue? venue;
  final Map<String, String> sportNames;

  /// The venue is hidden or gone (404): retrying will not help.
  final bool notFound;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, venue, sportNames, notFound, errorMessage];
}
