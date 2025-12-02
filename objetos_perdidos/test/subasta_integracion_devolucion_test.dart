import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/subastas_repository.dart';
import 'package:objetos_perdidos/Datos/services/subasta_service.dart';
import 'package:objetos_perdidos/objeto_perdido.dart';
import 'package:objetos_perdidos/perfil.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart';

void main() {
  test('flujo devolucion → puntos → puja → cierre integra repos temporales', () async {
    final base = Directory.systemTemp.createTempSync('flow_devolucion_');
    try {
      final profilesRepo = ProfilesRepository(baseDirectory: base);
      final informesRepo = InformesRepository(baseDirectory: base);
      final subastaRepo = SubastasRepository(baseDirectory: base);
      final service = SubastaService(
        subastaRepository: subastaRepo,
        profileRepository: profilesRepo,
      );

      final admin = Perfil('admin-flow', 0, <ObjetoPerdido>[], isAdmin: true);

      await profilesRepo.createProfile(nombre: 'Juan Entregador', tipo: Tipo.perfil);
      await profilesRepo.createProfile(nombre: 'Comprador', tipo: Tipo.perfil);

      final entrega = await informesRepo.createInformeEntrega(
        admin: admin,
        titulo: 'Entrega mochila',
        categoria: 'mochila',
        descripcion: 'entregada en guardia',
        lugar: 'hall',
        entregadoPorUsuario: 'Juan Entregador',
      );

      await informesRepo.createInformeRetiro(
        admin: admin,
        objeto: entrega.objeto,
        titulo: 'Retiro mochila',
        notaTexto: 'dueño identificado',
        retiradoPorUsuario: 'Propietario legitimo',
      );

      var perfiles = await profilesRepo.listProfiles();
      final juan = perfiles.firstWhere((p) => p.nombre == 'Juan Entregador');
      final puntosGanados = juan.puntos;
      expect(puntosGanados, InformesRepository.kPuntosPorEntrega);

      final subasta = await subastaRepo.crearSubasta(
        itemId: 'obj-subasta',
        minPuj: 5,
      );

      final resultado = await service.pujaInicial(
        subastaId: subasta.subastaId,
        userId: 'Juan Entregador',
        cantidad: puntosGanados,
      );

      expect(resultado.mayorPostorId, 'Juan Entregador');
      expect(resultado.actualPuja, puntosGanados.toDouble());

      perfiles = await profilesRepo.listProfiles();
      final juanTrasPuja = perfiles.firstWhere((p) => p.nombre == 'Juan Entregador');
      expect(juanTrasPuja.puntos, 0,
          reason: 'Los puntos quedan bloqueados mientras lidera la subasta');

      final cerrada = await service.cerrarSubastaManual(subastaId: subasta.subastaId);
      expect(cerrada.cerrada, isTrue);
      expect(cerrada.ganadorId, 'Juan Entregador');

      final controller = ProfileController(repo: profilesRepo);
      await controller.refresh();
      await controller.select(
        controller.records.firstWhere((r) => r.nombre == 'Juan Entregador'),
      );
      expect((controller.current as Perfil).puntos, 0,
          reason: 'El saldo visible del usuario coincide tras cerrar la subasta');
    } finally {
      try {
        base.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
