import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: TakePicture(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

class TakePicture extends StatefulWidget {
  const TakePicture({super.key, required this.camera});

  final CameraDescription camera;

  @override
  TakePictureState createState() => TakePictureState();
}

class TakePictureState extends State<TakePicture> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    //Display output
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
    );

    //Initialize the controller
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fashion Discriminator'),
        centerTitle: true,
      ),
      body: Stack(
        children: <Widget>[
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CameraPreview(_controller);
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: InkWell(
                onTap: () async {
                  try {
                    await _initializeControllerFuture;

                    final image = await _controller.takePicture();

                    if (!mounted) return;

                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DisplayPictureScreen(
                          imagePath: image.path,
                        ),
                      ),
                    );
                  } catch (e) {
                    print(e);
                  }
                },
                child: Container(
                  width: 80.0,
                  height: 80.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.camera_alt,
                      size: 40.0,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DisplayPictureScreen extends StatefulWidget {
  const DisplayPictureScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  PredictImageState createState() => PredictImageState();
}

class PredictImageState extends State<DisplayPictureScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  Future<img.Image> getImage(String imagePath, int height, int width) async {
    final cmd = img.decodeImageFile(widget.imagePath)
      // Resize the image to a width of 64 pixels and a height that maintains the aspect ratio of the original.
      ..copyResize(width: 175, height: 350);

    final ByteData imageByteData = await rootBundle.load(widget.imagePath);
    img.Image baseSizeImage =
        img.decodeImage(imageByteData.buffer.asUint8List());
    img.Image resizeImage =
        img.copyResize(baseSizeImage, height: 350, width: 175);
    return resizeImage;
  }

  void predict() async {
    final interpreter = await tfl.Interpreter.fromAsset('aifsModel.tflite');

    var _inputShape = interpreter.getInputTensor(0).shape;
    var _outputShape = interpreter.getOutputTensor(0).shape;
    var _inputType = interpreter.getInputTensor(0).type;
    var _outputType = interpreter.getOutputTensor(0).type;

    ImageProcessor imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(350, 175, ResizeMethod.NEAREST_NEIGHBOUR))
        .build();

    img.Image resizedImage =
        ResizeImage(FileImage(File(widget.imagePath)), width: 175, height: 300);

    // Convert the resized image to a 1D Float32List.
    Float32List inputBytes = Float32List(1 * 150 * 150 * 3);
    int pixelIndex = 0;
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        int pixel = resizedImage.getPixel(x, y);
        inputBytes[pixelIndex++] = img.getRed(pixel) / 127.5 - 1.0;
        inputBytes[pixelIndex++] = img.getGreen(pixel) / 127.5 - 1.0;
        inputBytes[pixelIndex++] = img.getBlue(pixel) / 127.5 - 1.0;
      }
    }

    // Reshape to input format specific for model. 1 item in list with pixels 150x150 and 3 layers for RGB
    final input = inputBytes.reshape([1, 150, 150, 3]);

    // Create a TensorImage object from a File
    TensorImage tensorImage = TensorImage.fromFile(File(widget.imagePath));

    // Preprocess the image.
    // The image for imageFile will be resized to (224, 224)
    tensorImage = imageProcessor.process(tensorImage);

    //var output = List.filled(1 * 5, 0).reshape([1, 5]);

    var _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);

    print(_inputShape);
    print(_inputType);

    interpreter.run(tensorImage.buffer, _outputBuffer.getBuffer());

    print(_outputBuffer);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    predict();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display the Picture'),
        centerTitle: true,
      ),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image(
          image: ResizeImage(FileImage(File(widget.imagePath)),
              width: 350, height: 700)),
    );
  }
}

/*
    @override
    Widget build(BuildContext context){
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Fashion Discriminator')),
        child: Center(
          child: Column(
            children: <Widget>[
              FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return CameraPreview(_controller);
                  } else {
                    return const Center(child: CircularProgressIndicator()); 
                  }
                },
              ),
              CupertinoButton.filled(
              alignment: Alignment.bottomCenter,
              onPressed: () async {
                try {
                  await _initializeControllerFuture;

                  final image = await _controller.takePicture();const

                  if (!mounted) return;

                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DisplayPictureScreen(
                        imagePath: image.path,
                      ),
                    ),
                    );
                } catch (e) {
                  print(e);
                }
              },
              child: const Icon(Icons.camera_alt),
            ),
            ]
          ),
        ),
      );
    }
}
*/
