import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel recorder_channel =
    const MethodChannel("bz.rxla.flutter/recorder");
const MethodChannel player_channel =
    const MethodChannel("bz.rxla.flutter/player");

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

const languages = const [
  const Language('Francais', 'fr_FR'),
  const Language('English', 'en_US'),
  const Language('русский', 'ru_RU'),
  const Language('italiano', 'it_IT'),
];

void main() {
  runApp(new SytodyApp());
}

class SytodyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new SytodyAppState();
}

class SytodyAppState extends State<SytodyApp> {
  Language selectedLang = languages[0];

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        home: new Scaffold(
      appBar: new AppBar(
          title: new Row(children: [
            new Image.asset('assets/sytody.png', fit: BoxFit.fitHeight),
            new Text('Sytôdy'),
          ]),
          backgroundColor: Colors.blueGrey,
          actions: [
            new PopupMenuButton<Language>(
              onSelected: (Language value) =>
                  setState(() => selectedLang = value),
              itemBuilder: (BuildContext context) => languages
                  .map((l) => new CheckedPopupMenuItem<Language>(
                        value: l,
                        checked: selectedLang == l,
                        child: new Text(l.name),
                      ))
                  .toList(),
            )
          ]),
      body: new TranscriptorApp(lang: selectedLang),
    ));
  }

  selectLang(Language lang) {
    setState(() => selectedLang = lang);
  }
}

class TranscriptorApp extends StatefulWidget {
  final Language lang;

  TranscriptorApp({this.lang});

  @override
  _TranscriptorAppState createState() => new _TranscriptorAppState();
}

class _TranscriptorAppState extends State<TranscriptorApp> {
  String transcription = '';

  bool authorized = false;

  bool isListening = false;

  List<Task> todos = [];

  bool get isNotEmpty => transcription != '';

  get numArchived => todos.where((t) => t.complete).length;
  Iterable<Task> get incompleteTasks => todos.where((t) => !t.complete);

  @override
  void initState() {
    super.initState();
    recorder_channel.setMethodCallHandler(_platformCallHandler);
    activateRecognition();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    List<Widget> blocks = [
      new Expanded(
          flex: 2,
          child: new ListView(
              children: todos
                  .where((t) => !t.complete)
                  .map((t) => getTaskRenderer(
                      task: t,
                      onDelete: () => deleteTaskHandler(t),
                      onComplete: () => completeTaskHandler(t)))
                  .toList())),
      getButtonBar(),
    ];
    if (transcription != '')
      blocks.insert(
          1,
          getTranscriptionBox(
              text: transcription,
              onCancel: cancelRecognitionHandler,
              width: size.width - 20.0));
    return new Center(
        child: new Column(mainAxisSize: MainAxisSize.min, children: blocks));
  }

  void saveTranscription() {
    setState(() {
      todos.add(new Task(
          taskId: new DateTime.now().millisecondsSinceEpoch,
          label: transcription));
      transcription = '';
    });
    cancelRecognitionHandler();
  }

  Future startRecognition() async {
    final res = await recorder_channel.invokeMethod(
        "startRecognition", widget.lang.code);
    if (!res)
      showDialog(
          context: context,
          child: new SimpleDialog(title: new Text("Error"), children: [
            new Padding(
                padding: new EdgeInsets.all(12.0),
                child: new Text('Recognition not started'))
          ]));
  }

  Future cancelRecognitionHandler() async {
    final res = await recorder_channel.invokeMethod("cancelRecognition");
    setState(() {
      transcription = '';
      isListening = res;
    });
  }

  Future stopRecognition() async {
    final res = await recorder_channel.invokeMethod("stopRecognition");
    setState(() => isListening = res);
  }

  Future activateRecognition() async {
    final res = await recorder_channel.invokeMethod("activateRecognition");
    setState(() => authorized = res);
  }

