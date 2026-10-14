bool isValidPhone(String s) => RegExp(r'^\+?[0-9 ]{7,16}$').hasMatch(s.trim());

class ProfileData {
  final String id, email, role;
  final String? fullName, phone;
  final bool suspended;
  const ProfileData({required this.id, required this.email, required this.role, this.fullName, this.phone, this.suspended = false});

  String get name => (fullName ?? '').trim();

  String get roleLabel => const {
        'student': 'Student',
        'landlord': 'Landlord',
        'agent': 'Agent / Property manager',
        'admin': 'Administrator',
      }[role] ?? role;

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return (parts.first[0] + parts.last[0]).toUpperCase();
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    return email.isEmpty ? '?' : email[0].toUpperCase();
  }
}

class AppNotification {
  final String id, kind, title;
  final String? body;
  final bool read;
  final DateTime createdAt;
  const AppNotification(this.id, this.kind, this.title, this.body, this.read, this.createdAt);
}

class BlockedPerson {
  final String id;
  final DateTime since;
  const BlockedPerson(this.id, this.since);
}
