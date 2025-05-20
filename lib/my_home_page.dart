import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Position? currentPosition;
  StreamSubscription? subscription;
  bool hasSentLocationToday = false;

  @override
  void initState() {
    super.initState();
    startListeningLocation();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void startListeningLocation() async {
    locationPermission(
      inSuccess: () async {
        if (Platform.isAndroid) {
          subscription = Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              forceLocationManager: true,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'Monitoramento Ativo',
                notificationText: 'Aguardando horário programado (12h)',
                enableWakeLock: true,
              ),
            ),
          ).listen((position) async {
            currentPosition = position;
            final now = DateTime.now().toUtc().add(const Duration(hours: -3));

            if (now.hour == 0 && now.minute == 0) {
              hasSentLocationToday = false;
            }

            if (now.hour == 12 && now.minute == 0 && !hasSentLocationToday) {
              await _sendLocationToAPI(position);
              hasSentLocationToday = true;
              log('Localização registrada com sucesso às 12h');
            }
          });
        } else {
          subscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
            ),
          ).listen((position) async {
            currentPosition = position;
            final now = DateTime.now().toUtc().add(const Duration(hours: -3));

            if (now.hour == 0 && now.minute == 0) {
              hasSentLocationToday = false;
            }

            if (now.hour == 12 && now.minute == 0 && !hasSentLocationToday) {
              await _sendLocationToAPI(position);
              hasSentLocationToday = true;
            }
          });
        }
      },
    );
  }

  Future<void> _sendLocationToAPI(Position position) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: -3));
    log(
      'Enviando localização às ${now.hour}h${now.minute}m: ${position.latitude}, ${position.longitude}',
    );

    try {
      final response = await http.post(
        Uri.parse('http://10.24.4.240:8484/api/Location/register'),
        headers: {'Content-Type': 'application/json'},
        body: '''
        {
          "latitude": ${position.latitude},
          "longitude": ${position.longitude},
          "userHash": "app_teste_horario"
        }
        ''',
      );
      log('Resposta da API: ${response.body}');
    } catch (e) {
      log('Erro ao enviar localização: $e');
    }
  }

  Future<void> locationPermission({required Function() inSuccess}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Serviços de localização estão desativados.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissões de localização foram negadas.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Permissões de localização foram permanentemente negadas.',
      );
    }

    await inSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rastreamento de Localização')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Status: Monitorando localização',
              style: TextStyle(fontSize: 18),
            ),
            if (currentPosition != null) ...[
              const SizedBox(height: 20),
              Text(
                'Última localização:\nLat: ${currentPosition?.latitude}\nLong: ${currentPosition?.longitude}',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
