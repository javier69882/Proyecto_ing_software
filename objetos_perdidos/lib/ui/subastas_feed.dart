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

  // UI State para cada subasta (almacenar cantidad pujeada en cada tarjeta)
  final Map<String, TextEditingController> _bidControllers =
      <String, TextEditingController>{};
  final Map<String, bool> _pujando = <String, bool>{};

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
        for (final inf in informes) {
          if (inf is InformeEntrega) {
            final objetoId = inf.objeto.id;
            if (objetoId.isNotEmpty && !_itemTitles.containsKey(objetoId)) {
              _itemTitles[objetoId] = inf.titulo;
            }
          }
        }
      } catch (_) {
        // ignore informe loading errors; we'll fallback to itemId
      }
      if (!mounted) return;
      setState(() {
        _subastas = subastas;
        // Inicializar controllers para cada subasta
        for (final s in subastas) {
          _bidControllers.putIfAbsent(s.subastaId, () => TextEditingController());
          _pujando.putIfAbsent(s.subastaId, () => false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La puja debe ser mayor a ${e.currentBidAmount.toInt()} puntos'),
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

  String _formatFecha(DateTime fecha) {
    final ahora = DateTime.now();
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
                      final estaActiva = subasta.fechaFin.isAfter(DateTime.now());

                      return _buildSubastaCard(
                        context: context,
                        subasta: subasta,
                        tiempoRestante: tiempoRestante,
                        estaActiva: estaActiva,
                        esUsuarioComun: esUsuarioComun,
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
    required ColorScheme colorScheme,
  }) {
    final estaPujando = _pujando[subasta.subastaId] ?? false;
    final controller = _bidControllers[subasta.subastaId];

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
                    color: estaActiva ? colorScheme.primaryContainer : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estaActiva ? 'Activa' : 'Finalizada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: estaActiva ? colorScheme.onPrimaryContainer : Colors.red[700],
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
            ] else if (!esUsuarioComun && estaActiva) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Los administradores no pueden pujar',
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
