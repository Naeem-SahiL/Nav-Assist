import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'main.dart';

class NavigationScreen extends StatefulWidget {
  // const NavigationScreen({super.key});
  const NavigationScreen({Key? key}) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  CameraImage? cameraImage;
  late CameraController controller;
  late FlutterVision vision;
  late List<Map<String, dynamic>> yoloResults;
  bool isLoaded = false;
  bool isDetecting = false;

  String output = 'Speak "start streaming" to start the navigation';
  String _text = 'Action!';
  late SpeechToText _speech;
  bool _isListening = true;
  int _lastStreamTime = 0;

  @override
  void initState() {
    super.initState();
    init();
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
  void processWords() async{
    print(_text);
    if(_text.contains('detect')){
      Navigator.pushNamed(context, '/camera');
    }
    else if(_text.contains('capture')){
      print("capture called");
      await startDetection();
      
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

  init() async {
    cameras = await availableCameras();
    vision = FlutterVision();
    controller = CameraController(cameras[0], ResolutionPreset.low);
    controller.initialize().then((value) {
      loadYoloModel().then((value) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          yoloResults = [];
        });
      });
    });
  }

  @override
  void dispose() {
    controller.stopImageStream();
    controller.dispose();
    vision.closeYoloModel();
    _stopListen();
    _speech.cancel();
    super.dispose();
  }

  Future<void> loadYoloModel() async {
    await vision.loadYoloModel(
        labels: 'assets/labels.txt',
        modelPath: 'assets/yolov8n.tflite',
        modelVersion: "yolov8",
        numThreads: 2,
        useGpu: false);
    setState(() {
      isLoaded = true;
    });
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        yoloOnFrame(image);
      }
    });
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    final result = await vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        iouThreshold: 0.4,
        confThreshold: 0.4,
        classThreshold: 0.5);
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result;
      });
    }
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
      controller.stopImageStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = Size(
      MediaQuery.of(context).size.width - 10,
      (MediaQuery.of(context).size.height * 0.7) - 10,
    );

    if (!isLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Navigation Screen'),
        ),
        body: const Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Screen'),
      ),
      body: Column(
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(5),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  width: MediaQuery.of(context).size.width,
                  child: !controller.value.isInitialized
                      ? Container()
                      : AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: CameraPreview(controller),
                        ),
                ),
              ),
              ...displayBoxesAroundRecognizedObjects(size),
              Positioned(
                bottom: 20,
                width: MediaQuery.of(context).size.width,
                child: Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        width: 5,
                        color: Colors.white,
                        style: BorderStyle.solid),
                  ),
                  child: isDetecting
                      ? IconButton(
                          onPressed: () async {
                            stopDetection();
                          },
                          icon: const Icon(
                            Icons.stop,
                            color: Colors.red,
                          ),
                          iconSize: 40,
                        )
                      : IconButton(
                          onPressed: () async {
                            await startDetection();
                          },
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                          ),
                          iconSize: 50,
                        ),
                ),
              ),
            ],
          ),
          Text(
            _text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(
                    Colors.white), // Set the background color
                minimumSize: MaterialStateProperty.all<Size>(
                    Size(300, 50)), // Set the size
              ),
              onPressed: () {
                Navigator.popUntil(context, ModalRoute.withName(Navigator.defaultRouteName));
              },
              child: const Text('Home screen', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }

   List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];
    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    return yoloResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY,
        width: (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }
}
