import 'dart:async';

import 'package:image/image.dart' as img;

import 'package:tflite_flutter/tflite_flutter.dart';

enum DetectionClasses { formal, preppy, sportswear, techwear, streetwear }

class Classifier {
  /// Instance of Interpreter
  late Interpreter _interpreter;

  static const String modelFile = "aifsModel.tflite";

  /// Loads interpreter from asset
  Future<void> loadModel({Interpreter? interpreter}) async {
    try {
      _interpreter = interpreter ??
          await Interpreter.fromAsset(
            modelFile,
            options: InterpreterOptions()..threads = 4,
          );

      _interpreter.allocateTensors();
    } catch (e) {
      print("Error while creating interpreter: $e");
    }
  }

  /// Gets the interpreter instance
  Interpreter get interpreter => _interpreter;

  void predict(img.Image image) async {
    img.Image resizedImage = img.copyResize(image, width: 350, height: 700);

    var output = List.filled(1 * 5, 0).reshape([1, 5]);

    interpreter.run(resizedImage, output);

    print(output);
  }
}
