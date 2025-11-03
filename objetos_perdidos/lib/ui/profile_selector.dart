import 'package:flutter/material.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/persona.dart' show Persona;

/// Controlador de sesión de perfil
class ProfileController extends ChangeNotifier {
  final ProfilesRepository repo;
  Persona? _current;
  List<ProfileRecord> _records = [];
  bool _loading = false;
  Object? _error;

  ProfileController({required this.repo});

  Persona? get current => _current;
  List<ProfileRecord> get records => _records;
  bool get loading => _loading;
  Object? get error => _error;

  /// Carga y recarga la lista de perfiles desde el repositorio
  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await repo.listProfiles();
    } catch (e) {
      _records = [];
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Selecciona un perfil y lo convierte a clase de dominio
  Future<void> select(ProfileRecord record) async {
    _current = record.toPersona();
    notifyListeners();
  }

  /// Limpia el perfil actual (logout) y notifica a los listeners.
  void clear() {
    _current = null;
    notifyListeners();
  }
}

/// Scope que expone el ProfileController en el árbol
class ProfileScope extends InheritedNotifier<ProfileController> {
  const ProfileScope({
    super.key,
    required ProfileController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ProfileController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ProfileScope>();
    assert(scope != null, 'ProfileScope.of() llamado fuera del scope');
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(ProfileScope oldWidget) =>
      oldWidget.notifier != notifier;
}

// lista perfiles y permite elegir uno con tap
class ProfileSelectorPage extends StatefulWidget {
  const ProfileSelectorPage({super.key});

  @override
  State<ProfileSelectorPage> createState() => _ProfileSelectorPageState();
}

class _ProfileSelectorPageState extends State<ProfileSelectorPage> {
  @override
  void initState() {
    super.initState();
    // Carga inicial de perfiles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProfileScope.of(context).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ProfileScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar perfil'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error != null) {
            return Center(
              child: Text('Error: ${controller.error}'),
            );
          }
          final items = controller.records;
          if (items.isEmpty) {
            return const Center(
              child: Text('No hay perfiles guardados'),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = items[i];
              final tipoStr = r.tipo == Tipo.admin ? 'Admin' : 'Perfil';
              return ListTile(
                title: Text(r.nombre),
                subtitle: Text(tipoStr),
                leading: Icon(
                  r.tipo == Tipo.admin
                      ? Icons.verified_user
                      : Icons.person_outline,
                ),
                onTap: () async {
                  await controller.select(r);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Navega a la pantalla de selector y muestra el usuario actual.
class ProfileSwitchAction extends StatelessWidget {
  const ProfileSwitchAction({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ProfileScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final currentName = controller.current?.usuario ?? 'Sin perfil';
        return IconButton(
          tooltip: 'Cambiar de perfil ($currentName)',
          icon: const Icon(Icons.switch_account),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileSelectorPage()),
            );
          },
        );
      },
    );
  }
}