import 'package:flutter/material.dart';

import 'package:objetos_perdidos/objeto_perdido.dart';
import 'package:objetos_perdidos/perfil.dart';
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart';

class CrearInformeRetiroScreen extends StatefulWidget {
  final InformesRepository repo;
  final Perfil admin;
  final ObjetoPerdido objeto;

  CrearInformeRetiroScreen({
    super.key,
    required this.admin,
    required this.objeto,
    InformesRepository? repository,
  }) : repo = repository ?? InformesRepository();

  @override
  State<CrearInformeRetiroScreen> createState() =>
      _CrearInformeRetiroScreenState();
}

class _CrearInformeRetiroScreenState extends State<CrearInformeRetiroScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tituloCtrl = TextEditingController();
  final _retiradoPorCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  bool _guardando = false;

  bool get _formValido =>
      _tituloCtrl.text.trim().isNotEmpty &&
      _notaCtrl.text.trim().isNotEmpty &&
      _retiradoPorCtrl.text.trim().isNotEmpty &&
      !_guardando;

  @override
  void initState() {
    super.initState();
    _tituloCtrl.text = 'Retiro de ${widget.objeto.categoria}';
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _retiradoPorCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valido = _formKey.currentState?.validate() ?? false;
    if (!valido) return;

    setState(() => _guardando = true);

    try {
      final titulo = _tituloCtrl.text.trim();
      final notaTexto = _notaCtrl.text.trim();
      final retiradoPor = _retiradoPorCtrl.text.trim();

      // Crea el InformeRetiro + .txt
      await widget.repo.createInformeRetiro(
        admin: widget.admin,
        objeto: widget.objeto,
        titulo: titulo,
        notaTexto: notaTexto,
        retiradoPorUsuario: retiradoPor,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe de retiro creado correctamente.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar informe: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardarHabilitado = _formValido;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar retiro de objeto'),
        actions: [
          IconButton(
            tooltip: 'Volver al inicio',
            icon: const Icon(Icons.home),
            onPressed: () {
              ProfileScope.of(context).clear();
              Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info rápida del objeto
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                title: Text(widget.objeto.categoria),
                subtitle: Text(
                  'Lugar: ${widget.objeto.lugar}\n'
                  'Fecha: ${widget.objeto.fecha}',
                ),
              ),
            ),
            TextFormField(
              controller: _tituloCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Título del informe',
                hintText: 'Ej: Retiro de mochila negra',
                border: OutlineInputBorder(),
              ),
              maxLength: 80,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'El título es obligatorio';
                if (s.length < 4) {
                  return 'Debe tener al menos 4 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _retiradoPorCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Retirado por',
                hintText: 'Nombre del dueño que retira el objeto',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) {
                  return 'Debes indicar quién retira el objeto';
                }
                if (s.length < 2) {
                  return 'Debe tener al menos 2 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notaCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nota (obligatoria)',
                hintText:
                    'Ej: Se verificó identidad con carnet, se confirma que es el dueño...',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) {
                  return 'La nota es obligatoria';
                }
                if (s.length < 5) {
                  return 'La nota debe tener al menos 5 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: guardarHabilitado ? _guardar : null,
                icon: _guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label:
                    Text(_guardando ? 'Guardando...' : 'Guardar informe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
