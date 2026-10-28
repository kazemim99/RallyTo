import 'package:flutter/material.dart';

import '../../../../config/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';

/// The design's field `.label` above a form field: 12 bold.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// A field's error under it; nothing when [message] is null.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
    );
  }
}

/// A refusal shown as the design's error banner.
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: NoticeBanner(tone: NoticeTone.error, body: message),
    );
  }
}

/// A controlled dropdown in the app's field style. [enabled] false shows the value without letting it change.
/// [floatingLabel] false keeps [label] as a hint only, for a field that already has a [FieldLabel] above it.
class DropdownField<T> extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.enabled = true,
    this.floatingLabel = true,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool floatingLabel;

  @override
  Widget build(BuildContext context) {
    final field = InputDecorator(
      decoration: floatingLabel
          ? InputDecoration(labelText: label, enabled: enabled)
          : InputDecoration(hintText: label, enabled: enabled),
      isEmpty: value == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          isDense: true,
          menuMaxHeight: 360,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled
              ? (item) {
                  if (item != null) onChanged(item);
                }
              : null,
        ),
      ),
    );
    return floatingLabel ? field : Semantics(label: label, child: field);
  }
}
