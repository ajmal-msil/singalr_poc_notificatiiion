import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:singalr_poc/local_notification_service.dart';

void main() async {
  LocalNotificationService localNotificationService =
  LocalNotificationService();
  WidgetsFlutterBinding.ensureInitialized();
  await localNotificationService.setup();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? reconnectTimer;
  bool isStreaming = false;

  final hubConnection = HubConnectionBuilder()
      .withUrl("http://192.168.100.63:5002/notificationHub",
      options: HttpConnectionOptions())
      .withAutomaticReconnect(retryDelays: [
    2000,
    5000,
    10000,
    20000,
  ]).build();
  late Logger _logger;
  LocalNotificationService _localNotificationService =
  LocalNotificationService();

  String receivedNotification = ""; // To store the received notification

  @override
  void initState() {
    super.initState();
    connectToSignalR();
  }

  Future<void> connectToSignalR() async {
    try {
      await hubConnection.start();
      print("Connected to SignalR server");
      hubConnection.on("ReceiveNotification", _handleIncommingMessage);


      // final result = await hubConnection.invoke("StartStreaming");
      // Subscribe to the "StreamStarted" event to handle streaming start
      hubConnection.on("StreamStarted", (_) {
        print("Streaming started");
        setState(() {
          isStreaming = true;
        });
      });

      // Subscribe to the "ReceiveStreamingData" event to handle received data
      hubConnection.on("ReceiveStreamingData", _handlestreamingData);
    } catch (e) {
      print("Error connecting to SignalR server: $e");
    }
    startStreaming();
  }

  void startStreaming() async {
    try {
      if (hubConnection.state == HubConnectionState.Connected) {
        await hubConnection.invoke("StartStreaming");
      } else {
        print("Connection is not in the 'Connected' state.");

        reconnectTimer = Timer(Duration(seconds: 5), () {
          connectToSignalR(); // Implement the connectToSignalR function to reconnect
        });
      }
    } catch (e) {
      print("Error connecting to SignalR server: $e");
    }

}

void _handlestreamingData(List<Object?>? args) {
  final String message = args![0] as String;
  print("Received streaming data: $message");

  setState(() {
    receivedNotification = message as String;
  });
}

void _handleIncommingMessage(List<Object?>? args) {
  final String senderName = args![0] as String;
  final String message = args[1] as String;

  // Handle the received notification
  print("Received notification: $message");
  _localNotificationService.showLocalNotification(
    senderName,
    message,
  );


  setState(() {
    receivedNotification = message as String;
  });
}

@override
void dispose() {
  hubConnection.invoke("StopStreaming");
  reconnectTimer?.cancel(); // Cancel the reconnect timer when disposing
  hubConnection.stop();

  super.dispose();
}

@override
Widget build(BuildContext context) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: Text("SignalR Push Notifications"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Received Notification:",
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 10),
            Text(
              receivedNotification,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Start streaming when the button is pressed
                  startStreaming();
                },
                child: Text('Start Streaming'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}}
