import 'package:flutter/material.dart';
import '../Datos/repositories/informes_repository.dart';
import '../informe.dart';
import '../perfil.dart';
import 'crear_informe_retiro_screen.dart';
import '../ui/profile_selector.dart';

class ListarInformesScreen extends StatefulWidget {
  final InformesRepository repository;
  final Perfil admin;
  final bool modoRegistroRetiro;
  const ListarInformesScreen({
    super.key,
    required this.repository,
    required this.admin,
    this.modoRegistroRetiro = false,
  });

  @override
  State<ListarInformesScreen> createState() => _ListarInformesScreenState();
}

class _ListarInformesScreenState extends State<ListarInformesScreen> {
  List<Informe> _informes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final informes = await widget.repository.listInformes((usuario) {
        // Reconstruye un perfil simple; marca admin si coincide con admin actual
        return Perfil(
          usuario,
          0,
          const [],
          isAdmin: usuario == widget.admin.usuario,
        );
      });
      if (!mounted) return;
      setState(() {
        _informes = informes
            .where((i) => i.tipo == 'entrega')
            .toList()
          ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error cargando informes: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminar(Informe informe) async {
    final ok = await widget.repository.deleteInforme(informe.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Informe eliminado: ${informe.titulo}')),
      );
      await _cargar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar informe')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modoRegistroRetiro ? 'Registrar retiro' : 'Informes de entrega'),
        actions: [
          IconButton(
            tooltip: 'Ruta carpeta informes',
            icon: const Icon(Icons.folder),
            onPressed: () async {
              final path = await widget.repository.debugDirPath();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Carpeta informes: $path')),
              );
            },
          ),
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
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
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _informes.isEmpty
                  ? Center(
                      child: Text(
                        widget.modoRegistroRetiro
                            ? 'No hay informes de entrega disponibles para registrar retiro'
                            : 'No hay informes de entrega',
                      ),
                    )
                  : Column(
                      children: [
                        if (widget.modoRegistroRetiro)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Text(
                              'Selecciona una entrega y pulsa el icono de check para registrar el retiro.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _informes.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (_, i) {
                              final inf = _informes[i];
                              final fechaStr = inf.fechaCreacion
                                  .toLocal()
                                  .toString()
                                  .split(' ')
                                  .first;
                              final esEntrega = inf is InformeEntrega;
                              final entrega = esEntrega
                                  ? inf.entregadoPorUsuario
                                  : '';
                              final retirado = esEntrega && inf.estaRetirado;
                              final retiradoFecha = (esEntrega
                                      ? inf.retiradoFecha
                                      : null)
                                  ?.toLocal()
                                  .toString()
                                  .split(' ')
                                  .first;

                              return ListTile(
                                title: Text(inf.titulo),
                                subtitle: Text(
                                  'Categoría: ${inf.objeto.categoria}\n'
                                  'Fecha: $fechaStr\n'
                                  'Entregado por: $entrega\n'
                                  'Estado: ${retirado ? 'Retirado' : 'Pendiente'}'
                                  '${retirado && inf is InformeEntrega && inf.retiradoPor != null ? ' por ${inf.retiradoPor}' : ''}'
                                  '${retiradoFecha != null ? ' el $retiradoFecha' : ''}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botón para registrar retiro
                                    IconButton(
                                      icon: const Icon(Icons.assignment_turned_in),
                                      tooltip: retirado ? 'Ya retirado' : 'Registrar retiro',
                                      onPressed: retirado
                                          ? null
                                          : () async {
                                              final creado =
                                                  await Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => CrearInformeRetiroScreen(
                                                    admin: widget.admin,
                                                    objeto: inf.objeto,
                                                  ),
                                                ),
                                              );
                                              if (creado == true && mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Informe de retiro creado para ${inf.objeto.categoria}',
                                                    ),
                                                  ),
                                                );
                                                await _cargar();
                                              }
                                            },
                                    ),
                                    if (!widget.modoRegistroRetiro)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Eliminar informe',
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Eliminar informe'),
                                              content: const Text(
                                                  '¿Confirmas eliminar este informe?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await _eliminar(inf);
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
