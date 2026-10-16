class ExactLocation {
  final double lat, lng;
  final String addressLine;
  const ExactLocation(this.lat, this.lng, [this.addressLine = '']);
}

/// What the server says about reaching a landlord by phone. It never includes the number.
class ContactStatus {
  static const signIn = 'signin';
  static const none = 'none';
  static const hidden = 'hidden';
  static const locked = 'locked';
  static const available = 'available';
}

const phoneVisibilityLabels = {
  'hidden': 'Hidden',
  'after_enquiry': 'After a student messages me',
  'public': 'Everyone signed in',
};

const phoneVisibilityHelp = {
  'hidden': 'Students can only message you inside CampusStay.',
  'after_enquiry': 'Your number unlocks for a student once they message you or you confirm a viewing.',
  'public': 'Any signed-in student can tap to call or WhatsApp you from your listing.',
};

/// 08012345678 and +234 801 234 5678 both become 2348012345678 for wa.me links.
String toInternationalPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.trim().startsWith('+')) return digits;
  if (digits.startsWith('0') && digits.length == 11) return '234${digits.substring(1)}';
  if (digits.startsWith('234')) return digits;
  return digits;
}

/// ₦150,000 becomes ₦150k on map pins.
String compactNaira(int v) {
  if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M';
  if (v >= 1000) return '₦${(v / 1000).round()}k';
  return '₦$v';
}
