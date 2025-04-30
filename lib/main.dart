import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(home: InventarioScreen()));

class Item {
  final String id;
  final String nome;
  bool disponivel;

  Item({
    required this.id,
    required this.nome,
    this.disponivel = true,
  });
}

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({Key? key}) : super(key: key);

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final List<Item> itens = [];
  final TextEditingController _nomeController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _hasCameraPermission = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      _hasCameraPermission = status.isGranted;
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasCameraPermission = status.isGranted;
    });
  }

  void _adicionarItem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Item'),
        content: TextField(
          controller: _nomeController,
          decoration: const InputDecoration(
            labelText: 'Nome do Item',
            hintText: 'Ex: Notebook, Projetor',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (_nomeController.text.isNotEmpty) {
                setState(() {
                  itens.add(Item(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nome: _nomeController.text,
                  ));
                  _nomeController.clear();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _alterarStatus(String itemId) {
    setState(() {
      final item = itens.firstWhere((i) => i.id == itemId);
      item.disponivel = !item.disponivel;
    });
  }

  Future<void> _abrirScanner(BuildContext context) async {
    if (!_hasCameraPermission) {
      await _requestCameraPermission();
      if (!_hasCameraPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão da câmera negada')),
        );
        return;
      }
    }

    final scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('Escanear QR'),
            actions: [
              IconButton(
                icon: ValueListenableBuilder(
                  valueListenable: scannerController.torchState,
                  builder: (context, state, child) {
                    switch (state) {
                      case TorchState.off:
                        return const Icon(Icons.flash_off);
                      case TorchState.on:
                        return const Icon(Icons.flash_on);
                    }
                  },
                ),
                onPressed: () => scannerController.toggleTorch(),
              ),
            ],
          ),
          body: Stack(
            children: [
              MobileScanner(
                controller: scannerController,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? codigo = barcodes.first.rawValue;
                    if (codigo != null && itens.any((item) => item.id == codigo)) {
                      Navigator.pop(ctx);
                      _alterarStatus(codigo);
                    }
                  }
                },
              ),
              if (!scannerController.isStarting)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );

    await scannerController.stop();
    scannerController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventário QR')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _adicionarItem,
              child: const Text('Adicionar Item'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: itens.length,
              itemBuilder: (ctx, index) {
                final item = itens[index];
                return ListTile(
                  title: Text(item.nome),
                  subtitle: Text(item.disponivel ? 'Disponível' : 'Em uso'),
                  trailing: QrImageView(
                    data: item.id,
                    size: 50,
                  ),
                  onTap: () => _alterarStatus(item.id),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => _abrirScanner(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Escanear QR Code'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }
}