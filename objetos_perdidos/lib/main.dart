import 'package:flutter/material.dart';
import 'package:objetos_perdidos/screen/crear_perfil_screen.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/screen/crear_publicacion_screen.dart';
import 'package:objetos_perdidos/Datos/repositories/publications_repository.dart';
import 'package:objetos_perdidos/Datos/models/publication_record.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart';
import 'package:objetos_perdidos/ui/publicaciones_feed.dart';
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart';
import 'package:objetos_perdidos/screen/admin_actions_screen.dart';
import 'package:objetos_perdidos/perfil.dart';
import 'package:objetos_perdidos/informe.dart';
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
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
          scaffoldBackgroundColor: const Color(0xFFF4F6F8),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
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
  List<Informe> _informesAdmin = [];
  bool _cargandoInformesAdmin = false;
  String? _ultimaPersonaId;

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

  Future<void> _loadInformesAdmin(Perfil admin) async {
    setState(() {
      _cargandoInformesAdmin = true;
    });
    try {
      final informes = await _informesRepo.listInformes(
        (usuario) => Perfil(
          usuario,
          0,
          const [],
          isAdmin: usuario == admin.usuario,
        ),
      );
      if (!mounted) return;
      setState(() {
        _informesAdmin = informes
            .where((i) => i.admin.usuario == admin.usuario)
            .toList()
          ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _informesAdmin = []);
    } finally {
      if (mounted) {
        setState(() => _cargandoInformesAdmin = false);
      }
    }
  }

  void _handlePersonaChange(Perfil? persona) {
    final nuevoId = persona?.usuario;
    if (_ultimaPersonaId == nuevoId) return;
    _ultimaPersonaId = nuevoId;

    if (persona != null && persona.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadInformesAdmin(persona);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _informesAdmin = []);
        }
      });
    }
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
    final esAdmin = personaActual is Perfil && personaActual.isAdmin;
    final esPerfilComun = personaActual is Perfil && !personaActual.isAdmin;
    final mostrarPuntos = esPerfilComun;
    final puntosActual = mostrarPuntos ? (personaActual as Perfil).puntos : 0;
    final totalPublicaciones = _publicaciones.length;
    final perfilSeleccionado = personaActual is Perfil ? personaActual : null;
    _handlePersonaChange(perfilSeleccionado);
    final misPublicaciones = perfilSeleccionado == null
        ? <PublicationRecord>[]
        : _publicaciones
            .where((p) =>
                p.autorId == perfilSeleccionado.id ||
                p.autorNombre == perfilSeleccionado.usuario)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetos Perdidos'),
        actions: [
          IconButton(
            tooltip: 'Volver al inicio',
            icon: const Icon(Icons.home),
            onPressed: () {
              perfilCtrl.clear();
              Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
            },
          ),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE6F2FF), Color(0xFFF9FBFD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWelcomeCard(
                  context,
                  usuario: usuario,
                  esAdmin: esAdmin,
                  puntos: puntosActual,
                  totalPublicaciones: totalPublicaciones,
                ),
                const SizedBox(height: 16),
                _buildPerfilSection(
                  context,
                  perfilSeleccionado,
                  misPublicaciones,
                  mostrarPuntos ? puntosActual : null,
                ),
                const SizedBox(height: 12),
                _buildPublicacionesCard(
                  context,
                  perfilSeleccionado,
                  misPublicaciones,
                  esPerfilComun: esPerfilComun,
                ),
                const SizedBox(height: 16),
                if (_ultimaRuta != null) _buildArchivoInfo(context, _ultimaRuta!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(
    BuildContext context, {
    required String usuario,
    required bool esAdmin,
    required int puntos,
    required int totalPublicaciones,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final sinPerfil = usuario == 'Sin perfil';
    final esUsuarioComun = !esAdmin && !sinPerfil;
    final roleText = esAdmin
        ? 'Administrador'
        : sinPerfil
            ? 'Sin perfil seleccionado'
            : 'Usuario';
    final saludo = sinPerfil ? 'Bienvenido' : 'Hola, $usuario';
    final detalle = sinPerfil
        ? 'Selecciona o crea un perfil para comenzar.'
        : esAdmin
            ? 'Gestiona objetos y retiros desde el panel admin.'
            : 'Explora, publica y gana puntos por ayudar.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    esAdmin ? Icons.shield_moon : Icons.person,
                    color: colorScheme.onPrimaryContainer,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saludo,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detalle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        esAdmin ? Icons.shield : Icons.person_outline,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text('Rol: $roleText'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Publicaciones registradas: $totalPublicaciones'),
                  if (esUsuarioComun) ...[
                    const SizedBox(height: 6),
                    Text('Tus puntos: $puntos'),
                  ],
                  if (sinPerfil) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Usa la sección de perfil de abajo para comenzar.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerfilSection(
    BuildContext context,
    Perfil? perfil,
    List<PublicationRecord> misPublicaciones,
    int? puntos,
  ) {
    if (perfil == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu perfil',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Configura o selecciona un perfil para personalizar la experiencia.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: FilledButton.icon(
                      onPressed: _abrirCrearPerfil,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Crear perfil'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileSelectorPage()),
                        );
                      },
                      icon: const Icon(Icons.switch_account),
                      label: const Text('Seleccionar perfil'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (perfil.isAdmin) {
      return _buildAdminCard(context, perfil);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textoPuntos = puntos != null ? '$puntos pts' : 'Sin puntos';
    final mis = misPublicaciones.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi perfil',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(perfil.usuario, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const Spacer(),
                Chip(
                  avatar: const Icon(Icons.star, size: 18),
                  label: Text(textoPuntos),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tus publicaciones',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (mis.isEmpty)
              const Text('Aún no has publicado objetos.', style: TextStyle(color: Colors.grey))
            else
              ...mis.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: const Icon(Icons.inventory_2),
                  ),
                  title: Text(p.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${p.categoria} · ${p.lugar}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicacionesCard(
    BuildContext context,
    Perfil? perfil,
    List<PublicationRecord> misPublicaciones, {
    required bool esPerfilComun,
  }) {
    final totalPropias = perfil == null ? 0 : misPublicaciones.length;
    final acciones = <Widget>[];
    if (esPerfilComun) {
      acciones.add(
        FilledButton.icon(
          onPressed: _abrirCrearPublicacion,
          icon: const Icon(Icons.publish),
          label: const Text('Crear publicación'),
        ),
      );
    }
    acciones.add(
      FilledButton.tonalIcon(
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
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Publicaciones',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              perfil == null
                  ? 'Navega por el feed o crea un perfil para publicar.'
                  : esPerfilComun
                      ? 'Publica objetos encontrados y revisa tus avisos.'
                      : 'Explora el feed para verificar objetos reportados.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[700]),
            ),
            if (perfil != null) ...[
              const SizedBox(height: 6),
              Text(
                esPerfilComun
                    ? 'Tienes $totalPropias publicaciones creadas.'
                    : 'Como administrador, puedes revisar todas las publicaciones.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: acciones
                  .map((a) => SizedBox(
                        width: 220,
                        child: a,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, Perfil admin) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_mode, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Panel administrativo',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Crea y revisa informes desde un panel separado para mantener todo ordenado.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminActionsScreen(
                        admin: admin,
                        informesRepo: _informesRepo,
                      ),
                    ),
                  );
                  if (mounted) _loadPublicaciones();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: colorScheme.primary,
                ),
                icon: const Icon(Icons.dashboard_customize),
                label: const Text('Abrir panel'),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListarInformesScreen(
                        repository: _informesRepo,
                        admin: admin,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment),
                label: const Text('Ver informes de entrega'),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListarInformesRetiroScreen(
                        repository: _informesRepo,
                        admin: admin,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text('Ver informes de retiro'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Informes creados por ti',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_cargandoInformesAdmin)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white24,
              ),
            )
          else if (_informesAdmin.isEmpty)
            Text(
              'Aún no registras informes.',
              style: TextStyle(color: Colors.white.withOpacity(0.85)),
            )
          else
            ..._informesAdmin.take(3).map(
              (inf) {
                final fechaStr = inf.fechaCreacion
                    .toLocal()
                    .toString()
                    .split(' ')
                    .first;
                final estado = (inf is InformeEntrega && inf.estaRetirado)
                    ? 'Retirado'
                    : 'Abierto';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(
                      inf.tipo == 'entrega'
                          ? Icons.assignment
                          : Icons.assignment_turned_in,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    inf.titulo,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$fechaStr · $estado',
                    style: TextStyle(color: Colors.white.withOpacity(0.85)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildArchivoInfo(BuildContext context, String path) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_open),
        title: const Text('Archivo de perfiles'),
        subtitle: Text(path),
      ),
    );
  }
}
