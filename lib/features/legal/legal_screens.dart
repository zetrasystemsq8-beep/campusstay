import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';

/// Bump this when the terms or policy change in a way people should accept again.
const kTermsVersion = '2026-10';

// NOTE FOR THE OWNER: these texts describe what the app really does today, in plain words.
// They are a starting point, not legal advice. Have a Nigerian lawyer review them before launch.

class _Section {
  final String heading, body;
  const _Section(this.heading, this.body);
}

class _LegalPage extends StatelessWidget {
  final String title;
  final List<_Section> sections;
  const _LegalPage({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(CS.s16), children: [
          Text('Version $kTermsVersion', style: Theme.of(context).textTheme.bodySmall),
          for (final s in sections) ...[
            Padding(padding: const EdgeInsets.only(top: 18, bottom: 6), child: Text(s.heading, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            Text(s.body, style: const TextStyle(fontSize: 15, height: 1.45)),
          ],
          const SizedBox(height: 24),
        ]),
      );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LegalPage(title: 'Terms of use', sections: [
        _Section('What CampusStay is', 'CampusStay helps students find accommodation and helps landlords list it. We are a marketplace. We are not the landlord, we do not own the properties, and we are not a party to any rental agreement between you and a landlord or student.'),
        _Section('Listing is free', 'Listing a property and searching are free. We do not charge listing fees or take a commission. Nobody at CampusStay will ask you to pay to be listed or to see a property. If someone does, report them.'),
        _Section('Your account', 'Give true information. Keep your password private. You are responsible for what happens under your account. You must be old enough to agree to these terms where you live; if you are under 18, use CampusStay with a parent or guardian.'),
        _Section('For landlords', 'Only list a property you own or are allowed to rent out. Show real photos of the real place. Give the real price and every fee. Keep your listing up to date and mark it rented when it is. Listings are reviewed before students can see them, and we may reject, pause or remove a listing that is misleading or unsafe.'),
        _Section('For students', 'Be honest and respectful. Never pay money before you have seen the property and met the landlord or their real representative. Reviews must be about a place you actually viewed.'),
        _Section('Not allowed', 'Fake or duplicate listings, stolen photos, scams, harassment, hate, threats, asking for money outside a proper agreement, sharing other people\'s private details, or trying to break or misuse the app.'),
        _Section('Verification', 'A Verified badge means our team checked the documents the landlord uploaded. It is not a guarantee about the property, the landlord or any agreement. Always see the place yourself.'),
        _Section('Reports and removal', 'You can report listings, people and reviews. We review reports and may remove content or suspend accounts. Decisions we make are recorded.'),
        _Section('Our responsibility', 'We work to keep CampusStay safe and accurate, but we cannot promise every listing or person is honest. To the extent the law allows, we are not responsible for losses from agreements or payments between users.'),
        _Section('Changes', 'We may update these terms. If the change matters, we will ask you to accept the new version.'),
        _Section('Contact', 'Use Help & Support in the app.'),
      ]);
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LegalPage(title: 'Privacy policy', sections: [
        _Section('What we collect', 'Your email, a password (stored securely by our login provider, never readable by us), and your name. Optional: your phone number. If you are a landlord: your property details, photos, a map pin and, if you choose to upload them, identity and ownership documents. Your messages, saved listings, saved searches, viewing requests and reviews. If you tap "Use my location", your phone\'s location is used for that action.'),
        _Section('How we use it', 'To run the app: show listings, let people message each other, review listings and keep CampusStay safe. We use reports and messages to deal with abuse.'),
        _Section('Who can see what', 'Your email is never shown to other users. Your phone number is shown only if you are a landlord who chose to share it, and only as your setting allows (hidden, after a student messages you, or to signed-in students). A listing\'s exact location and address are shown only to the landlord, our reviewers, and students whose viewing the landlord confirmed; everyone else sees an approximate area. Identity and ownership documents are private: only you and our review team can open them. Reviews are shown without the reviewer\'s name.'),
        _Section('What we do not do', 'We do not sell your personal information. We do not show targeted ads based on sensitive information.'),
        _Section('Keeping it safe', 'Data is stored with our hosting provider, protected by access rules so people can only see what they are allowed to. No system is perfect, so keep your password private.'),
        _Section('Your choices', 'You can edit your name and phone number, change who sees your phone number, block people, and delete saved searches and listings. To ask us to delete your account or data, contact support from Help & Support in the app.'),
        _Section('Children', 'Students may be under 18. We keep contact limited to messages about listings, with reporting and blocking available, and we do not use children\'s data for advertising.'),
        _Section('Changes', 'If this policy changes in an important way, we will tell you in the app.'),
      ]);
}
