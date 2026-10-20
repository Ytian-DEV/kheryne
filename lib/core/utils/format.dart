import 'package:intl/intl.dart';

String longDate(DateTime d) => DateFormat('EEEE, d MMMM').format(d);
String shortDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
String dateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
String timeOnly(DateTime d) => DateFormat('h:mm a').format(d);

String greeting(DateTime now) => now.hour < 12 ? 'Good morning' : (now.hour < 18 ? 'Good afternoon' : 'Good evening');

/// "Today", "Yesterday", "This week", "Earlier" buckets for history.
String dayBucket(DateTime d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return 'This week';
  if (diff < 14) return 'Last week';
  return DateFormat('MMMM yyyy').format(d);
}

String relative(DateTime d, DateTime now) {
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('d MMM').format(d);
}

String um(double v) => '${v.toStringAsFixed(v >= 100 ? 0 : 1)} µm';
String ratio(double v) => v.toStringAsFixed(1);
