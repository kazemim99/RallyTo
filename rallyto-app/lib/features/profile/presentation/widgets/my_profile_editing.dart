import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/entities/place.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../catalog/domain/entities/venue.dart';
import '../../../catalog/presentation/widgets/city_picker.dart';
import '../../../catalog/presentation/widgets/venue_picker.dart';
import '../../../onboarding/presentation/bloc/onboarding_cubit.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/sport_rules.dart';
import '../bloc/my_profile_cubit.dart';
import '../profile_labels.dart';
import 'sport_profile_editor.dart';

/// The player's own profile edits, shared by the profile page and its sections: each opens a sheet or picker over the
/// bottom bar and hands the result to the [MyProfileCubit] read from [BuildContext].
class MyProfileEditing {
  MyProfileEditing._();

  static const Key photoPickKey = Key('myProfile.photoPick');
  static const Key photoRemoveKey = Key('myProfile.photoRemove');
  static const Key basicsSaveKey = Key('myProfile.basicsSave');

  /// Name, bio and city, with the age range and gender shown as they are.
  static Future<void> editBasics(BuildContext context) {
    final cubit = context.read<MyProfileCubit>();
    final profile = cubit.state.profile;
    if (profile == null) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _BasicsSheet(profile: profile),
      ),
    );
  }

  /// Picks a catalog sport not yet in the profile, then edits its new profile.
  static Future<void> addSport(BuildContext context) async {
    final cubit = context.read<MyProfileCubit>();
    final addable = cubit.state.addableSports;
    if (addable.isEmpty) {
      AppSnackbar.info(context, AppStrings.allSportsAdded);
      return;
    }
    final sport = await showModalBottomSheet<Sport>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: AppStrings.chooseSport),
              MenuList(
                items: [
                  for (final sport in addable)
                    MenuItem(
                      icon: Icons.sports_tennis_rounded,
                      label: sport.nameFa,
                      onTap: () => Navigator.of(sheetContext).pop(sport),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (sport == null || !context.mounted) return;
    await editSport(context, sport, SportRules.newDraft(sport));
  }

  /// One sport's level, experience, formats and goals.
  static Future<void> editSport(BuildContext context, Sport sport, SportProfileDraft draft) {
    final cubit = context.read<MyProfileCubit>();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _SportSheet(sport: sport, initial: draft),
      ),
    );
  }

  /// Removes a sport after asking; the server refuses the last one.
  static Future<void> removeSport(BuildContext context, SportProfile sport, String name) async {
    final cubit = context.read<MyProfileCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        content: Text(AppStrings.removeSportQuestion(name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text(AppStrings.remove)),
        ],
      ),
    );
    if (confirmed == true) await cubit.removeSport(sport.sportId);
  }

  /// The home clubs, picked from the player's city.
  static Future<void> editHomeVenues(BuildContext context) async {
    final cubit = context.read<MyProfileCubit>();
    final profile = cubit.state.profile;
    if (profile == null) return;
    final venues = await VenuePicker.show(
      context,
      cityId: profile.city.id,
      maxSelection: OnboardingCubit.maxHomeVenues,
      initialSelection: [
        for (final v in profile.homeVenues)
          Venue(id: v.id, name: v.name, cityId: profile.city.id, cityName: profile.city.name),
      ],
    );
    if (venues != null) await cubit.setHomeVenues(venues);
  }

  /// Adding, changing or removing the photo.
  static Future<void> editPhoto(BuildContext context) {
    final cubit = context.read<MyProfileCubit>();
    final hasPhoto = cubit.state.profile?.photoUrl != null;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
          child: MenuList(
            items: [
              MenuItem(
                key: photoPickKey,
                icon: Icons.photo_camera_outlined,
                label: hasPhoto ? AppStrings.photoChange : AppStrings.photoAdd,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickPhoto(context, cubit);
                },
              ),
              if (hasPhoto)
                MenuItem(
                  key: photoRemoveKey,
                  icon: Icons.delete_outline_rounded,
                  label: AppStrings.photoRemove,
                  destructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    cubit.removePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks from the gallery, downscaled on the device to at most 1024px a side before upload.
  static Future<void> _pickPhoto(BuildContext context, MyProfileCubit cubit) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await cubit.uploadPhoto(ProfilePhoto(bytes: bytes, fileName: file.name, contentType: file.mimeType));
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, AppStrings.photoReadFailed);
    }
  }
}

/// Name, bio and city.
class _BasicsSheet extends StatefulWidget {
  const _BasicsSheet({required this.profile});

  final MyProfile profile;

  @override
  State<_BasicsSheet> createState() => _BasicsSheetState();
}

class _BasicsSheetState extends State<_BasicsSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.profile.displayName);
  late final TextEditingController _bio = TextEditingController(text: widget.profile.bio ?? '');
  late CitySelection _city = CitySelection(cityId: widget.profile.city.id, cityName: widget.profile.city.name);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await context.read<MyProfileCubit>().updateBasics(
      displayName: _name.text,
      cityId: _city.cityId,
      bio: _bio.text,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final gender = profile.gender;
    final palette = context.palette;
    return _SheetFrame(
      children: [
        Text(AppStrings.editProfile, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _name,
          maxLength: 30,
          decoration: const InputDecoration(labelText: AppStrings.displayNameLabel),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _bio,
          maxLength: MyProfileCubit.maxBioLength,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: AppStrings.bioLabel, hintText: AppStrings.bioHint),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListRow(
          leading: const Icon(Icons.location_city_outlined),
          title: _city.cityName,
          subtitle: AppStrings.cityLabel,
          trailing: AppButton.ghost(
            label: AppStrings.changeCity,
            compact: true,
            onPressed: () async {
              final city = await CityPicker.show(context);
              if (city != null && mounted) setState(() => _city = city);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _InfoRow(label: AppStrings.ageRangeLabel, value: ProfileLabels.ageRange(profile.ageRange)),
        if (gender != null)
          _InfoRow(
            label: AppStrings.genderLabel,
            value: '${ProfileLabels.gender(gender)} (${AppStrings.genderCannotChange})',
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_error!, style: TextStyle(color: palette.error)),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(key: MyProfileEditing.basicsSaveKey, label: AppStrings.save, loading: _saving, onPressed: _save),
      ],
    );
  }
}

/// A fact the player cannot edit here: a muted label and its value.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: context.palette.muted)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

/// One sport's level, experience, formats and goals.
class _SportSheet extends StatefulWidget {
  const _SportSheet({required this.sport, required this.initial});

  final Sport sport;
  final SportProfileDraft initial;

  @override
  State<_SportSheet> createState() => _SportSheetState();
}

class _SportSheetState extends State<_SportSheet> {
  late SportProfileDraft _draft = widget.initial;
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await context.read<MyProfileCubit>().saveSport(_draft);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      children: [
        Text(widget.sport.nameFa, style: Theme.of(context).textTheme.titleLarge),
        SportProfileEditor(
          sport: widget.sport,
          draft: _draft,
          onChanged: (draft) => setState(() {
            _draft = draft;
            _error = null;
          }),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: TextStyle(color: context.palette.error)),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(label: AppStrings.save, loading: _saving, onPressed: _save),
      ],
    );
  }
}

/// A bottom sheet's scrollable body, lifted above the keyboard.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}
