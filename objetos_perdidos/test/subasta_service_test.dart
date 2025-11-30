import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/Datos/models/subasta.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/models/exceptions.dart';
import 'package:objetos_perdidos/Datos/repositories/subastas_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/Datos/services/subasta_service.dart';

void main() {
  group('SubastaService - Pujas Iniciales', () {
    late Directory tmpSubastas;
    late Directory tmpProfiles;
    late SubastasRepository subastaRepo;
    late ProfilesRepository profileRepo;
    late SubastaService service;

    setUp(() {
      tmpSubastas = Directory.systemTemp.createTempSync('subastas_service_');
      tmpProfiles = Directory.systemTemp.createTempSync('profiles_service_');
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

    test('Validación 1: Lanza InsufficientFunds cuando usuario no tiene puntos suficientes',
        () async {
      // Setup: Crear usuario con 50 puntos y subasta
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 50);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 40);

      // Act & Assert: Intentar pujar 60 puntos sin tenerlos
      expect(
        () => service.pujaInicial(
          subastaId: subasta.subastaId,
          userId: 'user1',
          cantidad: 60,
        ),
        throwsA(isA<InsufficientFunds>()
            .having((e) => e.userId, 'userId', 'user1')
            .having((e) => e.requiredPoints, 'requiredPoints', 60)
            .having((e) => e.availablePoints, 'availablePoints', 50)),
      );
    });

    test('Validación 2: Lanza InvalidBidAmount cuando puja no supera la actual', () async {
      // Setup
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 100);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 50);

      // Act & Assert: Intentar pujar 40 (menos que actualPuja = 50)
      expect(
        () => service.pujaInicial(
          subastaId: subasta.subastaId,
          userId: 'user1',
          cantidad: 40,
        ),
        throwsA(isA<InvalidBidAmount>()
            .having((e) => e.bidAmount, 'bidAmount', 40.0)
            .having((e) => e.currentBidAmount, 'currentBidAmount', 50.0)),
      );
    });

    test('SubastaNotFound: Lanza cuando subasta no existe', () async {
      // Setup
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 100);

      // Act & Assert
      expect(
        () => service.pujaInicial(
          subastaId: 'nonexistent',
          userId: 'user1',
          cantidad: 60,
        ),
        throwsA(isA<SubastaNotFound>()),
      );
    });

    test('UserNotFound: Lanza cuando usuario no existe', () async {
      // Setup
      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 40);

      // Act & Assert
      expect(
        () => service.pujaInicial(
          subastaId: subasta.subastaId,
          userId: 'nonexistent',
          cantidad: 60,
        ),
        throwsA(isA<UserNotFound>()),
      );
    });

    test('Acción de Cobro: Descuenta puntos del usuario actual', () async {
      // Setup
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 100);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 40);

      // Act
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'user1',
        cantidad: 60,
      );

      // Assert: user1 debe tener 40 puntos restantes (100 - 60)
      final profiles = await profileRepo.listProfiles();
      final user1 = profiles.firstWhere((p) => p.nombre == 'user1');
      expect(user1.puntos, 40);
    });

    test('Persistencia: Subasta actualizada con nueva puja y mayorPostor', () async {
      // Setup
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 100);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 40);

      // Act
      final result = await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'user1',
        cantidad: 60,
      );

      // Assert: Verificar que la subasta fue actualizada en disco
      expect(result.actualPuja, 60);
      expect(result.mayorPostorId, 'user1');

      // Recargar desde disco para verificar persistencia
      final activas = await subastaRepo.getSubastasActivas();
      final reloaded = activas.firstWhere((s) => s.subastaId == subasta.subastaId);
      expect(reloaded.actualPuja, 60);
      expect(reloaded.mayorPostorId, 'user1');
    });

    test('Acción de Reembolso: Devuelve puntos al usuario anterior (Scenario: A -> B)', () async {
      // Setup: User A puja 60
      await profileRepo.createProfile(nombre: 'userA', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userA', 100);

      await profileRepo.createProfile(nombre: 'userB', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userB', 100);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 40);

      // Act 1: User A hace puja de 60
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userA',
        cantidad: 60,
      );

      // Verificar estado después de puja de A
      var profiles = await profileRepo.listProfiles();
      var userA = profiles.firstWhere((p) => p.nombre == 'userA');
      var userB = profiles.firstWhere((p) => p.nombre == 'userB');
      expect(userA.puntos, 40, reason: 'userA debe tener 40 después de pujar 60');
      expect(userB.puntos, 100, reason: 'userB debe mantener 100 (sin puja aún)');

      // Act 2: User B hace puja de 70 (supera a A)
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userB',
        cantidad: 70,
      );

      // Assert: Verificar reembolso a A y cobro a B
      profiles = await profileRepo.listProfiles();
      userA = profiles.firstWhere((p) => p.nombre == 'userA');
      userB = profiles.firstWhere((p) => p.nombre == 'userB');

      expect(userA.puntos, 100,
          reason: 'userA debe recuperar sus 60 puntos después de ser superado');
      expect(userB.puntos, 30,
          reason: 'userB debe tener 30 después de pujar 70 (100 - 70)');

      // Verificar que la subasta tiene a B como mayorPostor
      final activas = await subastaRepo.getSubastasActivas();
      final reloaded = activas.firstWhere((s) => s.subastaId == subasta.subastaId);
      expect(reloaded.mayorPostorId, 'userB');
      expect(reloaded.actualPuja, 70);
    });

    test('Acción de Reembolso: Cadena de múltiples pujas (A -> B -> C)', () async {
      // Setup: Tres usuarios
      await profileRepo.createProfile(nombre: 'userA', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userA', 100);

      await profileRepo.createProfile(nombre: 'userB', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userB', 100);

      await profileRepo.createProfile(nombre: 'userC', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('userC', 100);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 30);

      // Act 1: A puja 40
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userA',
        cantidad: 40,
      );

      // Act 2: B puja 50
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userB',
        cantidad: 50,
      );

      // Act 3: C puja 60
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'userC',
        cantidad: 60,
      );

      // Assert
      var profiles = await profileRepo.listProfiles();
      var userA = profiles.firstWhere((p) => p.nombre == 'userA');
      var userB = profiles.firstWhere((p) => p.nombre == 'userB');
      var userC = profiles.firstWhere((p) => p.nombre == 'userC');

      // A: 100 - 40 + 40 (reembolso) = 100
      expect(userA.puntos, 100, reason: 'userA debe tener 100 (sin cambios netos)');
      // B: 100 - 50 + 50 (reembolso) = 100
      expect(userB.puntos, 100, reason: 'userB debe tener 100 (sin cambios netos)');
      // C: 100 - 60 = 40
      expect(userC.puntos, 40, reason: 'userC debe tener 40 (60 puntos pujos)');

      // Verificar que la subasta tiene a C como mayorPostor
      final activas = await subastaRepo.getSubastasActivas();
      final reloaded = activas.firstWhere((s) => s.subastaId == subasta.subastaId);
      expect(reloaded.mayorPostorId, 'userC');
      expect(reloaded.actualPuja, 60);
    });

    test('Persistencia: Las 3 escrituras son secuenciales y seguras', () async {
      // Setup
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 200);

      await profileRepo.createProfile(nombre: 'user2', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user2', 200);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 50);

      // Act 1: User1 puja 100
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'user1',
        cantidad: 100,
      );

      // Act 2: User2 puja 150 (supera a user1)
      await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'user2',
        cantidad: 150,
      );

      // Assert: Verificar consistencia de todas las escrituras
      // 1. Subasta guardada correctamente
      var activas = await subastaRepo.getSubastasActivas();
      var currentSubasta = activas.firstWhere((s) => s.subastaId == subasta.subastaId);
      expect(currentSubasta.mayorPostorId, 'user2');
      expect(currentSubasta.actualPuja, 150);

      // 2. User1 profile guardado correctamente (dinero reembolsado)
      var profiles = await profileRepo.listProfiles();
      var user1 = profiles.firstWhere((p) => p.nombre == 'user1');
      expect(user1.puntos, 200,
          reason: 'user1 debe tener 200 después de ser reembolsado');

      // 3. User2 profile guardado correctamente (dinero deducido)
      var user2 = profiles.firstWhere((p) => p.nombre == 'user2');
      expect(user2.puntos, 50, reason: 'user2 debe tener 50 después de pujar 150');

      // Verificar que no hay inconsistencias (suma total de puntos)
      final totalPointsBefore = 200 + 200; // Inicial
      final totalPointsAfter = user1.puntos + user2.puntos + 150; // User2 tiene 150 pujos
      expect(totalPointsAfter, totalPointsBefore,
          reason: 'No debe haber pérdida de puntos en el sistema');
    });

    test('Validación: cantidad debe ser mayor que 0', () async {
      // Setup
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 100);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 40);

      // Act & Assert
      expect(
        () => service.pujaInicial(
          subastaId: subasta.subastaId,
          userId: 'user1',
          cantidad: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Integración: Puja exitosa con cantidad exacta igual a saldo disponible',
        () async {
      // Setup
      await profileRepo.createProfile(nombre: 'user1', tipo: Tipo.perfil);
      await profileRepo.addPointsForNombre('user1', 100);

      final subasta = await subastaRepo.crearSubasta(itemId: 'item-1', minPuj: 50);

      // Act: Pujar toda la cantidad disponible (100)
      final result = await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'user1',
        cantidad: 100,
      );

      // Assert
      expect(result.actualPuja, 100);
      expect(result.mayorPostorId, 'user1');

      final profiles = await profileRepo.listProfiles();
      final user1 = profiles.firstWhere((p) => p.nombre == 'user1');
      expect(user1.puntos, 0, reason: 'user1 debe tener 0 puntos después de pujar todo');
    });
  });
}
