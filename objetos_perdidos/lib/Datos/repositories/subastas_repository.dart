import 'dart:convert';
import 'dart:io';

import '../models/subasta.dart';

class SubastasRepository {
  final Directory? _overrideBaseDir;

  SubastasRepository({Directory? baseDirectory}) : _overrideBaseDir = baseDirectory;

  static String get _sep => Platform.pathSeparator;

  Future<Directory> _findProjectRoot() async {
    if (_overrideBaseDir != null) return _overrideBaseDir!;
    Directory dir = Directory.current;
    for (int i = 0; i < 20; i++) {
      final pubspec = File('${dir.path}${_sep}pubspec.yaml');
      if (await pubspec.exists()) return dir;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return Directory.current;
  }

  Future<Directory> _resolveSubastasDir() async {
    final root = await _findProjectRoot();
    final dir = Directory('${root.path}${_sep}subastas');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileForId(String id) async {
    final dir = await _resolveSubastasDir();
    return File('${dir.path}$_sep$id.json');
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<Subasta> crearSubasta({
    required String itemId,
    required double minPuj,
    DateTime? fechaFin,
  }) async {
    if (itemId.trim().isEmpty) {
      throw ArgumentError('itemId es obligatorio');
    }
    if (minPuj <= 0) {
      throw ArgumentError('minPuj debe ser mayor que 0');
    }

    final now = DateTime.now();
    final cierre = fechaFin ?? now.add(const Duration(days: 7));
    final id = _generateId();

    final subasta = Subasta(
      subastaId: id,
      itemId: itemId.trim(),
      minPuja: minPuj,
      actualPuja: minPuj,
      mayorPostorId: null,
      fechaFin: cierre,
    );

    final file = await _fileForId(id);
    await file.writeAsString(jsonEncode(subasta.toJson()), flush: true);
    return subasta;
  }

  Future<List<Subasta>> getSubastasActivas() async {
    try {
      final dir = await _resolveSubastasDir();
      final files = await dir.list().toList();
      final now = DateTime.now();
      final result = <Subasta>[];
      for (final f in files) {
        if (f is! File || !f.path.toLowerCase().endsWith('.json')) continue;
        try {
          final content = await f.readAsString();
          if (content.trim().isEmpty) continue;
          final dynamic data = jsonDecode(content);
          if (data is! Map<String, dynamic>) continue;
          final subasta = Subasta.fromJson(data);
          if (subasta.fechaFin.isAfter(now)) {
            result.add(subasta);
          }
        } catch (_) {}
      }
      result.sort((a, b) => a.fechaFin.compareTo(b.fechaFin));
      return result;
    } catch (e) {
      return <Subasta>[];
    }
  }

  /// Devuelve la ruta del directorio de subastas.
  Future<String> debugDirPath() async {
    try {
      final d = await _resolveSubastasDir();
      return d.path;
    } catch (e) {
      return 'error resolving subastas dir: $e';
    }
  }

  /// Expone el directorio de subastas para acceso del servicio.
  /// Esta es una API pública para SubastaService.
  Future<Directory> getSubastasDir() async {
    return _resolveSubastasDir();
  }
}
