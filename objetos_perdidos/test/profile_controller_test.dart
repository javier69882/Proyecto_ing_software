import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';

void main() {
  group('ProfileController', () {
    test('select establece current y clear lo reinicia', () async {
      // crear un controlador con un repositorio temporal. el repo no se usa en select/clear
      // pero usamos un ProfilesRepository apuntando a un directorio temporal para aislar la prueba
      final tmp = Directory.systemTemp.createTempSync('pf_test');
      final repo = ProfilesRepository(baseDirectory: tmp);
      final controller = ProfileController(repo: repo);

      final record = ProfileRecord(id: '1', nombre: 'Test', tipo: Tipo.perfil);
      await controller.select(record);
      expect(controller.current, isNotNull);
      expect(controller.current!.usuario, 'Test');

      controller.clear();
      expect(controller.current, isNull);
    });
  });
}
