import 'dart:async';
import 'package:flutter/services.dart';

const MethodChannel _speech_channel =
    const MethodChannel("bz.rxla.flutter/recorder");

class Recognizer {

  static void setMethodCallHandler(handler) {
    _speech_channel.setMethodCallHandler(handler);
  }

  static Future activateRecognition() {
    return _speech_channel.invokeMethod("activateRecognition");
  }

  static Future startRecognition(String lang) {
    return _speech_channel.invokeMethod("startRecognition", lang);
  }

  static Future cancelRecognition() {
    return _speech_channel.invokeMethod("cancelRecognition");
  }

  static Future stopRecognition() {
    return _speech_channel.invokeMethod("stopRecognition");
  }

}
