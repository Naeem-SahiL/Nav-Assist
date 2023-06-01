import 'dart:ui';

import 'package:detect/DetectScreen.dart';
import 'package:detect/flutter_vission.dart';
import 'package:detect/speech.dart';
import 'package:flutter/material.dart';
import "package:flutter_tts/flutter_tts.dart";
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'navigationScreen.dart';

List<CameraDescription> cameras = [];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error in fetching the cameras: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: white,
      ),
      home: const MyHomePage(title: 'Nav Assist'),
      initialRoute: '/',
      routes: {
        '/camera': (context) => CameraScreen(
              cameras: cameras,
            ),
        '/navigate': (context) => const NavigationScreen(),
        '/yolo': (context) => const YoloModelsScreen(),
        '/stt': (context) => SpeechTT(),
      },
    );
  }
}

const MaterialColor white = MaterialColor(
  0xFFFFFFFF,
  <int, Color>{
    50: Color(0xFFFFFFFF),
    100: Color(0xFFFFFFFF),
    200: Color(0xFFFFFFFF),
    300: Color(0xFFFFFFFF),
    400: Color(0xFFFFFFFF),
    500: Color(0xFFFFFFFF),
    600: Color(0xFFFFFFFF),
    700: Color(0xFFFFFFFF),
    800: Color(0xFFFFFFFF),
    900: Color(0xFFFFFFFF),
  },
);

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterTts ftts = FlutterTts();
  late SpeechToText _speech;
  bool _isListening = true;
  String _text = 'Speak the action!';
  _MyHomePageState() {
    speak("Welcome to nav assist!", ftts);
  }

  void speak(text, ftts) async {
    var result = await ftts.speak(text);
    if (result == 1) {
      //speaking
    } else {
      //not speaking
    }
  }

  void _listen() async {
    if (_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() {});
        _speech.listen(onResult: (val) {
          setState(() {
            _text = val.recognizedWords;
          });

          processWords();
        });
      }
    }
  }
  void processWords(){
    print(_text);
    if(_text.contains('detect')){
      Navigator.pushNamed(context, '/camera');
    }
    else if(_text.contains('navigate')){
      Navigator.pushNamed(context, '/navigate');
    }
    else if(_text.contains('home')){
      Navigator.popUntil(context, ModalRoute.withName(Navigator.defaultRouteName));
    }
  }
  void _stopListen() async {
    print("stop listening");
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  void initState() {
    super.initState();
    _speech = SpeechToText();
  }

  @override
  void dispose() async {
    _stopListen();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _listen();
    final ButtonStyle style = ElevatedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 20),
        minimumSize: const Size(200, 50));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(
                              top: 10, right: 40, left: 40),
                          child: ElevatedButton(
                            style: style,
                            onPressed: () {
                              Navigator.pushNamed(context, '/camera');
                            },
                            child: const Text("Camera Screen"),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(
                              top: 10, right: 40, left: 40),
                          child: ElevatedButton(
                            style: style,
                            onPressed: () {
                              Navigator.pushNamed(context, '/navigate');
                            },
                            child: const Text("Navigation Screen"),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(
                              top: 10, right: 40, left: 40),
                          child: ElevatedButton(
                            style: style,
                            onPressed: _stopListen,
                            child: const Text("Stop Listening"),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                            margin: const EdgeInsets.only(
                                top: 10, right: 40, left: 40),
                            child: Center(
                              child: Text(
                                _text,
                                style: TextStyle(fontSize: 15),
                              ),
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
