import 'package:flutter/material.dart';
import 'package:objetos_perdidos/Datos/models/publication_record.dart';
import 'package:objetos_perdidos/Datos/repositories/publications_repository.dart';
import 'package:objetos_perdidos/screen/crear_publicacion_screen.dart';

class PublicacionesFeedScreen extends StatefulWidget {
  final PublicationsRepository publicationsRepo;

  PublicacionesFeedScreen({
    super.key,
    PublicationsRepository? publicationsRepository,
  }) : publicationsRepo = publicationsRepository ?? PublicationsRepository();

  @override
  State<PublicacionesFeedScreen> createState() => _PublicacionesFeedScreenState();
}

class _PublicacionesFeedScreenState extends State<PublicacionesFeedScreen> {
  bool _cargando = true;

  // Datos
  List<PublicationRecord> _items = <PublicationRecord>[];
  List<PublicationRecord> _filtrados = <PublicationRecord>[];

  // Filtros
  String _query = '';
  String _categoria = 'Todas';
  DateTime? _desde;
  DateTime? _hasta;

  // Orden
  String _orden = 'creationDesc'; // creationDesc | fechaDesc | creationAsc | fechaAsc

  // UI
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final items = await widget.publicationsRepo.listPublications();

      // Orden inicial por creación desc con fallback por fecha
      int idAsInt(PublicationRecord r) => int.tryParse(r.id) ?? 0;
      DateTime fecha(PublicationRecord r) =>
          DateTime.tryParse(r.fechaIso) ?? DateTime.fromMillisecondsSinceEpoch(0);

      items.sort((a, b) {
        final byId = idAsInt(b).compareTo(idAsInt(a));
        if (byId != 0) return byId;
        return fecha(b).compareTo(fecha(a));
      });

