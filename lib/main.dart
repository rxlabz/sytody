import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel speech_channel =
    const MethodChannel("bz.rxla.flutter/recorder");

const languages = const [
  const Language('Francais', 'fr_FR'),
  const Language('English', 'en_US'),
  const Language('Pусский', 'ru_RU'),
  const Language('Italiano', 'it_IT'),
];

void main() {
  runApp(new SytodyApp());
}


class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

class Task {
  int taskId;
  String label;
  bool complete;

  Task({this.taskId, this.label, this.complete = false});
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
              onSelected: _selectLangHandler,
              itemBuilder: (BuildContext context) => _buildLanguagesWidgets,
            )
          ]),
      body: new TranscriptorWidget(lang: selectedLang),
    ));
  }

  List<CheckedPopupMenuItem<Language>> get _buildLanguagesWidgets => languages
                  .map((l) => new CheckedPopupMenuItem<Language>(
                        value: l,
                        checked: selectedLang == l,
                        child: new Text(l.name),
                      ))
                  .toList();

  void _selectLangHandler(Language lang) {
    setState(() => selectedLang = lang);
  }
}

class TranscriptorWidget extends StatefulWidget {
  final Language lang;

  TranscriptorWidget({this.lang});

  @override
  _TranscriptorAppState createState() => new _TranscriptorAppState();
}

class _TranscriptorAppState extends State<TranscriptorWidget> {
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
    speech_channel.setMethodCallHandler(_platformCallHandler);
    _activateRecognition();
  }

  @override
  void dispose() {
    super.dispose();
    if(isListening)
      _cancelRecognitionHandler();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    List<Widget> blocks = [
      new Expanded(
          flex: 2,
          child: new ListView(
              children: incompleteTasks
                  .map((t) => _buildTaskWidgets(
                      task: t,
                      onDelete: () => _deleteTaskHandler(t),
                      onComplete: () => _completeTaskHandler(t)))
                  .toList())),
      _buildButtonBar(),
    ];
    if (transcription != '')
      blocks.insert(
          1,
          _buildTranscriptionBox(
              text: transcription,
              onCancel: _cancelRecognitionHandler,
              width: size.width - 20.0));
    return new Center(
        child: new Column(mainAxisSize: MainAxisSize.min, children: blocks));
  }

  void _saveTranscription() {
    if(transcription.isEmpty) return;
    setState(() {
      todos.add(new Task(
          taskId: new DateTime.now().millisecondsSinceEpoch,
          label: transcription));
      transcription = '';
    });
    _cancelRecognitionHandler();
  }

  Future _startRecognition() async {
    final res =
        await speech_channel.invokeMethod("startRecognition", widget.lang.code);
    if (!res)
      showDialog(
          context: context,
          child: new SimpleDialog(title: new Text("Error"), children: [
            new Padding(
                padding: new EdgeInsets.all(12.0),
                child: new Text('Recognition not started'))
          ]));
  }

  Future _cancelRecognitionHandler() async {
    final res = await speech_channel.invokeMethod("cancelRecognition");
    setState(() {
      transcription = '';
      isListening = res;
    });
  }

  /* not used, anymore, ... for now
    Future stopRecognition() async {
    final res = await speech_channel.invokeMethod("stopRecognition");
    setState(() => isListening = res);
  }*/

  Future _activateRecognition() async {
    final res = await speech_channel.invokeMethod("activateRecognition");
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

  _deleteTaskHandler(Task t) {
    setState(() {
      todos.remove(t);
      _showStatus("cancelled");
    });
  }

  void _completeTaskHandler(Task completed) {
    setState(() {
      todos =
          todos.map((t) => completed == t ? (t..complete = true) : t).toList();
      _showStatus("completed");
    });
  }

  Widget _buildButtonBar() {
    List<Widget> buttons = [
      !isListening
          ? _buildIconButton(authorized ? Icons.mic : Icons.mic_off,
              authorized ? _startRecognition : null,
              color: Colors.white, fab: true)
          : _buildIconButton(Icons.add, isListening ? _saveTranscription : null,
              color: Colors.white,
              backgroundColor: Colors.greenAccent,
              fab: true),
    ];
    Row buttonBar = new Row(mainAxisSize: MainAxisSize.min, children: buttons);
    return buttonBar;
  }

  Widget _buildTranscriptionBox(
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

  Widget _buildIconButton(IconData icon, VoidCallback onPress,
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
              icon: new Icon(icon, size: 32.0),
              color: color,
              onPressed: onPress),
    );
  }

  Widget _buildTaskWidgets(
      {Task task, VoidCallback onDelete, VoidCallback onComplete}) {
    return new TaskWidget(
        label: task.label, onDelete: onDelete, onComplete: onComplete);
  }

  void _showStatus(String action) {
    final label = "Task $action : ${incompleteTasks.length} left "
        "/ ${numArchived} archived";
    Scaffold.of(context).showSnackBar(new SnackBar(content: new Text(label)));
  }
}

class TaskWidget extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;
  final VoidCallback onComplete;

  TaskWidget({this.label, this.onDelete, this.onComplete});

  Widget _buildDissmissibleBackground(
          {Color color,
          IconData icon,
          FractionalOffset align = FractionalOffset.centerLeft}) =>
      new Container(
        height: 42.0,
        color: color,
        child: new Icon(icon, color: Colors.white70),
        alignment: align,
      );

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
            background: _buildDissmissibleBackground(
                color: Colors.lime, icon: Icons.check),
            secondaryBackground: _buildDissmissibleBackground(
                color: Colors.red,
                icon: Icons.delete,
                align: FractionalOffset.centerRight),
            onDismissed: (direction) => direction == DismissDirection.startToEnd
                ? onComplete()
                : onDelete()));
  }
}
