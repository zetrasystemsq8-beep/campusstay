import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/state_views.dart';
import '../../core/errors.dart';
import '../../core/widgets/error_views.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<Conversation>> _f = Services.repo.conversations();
  void _refresh() => setState(() => _f = Services.repo.conversations());

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s16, CS.s8),
          child: Row(children: [
            Expanded(child: Text('Messages', style: Theme.of(context).textTheme.headlineMedium)),
            IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Conversation>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (s.hasError) return ErrorView(error: s.error!, onRetry: _refresh);
              if (s.data!.isEmpty) {
                return const EmptyState(icon: Icons.chat_bubble_outline, title: 'No messages yet', message: 'Message a landlord from any listing to start a conversation.');
              }
              return ListView.separated(
                itemCount: s.data!.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final conv = s.data![i];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: CS.blueSoft, child: Icon(Icons.home_outlined, color: CS.blue)),
                    title: Text(conv.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ThreadScreen(conversation: conv))),
                  );
                },
              );
            },
          ),
        ),
      ]);
}

class ThreadScreen extends StatefulWidget {
  final Conversation conversation;
  const ThreadScreen({super.key, required this.conversation});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  late Future<List<ChatMessage>> _f = Services.repo.messages(widget.conversation.id);
  final _c = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Services.repo.sendMessage(widget.conversation.id, t);
      _c.clear();
      setState(() => _f = Services.repo.messages(widget.conversation.id));
    } catch (e) {
      if (mounted) {
        final ex = classify(e);
        // A refused insert here means the other person blocked you, or you blocked them.
        showError(context, ex.kind == AppErrorKind.forbidden ? const AppException(AppErrorKind.blocked) : ex);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _block() async {
    final other = widget.conversation.otherUserId;
    if (other == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text('Neither of you will be able to send messages in this conversation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Block')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Services.repo.blockUser(other);
      if (mounted) showMessage(context, 'Blocked. They can no longer message you.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _reportPerson() async {
    final other = widget.conversation.otherUserId;
    if (other == null) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Report this person'), children: [
        for (final r in const ['Scam or fraud', 'Harassment or abuse', 'Fake listing', 'Asking for money outside CampusStay', 'Other'])
          SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r)),
      ]),
    );
    if (reason == null) return;
    try {
      await Services.repo.report('user', other, reason, '');
      if (mounted) showMessage(context, 'Report sent. Our team will review it.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.conversation.title), actions: [
          if (widget.conversation.otherUserId != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) => v == 'block' ? _block() : _reportPerson(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report this person')),
                PopupMenuItem(value: 'block', child: Text('Block this person')),
              ],
            ),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => setState(() => _f = Services.repo.messages(widget.conversation.id))),
        ]),
        body: Column(children: [
          Expanded(
            child: FutureBuilder<List<ChatMessage>>(
              future: _f,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (s.hasError) return ErrorView(error: s.error!, onRetry: () => setState(() => _f = Services.repo.messages(widget.conversation.id)));
                return ListView(padding: const EdgeInsets.all(CS.s16), children: [
                  for (final m in s.data!)
                    Align(
                      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(color: m.mine ? CS.blue : CS.surface, borderRadius: BorderRadius.circular(CS.rMd)),
                        child: Text(m.body, style: TextStyle(color: m.mine ? Colors.white : CS.ink, fontSize: 15)),
                      ),
                    ),
                ]);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(CS.s12, CS.s8, CS.s12, CS.s8 + MediaQuery.of(context).viewInsets.bottom),
              child: Row(children: [
                Expanded(child: TextField(controller: _c, maxLength: 2000, buildCounter: (c, {required currentLength, required isFocused, maxLength}) => null, decoration: const InputDecoration(hintText: 'Write a message'))),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, tooltip: 'Send', icon: const Icon(Icons.send)),
              ]),
            ),
          ),
        ]),
      );
}
