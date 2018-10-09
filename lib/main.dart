import "dart:async";
import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'secret.dart' as SECRET;
import 'package:http/http.dart' as http;

List<CameraDescription> cameras;
CameraController controller;

Future main() async {
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return new _MyAppState();
  }
}

class _MyAppState extends State<MyApp> {
  List<Annotation> _labels = new List();
  final List<String> priorityWords = [
    'person',
    'car',
    'street',
    'tree',
    'wall',
    'door',
    'furniture',
    'dog',
    'cat',
    'stairs',
    'bike',
    'vehicle',
    'skateboard',
    'box'
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            backgroundColor: Colors.grey[800],
            appBar: AppBar(
              title: Text("Pigen"),
              backgroundColor: Colors.deepOrange[700],
            ),
            body: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: InkWell(
                        onTap: captureImage,
                        child: Container(
                          child: (cameras.length > 0)
                              ? CameraApp()
                              : AlertDialog(
                                  title: Text(
                                    "The Camera isn't working",
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                        ),
                        splashColor: Colors.red,
                      ),
                      color: Colors.grey[700],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                    ),
                  ),
                  Expanded(
                      flex: 1,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: Card(
                              color: Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0)),
                              child: (_labels.length > 3)
                                  ? Text(
                                      "${_labels[0]}, ${_labels[1]}, ${_labels[2]}, ${_labels[3]}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 32.0),
                                      textAlign: TextAlign.center,
                                    )
                                  : Text(" "),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Card(
                                color: Colors.grey[900],
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0)),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.settings,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {},
                                )),
                          ),
                        ],
                      )),
                ],
              ),
            )));
  }

  String timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  captureImage() async {
    if (!controller.value.isInitialized) {
      return null;
    }
    if (controller.value.isTakingPicture) {
      return null;
    }

    final Directory extDir = await getTemporaryDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await new Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';
    await controller.takePicture(filePath);
    List<int> byteArray = File(filePath).readAsBytesSync();
    String base64Image = base64Encode(byteArray);
    var serverResponse = await fetchImageAnnotations(base64Image);
    var resString = serverResponse.toString().replaceAll("\n", " ");
    Map json = await jsonDecode(resString);
    var labelAnnotations = json['responses'][0]['labelAnnotations'];
    determineViableLabelAnnotations(labelAnnotations);
    // var textAnnotations = json['responses'][1]['textAnnotations'];
    // determineViableTextAnnotations(textAnnotations);
  }

  fetchImageAnnotations(String base64Image) async {
        print("Sending data to server ... ");
     var loading = new Annotation();
     loading.description = "Loading...";
    _labels.add(loading);
    String key = SECRET.visionApiKey;
    var url = 'https://vision.googleapis.com/v1/images:annotate?key=' + key;
    var response = await http
        .post(url,
            headers: {'Content-type': 'application/json'},
            body: jsonEncode({
              "requests": [
                {
                  "image": {"content": base64Image},
                  "features": [
                    {"type": "LABEL_DETECTION", "maxResults": 6},
                    {"type": "TEXT_DETECTION", "maxResults": 6},
                  ]
                }
              ]
            }))
        .then((http.Response r) => r.body)
        .whenComplete(() => print("server responded"));
    return response;
  }

  determineViableLabelAnnotations(annotations) {
    _labels.clear();
    bool noPriorityWordsInList = true;
    if (annotations != null) {
      for (var annotation in annotations) {
        var annotationObj = new Annotation();
        annotationObj.score = annotation["score"];
        annotationObj.topicalitiy = annotation["topicality"];
        annotationObj.description = annotation["description"];
        if (priorityWords.contains(annotationObj.description)) {
          annotationObj.score = 1.0;
          annotationObj.topicalitiy = 1.0;
          annotationObj.description = annotationObj.description.toUpperCase();
          if (_labels.length > 0) {
            _labels[0] = annotationObj;
          }
        }
        _labels.add(annotationObj);
      }
    }
    // print("Unsorted: " + _labels.toString());
    // _labels.sort();
    // print("Sorted: " + _labels.toString());

    setState(() {
      if (_labels.length > 0) {
        if (_labels[0].score < 0.75 &&
            _labels[0].topicalitiy < 0.75 &&
            noPriorityWordsInList) {
          _labels.clear();
          var tryAgain = new Annotation();
          tryAgain.description = "Try Again";
          _labels.add(tryAgain);
        }
      }
    }
        // Tts.speak(_labels[0].description +
        //     ", " +
        //     _labels[1].description +
        //     ", " +
        //     _labels[2].description +
        //     ", " +
        //     _labels[3].description);
        );
  }

  determineViableTextAnnotations(annotations) {
    print("Hello Annotations");
    bool viableAnnotationsExist = false;
    if (annotations[0]['descrption'].toString().length > 0) {
      viableAnnotationsExist = true;
      print(annotations[0]['descrption']);
    }
    if (!viableAnnotationsExist) {
      print("Sorry, we couldn't determine any text for this photo. Try again?");
    }
  }
}

class CameraApp extends StatefulWidget {
  @override
  CameraAppState createState() => new CameraAppState();
}

class CameraAppState extends State<CameraApp> {
  @override
  void initState() {
    super.initState();
    if (cameras.length > 0) {
      controller = new CameraController(cameras[0], ResolutionPreset.medium);
    }
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return new Container();
    }
    return new AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: new CameraPreview(controller));
  }
}

class Annotation extends Comparable {
  double score;
  double topicalitiy;
  String description;

  @override
  int compareTo(other) {
    var thisQuality = score * topicalitiy;
    var otherQuality = other.score * other.topicalitiy;
    if (thisQuality > otherQuality) {
      return -1;
    } else if (thisQuality < otherQuality) {
      return 1;
    } else {
      return 0;
    }
  }

  @override
  String toString() {
    return description.toString();
  }
}
