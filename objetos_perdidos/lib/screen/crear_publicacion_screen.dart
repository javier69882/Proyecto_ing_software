import 'package:flutter/material.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart' show ProfileScope;
import 'package:objetos_perdidos/Datos/repositories/publications_repository.dart';

// widget para crear el post de un objeto perdido
class CrearPublicacionScreen extends StatefulWidget {
  final ProfilesRepository profilesRepo;
  final PublicationsRepository publicationsRepo;

  CrearPublicacionScreen({
    super.key,
    ProfilesRepository? profilesRepository,
    PublicationsRepository? publicationsRepository,
  })  : profilesRepo = profilesRepository ?? ProfilesRepository(),
        publicationsRepo = publicationsRepository ?? PublicationsRepository();

  @override
  State<CrearPublicacionScreen> createState() => _CrearPublicacionScreenState();
}

// estado del widget
class _CrearPublicacionScreenState extends State<CrearPublicacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  String? _categoria;
  DateTime? _fecha;
  bool _guardando = false;

  final _categorias = ['Electrónica', 'Ropa', 'Documentos', 'Varios'];

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _lugarCtrl.dispose();
    super.dispose();
  }

  // selecciona la fecha (hecho con ia, no se como funciona)
  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _fecha = picked);
  }


  // guarda el post
  Future<void> _publicar() async {
    final valido = _formKey.currentState?.validate() ?? false;
    if (!valido) return;

    setState(() => _guardando = true);
    try {
      final persona = ProfileScope.of(context).current;
      if (persona == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay perfil seleccionado. Selecciona un perfil primero.')),
        );
        return;
      }

      // Usar el nombre de la persona como autor; para id mantenemos una convención
      // sencilla: si es Perfil/Admin sin id persistido, guardamos nombre como id.
      final autorId = persona.usuario; // alternativa simple a usar repo.listProfiles()
      final autorNombre = persona.usuario;

      await widget.publicationsRepo.createPublication(
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        categoria: _categoria ?? 'Varios',
        fecha: _fecha ?? DateTime.now(),
        lugar: _lugarCtrl.text.trim(),
        autorId: autorId,
        autorNombre: autorNombre,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación creada correctamente.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear publicación: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = !_guardando;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear publicación')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Título obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Descripción obligatoria' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
              items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _categoria = v),
              validator: (v) => v == null ? 'Elige una categoría' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lugarCtrl,
              decoration: const InputDecoration(labelText: 'Lugar aproximado', border: OutlineInputBorder()),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Lugar obligatorio' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_fecha == null ? 'Fecha (no seleccionada)' : 'Fecha: ${_fecha!.toLocal().toString().split(' ').first}'),
              trailing: TextButton(onPressed: _pickFecha, child: const Text('Seleccionar')),
            ),
            if (_fecha == null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Debes seleccionar una fecha', style: TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: habilitado && _fecha != null ? _publicar : null,
                icon: _guardando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish),
                label: Text(_guardando ? 'Publicando...' : 'Publicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
