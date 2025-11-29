import 'dart:io';
import 'package:flutter/material.dart';
import '../Datos/repositories/informes_repository.dart';
import '../perfil.dart';
import '../ui/profile_selector.dart';

class _RetiroItem {
  final String id;
  final String objetoId;
  final String usuarioId;
  final String titulo;
  final String notaTexto;
  final DateTime notaHora;
  final String retiradoPor;

  _RetiroItem({
    required this.id,
    required this.objetoId,
    required this.usuarioId,
    required this.titulo,
    required this.notaTexto,
    required this.notaHora,
    required this.retiradoPor,
  });
}

class ListarInformesRetiroScreen extends StatefulWidget {
  final InformesRepository repository;
  final Perfil admin;

  const ListarInformesRetiroScreen({
    super.key,
    required this.repository,
    required this.admin,
  });

  @override
  State<ListarInformesRetiroScreen> createState() =>
      _ListarInformesRetiroScreenState();
}

class _ListarInformesRetiroScreenState
    extends State<ListarInformesRetiroScreen> {
  List<_RetiroItem> _retiros = [];
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
      // Lee los informes de retiro desde el sistema de archivos
      final basePath = await widget.repository.debugDirPath();
      final sep = Platform.pathSeparator;
      final retiroDir = Directory('$basePath$sep${'retiro'}');

      if (!await retiroDir.exists()) {
        setState(() {
          _retiros = [];
        });
      } else {
        final files = await retiroDir.list().toList();
        final lista = <_RetiroItem>[];

        for (final f in files) {
          if (f is! File || !f.path.toLowerCase().endsWith('.txt')) continue;

          try {
            final lines = await f.readAsLines();

            String? id;
            String? objetoId;
            String? usuarioId;
            String? titulo;
            String? notaTexto;
            DateTime? notaHora;
            String? retiradoPor;

            for (final line in lines) {
              final idx = line.indexOf(':');
              if (idx == -1) continue;
              final key = line.substring(0, idx).trim();
              final value = line.substring(idx + 1).trim();

              switch (key) {
                case 'ID':
                  id = value;
                  break;
                case 'ObjetoId':
                  objetoId = value;
                  break;
                case 'UsuarioId':
                  usuarioId = value;
                  break;
                case 'Titulo':
                  titulo = value;
                  break;
                case 'NotaTexto':
                  notaTexto = value;
                  break;
                case 'NotaHora':
                  notaHora = DateTime.tryParse(value);
                  break;
                case 'RetiradoPor':
                  retiradoPor = value;
                  break;
              }
            }

            if (id != null &&
                objetoId != null &&
                usuarioId != null &&
                titulo != null &&
                notaTexto != null &&
                notaHora != null &&
                retiradoPor != null) {
              lista.add(
                _RetiroItem(
                  id: id!,
                  objetoId: objetoId!,
                  usuarioId: usuarioId!,
                  titulo: titulo!,
                  notaTexto: notaTexto!,
                  notaHora: notaHora!,
                  retiradoPor: retiradoPor!,
                ),
              );
            }
          } catch (_) {
          }
        }

        lista.sort((a, b) => b.notaHora.compareTo(a.notaHora));

        if (!mounted) return;
        setState(() {
          _retiros = lista;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error cargando informes de retiro: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informes de retiro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargar,
          ),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Volver al inicio',
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
              : _retiros.isEmpty
                  ? const Center(child: Text('No hay informes de retiro'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _retiros.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final r = _retiros[i];
                        final fechaStr = r.notaHora
                            .toLocal()
                            .toString()
                            .split(' ')
                            .first;
                        return ListTile(
                          title: Text(r.titulo),
                          subtitle: Text(
                            'Fecha: $fechaStr\n'
                            'Retirado por: ${r.retiradoPor}\n'
                            'ObjetoId: ${r.objetoId}\n'
                            'Admin (UsuarioId): ${r.usuarioId}',
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
    );
  }
}
