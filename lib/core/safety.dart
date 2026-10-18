enum SafetyFlag { money, account, secretCode, phone }

/// Looks for the patterns scammers use. It only warns; it never blocks or reads anything out of the app.
class SafetyCheck {
  static final _account = RegExp(r'\b\d{10}\b');
  static final _phone = RegExp(r'(\+?234|\b0)[789][01]\d{8}\b');
  static final _money = RegExp(
      r'(send|transfer|pay|deposit|payment)\b.{0,25}\b(money|first|now|before|account|naira|fee|advance)|\bgift ?card\b|\bwestern union\b|\bbitcoin\b|\bcrypto\b|₦\s?\d',
      caseSensitive: false);
  static final _code = RegExp(r'\b(otp|bvn|cvv)\b|card number|verification code|your pin\b|password', caseSensitive: false);

  static Set<SafetyFlag> scan(String text) {
    final flags = <SafetyFlag>{};
    if (_money.hasMatch(text)) flags.add(SafetyFlag.money);
    if (_account.hasMatch(text)) flags.add(SafetyFlag.account);
    if (_code.hasMatch(text)) flags.add(SafetyFlag.secretCode);
    if (_phone.hasMatch(text)) flags.add(SafetyFlag.phone);
    return flags;
  }
}
