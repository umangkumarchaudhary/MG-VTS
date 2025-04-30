import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRCodeScanner extends StatefulWidget {
  final Function(String) onQRCodeScanned;

  QRCodeScanner({required this.onQRCodeScanned});

  @override
  _QRCodeScannerState createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  late MobileScannerController controller;
  bool isScanning = false;
  String scannedCode = '';

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      isScanning = true;
      scannedCode = '';
      controller.start();
    });
  }

  void _stopScanning() {
    controller.stop();
    setState(() {
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isScanning)
          Container(
            height: 300,
            width: double.infinity,
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    setState(() {
                      scannedCode = code;
                    });
                    widget.onQRCodeScanned(code);
                    _stopScanning(); // Auto close camera
                  }
                }
              },
            ),
          )
        else
          ElevatedButton(
            onPressed: _startScanning,
            child: Text('Open Camera to Scan QR'),
          ),
        SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            labelText: 'Scanned QR Code',
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: scannedCode),
          readOnly: true,
        ),
      ],
    );
  }
}
