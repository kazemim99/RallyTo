import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/place.dart';
import '../bloc/catalog_load_status.dart';
import '../bloc/city_picker_cubit.dart';
import 'catalog_search_field.dart';

/// Province, then city, each with a search that matches Persian text however it was typed. Needs a
/// [CityPickerCubit] above it (loaded); [CityPicker.show] opens it as a full screen and returns the choice.
class CityPicker extends StatefulWidget {
  const CityPicker({super.key, required this.onSelected});

  static const Key searchFieldKey = Key('cityPicker.search');

  final ValueChanged<CitySelection> onSelected;

  /// Opens the picker full screen (on the root navigator, over the bottom bar); null when the player leaves without
  /// choosing.
  static Future<CitySelection?> show(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push<CitySelection>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => BlocProvider(create: (_) => getIt<CityPickerCubit>()..load(), child: const CityPickerPage()),
        ),
      );

  @override
  State<CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<CityPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CityPickerCubit>();
    return BlocConsumer<CityPickerCubit, CityPickerState>(
      // Each step starts with an empty search.
      listenWhen: (previous, current) => previous.step != current.step,
      listener: (context, state) => _search.clear(),
      builder: (context, state) {
        final onCities = state.step == CityPickerStep.cities;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onCities) _ProvinceHeader(name: state.province?.name ?? '', onChange: cubit.backToProvinces),
            CatalogSearchField(
              key: CityPicker.searchFieldKey,
              controller: _search,
              hint: onCities ? AppStrings.citySearchHint : AppStrings.provinceSearchHint,
              onChanged: cubit.queryChanged,
            ),
            Expanded(child: _list(context, state)),
          ],
        );
      },
    );
  }

  static const EdgeInsetsGeometry _listPadding = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.screen,
    0,
    AppSpacing.screen,
    AppSpacing.lg,
  );

  Widget _list(BuildContext context, CityPickerState state) {
    final cubit = context.read<CityPickerCubit>();
    switch (state.status) {
      case CatalogLoadStatus.loading:
        return const LoadingView();
      case CatalogLoadStatus.failure:
        return ErrorState(message: state.errorMessage, onRetry: cubit.retry);
      case CatalogLoadStatus.ready:
        break;
    }

    if (state.step == CityPickerStep.provinces) {
      final provinces = state.visibleProvinces;
      if (provinces.isEmpty) return const EmptyState(icon: Icons.search_off, title: AppStrings.noResultsTitle);
      return ListView.separated(
        padding: _listPadding,
        itemCount: provinces.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final province = provinces[index];
          return ListRow(
            title: province.name,
            trailing: Icon(Icons.chevron_right_rounded, color: context.palette.muted),
            onTap: () => cubit.selectProvince(province),
          );
        },
      );
    }

    final cities = state.visibleCities;
    if (cities.isEmpty) return const EmptyState(icon: Icons.search_off, title: AppStrings.noResultsTitle);
    return ListView.separated(
      padding: _listPadding,
      itemCount: cities.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final city = cities[index];
        return ListRow(
          leading: const Icon(Icons.location_city_outlined),
          title: city.name,
          subtitle: city.activeVenueCount > 0
              ? AppStrings.cityVenueCount(PersianDigits.fromInt(city.activeVenueCount))
              : null,
          onTap: () => widget.onSelected(
            CitySelection(cityId: city.id, cityName: city.name, provinceName: state.province?.name),
          ),
        );
      },
    );
  }
}

class _ProvinceHeader extends StatelessWidget {
  const _ProvinceHeader({required this.name, required this.onChange});

  final String name;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, AppSpacing.xs, AppSpacing.xs, 0),
      child: Row(
        children: [
          Icon(Icons.map_outlined, size: AppIconSize.action, color: context.palette.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
          AppButton.ghost(label: AppStrings.changeProvince, onPressed: onChange, expanded: false, compact: true),
        ],
      ),
    );
  }
}

/// [CityPicker] as a full screen. Back from the city list returns to the province list; back from there closes it.
class CityPickerPage extends StatelessWidget {
  const CityPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final onCities = context.select<CityPickerCubit, bool>((c) => c.state.step == CityPickerStep.cities);
    return PopScope<CitySelection>(
      canPop: !onCities,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.read<CityPickerCubit>().backToProvinces();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.cityPickerTitle)),
        body: CityPicker(onSelected: (selection) => Navigator.of(context).pop(selection)),
      ),
    );
  }
}
