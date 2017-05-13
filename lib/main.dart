import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel recorder_channel =
    const MethodChannel("bz.rxla.flutter/recorder");
const MethodChannel player_channel =
    const MethodChannel("bz.rxla.flutter/player");

void main() {
  runApp(new MaterialApp(home: new Scaffold(body: new TranscriptorApp())));
}

class TranscriptorApp extends StatefulWidget {
  @override
  _TranscriptorAppState createState() => new _TranscriptorAppState();
}

class _TranscriptorAppState extends State<TranscriptorApp> {
  String transcription = '';

  bool authorized = false;

  bool isListening = false;

  List<String> todos = [];

  bool get isNotEmpty => transcription != '';

  @override
  void initState() {
    super.initState();
    recorder_channel.setMethodCallHandler(_platformCallHandler);
    activateRecognition();
  }

  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;

    return new Center(
        child: new Column(mainAxisSize: MainAxisSize.min, children: [
      new Row(mainAxisSize: MainAxisSize.min, children: [
        !isListening
            ? bt('start', authorized ? startRecording : null)
            : bt('stop', isListening ? stopRecording : null),
        bt('+', isNotEmpty ? saveTranscription : null),
      ]),
      new Container(
              width:size.width - 20.0,
              height: 20.0,
              color: Colors.grey.shade200,
              child: new Row(children: [
                new Text(transcription),
                new IconButton(
                    icon: new Icon(Icons.cancel),
                    onPressed: () => cancelInput())
              ])),
      new Expanded(
          flex: 2,
          child: new ListView(children: todos.map((t) => new Text(t)).toList()))
    ]));
  }

  void saveTranscription() {

    setState(() {
      todos.add(transcription);
      transcription = '';
      print('_TranscriptorAppState.saveTranscription => todos ${todos}');
    });
  }

  Future startRecording() async {
    final res = await recorder_channel.invokeMethod("startRecording");
    //setState(() => transcription = res.toString());
    print('_TranscriptorAppState.startRecording... $res');
  }

  Future stopRecording() async {
    final res = await recorder_channel.invokeMethod("stopRecording");
    //setState(() => transcription = res.toString());
    setState(()=>isListening = res == 0);
    print('_TranscriptorAppState.stopRecording... $res');
  }

  Future activateRecognition() async {
    final res = await recorder_channel.invokeMethod("activateRecognition");
    print('_TranscriptorAppState.activateRecognition '
        '-> recognitionActivation : $res');
    setState(() => authorized = res);
  }

  Future _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case "onSpeechAvailability":
        print('_TranscriptorAppState._platformCallHandler '
            '-> onSpeechAvailability : ${call.arguments}');
        setState(() => isListening = call.arguments);
        break;
      case "onSpeech":
        print('_TranscriptorAppState._platformCallHandler '
            '-> onSpeech : ${call.arguments}');
        setState(() => transcription = call.arguments);
        break;
      case "onRecognitionStarted":
        print('_TranscriptorAppState._platformCallHandler '
            '-> onRecognitionStarted : ${call.arguments}');
        setState(() => isListening = true);
        break;
      case "onRecognitionComplete":
        print('_TranscriptorAppState._platformCallHandler '
            '-> onRecognitionComplete : ${call.arguments}');
        setState(() => isListening = false);
        break;
      default:
        print('Unknowm method ${call.method} ');
    }
  }

  cancelInput() {
    stopRecording().then((v){
      setState((){
        transcription = '';
      });
    });

  }
}

Widget bt(String label, VoidCallback onPress) {
  return new Padding(
    padding: new EdgeInsets.all(12.0),
    child: new RaisedButton(child: new Text(label), onPressed: onPress),
  );
}

Widget task(String label, VoidCallback onPress) {
  return new Padding(
    padding: new EdgeInsets.all(12.0),
    child: new Text(label),
  );
}
