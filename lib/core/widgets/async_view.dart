import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/theme.dart';
import 'illustrations.dart';
import 'k_icons.dart';
import 'small_widgets.dart';

/// Screen states every screen supports.
enum ViewState { content, loading, empty, error, offline }

/// Forces a state for the screen gallery and screenshot tests.
class ViewStateScope extends InheritedWidget {
  const ViewStateScope({super.key, required this.state, required super.child});
  final ViewState state;

  static ViewState? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ViewStateScope>()?.state;

  @override
  bool updateShouldNotify(ViewStateScope oldWidget) => oldWidget.state != state;
}

/// Renders an [AsyncValue] with layout-matching skeletons, a calm error
/// state with retry, and an empty state.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.loading,
    this.isEmpty,
    this.empty,
    this.errorTitle = 'Couldn’t load this',
    this.onRetry,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget loading;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final String errorTitle;
  final VoidCallback? onRetry;

  /// Replaces the default full error state (for small containers).
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final forced = ViewStateScope.of(context);
    switch (forced) {
      case ViewState.loading:
        return loading;
      case ViewState.empty:
        return empty ?? const SizedBox.shrink();
      case ViewState.error:
        return error ?? ErrorState(title: errorTitle, onRetry: onRetry ?? () {});
      case ViewState.content || ViewState.offline || null:
        break;
    }
    return switch (value) {
      AsyncData(:final value) => (isEmpty?.call(value) ?? false) ? (empty ?? const SizedBox.shrink()) : data(value),
      AsyncError() => error ?? ErrorState(title: errorTitle, onRetry: onRetry),
      _ => loading,
    };
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.title, this.message = 'Something went wrong on this device. Your saved identifications are safe.', this.onRetry});
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        art: LineArt.brokenSlide,
        message: title,
        detail: message,
        action: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
}

/// Shown at the top of screens when the device is offline. Identification
/// keeps working; only updates and external links need a connection.
class OfflineNotice extends ConsumerWidget {
  const OfflineNotice({super.key, this.message = 'Identification still works. Model updates and NeMys links need a connection.', this.padding = const EdgeInsets.only(bottom: KSpace.s16)});
  final String message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = !ref.watch(onlineProvider) || ViewStateScope.of(context) == ViewState.offline;
    if (!offline) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: StatusBanner(title: 'You’re offline', message: message, tone: BannerTone.info, icon: KIcons.offline),
    );
  }
}
