String fmtDateTime(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = d.hour.toString().padLeft(2, '0'), mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]} ${d.year}, $hh:$mm';
}

String fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}
