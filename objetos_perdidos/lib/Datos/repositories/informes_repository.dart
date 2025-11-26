import 'dart:convert';
import 'dart:io';
import '../../informe.dart';
import '../../perfil.dart';
import '../../objeto_perdido.dart';
import '../../nota.dart';
import 'profiles_repository.dart';
import '../models/profile_record.dart';

// Repositorio para persistir informes en el sistema de archivos
class InformesRepository {
  final Directory? _overrideBaseDir;

  InformesRepository({Directory? baseDirectory})
      : _overrideBaseDir = baseDirectory;

  // puntos que se otorgan al entregador cuando el objeto es retirado
  static const int kPuntosPorEntrega = 10;

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

  // Directorio base de informes
  Future<Directory> _resolveInformesDir() async {
    final root = await _findProjectRoot();
    final informesDir = Directory('${root.path}${_sep}informes');
    if (!await informesDir.exists()) {
      await informesDir.create(recursive: true);
    }
    return informesDir;
  }

  // Directorio de informes de retiro
  Future<Directory> _resolveInformesRetiroDir() async {
    final base = await _resolveInformesDir();
    final retiroDir = Directory('${base.path}${_sep}retiro');
    if (!await retiroDir.exists()) {
      await retiroDir.create(recursive: true);
    }
    return retiroDir;
  }

  Future<File> _fileForId(String id) async {
    final dir = await _resolveInformesDir();
    return File('${dir.path}$_sep$id.json');
  }

  // Archivo .txt para un informe de retiro dado su ID.
  Future<File> _fileForRetiroId(String id) async {
    final retiroDir = await _resolveInformesRetiroDir();
    return File('${retiroDir.path}$_sep$id.txt');
  }

  // Genera un ID de retiro único
  String _generateRetiroId() {
    final now = DateTime.now();
    final datePart =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
    return 'INF-RET-$datePart-$timePart';
  }

  // informe de entrega
  Future<Informe> createInformeEntrega({
    required Perfil admin,
    required String titulo,
    required String categoria,
    required String descripcion,
    required String lugar,
    required String entregadoPorUsuario,
  }) async {
    if (!admin.isAdmin) {
      throw StateError('Solo un administrador puede crear informes de entrega');
    }

    final ahora = DateTime.now();
    final id = ahora.microsecondsSinceEpoch.toString();

    final objeto = ObjetoPerdido(
      categoria,
      Nota.ahora(descripcion),
      ahora,
      lugar,
    );

    final informe = InformeEntrega(
      id,
      titulo,
      objeto,
      admin,
      ahora,
      entregadoPorUsuario,
      nota: Nota.ahora('Recepción del objeto por $entregadoPorUsuario'),
    );

    final file = await _fileForId(id);
    await file.writeAsString(jsonEncode(informe.toJson()), flush: true);
    return informe;
  }

