import 'package:flutter/material.dart';
import 'package:objetos_perdidos/Datos/repositories/subastas_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart' show ProfileScope;
import 'package:objetos_perdidos/perfil.dart' show Perfil;
import 'package:objetos_perdidos/objeto_perdido.dart' show ObjetoPerdido;
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart' show InformesRepository;
import 'package:objetos_perdidos/informe.dart' show Informe, InformeEntrega;

class CrearSubastaScreen extends StatefulWidget {
  final SubastasRepository? subastaRepository;
  final ProfilesRepository? profilesRepository;

  CrearSubastaScreen({
    super.key,
    SubastasRepository? subastaRepository,
    ProfilesRepository? profilesRepository,
  })  : subastaRepository = subastaRepository ?? SubastasRepository(),
        profilesRepository = profilesRepository ?? ProfilesRepository();

  @override
  State<CrearSubastaScreen> createState() => _CrearSubastaScreenState();
}

class _Elegible {
  final ObjetoPerdido obj;
  final String titulo;
  final DateTime informeFecha;

  _Elegible(this.obj, this.titulo, this.informeFecha);
}

class _CrearSubastaScreenState extends State<CrearSubastaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minPujaCtrl = TextEditingController();

  _Elegible? _objetoSeleccionado;
  List<_Elegible> _objetosElegibles = <_Elegible>[];
  DateTime? _fechaFin;
  bool _creando = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarObjetos();
  }

  Future<void> _cargarObjetos() async {
    setState(() => _cargando = true);
    try {
      final profilesRepo = widget.profilesRepository!;
      final profileRecords = await profilesRepo.listProfiles();

      final ahora = DateTime.now();
      final hace6Meses = DateTime(ahora.year, ahora.month - 6, ahora.day);

      // Resolver perfiles por nombre para pasar al InformesRepository
      final resolverMap = <String, Perfil>{};
      for (final r in profileRecords) {
        final p = r.toPersona();
        if (p is Perfil) resolverMap[r.nombre] = p;
      }

      final informesRepo = InformesRepository();
      final informes = await informesRepo.listInformes((usuario) {
        return resolverMap[usuario] ?? Perfil(usuario, 0, <ObjetoPerdido>[]);
      });

      // Recolectar objetos desde informes de entrega antiguas (>6 meses)
      final objetosElegibles = <_Elegible>[];
      final seen = <String>{};
      for (final informe in informes) {
        if (informe is InformeEntrega && !informe.estaRetirado) {
          if (informe.fechaCreacion.isBefore(hace6Meses)) {
            final obj = informe.objeto;
            if (!seen.contains(obj.id)) {
              seen.add(obj.id);
              objetosElegibles.add(_Elegible(obj, informe.titulo, informe.fechaCreacion));
            }
          }
        }
      }

      // Ordenar por fecha ascendente (más antiguos primero)
      objetosElegibles.sort((a, b) => a.informeFecha.compareTo(b.informeFecha));
      
      if (!mounted) return;
      setState(() {
        _objetosElegibles = objetosElegibles;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar objetos: $e')),
      );
    }
  }

  @override
  void dispose() {
    _minPujaCtrl.dispose();
    super.dispose();
  }

  String _formatFecha(DateTime fecha) {
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$m-$d';
  }

  String _diasPerdido(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha).inDays;
    final meses = (diferencia / 30).floor();
    return meses >= 1 ? '$meses meses' : '$diferencia días';
  }

  Future<void> _pickFechaFin() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _fechaFin = picked);
    }
  }

  Future<void> _crearSubasta() async {
    if (_objetoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un objeto')),
      );
      return;
    }

    final valido = _formKey.currentState?.validate() ?? false;
    if (!valido) return;

    if (_fechaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una fecha de finalización')),
      );
      return;
    }

    final persona = ProfileScope.of(context).current;
    if (persona == null || persona is! Perfil || !persona.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo administradores pueden crear subastas')),
      );
      return;
    }

    setState(() => _creando = true);
    try {
      final minPuja = double.tryParse(_minPujaCtrl.text.trim()) ?? 0;
      if (minPuja <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La puja mínima debe ser mayor a 0')),
        );
        return;
      }

      await widget.subastaRepository!.crearSubasta(
        itemId: _objetoSeleccionado!.obj.id,
        minPuj: minPuja,
        fechaFin: _fechaFin,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subasta creada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Retornar con true para indicar que se creó exitosamente
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear subasta: $e')),
      );
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Subasta'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nueva Subasta',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Selecciona un objeto perdido que lleve más de 6 meses',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Lista de objetos elegibles
                    if (_objetosElegibles.isEmpty)
                      Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.info, color: Colors.orange[700], size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No hay objetos elegibles',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Todos los objetos perdidos deben tener más de 6 meses de antigüedad.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.orange[800],
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Objetos Disponibles (${_objetosElegibles.length})',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _objetosElegibles.length,
                            itemBuilder: (context, index) {
                              final wrapper = _objetosElegibles[index];
                              final obj = wrapper.obj;
                              final isSelected = _objetoSeleccionado?.obj.id == obj.id;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Colors.white,
                                child: ListTile(
                                  selected: isSelected,
                                  onTap: () {
                                    setState(() => _objetoSeleccionado = wrapper);
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                  title: Text(
                                    wrapper.titulo,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                  subtitle: Text(
                                    obj.descripcion.texto,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _diasPerdido(wrapper.informeFecha),
                                        style:
                                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange[700],
                                                ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatFecha(wrapper.informeFecha),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[500],
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // Puja Mínima
                    TextFormField(
                      controller: _minPujaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Puja Mínima (puntos)',
                        hintText: 'ej: 50',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.star),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'La puja mínima es obligatoria';
                        }
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) {
                          return 'Debe ser un número mayor a 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fecha de Finalización
                    GestureDetector(
                      onTap: _pickFechaFin,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha de Finalización',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _fechaFin == null
                                      ? 'No seleccionada'
                                      : _formatFecha(_fechaFin!),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Resumen
                    if (_objetoSeleccionado != null)
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Resumen',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Objeto: ${_objetoSeleccionado!.titulo}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Puja Mínima: ${_minPujaCtrl.text.trim().isEmpty ? '(no especificada)' : '${_minPujaCtrl.text.trim()} pts'}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Finaliza: ${_fechaFin == null ? '(no especificada)' : _formatFecha(_fechaFin!)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Botón de crear
                    FilledButton.icon(
                      onPressed: _creando ? null : _crearSubasta,
                      icon: _creando
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : const Icon(Icons.gavel),
                      label: Text(_creando ? 'Creando...' : 'Crear Subasta'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
