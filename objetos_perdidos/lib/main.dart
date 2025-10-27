import 'package:flutter/material.dart';

// Ajusta el nombre del paquete si es distinto en tu pubspec.yaml
import 'package:objetos_perdidos/screen/crear_perfil_screen.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  MainApp({super.key});

  final _repo = ProfilesRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Objetos Perdidos – Demo',
      debugShowCheckedModeBanner: false,
      home: DemoHome(repo: _repo),
    );
  }
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key, required this.repo});
  final ProfilesRepository repo;

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  String? _ultimaRuta;

  Future<void> _abrirCrearPerfil() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CrearPerfilScreen(repository: widget.repo)),
    );

    if (creado == true) {
      final path = await widget.repo.debugFilePath();
      setState(() => _ultimaRuta = path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil creado correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo creación de perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pulsa el botón para crear un perfil.\n'
              'Se guardará en ./data/profiles.json',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _abrirCrearPerfil,
              icon: const Icon(Icons.person_add),
              label: const Text('Crear perfil'),
            ),
            const SizedBox(height: 24),
            if (_ultimaRuta != null) ...[
              const Text('Archivo de perfiles:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_ultimaRuta!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