  /// informe de retiro
  Future<InformeRetiro> createInformeRetiro({
    required Perfil admin,
    required ObjetoPerdido objeto,
    required String titulo,
    required String notaTexto,
    required String retiradoPorUsuario,
  }) async {
    if (!admin.isAdmin) {
      throw StateError('Solo un administrador puede crear informes de retiro');
    }

    final tituloTrim = titulo.trim();
    final notaTrim = notaTexto.trim();
    final usuarioId = admin.id.trim();
    final objetoId = objeto.id.trim();

    if (tituloTrim.isEmpty) {
      throw ArgumentError('El título es obligatorio');
    }
    if (notaTrim.isEmpty) {
      throw ArgumentError('La nota (nota.texto) es obligatoria');
    }
    if (objetoId.isEmpty) {
      throw ArgumentError('objetoId es obligatorio (objeto.id vacío)');
    }
    if (usuarioId.isEmpty) {
      throw ArgumentError('usuarioId (admin actual) es obligatorio');
    }

    // validar que retiradoPorUsuario no sea administrador registrado
    final profilesRepo = ProfilesRepository(baseDirectory: _overrideBaseDir);
    try {
      final all = await profilesRepo.listProfiles();
      final matchAdmin = all.any((p) => p.nombre == retiradoPorUsuario && p.tipo == Tipo.admin);
      if (matchAdmin) {
        throw ArgumentError('Un administrador no puede ser la persona que retira el objeto');
      }
    } catch (_) {
      // si hay error leyendo perfiles, sigue
    }

    final id = _generateRetiroId();
    final nota = Nota.ahora(notaTrim);

    final informe = InformeRetiro(
      id,
      tituloTrim,
      objeto,
      admin,
      nota.hora, // fechaCreacion = hora de la nota
      retiradoPorUsuario,
      nota: nota,
    );

    // Estructura del archivo .txt
    final buffer = StringBuffer()
      ..writeln('ID: $id')
      ..writeln('ObjetoId: $objetoId')
      ..writeln('UsuarioId: $usuarioId')
      ..writeln('Titulo: $tituloTrim')
      ..writeln('NotaTexto: $notaTrim')
      ..writeln('NotaHora: ${nota.hora.toIso8601String()}')
      ..writeln('RetiradoPor: $retiradoPorUsuario');

    final file = await _fileForRetiroId(id);
    await file.writeAsString(buffer.toString(), flush: true);

    // intentar encontrar informe de entrega asociado y premiar entregador
    try {
      final dir = await _resolveInformesDir();
      final files = await dir.list().toList();
      for (final f in files) {
        if (f is! File || !f.path.toLowerCase().endsWith('.json')) continue;
        try {
          final content = await f.readAsString();
          if (content.trim().isEmpty) continue;
          final dynamic data = jsonDecode(content);
          if (data is! Map<String, dynamic>) continue;
          final tipo = data['tipo'] as String? ?? '';
          if (tipo != 'entrega') continue;
          final objetoJson = data['objeto'];
          if (objetoJson is! Map<String, dynamic>) continue;
          final idJson = objetoJson['id'] as String?;
          if (idJson == objetoId) {
            final entregadoPor = (data['entregadoPor'] as String?) ?? '';
            if (entregadoPor.isNotEmpty) {
              // sumar puntos al entregador (si es perfil común)
              await profilesRepo.addPointsForNombre(entregadoPor, kPuntosPorEntrega);
            }
            // borrar el informe de entrega vinculado
            await f.delete();
          }
        } catch (e) {
          print('[InformesRepository] error processing associated entrega for objetoId=$objetoId: $e');
        }
      }
    } catch (e) {
      print('[InformesRepository] _awardAndDeleteEntrega error: $e');
    }

    return informe;
  }

  // Borra todos los informes de entrega cuyo objeto.id == objetoId
  Future<void> _deleteInformesEntregaPorObjetoId(String objetoId) async {
    try {
      final dir = await _resolveInformesDir();
      final files = await dir.list().toList();
      for (final f in files) {
        if (f is! File || !f.path.toLowerCase().endsWith('.json')) continue;
        try {
          final content = await f.readAsString();
          if (content.trim().isEmpty) continue;
          final dynamic data = jsonDecode(content);
          if (data is! Map<String, dynamic>) continue;

          final tipo = data['tipo'] as String? ?? '';
          if (tipo != 'entrega') continue;

          final objetoJson = data['objeto'];
          if (objetoJson is! Map<String, dynamic>) continue;

          final idJson = objetoJson['id'] as String?;
          if (idJson == objetoId) {
            await f.delete();
          }
        } catch (e) {
          print(
            '[InformesRepository] error borrando informe de entrega por objetoId=$objetoId: $e',
          );
        }
      }
    } catch (e) {
      print(
        '[InformesRepository] _deleteInformesEntregaPorObjetoId($objetoId) error: $e',
      );
    }
  }

  // Lista informes JSON
  Future<List<Informe>> listInformes(
    Perfil Function(String usuario) perfilResolver,
  ) async {
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