import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';

/// The design's `.searchbox`: a 50dp white field with a search icon, a line border and radius 13, and a clear button
/// once there is text.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hint = AppStrings.searchHint,
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Called after the clear button emptied the field (as well as [onChanged] with «»).
  final VoidCallback? onCleared;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _own;

  TextEditingController get _controller => widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _own;
    if (old != _controller) {
      old?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _own?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: palette.muted, height: 1.4),
        filled: true,
        fillColor: palette.surface,
        constraints: const BoxConstraints(minHeight: AppSizes.control),
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 15),
        prefixIcon: Icon(Icons.search_rounded, color: palette.muted, size: AppIconSize.md - 2),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: AppStrings.clearSearch,
                icon: Icon(Icons.close_rounded, color: palette.muted, size: AppIconSize.action),
                onPressed: _clear,
              ),
        border: border(palette.line),
        enabledBorder: border(palette.line),
        focusedBorder: border(palette.primary, 1.5),
      ),
    );
  }
}
