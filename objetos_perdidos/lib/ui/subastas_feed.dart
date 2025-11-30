import 'package:flutter/material.dart';
import 'package:objetos_perdidos/Datos/models/subasta.dart';
import 'package:objetos_perdidos/Datos/repositories/subastas_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/Datos/services/subasta_service.dart';
import 'package:objetos_perdidos/Datos/models/exceptions.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart' show ProfileScope;
import 'package:objetos_perdidos/perfil.dart' show Perfil;
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart' show InformesRepository;
import 'package:objetos_perdidos/informe.dart' show Informe, InformeEntrega;
import 'package:objetos_perdidos/objeto_perdido.dart' show ObjetoPerdido;

class SubastasFeedScreen extends StatefulWidget {
  final SubastasRepository? subastaRepository;
  final ProfilesRepository? profilesRepository;

  SubastasFeedScreen({
    super.key,
    SubastasRepository? subastaRepository,
    ProfilesRepository? profilesRepository,
  })  : subastaRepository = subastaRepository ?? SubastasRepository(),
        profilesRepository = profilesRepository ?? ProfilesRepository();

  @override
  State<SubastasFeedScreen> createState() => _SubastasFeedScreenState();
}

class _SubastasFeedScreenState extends State<SubastasFeedScreen> {
  bool _cargando = true;
  List<Subasta> _subastas = <Subasta>[];
  late SubastaService _service;
  final Map<String, String> _itemTitles = {};
  final Map<String, ObjetoPerdido> _itemObjetos = {};