  Future _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case "onSpeechAvailability":
        setState(() => isListening = call.arguments);
        break;
      case "onSpeech":
        if (todos.isEmpty || transcription != todos.last.label)
          setState(() => transcription = call.arguments);
        break;
      case "onRecognitionStarted":
        setState(() => isListening = true);
        break;
      case "onRecognitionComplete":
        setState(() {
          isListening = false;
          if (call.arguments == todos.last.label) transcription = '';
        });
        break;
      default:
        print('Unknowm method ${call.method} ');
    }
  }

  deleteTaskHandler(Task t) {
    setState(() {
      todos.remove(t);
      showStatus("cancelled");
    });
  }

  void completeTaskHandler(Task completed) {
    setState(() {
      todos =
          todos.map((t) => completed == t ? (t..complete = true) : t).toList();
      showStatus("completed");
    });
  }

  Widget getButtonBar() {
    List<Widget> buttons = [
      !isListening
          ? getIconButton(authorized ? Icons.mic : Icons.mic_off,
              authorized ? startRecognition : null,
              color: Colors.white, fab: true)
          : getIconButton(Icons.add, isListening ? saveTranscription : null,
              color: Colors.white,
              backgroundColor: Colors.greenAccent,
              fab: true),
    ];
    Row buttonBar = new Row(mainAxisSize: MainAxisSize.min, children: buttons);
    return buttonBar;
  }

  void showStatus(String action) {
    final label = "Task $action : ${incompleteTasks.length} left "
        "/ ${numArchived} archived";
    Scaffold.of(context).showSnackBar(new SnackBar(content: new Text(label)));
  }
}

Widget getTranscriptionBox(
        {String text, VoidCallback onCancel, double width}) =>
    new Container(
        width: width,
        color: Colors.grey.shade200,
        child: new Row(children: [
          new Expanded(
              child: new Padding(
                  padding: new EdgeInsets.all(8.0), child: new Text(text))),
          new IconButton(
              icon: new Icon(Icons.close, color: Colors.grey.shade600),
              onPressed: text != '' ? () => onCancel() : null),
        ]));

Widget getButton(String label, VoidCallback onPress) {
  return new Padding(
    padding: new EdgeInsets.all(12.0),
    child: new RaisedButton(child: new Text(label), onPressed: onPress),
  );
}

Widget getIconButton(IconData icon, VoidCallback onPress,
    {Color color: Colors.grey,
    Color backgroundColor: Colors.pinkAccent,
    bool fab = false}) {
  return new Padding(
    padding: new EdgeInsets.all(12.0),
    child: fab
        ? new FloatingActionButton(
            child: new Icon(icon),
            onPressed: onPress,
            backgroundColor: backgroundColor)
        : new IconButton(
            icon: new Icon(icon, size: 32.0), color: color, onPressed: onPress),
  );
}

Widget getTaskRenderer(
    {Task task, VoidCallback onDelete, VoidCallback onComplete}) {
  return new TaskRenderer(
      label: task.label, onDelete: onDelete, onComplete: onComplete);
}

Widget getDissmissibleBackground(
        {Color color,
        IconData icon,
        FractionalOffset align = FractionalOffset.centerLeft}) =>
    new Container(
      height: 42.0,
      color: color,
      child: new Icon(icon, color: Colors.white70),
      alignment: align,
    );

class Task {
  int taskId;
  String label;
  bool complete;

  Task({this.taskId, this.label, this.complete = false});
}

class TaskRenderer extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;
  final VoidCallback onComplete;

  TaskRenderer({this.label, this.onDelete, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return new Container(
        height: 42.0,
        child: new Dismissible(
            direction: DismissDirection.horizontal,
            child: new Align(
                alignment: FractionalOffset.centerLeft,
                child: new Padding(
                    padding: new EdgeInsets.all(10.0), child: new Text(label))),
            key: new Key(label),
            background: new Container(
              height: 42.0,
              color: Colors.lime,
              child: new Icon(Icons.check, color: Colors.white70),
              alignment: FractionalOffset.centerLeft,
            ),
            secondaryBackground: new Container(
                height: 42.0,
                color: Colors.red,
                child: new Icon(Icons.delete, color: Colors.white70),
                alignment: FractionalOffset.centerRight),
            onDismissed: (direction) => direction == DismissDirection.startToEnd
                ? onComplete()
                : onDelete()));
  }
}
