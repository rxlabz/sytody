import UIKit
import Flutter
import Speech

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, SFSpeechRecognizerDelegate /*, FlutterStreamHandler */ {
  //private var eventSink: FlutterEventSink?


  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr_FR"))!

  private var recorderChannel: FlutterMethodChannel?

  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

  private var recognitionTask: SFSpeechRecognitionTask?

  private let audioEngine = AVAudioEngine()

  override func application(
     _ application: UIApplication,
     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController

    recorderChannel = FlutterMethodChannel.init(name: "bz.rxla.flutter/recorder",
       binaryMessenger: controller)
    recorderChannel!.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if ("startRecording" == call.method) {
        self.startRecording(result: result)
      } else if ("stopRecording" == call.method) {
        self.stopRecording(result: result)
      }  else if ("activateRecognition" == call.method) {
        self.activateRecognition(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    /*let chargingChannel = FlutterEventChannel.init(name: "samples.flutter.io/charging",
     binaryMessenger: controller)

     chargingChannel.setStreamHandler(self)
     */
    return true
  }

  func activateRecognition(result:@escaping FlutterResult){
    speechRecognizer.delegate = self

    SFSpeechRecognizer.requestAuthorization { authStatus in
      /*
          The callback may not be called on the main thread. Add an
          operation to the main queue to update the record button's state.
      */
      OperationQueue.main.addOperation {
        switch authStatus {
        case .authorized:
          result(true)

        case .denied:
          result(false)

        case .restricted:
          result(false)

        case .notDetermined:
          result(false)
        }
      }
    }
  }

  private func startRecording(result: FlutterResult) {

    if audioEngine.isRunning {
      audioEngine.stop()
      recognitionRequest?.endAudio()
      result(0)
    } else {
      try! start()
      result(1)
    }

  }

  private func stopRecording(result: FlutterResult) {
    if audioEngine.isRunning {
      audioEngine.stop()
      recognitionRequest?.endAudio()
    }
    result(0)
  }

  private func start() throws {

    // Cancel the previous task if it's running.
    if let recognitionTask = recognitionTask {
      recognitionTask.cancel()
      self.recognitionTask = nil
    }

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(AVAudioSessionCategoryRecord)
    try audioSession.setMode(AVAudioSessionModeMeasurement)
    try audioSession.setActive(true, with: .notifyOthersOnDeactivation)

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    guard let inputNode = audioEngine.inputNode else {
      fatalError("Audio engine has no input node")
    }
    guard let recognitionRequest = recognitionRequest else {
      fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
    }

    // Configure request so that results are returned before audio recording is finished
    recognitionRequest.shouldReportPartialResults = true

    // A recognition task represents a speech recognition session.
    // We keep a reference to the task so that it can be cancelled.
    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
      var isFinal = false

      if let result = result {
        print("Speech : \(result.bestTranscription.formattedString)")
        self.recorderChannel?.invokeMethod("onSpeech", arguments: result.bestTranscription.formattedString)
        isFinal = result.isFinal
        if isFinal{
          self.recorderChannel!.invokeMethod(
             "onRecognitionComplete",
             arguments: result.bestTranscription.formattedString
          )
        }
      }

      if error != nil || isFinal {
        self.audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        self.recognitionRequest = nil
        self.recognitionTask = nil

      }
    }

    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
      self.recognitionRequest?.append(buffer)
    }

    audioEngine.prepare()

    try audioEngine.start()

    recorderChannel!.invokeMethod("onRecognitionStarted", arguments: nil)
  }

  // MARK: SFSpeechRecognizerDelegate

  public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
    if available {
      recorderChannel?.invokeMethod("onSpeechAvailability", arguments: true)
    } else {
      recorderChannel?.invokeMethod("onSpeechAvailability", arguments: false)
    }
  }

}
