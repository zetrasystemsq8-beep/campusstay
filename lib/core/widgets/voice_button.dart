import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../errors.dart';
import '../theme/tokens.dart';
import 'error_views.dart';

/// A microphone for text boxes: tap, speak, tap again. For people who find typing hard.
class VoiceButton extends StatefulWidget {
  final TextEditingController controller;
  const VoiceButton({super.key, required this.controller});
  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  final _speech = SpeechToText();
  bool _ready = false, _listening = false;
  String _before = '';

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      if (!_ready) {
        _ready = await _speech.initialize(
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && mounted) setState(() => _listening = false);
          },
          onError: (e) {
            if (mounted) {
              setState(() => _listening = false);
              showError(context, AppException(AppErrorKind.voiceUnavailable, detail: e.permanent ? "Voice typing stopped: ${e.errorMsg}. Check that microphone permission is allowed." : null));
            }
          },
        );
      }
      if (!_ready) throw const AppException(AppErrorKind.voiceUnavailable, detail: 'Voice typing is off or not allowed on this phone. Allow the microphone for CampusStay in Settings, or use your keyboard\'s microphone.');
      _before = widget.controller.text.trim();
      await _speech.listen(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 6),
        onResult: (r) {
          final spoken = r.recognizedWords;
          widget.controller.text = _before.isEmpty ? spoken : '$_before $spoken';
          widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
        },
      );
      if (mounted) setState(() => _listening = true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: _listening ? 'Tap to stop' : 'Speak instead of typing',
        onPressed: _toggle,
        icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? CS.danger : CS.green, size: 28),
      );
}
