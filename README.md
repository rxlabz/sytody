# Sytôdy, a Flutter "speech to text" todo app POC

:warning: iOS10(Swift) only for now.

[![screenshot](screenshot.png)](https://youtu.be/7MGuNZfgGWw)

## Usage

Install [flutter](http://flutter.io)

```bash
cd sytody
flutter run
```

:tv: [Video demo](https://youtu.be/7MGuNZfgGWw)

## How it works

The flutter app open a channel on the host platform (iOS only for now). It uses it :
 
 - to ask for speech recognition and microphone usage. The permission is asked on the first application launch 
 - to start, cancel and stop the speech recognition 
 - to listen to the recognition result
 
### Recognition

#### [x] iOS

- [Speech API](https://developer.apple.com/reference/speech)

#### [ ] Android


### UI

#### Task list

A [ListView](https://docs.flutter.io/flutter/widgets/ListView-class.html) with [TaskWidget](https://github.com/rxlabz/sytody/blob/master/lib/task.dart) items

#### Dismissible

The tasks are displayed in a [Dismissible](https://docs.flutter.io/flutter/widgets/Dismissible-class.html) Widget

#### Languages menu

A [PopupMenuButton](https://docs.flutter.io/flutter/material/PopupMenuButton-class.html)  

## Getting Started with Flutter

For help getting started with Flutter, view our online
[documentation](http://flutter.io/).
