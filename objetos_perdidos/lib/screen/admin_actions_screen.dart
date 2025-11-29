import 'package:flutter/material.dart';
import '../Datos/repositories/informes_repository.dart';
import '../informe.dart';
import '../perfil.dart';
import 'crear_informe_entrega_screen.dart';
import 'listar_informes_screen.dart';
import 'listar_informes_retiro_screen.dart';
import '../ui/profile_selector.dart';

class AdminActionsScreen extends StatefulWidget {
  final Perfil admin;
  final InformesRepository informesRepo;

  const AdminActionsScreen({
    super.key,
    required this.admin,
    required this.informesRepo,
  });

  @override
  State<AdminActionsScreen> createState() => _AdminActionsScreenState();
}

class _AdminActionsScreenState extends State<AdminActionsScreen> {
  Future<void> _crearInformeEntrega() async {
    final informe = await Navigator.push<Informe>(
      context,
      MaterialPageRoute(
        builder: (_) => CrearInformeEntregaScreen(
          admin: widget.admin,
          repository: widget.informesRepo,
        ),
      ),
    );
    if (!mounted) return;
    if (informe != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Informe creado: ${informe.titulo}')),
      );
    }
  }

  Future<void> _verInformesEntrega() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListarInformesScreen(
          repository: widget.informesRepo,
          admin: widget.admin,
        ),
      ),
    );
  }

  Future<void> _registrarRetiro() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListarInformesScreen(
          repository: widget.informesRepo,
          admin: widget.admin,
          modoRegistroRetiro: true,
        ),
      ),
    );
  }

  Future<void> _verInformesRetiro() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListarInformesRetiroScreen(
          repository: widget.informesRepo,
          admin: widget.admin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel administrativo'),
        actions: [
          IconButton(
            tooltip: 'Volver al inicio',
            icon: const Icon(Icons.home),
            onPressed: () {
              ProfileScope.of(context).clear();
              Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F7FF), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.shield, color: colorScheme.onPrimaryContainer),
                    ),
                    title: Text(
                      'Hola, ${widget.admin.usuario}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Administra entregas y retiros desde un solo lugar.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acciones rápidas',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _adminActionButton(
                              context,
                              icon: Icons.assignment_add,
                              label: 'Crear informe de entrega',
                              description: 'Registra un objeto que llega a la oficina.',
                              onPressed: _crearInformeEntrega,
                              color: colorScheme.primaryContainer,
                              textColor: colorScheme.onPrimaryContainer,
                            ),
                            _adminActionButton(
                              context,
                              icon: Icons.assignment,
                              label: 'Ver informes de entrega',
                              description: 'Revisa y administra las entregas registradas.',
                              onPressed: _verInformesEntrega,
                              color: colorScheme.surfaceVariant,
                              textColor: colorScheme.onSurfaceVariant,
                            ),
                            _adminActionButton(
                              context,
                              icon: Icons.assignment_turned_in,
                              label: 'Registrar retiro',
                              description: 'Transforma una entrega en retiro para el dueño.',
                              onPressed: _registrarRetiro,
                              color: colorScheme.secondaryContainer,
                              textColor: colorScheme.onSecondaryContainer,
                            ),
                            _adminActionButton(
                              context,
                              icon: Icons.receipt_long,
                              label: 'Ver informes de retiro',
                              description: 'Consulta los retiros realizados y sus detalles.',
                              onPressed: _verInformesRetiro,
                              color: colorScheme.tertiaryContainer,
                              textColor: colorScheme.onTertiaryContainer,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _adminActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onPressed,
    Color? color,
    Color? textColor,
  }) {
    final foreground = textColor ?? Theme.of(context).colorScheme.onPrimaryContainer;
    return SizedBox(
      width: 260,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: foreground.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
