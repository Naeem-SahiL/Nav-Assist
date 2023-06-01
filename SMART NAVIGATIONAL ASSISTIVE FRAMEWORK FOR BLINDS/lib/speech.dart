import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechTT extends StatefulWidget {
  const SpeechTT({super.key});

  @override
  State<SpeechTT> createState() => _SpeechTTState();
}

class _SpeechTTState extends State<SpeechTT> {
  late SpeechToText _speech;
  bool _isListening = true;
  String _text = 'Press the button and start speaking';

  @override
  void initState() {
    super.initState();
    _speech = SpeechToText();
  }

  @override
  Widget build(BuildContext context) {
    _listen();
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _stopListen,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
      appBar: AppBar(
        title: const Text(
          "Speech detection",
          textAlign: TextAlign.center,
        ),
      ),
      body: SingleChildScrollView(
        reverse: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(30.0, 30.0, 30.0, 150.0),
          child: Text(_text)
        ),
      ),
    );
  }

  void _listen() async {
    // if (_isListening) {
    bool available = await _speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    if (available) {
      setState(() {});
      _speech.listen(
        onResult: (val) => setState(() {
          _text = val.recognizedWords;
        }),
      );
      // }
    }
  }

  void _stopListen() {
    _speech.stop();
    setState(() => _isListening = false);
  }
}
