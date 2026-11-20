/// Manual date/time formatting (no `intl` dependency — local-only app
/// keeps deps minimal). All inputs are ms-since-epoch.
String formatMessageTime(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final hm =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return hm;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final md = '${months[dt.month - 1]} ${dt.day}';
  if (dt.year == now.year) return '$md, $hm';
  return '$md ${dt.year}, $hm';
}
