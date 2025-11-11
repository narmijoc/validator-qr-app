import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ValidadorApp());
}

class ValidadorApp extends StatelessWidget {
  const ValidadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Validador de Evento',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ------------------ HOME PAGE ------------------
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validador de Evento'),
        centerTitle: true,
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
            textStyle: const TextStyle(fontSize: 20),
          ),
          child: const Text('Escanear QR'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QRScanPage()),
            );
          },
        ),
      ),
    );
  }
}

// ------------------ QR SCAN PAGE ------------------
class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false; // bandera para evitar múltiples alertas

  final String webAppUrl = 'https://script.google.com/macros/s/AKfycbwj9GKABRJDZ89B-Y2rYJwIpczTQfVaNcRuXiByrf-sXf9gV089IZMU2zq3onjwUl1K/exec'; // reemplaza con tu URL

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;

    controller!.scannedDataStream.listen((scanData) async {
      if (_isProcessing) return; // ya estamos procesando
      if (controller == null) return; // seguridad

      _isProcessing = true;
      await controller!.pauseCamera(); // pausa cámara mientras procesa

      final qrText = scanData.code;
      try {
        final uri = Uri.parse(qrText!);
        final run = uri.queryParameters['RUN'];

        if (run == null) {
          await _showResult('No se pudo leer RUN', false);
        } else {
          showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
          final allowed = await _isAllowed(run);
          await _showResult(run, allowed);
        }
      } catch (e) {
        await _showResult('QR inválido', false);
      }
    });
  }

  Future<bool> _isAllowed(String run) async {
    final url = '$webAppUrl?RUN=$run';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return false;

      final data = json.decode(response.body);
      return data['allowed'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _showResult(String run, bool allowed) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: allowed ? Colors.green[200] : Colors.red[200],
        title: Center(
          child: Text(
            allowed ? '¡Acceso Permitido!' : 'Acceso Denegado',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        content: Center(
          child: Text(
            'RUN: $run',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: allowed ? Colors.green[800] : Colors.red[800],
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // cerrar diálogo
                Navigator.of(context).pop(); // volver a HomePage
              },
              child: const Text(
                'Cerrar',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );

    _isProcessing = false; // desbloquear para próximo QR
    await controller?.resumeCamera(); // reanudar cámara
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.blue,
          borderRadius: 12,
          borderLength: 40,
          borderWidth: 8,
          cutOutSize: 300,
        ),
      ),
    );
  }
}