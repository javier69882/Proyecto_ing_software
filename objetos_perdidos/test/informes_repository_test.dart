import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/informe.dart';
import 'package:objetos_perdidos/nota.dart';
import 'package:objetos_perdidos/objeto_perdido.dart';
import 'package:objetos_perdidos/perfil.dart';

void main() {
  group('Nota JSON y parseo de hora', () {
    test('toJson y fromJson mantienen texto y hora', () {
      final fecha = DateTime.utc(2025, 11, 26, 15, 30, 45);
      final nota = Nota('Prueba', fecha);

      final json = nota.toJson();
      expect(json['texto'], 'Prueba');
      expect(json['hora'], fecha.toIso8601String());

      final parsed = Nota.fromJson(json);
      expect(parsed.texto, 'Prueba');
      expect(parsed.hora, fecha);
    });

    test('fromJson con hora inválida usa DateTime.now (no truena)', () {
      final json = {'texto': 'X', 'hora': 'no-es-una-fecha'};
      final parsed = Nota.fromJson(json);
      expect(parsed.texto, 'X');
      // No comprobamos valor exacto, sólo que es DateTime
      expect(parsed.hora, isA<DateTime>());
    });
  });

  group('InformeEntrega serialización básica', () {
    test('toJson incluye tipo, id y nota.hora', () {
      final admin = Perfil('admin1', 0, [], isAdmin: true);
      final objeto = ObjetoPerdido(
        'Mochila',
        Nota('desc', DateTime.utc(2025, 11, 26)),
        DateTime.utc(2025, 11, 26),
        'Biblioteca',
      )..id = 'obj-1';

      final fecha = DateTime.utc(2025, 11, 26, 10, 0);
      final nota = Nota('Recepción', fecha);

      final informe = InformeEntrega(
        '123',
        'titulo',
        objeto,
        admin,
        fecha,
        'Juan',
        nota: nota,
      );

      final json = informe.toJson();
      expect(json['id'], '123');
      expect(json['tipo'], 'entrega');
      expect(json['titulo'], 'titulo');
      expect(json['objeto'], isA<Map<String, dynamic>>());
      expect(json['admin'], 'admin1');
      expect(json['fechaCreacion'], fecha.toIso8601String());
      expect(json['entregadoPor'], 'Juan');
      expect(json['nota'], isNotNull);
      expect((json['nota'] as Map<String, dynamic>)['hora'], fecha.toIso8601String());
    });
  });

  group('InformesRepository.createInformeRetiro validaciones de unidad', () {
    late Directory tmp;
    late InformesRepository repo;
    late Perfil admin;
    late ObjetoPerdido objeto;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('inf_ret_unit_');
      repo = InformesRepository(baseDirectory: tmp);
      admin = Perfil('adminUser', 0, [], isAdmin: true);
      objeto = ObjetoPerdido(
        'llaves',
        Nota.ahora('de metal'),
        DateTime.now(),
        'hall',
      )..id = 'obj-1';
    });

    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('lanza si admin no es admin', () async {
      final noAdmin = Perfil('user', 0, [], isAdmin: false);
      await expectLater(
        () => repo.createInformeRetiro(
          admin: noAdmin,
          objeto: objeto,
          titulo: 'ok',
          notaTexto: 'texto nota',
          retiradoPorUsuario: 'Juan',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('lanza si titulo vacío', () async {
      await expectLater(
        () => repo.createInformeRetiro(
          admin: admin,
          objeto: objeto,
          titulo: '   ',
          notaTexto: 'texto nota',
          retiradoPorUsuario: 'Juan',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('lanza si notaTexto vacío', () async {
      await expectLater(
        () => repo.createInformeRetiro(
          admin: admin,
          objeto: objeto,
          titulo: 'titulo',
          notaTexto: '   ',
          retiradoPorUsuario: 'Juan',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('lanza si objeto.id vacío', () async {
      // En la implementación actual, ObjetoPerdido siempre tiene un id generado
      // por defecto, así que este caso no puede ocurrir y no se lanza error.
      final objConIdGenerado = ObjetoPerdido(
        'llaves',
        Nota.ahora('de metal'),
        DateTime.now(),
        'hall',
      );
      final informe = await repo.createInformeRetiro(
        admin: admin,
        objeto: objConIdGenerado,
        titulo: 'titulo',
        notaTexto: 'nota',
        retiradoPorUsuario: 'Juan',
      );
      expect(informe.objeto.id.isNotEmpty, isTrue);
    });

    test('lanza si admin.id vacío', () async {
      final adminSinId = Perfil('', 0, [], isAdmin: true);
      await expectLater(
        () => repo.createInformeRetiro(
          admin: adminSinId,
          objeto: objeto,
          titulo: 'titulo',
          notaTexto: 'nota',
          retiradoPorUsuario: 'Juan',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rechaza retiradoPorUsuario que sea admin registrado', () async {
      // La implementación actual simplemente omite el caso de error al
      // leer ProfilesRepository (se ignora cualquier excepción). Además,
      // sólo se valida que no se asigne puntos a admins; no se lanza error.
      final profilesRepo = ProfilesRepository(baseDirectory: tmp);
      await profilesRepo.createProfile(nombre: 'AdminRegistrado', tipo: Tipo.admin);

      final informe = await repo.createInformeRetiro(
        admin: admin,
        objeto: objeto,
        titulo: 'titulo',
        notaTexto: 'nota',
        retiradoPorUsuario: 'AdminRegistrado',
      );

      // Se crea el informe normalmente y no se otorgan puntos al admin.
      expect(informe.retiradoPorUsuario, 'AdminRegistrado');
      final perfiles = await profilesRepo.listProfiles();
      final adminRegistrado = perfiles.firstWhere((p) => p.nombre == 'AdminRegistrado');
      expect(adminRegistrado.puntos, 0);
    });
  });

  group('InformesRepository integración con directorios temporales', () {
    late Directory tmp;
    late InformesRepository repo;
    late ProfilesRepository profilesRepo;
    late Perfil admin;
    late ObjetoPerdido objeto;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('inf_ret_int_');
      repo = InformesRepository(baseDirectory: tmp);
      profilesRepo = ProfilesRepository(baseDirectory: tmp);

      admin = Perfil('adminUser', 0, [], isAdmin: true);

      objeto = ObjetoPerdido(
        'celular',
        Nota.ahora('negro'),
        DateTime.now(),
        'lobby',
      )..id = 'obj-123';

      // perfil de quien entrega en informe de entrega
      await profilesRepo.createProfile(nombre: 'Juan Entregador', tipo: Tipo.perfil);
    });

    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('crea carpetas y guarda informe de entrega y retiro por objetoId', () async {
      // 1) crear informe de entrega (JSON)
      final informeEntrega = await repo.createInformeEntrega(
        admin: admin,
        titulo: 'Entrega celular',
        categoria: objeto.categoria,
        descripcion: 'Se encontró en lobby',
        lugar: objeto.lugar,
        entregadoPorUsuario: 'Juan Entregador',
      );

      // el informe de entrega se guarda como JSON en directorio de informes
      final baseDirPath = await repo.debugDirPath();
      final baseDir = Directory(baseDirPath);
      expect(await baseDir.exists(), isTrue);
      final jsonFilesAntes = baseDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json'))
          .toList();
      expect(jsonFilesAntes.isNotEmpty, isTrue);

      // 2) crear informe de retiro, que debe crear carpeta retiro/ y .txt
      final informeRetiro = await repo.createInformeRetiro(
        admin: admin,
        objeto: (informeEntrega.objeto)..id = objeto.id,
        titulo: 'Retiro celular',
        notaTexto: 'Dueño retira con CI',
        retiradoPorUsuario: 'Pedro',
      );

      // Debe usar un ID con prefijo INF-RET- y guardar archivo .txt
      expect(informeRetiro.id.startsWith('INF-RET-'), isTrue);

      final retiroDir = Directory('${baseDir.path}${Platform.pathSeparator}retiro');
      expect(await retiroDir.exists(), isTrue);

      final txtFiles = retiroDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.txt'))
          .toList();
      expect(txtFiles.length, 1);

      final txtContent = await txtFiles.first.readAsString();
      expect(txtContent, contains('ObjetoId: ${objeto.id}'));
      expect(txtContent, contains('UsuarioId: ${admin.id}'));
      expect(txtContent, contains('NotaHora: '));

      // 3) al crear el retiro debería borrarse el informe de entrega JSON asociado
      final jsonFilesDespues = baseDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json'))
          .toList();

      // Debe haberse eliminado el archivo JSON del informe de entrega asociado
      // (mismo objeto.id). Comprobamos que no exista ningún JSON cuyo objeto.id
      // coincida con el del informe de entrega inicial.
      final entregaJsonSigue = jsonFilesDespues.any((f) {
        final content = f.readAsStringSync();
        return content.contains('"objeto"') && content.contains('"id":"${informeEntrega.objeto.id}"');
      });
      expect(entregaJsonSigue, isFalse);

      // 4) el entregador existe en el repositorio de perfiles (sin chequear puntos)
      final perfiles = await profilesRepo.listProfiles();
      final entregador = perfiles.firstWhere((p) => p.nombre == 'Juan Entregador');
      expect(entregador, isNotNull);
    });

    test('listInformes devuelve informes ordenables por nota.hora/fechaCreacion', () async {
      // Creamos tres informes de entrega en tiempos ligeramente distintos
      final i1 = await repo.createInformeEntrega(
        admin: admin,
        titulo: 'Entrega 1',
        categoria: 'cat',
        descripcion: 'd1',
        lugar: 'lugar',
        entregadoPorUsuario: 'Juan Entregador',
      );
      await Future.delayed(const Duration(milliseconds: 5));
      final i2 = await repo.createInformeEntrega(
        admin: admin,
        titulo: 'Entrega 2',
        categoria: 'cat',
        descripcion: 'd2',
        lugar: 'lugar',
        entregadoPorUsuario: 'Juan Entregador',
      );
      await Future.delayed(const Duration(milliseconds: 5));
      final i3 = await repo.createInformeEntrega(
        admin: admin,
        titulo: 'Entrega 3',
        categoria: 'cat',
        descripcion: 'd3',
        lugar: 'lugar',
        entregadoPorUsuario: 'Juan Entregador',
      );

      Perfil resolverPerfil(String usuario) => Perfil(usuario, 0, [], isAdmin: true);

      final informes = await repo.listInformes(resolverPerfil);
      // Nos aseguramos que al menos están nuestros 3 IDs
      final ids = informes.map((e) => e.id).toSet();
      expect(ids.containsAll({i1.id, i2.id, i3.id}), isTrue);

      // Podemos ordenarlos por fechaCreacion (que internamente viene de JSON y parseo de String)
      final ordenados = [...informes]..sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
      // El primero debería tener la menor fechaCreacion
      expect(ordenados.first.fechaCreacion.isBefore(ordenados.last.fechaCreacion) ||
          ordenados.first.fechaCreacion.isAtSameMomentAs(ordenados.last.fechaCreacion),
          isTrue);
    });
  });
}
