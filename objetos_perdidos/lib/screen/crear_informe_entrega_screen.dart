import 'package:flutter/material.dart';
import '../perfil.dart';
import '../Datos/repositories/informes_repository.dart';
import '../informe.dart';
import '../Datos/categorias.dart';

class CrearInformeEntregaScreen extends StatefulWidget {
  final Perfil admin;
  final InformesRepository repository;

  const CrearInformeEntregaScreen({super.key, required this.admin, required this.repository});

  @override
  State<CrearInformeEntregaScreen> createState() => _CrearInformeEntregaScreenState();
}

class _CrearInformeEntregaScreenState extends State<CrearInformeEntregaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  String? _categoriaSeleccionada;
  final _descripcionCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _entregadoPorCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _lugarCtrl.dispose();
    _entregadoPorCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!widget.admin.isAdmin) {
      setState(() => _error = 'Solo un administrador puede crear informes');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final Informe informe = await widget.repository.createInformeEntrega(
        admin: widget.admin,
        titulo: _tituloCtrl.text.trim(),
        categoria: _categoriaSeleccionada ?? kCategorias.first,
        descripcion: _descripcionCtrl.text.trim(),
        lugar: _lugarCtrl.text.trim(),
        entregadoPorUsuario: _entregadoPorCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(informe);
    } catch (e) {
      setState(() => _error = 'Error guardando informe: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informe de Entrega')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Administrador: ${widget.admin.usuario}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Título requerido' : null,
              ),
              DropdownButtonFormField<String>(
                value: _categoriaSeleccionada,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: kCategorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _categoriaSeleccionada = v),
                validator: (v) => v == null ? 'Categoría requerida' : null,
              ),
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Descripción requerida' : null,
              ),
              TextFormField(
                controller: _lugarCtrl,
                decoration: const InputDecoration(labelText: 'Lugar donde se encontró'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Lugar requerido' : null,
              ),
              TextFormField(
                controller: _entregadoPorCtrl,
                decoration: const InputDecoration(labelText: 'Usuario que entrega'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Usuario requerido' : null,
              ),
              const SizedBox(height: 20),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _saving ? null : _guardar,
                child: _saving ? const CircularProgressIndicator() : const Text('Crear Informe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}