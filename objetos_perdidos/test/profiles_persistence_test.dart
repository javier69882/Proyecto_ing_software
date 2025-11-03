import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';

void main() {
  test('ProfilesRepository persiste y recarga registros entre instancias', () async {
    final tmp = Directory.systemTemp.createTempSync('pf_seed_test');
    try {
      // repo1 crea dos perfiles
      final repo1 = ProfilesRepository(baseDirectory: tmp);
      final p1 = await repo1.createProfile(nombre: 'Seed Admin', tipo: Tipo.admin);
      final p2 = await repo1.createProfile(nombre: 'Seed User', tipo: Tipo.perfil);

      // Simular reinicio creando otra instancia apuntando al mismo directorio
      final repo2 = ProfilesRepository(baseDirectory: tmp);
      final list = await repo2.listProfiles();

      // Deben existir al menos los dos que creamos
      expect(list.any((r) => r.nombre == p1.nombre), isTrue);
      expect(list.any((r) => r.nombre == p2.nombre), isTrue);
    } finally {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