  // UI State para cada subasta (almacenar cantidad pujeada en cada tarjeta)
  final Map<String, TextEditingController> _bidControllers =
      <String, TextEditingController>{};
  final Map<String, bool> _pujando = <String, bool>{};
  final Map<String, bool> _cerrando = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _service = SubastaService(
      subastaRepository: widget.subastaRepository!,
      profileRepository: widget.profilesRepository!,
    );
    _cargar();
  }

  @override
  void dispose() {
    for (final ctrl in _bidControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final subastas = await widget.subastaRepository!.getSubastasActivas();
      // Cargar títulos desde informes de entrega para mostrar nombre legible
      try {
        final informesRepo = InformesRepository();
        final informes = await informesRepo.listInformes((usuario) => Perfil(usuario, 0, <ObjetoPerdido>[]));
        _itemTitles.clear();
        _itemObjetos.clear();
        for (final inf in informes) {
          if (inf is InformeEntrega) {
            final objetoId = inf.objeto.id;
            if (objetoId.isNotEmpty && !_itemTitles.containsKey(objetoId)) {
              _itemTitles[objetoId] = inf.titulo;
            }
            if (objetoId.isNotEmpty && !_itemObjetos.containsKey(objetoId)) {
              _itemObjetos[objetoId] = inf.objeto;
            }
          }
        }
      } catch (_) {
        // ignore informe loading errors; we'll fallback to itemId
      }
      if (!mounted) return;
      setState(() {
        _subastas = subastas;
        final ids = subastas.map((s) => s.subastaId).toSet();
        final toRemove = _bidControllers.keys.where((k) => !ids.contains(k)).toList();
        for (final id in toRemove) {
          _bidControllers[id]?.dispose();
          _bidControllers.remove(id);
        }
        _pujando.removeWhere((k, _) => !ids.contains(k));
        _cerrando.removeWhere((k, _) => !ids.contains(k));
        // Inicializar controllers para cada subasta
        for (final s in subastas) {
          _bidControllers.putIfAbsent(s.subastaId, () => TextEditingController());
          _pujando.putIfAbsent(s.subastaId, () => false);
          _cerrando.putIfAbsent(s.subastaId, () => false);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando subastas: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _realizarPuja(Subasta subasta) async {
    final persona = ProfileScope.of(context).current;
    if (persona is! Perfil || persona.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes ser un usuario común para pujar')),
      );
      return;
    }

    final cantidadStr = _bidControllers[subasta.subastaId]?.text.trim() ?? '';
    if (cantidadStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad para pujar')),
      );
      return;
    }

    final cantidad = int.tryParse(cantidadStr);
    if (cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad debe ser un número positivo')),
      );
      return;
    }

    // Realizar puja
    setState(() {
      _pujando[subasta.subastaId] = true;
    });

    try {
      final resultado = await _service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: persona.usuario,
        cantidad: cantidad,
      );

      if (!mounted) return;

      // Limpiar el campo de entrada
      _bidControllers[subasta.subastaId]?.clear();

      // Mostrar éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Puja exitosa! Nueva cantidad: ${resultado.actualPuja.toInt()}'),
          backgroundColor: Colors.green[700],
        ),
      );

      // Recargar subastas
      await _cargar();

      // Notificar al ProfileScope que los puntos del usuario cambiaron
      if (mounted) {
        ProfileScope.of(context).refresh();
      }
    } on InsufficientFunds catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo insuficiente: necesitas ${e.requiredPoints} puntos, '
              'pero solo tienes ${e.availablePoints}'),
          backgroundColor: Colors.red[700],
        ),
      );
    } on InvalidBidAmount catch (e) {
      if (!mounted) return;
      final minMensaje = subasta.mayorPostorId == null || subasta.mayorPostorId!.isEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            minMensaje
                ? 'La puja debe ser al menos ${subasta.minPuja.toInt()} puntos'
                : 'La puja debe ser mayor a ${e.currentBidAmount.toInt()} puntos',
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    } on SubastaNotFound catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subasta no encontrada: ${e.subastaId}'),
          backgroundColor: Colors.red[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al realizar la puja: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pujando[subasta.subastaId] = false;
        });
      }
    }
  }

  Future<_CerrarSubastaData?> _mostrarDialogoCierre(Subasta subasta) async {
    final hasWinner = subasta.mayorPostorId != null && subasta.mayorPostorId!.isNotEmpty;
    final ganadorCtrl = TextEditingController(text: subasta.mayorPostorId ?? '');
    final notaCtrl = TextEditingController(
      text: 'Subasta ${subasta.subastaId} cerrada con puja de ${subasta.actualPuja.toInt()} pts.',
    );

    final result = await showDialog<_CerrarSubastaData>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar subasta antes de tiempo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasWinner
                  ? 'Ganador fijo: ${subasta.mayorPostorId}'
                  : 'No hay pujas registradas. Ingresa el ganador manualmente.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ganadorCtrl,
              readOnly: hasWinner,
              decoration: const InputDecoration(
                labelText: 'Usuario ganador',
                hintText: 'Nombre de perfil',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notaCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nota para el informe',
                hintText: 'Detalle la entrega al ganador',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.flag),
            onPressed: () {
              Navigator.pop(
                ctx,
                _CerrarSubastaData(
                  ganadorCtrl.text.trim(),
                  notaCtrl.text.trim(),
                ),
              );
            },
            label: const Text('Cerrar subasta'),
          ),
        ],
      ),
    );

    ganadorCtrl.dispose();
    notaCtrl.dispose();
    return result;
  }

  Future<void> _cerrarSubasta(Subasta subasta) async {
    final persona = ProfileScope.of(context).current;
    if (persona is! Perfil || !persona.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes ser administrador para cerrar subastas')),
      );
      return;
    }

    final objeto = _itemObjetos[subasta.itemId];
    if (objeto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el objeto asociado a la subasta')),
      );
      return;
    }

    final datos = await _mostrarDialogoCierre(subasta);
    if (datos == null) return;
    final ganadorId = (subasta.mayorPostorId?.isNotEmpty == true
            ? subasta.mayorPostorId
            : datos.ganadorId)
        ?.trim() ??
        '';

    setState(() {
      _cerrando[subasta.subastaId] = true;
    });

    final nota = datos.nota.isEmpty
        ? 'Subasta ${subasta.subastaId} cerrada de forma anticipada. '
            'Puja ganadora: ${subasta.actualPuja.toInt()} pts.'
        : datos.nota;

    try {
      final cerrada = await _service.cerrarSubastaManual(
        subastaId: subasta.subastaId,
        ganadorId: ganadorId.isEmpty ? null : ganadorId,
      );

      if (cerrada.ganadorId != null && cerrada.ganadorId!.isNotEmpty) {
        final informesRepo = InformesRepository();
        final titulo = 'Retiro por subasta ${_itemTitles[subasta.itemId] ?? subasta.itemId}';

        await informesRepo.createInformeRetiro(
          admin: persona,
          objeto: objeto,
          titulo: titulo,
          notaTexto: nota,
          retiradoPorUsuario: cerrada.ganadorId ?? ganadorId,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subasta cerrada. Ganador: ${cerrada.ganadorId ?? ganadorId}',
            ),
            backgroundColor: Colors.green[700],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subasta cerrada sin pujas. Objeto sigue en informes de entrega.'),
          ),
        );
      }
      await _cargar();
    } on UserNotFound catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El ganador no coincide con ningún perfil registrado'),
          backgroundColor: Colors.red,
        ),
      );
    } on SubastaNotFound catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subasta no encontrada: ${e.subastaId}'),
          backgroundColor: Colors.red,
        ),
      );
    } on InsufficientFunds catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El ganador seleccionado no tiene saldo suficiente (${e.availablePoints}/${e.requiredPoints} pts)',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cerrar la subasta: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar la subasta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cerrando[subasta.subastaId] = false;
        });
      }
    }
  }

  String _formatFecha(DateTime fecha) {
    final ahora = DateTime.now();
    if (fecha.isBefore(ahora)) {
      return 'Finalizada';
    }
    final diferencia = fecha.difference(ahora);

    if (diferencia.inSeconds < 60) {
      return 'Casi finaliza';
    } else if (diferencia.inMinutes < 60) {
      return 'En ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'En ${diferencia.inHours} horas';
    } else {
      return 'En ${diferencia.inDays} días';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final persona = ProfileScope.of(context).current;
    final esUsuarioComun = persona is Perfil && !persona.isAdmin;
    final esAdmin = persona is Perfil && persona.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subastas Activas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _subastas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gavel, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay subastas activas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vuelve más tarde para ver nuevas subastas',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _subastas.length,
                    itemBuilder: (context, index) {
                      final subasta = _subastas[index];
                      final tiempoRestante = _formatFecha(subasta.fechaFin);
                      final estaActiva = subasta.activa;
                      final estaCerrando = _cerrando[subasta.subastaId] ?? false;

                      return _buildSubastaCard(
                        context: context,
                        subasta: subasta,
                        tiempoRestante: tiempoRestante,
                        estaActiva: estaActiva,
                        esUsuarioComun: esUsuarioComun,
                        esAdmin: esAdmin,
                        estaCerrando: estaCerrando,
                        colorScheme: colorScheme,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildSubastaCard({
    required BuildContext context,
    required Subasta subasta,
    required String tiempoRestante,
    required bool estaActiva,
    required bool esUsuarioComun,
    required bool esAdmin,
    required bool estaCerrando,
    required ColorScheme colorScheme,
  }) {
    final estaPujando = _pujando[subasta.subastaId] ?? false;
    final controller = _bidControllers[subasta.subastaId];
    final estaCerrada = subasta.cerrada || !estaActiva;
    final estadoTexto = estaCerrada ? 'Cerrada' : 'Activa';
    final estadoColor =
        estaCerrada ? Colors.red[100] : colorScheme.primaryContainer;
    final estadoTextColor =
        estaCerrada ? Colors.red[800] : colorScheme.onPrimaryContainer;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con item ID y estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Objeto: ${_itemTitles[subasta.itemId] ?? subasta.itemId}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID Subasta: ${subasta.subastaId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: estadoColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: estadoTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Información de pujas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Puja Mínima',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${subasta.minPuja.toInt()} pts',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Puja Actual',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${subasta.actualPuja.toInt()} pts',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiempo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tiempoRestante,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: estaActiva ? Colors.orange : Colors.red,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Mayor postor
            if (subasta.mayorPostorId != null && subasta.mayorPostorId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mayor postor: ${subasta.mayorPostorId}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Campo de entrada y botón de puja (solo para usuarios comunes)
            if (esUsuarioComun && estaActiva) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !estaPujando,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Cantidad a pujar',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: ElevatedButton.icon(
                      onPressed: estaPujando ? null : () => _realizarPuja(subasta),
                      icon: estaPujando
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : const Icon(Icons.gavel),
                      label: Text(estaPujando ? 'Pujando...' : 'Pujar'),
                    ),
                  ),
                ],
              ),
            ] else if (esAdmin && estaActiva) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cierre anticipado',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subasta.mayorPostorId == null || subasta.mayorPostorId!.isEmpty
                          ? 'Sin pujas registradas aún.'
                          : 'Mayor postor: ${subasta.mayorPostorId} con ${subasta.actualPuja.toInt()} pts',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red[900],
                          ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: estaCerrando ? null : () => _cerrarSubasta(subasta),
                        icon: estaCerrando
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.flag),
                        label: Text(estaCerrando ? 'Cerrando...' : 'Cerrar ahora'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!esUsuarioComun && !esAdmin && estaActiva) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Selecciona un perfil de usuario para pujar.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CerrarSubastaData {
  final String ganadorId;
  final String nota;

  _CerrarSubastaData(this.ganadorId, this.nota);
}
