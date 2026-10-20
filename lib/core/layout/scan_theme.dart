import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/theme.dart';

/// Live Scan and Workspace default to dark for dim labs. The Settings
/// toggle "Scan always dark" lets them follow the app theme instead.
class ScanTheme extends ConsumerWidget {
  const ScanTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alwaysDark = ref.watch(settingsProvider.select((s) => s.scanAlwaysDark));
    if (!alwaysDark) return child;
    return Theme(data: KheryneTheme.dark(), child: child);
  }
}
