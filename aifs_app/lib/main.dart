import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final cameras = await availableCameras();
  
  final firstCamera = cameras.first;
  
  runApp(
    CupertinoApp(
      theme: CupertinoThemeData(brightness: Brightness.light),
      home: TakePicture(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}


class TakePicture extends StatefulWidget {
  const TakePicture({
    super.key,
    required this.camera});
    
    final CameraDescription camera;
    
    @override
    TakePictureState createState() => TakePictureState();
}

class TakePictureState extends State<TakePicture>{
    late CameraController _controller;
    late Future<void> _initializeControllerFuture;
    
    @override
    void initState(){
      super.initState();
      //Display output
      _controller = CameraController(
        widget.camera,
        ResolutionPreset.medium,
      );
      
      //Initialize the controller
      _initializeControllerFuture = _controller.initialize();
    }
    
    @override
    void dispose(){
      _controller.dispose();
      super.dispose();
    }
    
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
              child: const Icon(Icons.camera_alt),
            ),
            ]
          ),
        ),
      );
    }
}

class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}

