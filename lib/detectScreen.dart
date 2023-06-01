import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  FlutterTts ftts = FlutterTts();
  CameraController? controller;
  bool _isCameraInitialized = false;
  final resolutionPresets = ResolutionPreset.values;
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;
  bool _isRearCameraSelected = false;
  late FlutterVision vision;
  late List<Map<String, dynamic>> yoloResults;
  File? imageFile;
  int imageHeight = 1;
  int imageWidth = 1;
  bool isLoaded = false;

  String? imagePath;
  late SpeechToText _speech;
  bool _isListening = true;
  String _text = '';
  List<String> _enableDistClasses = ['laptop', 'chair'];

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;
    // Instantiating the camera controller
    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
    );

    // Dispose the previous controller
    await previousCameraController?.dispose();

    // Replace with the new controller
    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize controller
    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    // Update the Boolean
    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void speak(text, ftts) async {
    var result = await ftts.speak(text);
    if (result == 1) {
      //speaking
    } else {
      //not speaking
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController!.value.isTakingPicture) {
      return null;
    }
    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      // ignore: avoid_print
      print('Error occured while taking picture: $e');
      return null;
    }
  }

  @override
  void initState() {
    _speech = SpeechToText();
    onNewCameraSelected(widget.cameras.first);
    super.initState();
    vision = FlutterVision();
    print("yolo model loading");
    loadYoloModel().then((value) {
      print("model loaded");
      setState(() {
        yoloResults = [];
        isLoaded = true;
      });
    });
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

  yoloOnImage() async {
    print("arrived");
    yoloResults.clear();
    List<int>  byte = await imageFile!.readAsBytes();
    img.Image? convertedImage = img.decodeImage(byte);

    // Convert the image to JPEG format
    List<int> jpegData = img.encodeJpg(convertedImage!);
    Uint8List uint8List = Uint8List.fromList(jpegData);
    final image = await decodeImageFromList(uint8List);
    imageHeight = image.height;
    imageWidth = image.width;
    print(imageHeight);
    print(imageWidth);

    final result = await vision.yoloOnImage(
        bytesList: uint8List,
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.8,
        confThreshold: 0.3,
        classThreshold: 0.5);
    print(result);

    if (result.isNotEmpty) {
      print("detected ");
      setState(() {
        yoloResults = result;
      });

      List<Size> objectDimensions = getObjectDimensions(result);
      DistanceObject distanceObject = DistanceObject();

      for (int i = 0; i < objectDimensions.length; i++) {
        if (result[i]['tag'] == 'laptop') {
          distanceObject.laptop =
              getObjectDistance(objectDimensions[i], result[i]['tag']);
        } else if (result[i]['tag'] == 'chair') {
          distanceObject.chair =
              getObjectDistance(objectDimensions[i], result[i]['tag']);
        }
        else if (result[i]['tag'] == 'bottle') {
          distanceObject.chair =
              getObjectDistance(objectDimensions[i], result[i]['tag']);
        }
      }

      String outputClass = generateOutputString(result, distanceObject);
      speak(outputClass, ftts);
      _text = objectDimensions.toString();
    }
  }

  String generateOutputString(List<Map<String, dynamic>> detectionResults, DistanceObject distanceObject) {
  String outputString = "There ";
  int numResults = detectionResults.length;

  if (numResults == 1) {
    if (distanceObject.laptop != null && detectionResults[0]['tag'] == 'laptop') {
      outputString += "is a ${detectionResults[0]['tag']} at ${distanceObject.laptop} inches";
    } else 
    if (distanceObject.chair != null && detectionResults[0]['tag'] == 'chair') {
      outputString += "is a ${detectionResults[0]['tag']} at ${distanceObject.chair} inches";
    } 
    else 
    if (distanceObject.chair != null && detectionResults[0]['tag'] == 'bottle') {
      outputString += "is a ${detectionResults[0]['tag']} at ${distanceObject.bottle} inches";
    } 
    else {
      outputString += "is a ${detectionResults[0]['tag']}";
    }
  } else {
    outputString += "are";

    for (int i = 0; i < numResults; i++) {
      String className = detectionResults[i]['tag'];

      if (className == 'laptop') {
        if (distanceObject.laptop != null) {
          outputString += " $className at ${distanceObject.laptop} inches";
        } else {
          outputString += " $className";
        }
      } else if (className == 'chair') {
        if (distanceObject.chair != null) {
          outputString += " $className at ${distanceObject.chair} inches";
        } else {
          outputString += " $className";
        }
      } 
      else if (className == 'bottle') {
        if (distanceObject.chair != null) {
          outputString += " $className at ${distanceObject.bottle} inches";
        } else {
          outputString += " $className";
        }
      } 
      else {
        outputString += " $className";
      }

      if (i == numResults - 2) {
        outputString += " and";
      } else if (i != numResults - 1) {
        outputString += ",";
      }
    }
  }

  return outputString;
}


  int getObjectDistance(Size dimension, String className) {
    double? knownDistance ;
    double? knownWidth;
    if(className == 'laptop')
    {
      knownDistance = 15.0;
      knownWidth = 431.0;
    }
    else if(className == 'chair')
    {
      knownDistance = 30.0;
      knownWidth = 620.0;
    }
    else if(className == 'bottle')
    {
      knownDistance = 15.0;
      knownWidth = 220.0;
    }
    
    double difference = knownWidth! - dimension.width;
    double ratio = getRatio(className);
    double noOfInches = difference / ratio;
    int distance = (knownDistance! + noOfInches).ceil();

    return distance;
  }

  double getRatio(String className)
  {
    if(className == 'laptop')
    {
      return 5.0;
    }
    else if(className == 'chair')
    {
      return 12.0;
    }
    else if(className == 'bottle')
    {
      return 9.5;
    }
    return 0;
  }

  List<Size> getObjectDimensions(List<Map<String, dynamic>> detectionResults) {
    List<Size> dimensions = [];

    for (Map<String, dynamic> result in detectionResults) {
      List<dynamic> box = result['box'];
      double x1 = box[0];
      double y1 = box[1];
      double x2 = box[2];
      double y2 = box[3];

      double width = x2 - x1;
      double height = y2 - y1;

      Size objectSize = Size(width, height);
      dimensions.add(objectSize);
    }

    return dimensions;
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Capture a photo
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        imageFile = File(photo.path);
      });

      yoloOnImage();
    }
  }

  void _captureImage() async {
    XFile? rawImage = await takePicture();
    imageFile = File(rawImage!.path);
    yoloOnImage();
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

  void processWords() {
    print(_text);
    if (_text.contains('capture')) {
      print("capture called");
      _captureImage();
    } else if (_text.contains('navigate')) {
      Navigator.pushNamed(context, '/navigate');
    } else if (_text.contains('home')) {
      Navigator.popUntil(
          context, ModalRoute.withName(Navigator.defaultRouteName));
    }
  }

  void _stopListen() async {
    print("stop listening");
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() async {
    controller?.dispose();
    _speech.stop();
    _speech.cancel();
    super.dispose();
    await vision.closeYoloModel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final ButtonStyle style = ElevatedButton.styleFrom(
        padding:
            const EdgeInsets.only(left: 30, right: 30, top: 10, bottom: 10),
        textStyle: const TextStyle(fontSize: 20),
        minimumSize: const Size(200, 50));
    _listen();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Screen'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              imageFile == null
                  ? _isCameraInitialized
                      ? Expanded(
                          child: AspectRatio(
                            aspectRatio: controller!.value.aspectRatio,
                            child: controller!.buildPreview(),
                          ),
                        )
                      : const CircularProgressIndicator()
                  : Expanded(child: Image.file(imageFile!)),
            ],
          ),
          ...displayBoxesAroundRecognizedObjects(size),
          Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    print('close button pressed');
                    imageFile = null;
                    yoloResults.clear();
                    setState(() {
                      _isCameraInitialized = false;
                    });
                    onNewCameraSelected(
                      widget.cameras[0],
                    );
                    setState(() {
                      _isRearCameraSelected = !_isRearCameraSelected;
                    });
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: const [
                      Icon(
                        Icons.circle,
                        color: Colors.black38,
                        size: 40,
                      ),
                      Icon(
                        //close icon
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 200,
                  child: Wrap(
                    children: [
                      Text(
                        _text,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isCameraInitialized = false;
                    });
                    onNewCameraSelected(
                      widget.cameras[_isRearCameraSelected ? 0 : 1],
                    );
                    setState(() {
                      _isRearCameraSelected = !_isRearCameraSelected;
                    });
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Colors.black38,
                        size: 40,
                      ),
                      Icon(
                        _isRearCameraSelected
                            ? Icons.camera_front
                            : Icons.camera_rear,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              children: [
                InkWell(
                  onTap: _captureImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: const [
                      Icon(Icons.circle, color: Colors.white38, size: 80),
                      Icon(Icons.circle, color: Colors.white, size: 65),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          style: style,
                          onPressed: () {
                            Navigator.popUntil(context, ModalRoute.withName(Navigator.defaultRouteName));
                          },
                          child: const Text('Home screen'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }


  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (imageWidth);
    double imgRatio = imageWidth / imageHeight;
    double newWidth = imageWidth * factorX;
    double newHeight = newWidth / imgRatio;
    double factorY = newHeight / (imageHeight);

    double pady = (screen.height - newHeight) / 2;

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);
    return yoloResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY + pady,
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


class DistanceObject {
  int? laptop;
  int? chair;
  int? bottle;

  DistanceObject({this.laptop, this.chair, this.bottle});
}


