import 'dart:convert';
import 'dart:io';
import '../../informe.dart';
import '../../perfil.dart';
import '../../objeto_perdido.dart';
import '../../nota.dart';

/// Repositorio para persistir informes (entrega y retiro) en archivos JSON individuales.
class InformesRepository {
  final Directory? _overrideBaseDir;

  InformesRepository({Directory? baseDirectory}) : _overrideBaseDir = baseDirectory;

  static String get _sep => Platform.pathSeparator;

  Future<Directory> _findProjectRoot() async {
    if (_overrideBaseDir != null) return _overrideBaseDir!; // ignore: unnecessary_non_null_assertion
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

  Future<Directory> _resolveInformesDir() async {
    final root = await _findProjectRoot();
    final informesDir = Directory('${root.path}${_sep}informes');
    if (!await informesDir.exists()) {
      await informesDir.create(recursive: true);
    }
    return informesDir;
  }

  Future<File> _fileForId(String id) async {
    final dir = await _resolveInformesDir();
    return File('${dir.path}$_sep$id.json');
  }

  Future<Informe> createInformeEntrega({
    required Perfil admin,
    required String titulo,
    required String categoria,
    required String descripcion,
    required String lugar,
    required String entregadoPorUsuario,
  }) async {
    if (!admin.isAdmin) throw StateError('Solo un administrador puede crear informes de entrega');
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final objeto = ObjetoPerdido(
      categoria,
      Nota(descripcion, DateTime.now()),
      DateTime.now(),
      lugar,
    );
    final informe = InformeEntrega(
      id,
      titulo,
      objeto,
      admin,
      DateTime.now(),
      entregadoPorUsuario,
      nota: Nota('Recepción del objeto por $entregadoPorUsuario', DateTime.now()),
    );
    final file = await _fileForId(id);
    await file.writeAsString(jsonEncode(informe.toJson()), flush: true);
    return informe;
  }

  Future<List<Informe>> listInformes(Perfil Function(String usuario) perfilResolver) async {
    try {
      final dir = await _resolveInformesDir();
      final files = await dir.list().toList();
      final result = <Informe>[];
      for (final f in files) {
        if (f is File && f.path.toLowerCase().endsWith('.json')) {
          try {
            final content = await f.readAsString();
            if (content.trim().isEmpty) continue;
            final dynamic data = jsonDecode(content);
            if (data is Map<String, dynamic>) {
              final informe = Informe.fromJson(data, perfilResolver);
              if (informe != null) result.add(informe);
            }
          } catch (e) {
            print('[InformesRepository] error leyendo ${f.path}: $e');
          }
        }
      }
      return result;
    } catch (e) {
      print('[InformesRepository] listInformes error: $e');
      return <Informe>[];
    }
  }

  Future<bool> deleteInforme(String id) async {
    try {
      final file = await _fileForId(id);
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (e) {
      print('[InformesRepository] deleteInforme($id) error: $e');
      return false;
    }
  }

  Future<String> debugDirPath() async {
    try {
      final d = await _resolveInformesDir();
      return d.path;
    } catch (e) {
      return 'error resolving informes dir: $e';
    }
  }
}
