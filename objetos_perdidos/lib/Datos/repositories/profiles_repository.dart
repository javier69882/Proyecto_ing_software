import 'dart:io';
import '../models/profile_record.dart';

class ProfilesRepository {
  final Directory? _overrideBaseDir;

  ProfilesRepository({Directory? baseDirectory}) : _overrideBaseDir = baseDirectory;

  static String get _sep => Platform.pathSeparator;

  /// Encuentra la raíz del proyecto buscando 'pubspec.yaml' hacia arriba
  
  Future<Directory> _findProjectRoot() async {
    if (_overrideBaseDir != null) return _overrideBaseDir;
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

 
  Future<Directory> _resolveLibDir() async {
    final root = await _findProjectRoot();
    final libDir = Directory('${root.path}${_sep}lib');
    if (!await libDir.exists()) {
      
      await libDir.create(recursive: true);
    }
    return libDir;
  }

  Future<File> _resolveFile() async {

    final libDir = await _resolveLibDir();
    final datosDir = Directory(
      '${libDir.path}${_sep}Datos${_sep}datos_perfil',
    );
    if (!(await datosDir.exists())) {
      await datosDir.create(recursive: true);
    }
    final file = File('${datosDir.path}${_sep}profiles.json');
    if (!(await file.exists())) {
      await file.writeAsString('[]'); // inicializa lista vacía
    }
    return file;
  }

  /// Lista todos los perfiles guardados. Si no hay archivo / JSON inválido → []
  Future<List<ProfileRecord>> listProfiles() async {
    try {
      final file = await _resolveFile();
      final content = await file.readAsString();
      return ProfileRecord.decodeList(content);
    } catch (e) {
      print('[ProfilesRepository] listProfiles error: $e');
      return <ProfileRecord>[];
    }
  }

  /// Crea un perfil (Nombre, Tipo), lo guarda y lo retorna.
  Future<ProfileRecord> createProfile({
    required String nombre,
    required Tipo tipo,
  }) async {
    final newRecord = ProfileRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre,
      tipo: tipo,
      puntos: 0,
    );

    try {
      final file = await _resolveFile();
      final current = await listProfiles();
      final updated = <ProfileRecord>[...current, newRecord];

      await file.writeAsString(
        ProfileRecord.encodeList(updated),
        flush: true,
      );

      return newRecord;
    } catch (e) {
      print('[ProfilesRepository] createProfile error: $e');
      rethrow;
    }
  }

  // Añade (o resta) puntos al perfil con el nombre dado.
  Future<bool> addPointsForNombre(String nombre, int delta) async {
    try {
      final file = await _resolveFile();
      final current = await listProfiles();
      var changed = false;
      final updated = current.map((r) {
        if (r.nombre == nombre && r.tipo == Tipo.perfil) {
          final nuevo = r.copyWith(puntos: r.puntos + delta);
          changed = true;
          return nuevo;
        }
        return r;
      }).toList();
      if (changed) {
        await file.writeAsString(ProfileRecord.encodeList(updated), flush: true);
      }
      return changed;
    } catch (e) {
      print('[ProfilesRepository] addPointsForNombre error: $e');
      return false;
    }
  }

  /// Ver la ruta efectiva del archivo.
  Future<String> debugFilePath() async {
    final f = await _resolveFile();
    return f.path;
  }

  /// Expone el archivo de perfiles para acceso del servicio.
  /// Esta es una API pública para SubastaService.
  Future<File> getProfilesFile() async {
    return _resolveFile();
  }
}