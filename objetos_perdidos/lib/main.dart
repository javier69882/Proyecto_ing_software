import 'package:flutter/material.dart';

// Ajusta el nombre del paquete si es distinto en tu pubspec.yaml
import 'package:objetos_perdidos/screen/crear_perfil_screen.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/screen/crear_publicacion_screen.dart';
import 'package:objetos_perdidos/Datos/repositories/publications_repository.dart';
import 'package:objetos_perdidos/Datos/models/publication_record.dart';

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
  final _pubRepo = PublicationsRepository();
  List<PublicationRecord> _publicaciones = [];

  @override
  void initState() {
    super.initState();
    _loadPublicaciones();
  }

  Future<void> _loadPublicaciones() async {
    final list = await _pubRepo.listPublications();
    setState(() => _publicaciones = list.reversed.toList()); // mostrar recientes arriba
  }

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

  // pantalla para crear el post
  Future<void> _abrirCrearPublicacion() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CrearPublicacionScreen(
          profilesRepository: widget.repo,
          publicationsRepository: _pubRepo,
        ),
      ),
    );
    if (creado == true) {
      await _loadPublicaciones();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo creación de perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _abrirCrearPublicacion,
              icon: const Icon(Icons.publish),
              label: const Text('Crear publicación'),
            ),
            const SizedBox(height: 24),
            if (_ultimaRuta != null) ...[
              const Text('Archivo de perfiles:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_ultimaRuta!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const Text('Publicaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _publicaciones.isEmpty
                  ? const Center(child: Text('No hay publicaciones'))
                  : ListView.separated(
                      itemCount: _publicaciones.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final p = _publicaciones[i];
                        final fecha = DateTime.tryParse(p.fechaIso);
                        final fechaStr = fecha != null ? fecha.toLocal().toString().split(' ').first : p.fechaIso;
                        return ListTile(
                          title: Text(p.titulo),
                          subtitle: Text('${p.categoria} • ${p.autorNombre}\n$fechaStr\n${p.lugar}'),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
