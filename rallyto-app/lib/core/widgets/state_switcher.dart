import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import 'empty_state.dart';
import 'error_state.dart';
import 'loading_view.dart';

/// The four states of a data-backed screen. Every such screen's state maps onto one of these: blank screens and
/// endless spinners are not allowed.
enum ViewStatus { loading, content, empty, error }

/// Renders a [ViewStatus]: loading, content, empty, or error with retry.
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({
    super.key,
    required this.status,
    required this.contentBuilder,
    required this.onRetry,
    this.loading,
    this.empty,
    this.errorMessage,
  });

  final ViewStatus status;

  /// Built only when [status] is [ViewStatus.content].
  final WidgetBuilder contentBuilder;

  final VoidCallback onRetry;

  /// Shown while loading; defaults to [LoadingView]. Pass a content-shaped placeholder where there is one.
  final Widget? loading;

  /// Shown when empty; defaults to a generic empty state, but screens should pass a purposeful one.
  final Widget? empty;

  final String? errorMessage;

  @override
  Widget build(BuildContext context) => switch (status) {
    ViewStatus.loading => loading ?? const LoadingView(),
    ViewStatus.content => contentBuilder(context),
    ViewStatus.empty => empty ?? const EmptyState(icon: Icons.inbox_outlined, title: AppStrings.noResultsTitle),
    ViewStatus.error => ErrorState(message: errorMessage, onRetry: onRetry),
  };
}
