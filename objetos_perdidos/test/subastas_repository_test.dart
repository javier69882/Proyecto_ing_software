import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/Datos/models/subasta.dart';
import 'package:objetos_perdidos/Datos/repositories/subastas_repository.dart';

void main() {
  group('SubastasRepository', () {
    late Directory tmp;
    late SubastasRepository repo;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('subastas_repo_');
      repo = SubastasRepository(baseDirectory: tmp);
    });

    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('crearSubasta guarda archivo y usa minPuj como actualPuja', () async {
      final subasta = await repo.crearSubasta(itemId: 'item-1', minPuj: 50);
      expect(subasta.subastaId.isNotEmpty, isTrue);
      expect(subasta.actualPuja, 50);
      final dirPath = await repo.debugDirPath();
      final file = File('$dirPath${Platform.pathSeparator}${subasta.subastaId}.json');
      expect(await file.exists(), isTrue);
    });

    test('getSubastasActivas solo devuelve subastas con fecha futura', () async {
      final future = DateTime.now().add(const Duration(days: 3));
      final past = DateTime.now().subtract(const Duration(days: 1));

      final activa = await repo.crearSubasta(itemId: 'item-2', minPuj: 10, fechaFin: future);

      // Crear subasta expirada manualmente
      final expirada = Subasta(
        subastaId: 'expirada',
        itemId: 'item-3',
        minPuja: 5,
        actualPuja: 5,
        mayorPostorId: null,
        fechaFin: past,
      );
      final dirPath = await repo.debugDirPath();
      final fileExp = File('$dirPath${Platform.pathSeparator}expirada.json');
      await fileExp.writeAsString(expirada.toString(), flush: true);

      final activas = await repo.getSubastasActivas();
      expect(activas.any((s) => s.subastaId == activa.subastaId), isTrue);
      expect(activas.any((s) => s.subastaId == 'expirada'), isFalse);
    });
  });
}
