import 'package:flutter/material.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';

class CrearPerfilScreen extends StatefulWidget {
  final ProfilesRepository repo;

  // ❌ No uses const aquí porque instanciamos ProfilesRepository() (no es const)
  CrearPerfilScreen({Key? key, ProfilesRepository? repository})
      : repo = repository ?? ProfilesRepository(),
        super(key: key);

  @override
  State<CrearPerfilScreen> createState() => _CrearPerfilScreenState();
}

class _CrearPerfilScreenState extends State<CrearPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  Tipo? _tipo;
  bool _guardando = false;

  bool get _formValido =>
      _nombreCtrl.text.trim().isNotEmpty && _tipo != null && !_guardando;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valido = _formKey.currentState?.validate() ?? false;
    if (!valido) return;

    setState(() => _guardando = true);
    try {
      await widget.repo.createProfile(
        nombre: _nombreCtrl.text.trim(),
        tipo: _tipo!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil creado correctamente.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardarHabilitado = _formValido;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear perfil')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: María',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'El nombre es obligatorio';
                if (s.length < 2) return 'Debe tener al menos 2 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Tipo>(
              value: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                hintText: 'Selecciona el tipo de usuario',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: Tipo.perfil, child: Text('Común')),
                DropdownMenuItem(value: Tipo.admin, child: Text('Administrador')),
              ],
              onChanged: (value) => setState(() => _tipo = value),
              validator: (v) => v == null ? 'Debes elegir un tipo' : null,
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
                label: Text(_guardando ? 'Guardando...' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
