import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/venue.dart';
import '../bloc/catalog_load_status.dart';
import '../bloc/venue_detail_cubit.dart';
import '../catalog_labels.dart';

/// A venue: a cover with its name, city and sports, a map with only the club's marker when its coordinates are known,
/// the address and phone as rows, and each sport's courts as a stat grid. The player's own location is never asked
/// for.
class VenueDetailPage extends StatelessWidget {
  const VenueDetailPage({super.key});

  static const Key mapKey = Key('venueDetail.map');
  static const Key coverKey = Key('venueDetail.cover');
  static const Key addressKey = Key('venueDetail.address');
  static const Key phoneKey = Key('venueDetail.phone');

  /// The chip of the sport [code] on the cover.
  static Key sportChipKey(String code) => Key('venueDetail.sportChip.$code');

  /// The courts of the sport [code].
  static Key sportKey(String code) => Key('venueDetail.sport.$code');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VenueDetailCubit, VenueDetailState>(
      builder: (context, state) {
        final venue = state.venue;
        return Scaffold(
          appBar: AppBar(title: Text(venue?.name ?? AppStrings.venueTitle)),
          body: switch (state.status) {
            CatalogLoadStatus.loading => const LoadingView(),
            CatalogLoadStatus.failure when state.notFound => EmptyState(
              icon: Icons.location_off_outlined,
              title: AppStrings.venueNotFound,
              ctaLabel: AppStrings.backToHome,
              onCta: () => context.go(Routes.home),
            ),
            CatalogLoadStatus.failure => ErrorState(
              message: state.errorMessage,
              onRetry: context.read<VenueDetailCubit>().load,
            ),
            CatalogLoadStatus.ready => _VenueDetails(venue: venue!, sportNames: state.sportNames),
          },
        );
      },
    );
  }
}

class _VenueDetails extends StatelessWidget {
  const _VenueDetails({required this.venue, required this.sportNames});

  final Venue venue;
  final Map<String, String> sportNames;

  @override
  Widget build(BuildContext context) {
    final phone = venue.phone;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.lg),
      children: [
        _VenueCover(venue: venue, sportNames: sportNames),
        const SizedBox(height: AppSpacing.md),
        if (venue.hasLocation) ...[
          _VenueMap(latitude: venue.latitude!, longitude: venue.longitude!),
          const SizedBox(height: AppSpacing.md),
        ],
        ListRow(
          key: VenueDetailPage.addressKey,
          leading: const Icon(Icons.place_outlined),
          title: AppStrings.venueAddress,
          subtitle: venue.address ?? AppStrings.venueNoAddress,
        ),
        if (phone != null) ...[
          const SizedBox(height: AppSpacing.xs),
          ListRow(
            key: VenueDetailPage.phoneKey,
            leading: const Icon(Icons.phone_outlined),
            title: AppStrings.venuePhone,
            subtitle: _ltr(phone),
          ),
        ],
        if (venue.sports.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionTitle(title: AppStrings.venueSports),
          for (final sport in venue.sports) ...[
            if (sport != venue.sports.first) const SizedBox(height: AppSpacing.md),
            _SportCourts(sport: sport, name: CatalogLabels.sportName(sport.sportCode, sportNames)),
          ],
        ],
      ],
    );
  }

  /// A phone number keeps its left-to-right order inside the right-to-left page.
  static String _ltr(String text) => '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';
}

/// The venue's cover (the design's `.hero` language): the brand gradient with the court-lines motif, the name in
/// white, its city, and the sports it offers as chips.
class _VenueCover extends StatelessWidget {
  const _VenueCover({required this.venue, required this.sportNames});

  final Venue venue;
  final Map<String, String> sportNames;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      key: VenueDetailPage.coverKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [palette.brandStart, palette.brandEnd],
        ),
      ),
      child: Stack(
        children: [
          const PositionedDirectional(
            end: -42,
            top: -AppSpacing.lg,
            child: ExcludeSemantics(child: CourtLines(width: 150, height: 180, angle: 12)),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(venue.name, style: theme.textTheme.headlineSmall?.copyWith(color: palette.onBrand)),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Icon(Icons.location_city_outlined, size: AppIconSize.sm, color: palette.onBrandMuted),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        venue.cityName,
                        style: theme.textTheme.bodySmall?.copyWith(color: palette.onBrandMuted),
                      ),
                    ),
                  ],
                ),
                if (venue.sports.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final sport in venue.sports)
                        AppChip(
                          key: VenueDetailPage.sportChipKey(sport.sportCode),
                          label: CatalogLabels.sportName(sport.sportCode, sportNames),
                          icon: Icons.sports_tennis_rounded,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One sport's courts: the sport's ball and name (with a night-lighting chip when lit), then the court count, setting
/// and surface as a stat grid. A fact the club has not given reads «نامشخص».
class _SportCourts extends StatelessWidget {
  const _SportCourts({required this.sport, required this.name});

  final VenueSport sport;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = sport.courtCount;
    final setting = sport.setting;
    final surface = sport.surface;
    final code = sport.sportCode;
    return Column(
      key: VenueDetailPage.sportKey(code),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SportBall(label: code.isEmpty ? '' : code.substring(0, 1).toUpperCase(), semanticLabel: name),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
            if (sport.hasLighting)
              const AppChip(
                label: AppStrings.courtLighting,
                tone: AppChipTone.green,
                icon: Icons.lightbulb_outline_rounded,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        StatGrid(
          items: [
            StatItem(
              label: AppStrings.venueCourtsStat,
              value: count == null ? AppStrings.venueStatUnknown : PersianDigits.fromInt(count),
            ),
            StatItem(
              label: AppStrings.venueSettingStat,
              value: setting == null ? AppStrings.venueStatUnknown : CatalogLabels.setting(setting),
            ),
            StatItem(
              label: AppStrings.venueSurfaceStat,
              value: surface == null ? AppStrings.venueStatUnknown : CatalogLabels.surface(surface),
            ),
          ],
        ),
      ],
    );
  }
}

/// OpenStreetMap tiles centred on the club, with its marker only. Rotation is off so north stays up.
class _VenueMap extends StatelessWidget {
  const _VenueMap({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  static const String _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// OpenStreetMap's tile policy asks every app to identify itself.
  static const String _userAgentPackage = 'ir.rallyto.app';

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: AppStrings.venueMapLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            key: VenueDetailPage.mapKey,
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgentPackage),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_on, size: 40, color: scheme.primary),
                  ),
                ],
              ),
              const SimpleAttributionWidget(source: Text(AppStrings.mapAttribution)),
            ],
          ),
        ),
      ),
    );
  }
}
