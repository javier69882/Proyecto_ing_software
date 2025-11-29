import 'package:flutter/material.dart';
import 'package:objetos_perdidos/screen/crear_perfil_screen.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/screen/crear_publicacion_screen.dart';
import 'package:objetos_perdidos/Datos/repositories/publications_repository.dart';
import 'package:objetos_perdidos/Datos/models/publication_record.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart';
import 'package:objetos_perdidos/admin.dart';
import 'package:objetos_perdidos/ui/publicaciones_feed.dart';
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart';
import 'package:objetos_perdidos/screen/crear_informe_entrega_screen.dart';
import 'package:objetos_perdidos/informe.dart';
import 'package:objetos_perdidos/perfil.dart';
import 'package:objetos_perdidos/screen/listar_informes_screen.dart';
import 'package:objetos_perdidos/screen/listar_informes_retiro_screen.dart';


void main() {
  final controller = ProfileController(repo: ProfilesRepository());
  runApp(MainApp(controller: controller));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.controller});
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return ProfileScope(
      controller: controller,
      child: MaterialApp(
        title: 'Objetos Perdidos – Demo',
        debugShowCheckedModeBanner: false,
        home: DemoHome(repo: controller.repo),
      ),
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
  final _informesRepo = InformesRepository();
  List<PublicationRecord> _publicaciones = [];

  @override
  void initState() {
    super.initState();
    _loadPublicaciones();
  }

  Future<void> _loadPublicaciones() async {
    final list = await _pubRepo.listPublications();

    int idAsInt(PublicationRecord r) => int.tryParse(r.id) ?? 0;
    DateTime f(PublicationRecord r) =>
        DateTime.tryParse(r.fechaIso) ?? DateTime.fromMillisecondsSinceEpoch(0);

    list.sort((a, b) {
      final byId = idAsInt(b).compareTo(idAsInt(a));
      if (byId != 0) return byId;
      return f(b).compareTo(f(a));
    });

    if (!mounted) return;
    setState(() => _publicaciones = list);
  }

  Future<void> _abrirCrearPerfil() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CrearPerfilScreen(repository: widget.repo)),
    );

    if (creado == true) {
      final path = await widget.repo.debugFilePath();
      if (!mounted) return;
      setState(() => _ultimaRuta = path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil creado correctamente.')),
      );
    }
  }

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
    final perfilCtrl = ProfileScope.of(context);
    final usuario = perfilCtrl.current?.usuario ?? 'Sin perfil';
    final personaActual = perfilCtrl.current;
    final mostrarPuntos = personaActual is Perfil && !personaActual.isAdmin;
    final puntosActual = mostrarPuntos ? (personaActual as Perfil).puntos : 0;
 
    return Scaffold(
      appBar: AppBar(
        title: Text('Inicio – $usuario'),
        actions: [
          if (mostrarPuntos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.star, size: 16),
                label: Text('$puntosActual pts'),
              ),
            ),
          const ProfileSwitchAction(),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Pulsa el botón para crear un perfil.\nLa ruta exacta se mostrará abajo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // crear perfil
              SizedBox(
                width: 320,
                child: ElevatedButton.icon(
                  onPressed: _abrirCrearPerfil,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Crear perfil'),
                ),
              ),
              const SizedBox(height: 12),

              // cambiar de perfil
              SizedBox(
                width: 320,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileSelectorPage()),
                    );
                  },
                  icon: const Icon(Icons.switch_account),
                  label: const Text('Cambiar de perfil'),
                ),
              ),
              const SizedBox(height: 12),

              // crear publicación (solo usuarios comunes)
              Builder(builder: (ctx) {
                final c = ProfileScope.of(ctx).current;
                final puedeCrear = c is Perfil && !c.isAdmin;
                if (!puedeCrear) return const SizedBox.shrink();
                return SizedBox(
                  width: 320,
                  child: ElevatedButton.icon(
                    onPressed: _abrirCrearPublicacion,
                    icon: const Icon(Icons.publish),
                    label: const Text('Crear publicación'),
                  ),
                );
              }),
              const SizedBox(height: 12),

              // crear informe de entrega (solo admin)
              Builder(builder: (ctx) {
                final perfilCtrl2 = ProfileScope.of(ctx);
                final persona = perfilCtrl2.current;
                final esAdmin = persona is Perfil && persona.isAdmin;
                if (!esAdmin) return const SizedBox.shrink();
                return SizedBox(
                  width: 320,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final informe = await Navigator.push<Informe>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CrearInformeEntregaScreen(
                            admin: persona,
                            repository: _informesRepo,
                          ),
                        ),
                      );
                      if (informe != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Informe creado: ${informe.titulo}')),
                        );
                      }
                    },
                    icon: const Icon(Icons.assignment_add),
                    label: const Text('Crear informe de entrega'),
                  ),
                );
              }),
              const SizedBox(height: 12),
              // ver informes de entrega (solo admin)
              Builder(builder: (ctx) {
                final perfilCtrl2 = ProfileScope.of(ctx);
                final persona = perfilCtrl2.current;
                final esAdmin = persona is Perfil && persona.isAdmin;
                if (!esAdmin) return const SizedBox.shrink();
                return SizedBox(
                  width: 320,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListarInformesScreen(
                            repository: _informesRepo,
                            admin: persona,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assignment),
                    label: const Text('Ver informes de entrega'),
                  ),
                );
              }),
              const SizedBox(height: 12),

              // registrar informe de retiro (solo admin)
              Builder(builder: (ctx) {
                final perfilCtrl2 = ProfileScope.of(ctx);
                final persona = perfilCtrl2.current;
                final esAdmin = persona is Perfil && persona.isAdmin;
                if (!esAdmin) return const SizedBox.shrink();
                return SizedBox(
                  width: 320,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListarInformesScreen(
                            repository: _informesRepo,
                            admin: persona,
                            modoRegistroRetiro: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('Crear informe de retiro'),
                  ),
                );
              }),
              const SizedBox(height: 12),

              // ver informes de retiro (solo admin)
              Builder(builder: (ctx) {
                final perfilCtrl2 = ProfileScope.of(ctx);
                final persona = perfilCtrl2.current;
                final esAdmin = persona is Perfil && persona.isAdmin;
                if (!esAdmin) return const SizedBox.shrink();
                return SizedBox(
                  width: 320,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListarInformesRetiroScreen(
                            repository: _informesRepo,
                            admin: persona,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assignment_turned_in),
                    label: const Text('Ver informes de retiro'),
                  ),
                );
              }),
              const SizedBox(height: 12),


              // ver feed con filtros
              SizedBox(
                width: 320,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicacionesFeedScreen(
                          publicationsRepository: _pubRepo, // reutiliza el repo
                        ),
                      ),
                    );
                    if (mounted) _loadPublicaciones(); // recarga al volver
                  },
                  icon: const Icon(Icons.dynamic_feed),
                  label: const Text('Ver feed con filtros'),
                ),
              ),

              const SizedBox(height: 24),
              if (_ultimaRuta != null) ...[
                const Text('Archivo de perfiles:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_ultimaRuta!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
