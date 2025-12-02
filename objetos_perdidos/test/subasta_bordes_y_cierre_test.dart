import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/Datos/models/exceptions.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/subastas_repository.dart';
import 'package:objetos_perdidos/Datos/services/subasta_service.dart';

void main() {
  group('SubastaService - Bordes y cierre', () {
    late Directory tmpSubastas;
    late Directory tmpProfiles;
    late SubastasRepository subastaRepo;
    late ProfilesRepository profileRepo;
    late SubastaService service;

    setUp(() {
      tmpSubastas = Directory.systemTemp.createTempSync('subastas_bordes_');
      tmpProfiles = Directory.systemTemp.createTempSync('profiles_bordes_');
      subastaRepo = SubastasRepository(baseDirectory: tmpSubastas);
      profileRepo = ProfilesRepository(baseDirectory: tmpProfiles);
      service = SubastaService(
        subastaRepository: subastaRepo,
        profileRepository: profileRepo,
      );
    });

    tearDown(() {
      try {
        tmpSubastas.deleteSync(recursive: true);
        tmpProfiles.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('acepta puja igual al minimo inicial (comportamiento actual)', () async {
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 100);
      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 50);

      final result = await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'user1',
        cantidad: 50,
      );
      expect(result.actualPuja, 50);
      expect(result.mayorPostorId, 'user1');
    });

    test('rechaza puja igual a la actual cuando ya hay ofertas', () async {
      await profileRepo.createProfile(nombre: 'userA', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userA', 100);
      await profileRepo.createProfile(nombre: 'userB', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userB', 100);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 40);
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userA',
        cantidad: 60,
      );

      expect(
        () => service.pujaInicial(
          subastaId: subasta.subastaId,
          userId: 'userB',
          cantidad: 60,
        ),
        throwsA(isA<InvalidBidAmount>()),
      );
    });

    test('usuario sin puntos no puede pujar (saldo 0)', () async {
      await profileRepo.createProfile(nombre: 'sinSaldo', tipo: Tipo.perfil);
      final subasta = await subastaRepo.crearSubasta(itemId: 'item-2', minPuj: 10);

      expect(
        () => service.pujaInicial(
          subastaId: subasta.subastaId,
          userId: 'sinSaldo',
          cantidad: 10,
        ),
        throwsA(isA<InsufficientFunds>().having((e) => e.availablePoints, 'available', 0)),
      );
    });

    test('acepta pujas altas y persiste al lider', () async {
      await profileRepo.createProfile(nombre: 'userBig', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userBig', 1000000);
      final subasta = await subastaRepo.crearSubasta(itemId: 'item-3', minPuj: 100000);

      final updated = await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userBig',
        cantidad: 900000,
      );

      expect(updated.actualPuja, 900000);
      expect(updated.mayorPostorId, 'userBig');

      final perfiles = await profileRepo.listProfiles();
      final userBig = perfiles.firstWhere((p) => p.nombre == 'userBig');
      expect(userBig.puntos, 100000);
    });

    test('cerrar subasta sin pujas deja sin ganador y sin descuentos', () async {
      await profileRepo.createProfile(nombre: 'espectador', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('espectador', 50);
      final subasta = await subastaRepo.crearSubasta(itemId: 'item-4', minPuj: 30);

      final cerrada = await service.cerrarSubastaManual(subastaId: subasta.subastaId);
      expect(cerrada.cerrada, isTrue);
      expect(cerrada.ganadorId, isNull);
      expect(cerrada.mayorPostorId, isNull);

      final perfiles = await profileRepo.listProfiles();
      final espectador = perfiles.firstWhere((p) => p.nombre == 'espectador');
      expect(espectador.puntos, 50);
    });

    test('cerrar subasta ignora ganador alterno y mantiene mayor postor actual', () async {
      await profileRepo.createProfile(nombre: 'userA', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userA', 60);
      await profileRepo.createProfile(nombre: 'userB', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userB', 10);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-5', minPuj: 20);
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userA',
        cantidad: 25,
      );

      final cerrada = await service.cerrarSubastaManual(
        subastaId: subasta.subastaId,
        ganadorId: 'userB',
      );
      expect(cerrada.ganadorId, 'userA',
          reason: 'El servicio usa el mayor postor actual y no cambia al ganador propuesto');
    });

    test('cierre con mayor postor actual no deja saldo negativo', () async {
      await profileRepo.createProfile(nombre: 'userC', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userC', 30);
      final subasta = await subastaRepo.crearSubasta(itemId: 'item-6', minPuj: 10);

      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userC',
        cantidad: 30,
      );

      final cerrada = await service.cerrarSubastaManual(subastaId: subasta.subastaId);
      expect(cerrada.cerrada, isTrue);
      expect(cerrada.ganadorId, 'userC');

      final perfiles = await profileRepo.listProfiles();
      final userC = perfiles.firstWhere((p) => p.nombre == 'userC');
      expect(userC.puntos, greaterThanOrEqualTo(0));
    });
  });
}
