import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Position? currentPosition;
  StreamSubscription? subscription;

  @override
  void initState() {
    super.initState();
    startListeningLocation();
  }

  locationPermission({VoidCallback? inSuccess}) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.openLocationSettings();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openLocationSettings();
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }
    {
      inSuccess?.call();
    }
  }

  void startListeningLocation() async {
    locationPermission(
      inSuccess: () async {
        subscription = Geolocator.getPositionStream(
          locationSettings:
              Platform.isAndroid
                  ? AndroidSettings(
                    accuracy: LocationAccuracy.bestForNavigation,
                    distanceFilter: 10,
                    forceLocationManager: true,
                    foregroundNotificationConfig:
                        const ForegroundNotificationConfig(
                          notificationTitle: 'Rastreamento em andamento',
                          notificationText:
                              'Seu dispositivo está sendo rastreado',
                          enableWakeLock: true,
                        ),
                  )
                  : AppleSettings(
                    accuracy: LocationAccuracy.bestForNavigation,
                    activityType: ActivityType.fitness,
                    distanceFilter: 10,
                    showBackgroundLocationIndicator: true,
                    pauseLocationUpdatesAutomatically: false,
                  ),
        ).listen((event) async {
          currentPosition = event;
          final now = DateTime.now().toUtc().add(const Duration(hours: -3));
          final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
          log(
            'Posição: $currentPosition | Data e hora: $formattedDate',
            name: 'currentPosition',
          );
          await _sendLocationToAPI(currentPosition!, formattedDate);
        });
      },
    );
  }

  Future<void> _sendLocationToAPI(Position position, String dateTime) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.24.4.240:8484/api/Location/register'),
        headers: {'Content-Type': 'application/json'},
        body: '''
        {
          "latitude": ${position.latitude},
          "longitude": ${position.longitude},
          "userHash": "app_teste"
        }
        ''',
      );
      log('Resposta da API: ${response.body}');
      if (response.statusCode != 200) {
        log('Falha ao enviar localização: ${response.statusCode}');
      }
    } catch (e) {
      log('Erro ao enviar localização: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Geolocalization Example'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Habilite a localização e terá as coordenadas em tempo real no log da aplicação.',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }
}
