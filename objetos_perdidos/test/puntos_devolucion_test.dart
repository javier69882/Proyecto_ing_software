import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/informe.dart';
import 'package:objetos_perdidos/objeto_perdido.dart';
import 'package:objetos_perdidos/perfil.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart';

void main() {
  group('Puntos por devolucion y billetera', () {
    late Directory tmp;
    late ProfilesRepository profilesRepo;
    late InformesRepository informesRepo;
    late Perfil admin;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('puntos_devolucion_');
      profilesRepo = ProfilesRepository(baseDirectory: tmp);
      informesRepo = InformesRepository(baseDirectory: tmp);
      admin = Perfil('admin', 0, <ObjetoPerdido>[], isAdmin: true);
    });

    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<InformeEntrega> crearEntrega({
      required String titulo,
      required String entregadoPor,
    }) async {
      final informe = await informesRepo.createInformeEntrega(
        admin: admin,
        titulo: titulo,
        categoria: 'varios',
        descripcion: 'descripcion',
        lugar: 'lobby',
        entregadoPorUsuario: entregadoPor,
      );
      return informe as InformeEntrega;
    }

    test('asigna kPuntosPorEntrega al entregador al registrar un retiro', () async {
      await profilesRepo.createProfile(nombre: 'Carlos', tipo: Tipo.perfil);
      final entrega = await crearEntrega(
        titulo: 'Billetera azul',
        entregadoPor: 'Carlos',
      );

      await informesRepo.createInformeRetiro(
        admin: admin,
        objeto: entrega.objeto,
        titulo: 'Retiro billetera',
        notaTexto: 'dueño la reclama',
        retiradoPorUsuario: 'Dueña',
      );

      final perfiles = await profilesRepo.listProfiles();
      final carlos = perfiles.firstWhere((p) => p.nombre == 'Carlos');
      expect(carlos.puntos, InformesRepository.kPuntosPorEntrega);
    });

    test('acumula puntos si se procesa el mismo objeto dos veces (comportamiento actual)', () async {
      await profilesRepo.createProfile(nombre: 'Lucia', tipo: Tipo.perfil);
      final entrega = await crearEntrega(
        titulo: 'Laptop gris',
        entregadoPor: 'Lucia',
      );

      final mismoObjeto = entrega.objeto;

      await informesRepo.createInformeRetiro(
        admin: admin,
        objeto: mismoObjeto,
        titulo: 'Primer retiro laptop',
        notaTexto: 'dueño acreditado',
        retiradoPorUsuario: 'Propietario',
      );

      await informesRepo.createInformeRetiro(
        admin: admin,
        objeto: mismoObjeto,
        titulo: 'Retiro duplicado laptop',
        notaTexto: 'evento repetido',
        retiradoPorUsuario: 'Propietario',
      );

      final perfiles = await profilesRepo.listProfiles();
      final lucia = perfiles.firstWhere((p) => p.nombre == 'Lucia');
      expect(lucia.puntos, InformesRepository.kPuntosPorEntrega * 2,
          reason: 'La implementación actual suma en cada retiro procesado');
    });

    test('ProfileController refleja el saldo actualizado tras refresh', () async {
      final controller = ProfileController(repo: profilesRepo);
      final record = await profilesRepo.createProfile(nombre: 'SaldoUser', tipo: Tipo.perfil);

      await profilesRepo.addPointsForNombre('SaldoUser', 12);
      await controller.refresh();
      await controller.select(
        controller.records.firstWhere((r) => r.id == record.id),
      );

      expect(controller.current, isA<Perfil>());
      expect((controller.current as Perfil).puntos, 12);

      await profilesRepo.addPointsForNombre('SaldoUser', 8);
      await controller.refresh();
      expect((controller.current as Perfil).puntos, 20,
          reason: 'El usuario debe ver su saldo actualizado después de operaciones');
    });
  });
}
