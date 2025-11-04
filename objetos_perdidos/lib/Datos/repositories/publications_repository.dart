import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/publication_record.dart';

// Repositorio que maneja las publicaciones de objetos perdidos
class PublicationsRepository {
  final Directory? _overrideBaseDir;

  PublicationsRepository({Directory? baseDirectory}) : _overrideBaseDir = baseDirectory;

  static String get _sep => Platform.pathSeparator;

  // Busca el directorio raíz del proyecto buscando 'pubspec.yaml' hacia arriba
  Future<Directory> _findProjectRoot() async {
    final base = _overrideBaseDir;
    if (base != null) return base;
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

  // Directorio raíz para almacenar archivos individuales
  Future<Directory> _resolvePublicDir() async {
    final root = await _findProjectRoot();
    final publicDir = Directory('${root.path}${_sep}publicaciones');
    if (!await publicDir.exists()) {
      await publicDir.create(recursive: true);
    }
    return publicDir;
  }

  Future<File> _fileForId(String id) async {
    final dir = await _resolvePublicDir();
    return File('${dir.path}$_sep$id.txt');
  }

  /// Lista todas las publicaciones leyendo cada archivo .txt en ./publicaciones.
  /// Los archivos con `{ "eliminada": true }` son ignorados.
  Future<List<PublicationRecord>> listPublications() async {
    try {
      final dir = await _resolvePublicDir();
      final files = await dir.list().toList();
      final result = <PublicationRecord>[];
      for (final f in files) {
        if (f is File && f.path.toLowerCase().endsWith('.txt')) {
          try {
            final content = await f.readAsString();
            if (content.trim().isEmpty) continue;
            final dynamic data = jsonDecode(content);
            if (data is Map<String, dynamic>) {
              if (data['eliminada'] == true) continue; // saltar eliminadas
              result.add(PublicationRecord.fromJson(data));
            }
          } catch (e) {
            // no detener el listado por un archivo corrupto
            debugPrint('[PublicationsRepository] error reading file ${f.path}: $e');
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('[PublicationsRepository] listPublications error: $e');
      return <PublicationRecord>[];
    }
  }

  /// Crea un post, genera un id único y lo escribe en `./publicaciones/<ID>.txt`
  Future<PublicationRecord> createPublication({
    required String titulo,
    required String descripcion,
    required String categoria,
    required DateTime fecha,
    required String lugar,
    required String autorId,
    required String autorNombre,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final newRecord = PublicationRecord(
      id: id,
      titulo: titulo,
      descripcion: descripcion,
      categoria: categoria,
      fechaIso: fecha.toIso8601String(),
      lugar: lugar,
      autorId: autorId,
      autorNombre: autorNombre,
    );

    try {
      final file = await _fileForId(id);
      final map = newRecord.toJson();
      // escribir json dentro del .txt
      await file.writeAsString(jsonEncode(map), flush: true);
      return newRecord;
    } catch (e) {
      debugPrint('[PublicationsRepository] createPublication error: $e');
      rethrow;
    }
  }

  /// Lee un post por id. Retorna null si no existe o si está marcado como eliminado.
  Future<PublicationRecord?> readPublication(String id) async {
    try {
      final file = await _fileForId(id);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final dynamic data = jsonDecode(content);
      if (data is Map<String, dynamic>) {
        if (data['eliminada'] == true) return null;
        return PublicationRecord.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[PublicationsRepository] readPublication($id) error: $e');
      return null;
    }
  }


  Future<bool> deletePublication(String id, {bool markOnly = true}) async {
    try {
      final file = await _fileForId(id);
      if (!await file.exists()) return false;

      if (markOnly) {
        try {
          final content = await file.readAsString();
          final dynamic data =
              content.trim().isEmpty ? <String, dynamic>{} : jsonDecode(content);
          if (data is Map<String, dynamic>) {
            data['eliminada'] = true;
            await file.writeAsString(jsonEncode(data), flush: true);
            return true;
          } else {
            await file.writeAsString(
              jsonEncode({'id': id, 'eliminada': true}),
              flush: true,
            );
            return true;
          }
        } catch (e) {
          debugPrint('[PublicationsRepository] deletePublication mark error for $id: $e');
          return false;
        }
      } else {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('[PublicationsRepository] deletePublication($id) error: $e');
      return false;
    }
  }

  /// Ruta del directorio de publicaciones
  Future<String> debugDirPath() async {
    try {
      final d = await _resolvePublicDir();
      return d.path;
    } catch (e) {
      return 'error resolving publicaciones dir: $e';
    }
  }
}