      if (!mounted) return;
      setState(() {
        _items = items;
        _aplicarFiltros();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando publicaciones: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    final q = _query.trim().toLowerCase();
    final cat = _categoria;

    bool match(PublicationRecord r) {
      // Categoría
      final enCat = (cat == 'Todas') ||
          (r.categoria.trim().toLowerCase() == cat.toLowerCase());
      if (!enCat) return false;

      // Texto
      if (q.isNotEmpty) {
        final hit = r.titulo.toLowerCase().contains(q) ||
            r.descripcion.toLowerCase().contains(q) ||
            r.lugar.toLowerCase().contains(q) ||
            r.autorNombre.toLowerCase().contains(q);
        if (!hit) return false;
      }

      // Rango de fechas
      final f = DateTime.tryParse(r.fechaIso);
      if (f == null) return false;

      if (_desde != null && f.isBefore(_desde!)) return false;
      if (_hasta != null && f.isAfter(_finDia(_hasta!))) return false;

      return true;
    }

    final out = _items.where(match).toList();

    // Orden
    int idAsInt(PublicationRecord r) => int.tryParse(r.id) ?? 0;
    DateTime fecha(PublicationRecord r) =>
        DateTime.tryParse(r.fechaIso) ?? DateTime.fromMillisecondsSinceEpoch(0);

    switch (_orden) {
      case 'creationAsc':
        out.sort((a, b) => idAsInt(a).compareTo(idAsInt(b)));
        break;
      case 'fechaAsc':
        out.sort((a, b) => fecha(a).compareTo(fecha(b)));
        break;
      case 'fechaDesc':
        out.sort((a, b) => fecha(b).compareTo(fecha(a)));
        break;
      case 'creationDesc':
      default:
        out.sort((a, b) => idAsInt(b).compareTo(idAsInt(a)));
        break;
    }

    _filtrados = out;
  }

  DateTime _finDia(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<void> _refrescar() => _cargar();

  Future<void> _pickRangoFechas() async {
    final hoy = DateTime.now();
    final first = DateTime(hoy.year - 5, 1, 1);
    final last = DateTime(hoy.year + 1, 12, 31);

    final inicial = (_desde != null && _hasta != null)
        ? DateTimeRange(start: _desde!, end: _hasta!)
        : null;

    final rango = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: inicial,
      helpText: 'Selecciona rango de fechas',
      saveText: 'Aplicar',
    );

    if (rango != null && mounted) {
      setState(() {
        _desde = DateTime(rango.start.year, rango.start.month, rango.start.day);
        _hasta = DateTime(rango.end.year, rango.end.month, rango.end.day);
        _aplicarFiltros();
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _searchCtrl.clear();
      _query = '';
      _categoria = 'Todas';
      _desde = null;
      _hasta = null;
      _orden = 'creationDesc';
      _aplicarFiltros();
    });
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
    // Si luego quieres 'intl', aquí podrías usar DateFormat('yyyy-MM-dd').format(d)
  }

  @override
  Widget build(BuildContext context) {
    // Categorías dinámicas + "Todas"
    final categorias = <String>{
      'Todas',
      ..._items.map((e) => e.categoria.trim()).where((s) => s.isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!categorias.contains('Todas')) categorias.insert(0, 'Todas');

    final rangoSel = (_desde != null || _hasta != null)
        ? '${_desde != null ? _fmt(_desde!) : '...'} → ${_hasta != null ? _fmt(_hasta!) : '...'}'
        : 'Rango de fechas';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetos perdidos'),
        actions: [
          // Orden
          PopupMenuButton<String>(
            tooltip: 'Ordenar',
            initialValue: _orden,
            onSelected: (v) => setState(() {
              _orden = v;
              _aplicarFiltros();
            }),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'creationDesc', child: Text('Más nuevos (creación)')),
              PopupMenuItem(value: 'fechaDesc', child: Text('Más recientes (fecha objeto)')),
              PopupMenuItem(value: 'creationAsc', child: Text('Más antiguos (creación)')),
              PopupMenuItem(value: 'fechaAsc', child: Text('Más antiguos (fecha objeto)')),
            ],
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            tooltip: 'Limpiar filtros',
            onPressed: _limpiarFiltros,
            icon: const Icon(Icons.filter_alt_off),
          ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (t) => setState(() {
                _query = t;
                _aplicarFiltros();
              }),
              decoration: InputDecoration(
                hintText: 'Buscar por título, descripción, lugar o autor…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                          _aplicarFiltros();
                        }),
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                // Categorías
                ...categorias.map((c) {
                  final selected = c.toLowerCase() == _categoria.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        _categoria = c;
                        _aplicarFiltros();
                      }),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                // Rango de fechas
                OutlinedButton.icon(
                  onPressed: _pickRangoFechas,
                  icon: const Icon(Icons.date_range),
                  label: Text(rangoSel, overflow: TextOverflow.ellipsis),
                ),
                if (_desde != null || _hasta != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      tooltip: 'Quitar rango',
                      onPressed: () => setState(() {
                        _desde = null;
                        _hasta = null;
                        _aplicarFiltros();
                      }),
                      icon: const Icon(Icons.close),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refrescar,
              child: _cargando
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _filtrados.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.inventory_2_outlined,
                                size: 56, color: Colors.grey),
                            SizedBox(height: 12),
                            Center(
                              child: Text('Sin resultados',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtrados.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final pub = _filtrados[index];
                            return _PublicationCard(pub: pub);
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => CrearPublicacionScreen(
                publicationsRepository: widget.publicationsRepo,
              ),
            ),
          );
          if (ok == true && mounted) _cargar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Publicar'),
      ),
    );
  }
}

class _PublicationCard extends StatelessWidget {
  const _PublicationCard({required this.pub});
  final PublicationRecord pub;

  String _fmtFechaPerdida(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Fecha: —';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _leadingText(String s) {
    final t = s.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fechaPerdida = _fmtFechaPerdida(pub.fechaIso);
    final leadingText = _leadingText(pub.categoria);

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: CircleAvatar(child: Text(leadingText)),
        title: Text(pub.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pub.descripcion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(pub.descripcion,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: -6,
              children: [
                _Chip(icon: Icons.category, label: pub.categoria),
                _Chip(icon: Icons.place, label: pub.lugar),
                _Chip(icon: Icons.event, label: fechaPerdida),
                if (pub.autorNombre.isNotEmpty)
                  _Chip(icon: Icons.person, label: pub.autorNombre),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.only(right: 8),
      avatar: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}