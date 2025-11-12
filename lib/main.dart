import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _historial = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('historial');
    if (raw != null) {
      setState(() {
        _historial = List<Map<String, dynamic>>.from(json.decode(raw));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validador de Evento'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('historial');
              setState(() => _historial.clear());
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _historial.isEmpty
                ? const Center(child: Text('Sin historial aún'))
                : ListView.builder(
                    itemCount: _historial.length,
                    itemBuilder: (context, i) {
                      final item = _historial[i];
                      return ListTile(
                        leading: Icon(
                          item['allowed'] ? Icons.check_circle : Icons.cancel,
                          color: item['allowed'] ? Colors.green : Colors.red,
                        ),
                        title: Text('RUN: ${item['run']}'),
                        subtitle: Text(item['timestamp']),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                textStyle: const TextStyle(fontSize: 20),
              ),
              child: const Text('Escanear QR'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QRScanPage()),
                ).then((_) => _cargarHistorial());
              },
            ),
          ),
        ],
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
  bool _isProcessing = false;

  final String webAppUrl =
      'https://little-mountain-ebaa.nicolas-armijoc.workers.dev/';

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;

    controller!.scannedDataStream.listen((scanData) async {
      if (_isProcessing) return;
      if (controller == null) return;

      _isProcessing = true;
      await controller!.pauseCamera();

      final qrText = scanData.code;
      try {
        final uri = Uri.parse(qrText!);
        final run = uri.queryParameters['RUN'];

        if (run == null) {
          await _showResult('RUN no encontrado', false);
        } else {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          final allowed = await _isAllowed(run);
          Navigator.of(context).pop(); // cerrar loading
          await _guardarHistorial(run, allowed);
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

    if (response.statusCode != 200) {
      print('Error HTTP: ${response.statusCode}');
      return false;
    }

    final data = json.decode(response.body);
    print('Respuesta Cloudflare: $data');

    // Si el JSON tiene {"allowed": true}, retornamos eso
    return data['allowed'] ?? false;
  } catch (e) {
    print('Error al conectar con Worker: $e');
    return false;
  }
  }

  Future<void> _guardarHistorial(String run, bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('historial');
    List<Map<String, dynamic>> historial = [];
    if (raw != null) {
      historial = List<Map<String, dynamic>>.from(json.decode(raw));
    }

    historial.insert(0, {
      'run': run,
      'allowed': allowed,
      'timestamp': DateTime.now().toString().substring(0, 19),
    });

    // mantener solo los últimos 20
    if (historial.length > 500) historial = historial.sublist(0, 500);

    await prefs.setString('historial', json.encode(historial));
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
                Navigator.of(context).pop();
                Navigator.of(context).pop();
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

    _isProcessing = false;
    await controller?.resumeCamera();
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