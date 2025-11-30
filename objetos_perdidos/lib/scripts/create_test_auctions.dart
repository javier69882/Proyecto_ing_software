import 'dart:io';
import 'dart:convert';
import 'package:objetos_perdidos/Datos/models/subasta.dart';
import 'package:objetos_perdidos/Datos/repositories/subastas_repository.dart';

/// Script para crear subastas de prueba basadas en los objetos perdidos.
/// Ejecutar desde: c:\Users\diego\Codigo\flutter\Proyecto_ing_software\objetos_perdidos
/// Comando: dart run lib/scripts/create_test_auctions.dart

Future<void> main() async {
  final repo = SubastasRepository();
  final ahora = DateTime.now();

  // Crear 4 subastas de prueba
  final subastas = [
    {
      'itemId': 'OBJ-BILLETERA-001',
      'titulo': 'Billetera azul de cuero',
      'minPuja': 50.0,
      'diasDuracion': 7, // Activa por 7 días
    },
    {
      'itemId': 'OBJ-ANILLO-001',
      'titulo': 'Anillo de oro con diamante',
      'minPuja': 100.0,
      'diasDuracion': 10, // Activa por 10 días
    },
    {
      'itemId': 'OBJ-LENTES-001',
      'titulo': 'Lentes de sol Ray-Ban',
      'minPuja': 30.0,
      'diasDuracion': 5, // Activa por 5 días
    },
    {
      'itemId': 'OBJ-RELOJ-001',
      'titulo': 'Reloj inteligente Apple Watch Serie 8',
      'minPuja': 150.0,
      'diasDuracion': 14, // Activa por 14 días
    },
  ];

  try {
    for (final subastaData in subastas) {
      final diasDuracion = subastaData['diasDuracion'] as int;
      final fechaFin = ahora.add(Duration(days: diasDuracion));

      final subasta = await repo.crearSubasta(
        itemId: subastaData['itemId'] as String,
        minPuj: subastaData['minPuja'] as double,
        fechaFin: fechaFin,
      );

      print('✓ Subasta creada: ${subastaData['titulo']}');
      print('  ID: ${subasta.subastaId}');
      print('  Puja Mínima: ${subasta.minPuja} pts');
      print('  Válida hasta: ${subastaData['diasDuracion']} días');
      print('');
    }

    final subastaDir = await repo.getSubastasDir();
    print('✅ Se crearon 4 subastas de prueba exitosamente');
    print('Guardadas en: ${subastaDir.path}\n');
  } catch (e) {
    print('❌ Error: $e');
    rethrow;
  }
}
