import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/informes_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/publications_repository.dart';
import 'package:objetos_perdidos/Datos/repositories/subastas_repository.dart';
import 'package:objetos_perdidos/objeto_perdido.dart';
import 'package:objetos_perdidos/perfil.dart';
import 'package:objetos_perdidos/screen/crear_subasta_screen.dart';
import 'package:objetos_perdidos/ui/profile_selector.dart';
import 'package:objetos_perdidos/ui/publicaciones_feed.dart';

void main() {
  Directory tmpProject(String prefix) {
    final dir = Directory.systemTemp.createTempSync(prefix);
    File('${dir.path}${Platform.pathSeparator}pubspec.yaml').writeAsStringSync('name: dummy');
    return dir;
  }

  Future<void> overrideFecha(
    InformesRepository repo,
    String id,
    DateTime fecha,
  ) async {
    final dir = await repo.debugDirPath();
    final file = File('${dir}${Platform.pathSeparator}$id.json');
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    data['fechaCreacion'] = fecha.toIso8601String();
    await file.writeAsString(jsonEncode(data), flush: true);
  }

}
