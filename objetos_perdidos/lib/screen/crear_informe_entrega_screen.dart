import 'package:flutter/material.dart';
import '../perfil.dart';
import '../Datos/repositories/informes_repository.dart';
import '../informe.dart';
import '../Datos/categorias.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart';

class CrearInformeEntregaScreen extends StatefulWidget {
  final InformesRepository repo;
  final Perfil admin;
  final ProfilesRepository profilesRepo;

  CrearInformeEntregaScreen({
    super.key,
    required this.admin,
    InformesRepository? repository,
    ProfilesRepository? profilesRepository,
  })  : repo = repository ?? InformesRepository(),
        profilesRepo = profilesRepository ?? ProfilesRepository();

  @override
  State<CrearInformeEntregaScreen> createState() => _CrearInformeEntregaScreenState();
}

class _CrearInformeEntregaScreenState extends State<CrearInformeEntregaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  String? _categoriaSeleccionada;
  final _descripcionCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  String? _selectedEntregadoPor;
  bool _saving = false;
  String? _error;

  List<ProfileRecord> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final list = await widget.profilesRepo.listProfiles();
      if (!mounted) return;
      setState(() {
        // sólo perfiles comunes
        _profiles = list.where((p) => p.tipo == Tipo.perfil).toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _lugarCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!widget.admin.isAdmin) {
      setState(() => _error = 'Solo un administrador puede crear informes');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEntregadoPor == null || _selectedEntregadoPor!.isEmpty) {
      setState(() => _error = 'Debes seleccionar la persona que entregó el objeto');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final Informe informe = await widget.repo.createInformeEntrega(
        admin: widget.admin,
        titulo: _tituloCtrl.text.trim(),
        categoria: _categoriaSeleccionada ?? kCategorias.first,
        descripcion: _descripcionCtrl.text.trim(),
        lugar: _lugarCtrl.text.trim(),
        entregadoPorUsuario: _selectedEntregadoPor!,
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
      appBar: AppBar(
        title: const Text('Informe de Entrega'),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedEntregadoPor,
                decoration: const InputDecoration(labelText: 'Persona que entregó (perfil)'),
                items: _profiles.map((p) => DropdownMenuItem(value: p.nombre, child: Text('${p.nombre} (${p.puntos} pts)'))).toList(),
                onChanged: (v) => setState(() => _selectedEntregadoPor = v),
                validator: (v) => (v == null || v.isEmpty) ? 'Selecciona una persona' : null,
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
