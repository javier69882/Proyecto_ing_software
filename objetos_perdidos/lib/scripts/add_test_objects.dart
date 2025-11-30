import 'dart:io';
import 'dart:convert';
import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';

/// Script para agregar objetos perdidos de prueba para subastas.
/// Ejecutar desde: c:\Users\diego\Codigo\flutter\Proyecto_ing_software\objetos_perdidos
/// Comando: dart run lib/scripts/add_test_objects.dart

Future<void> main() async {
  final repo = ProfilesRepository();
  final profilesFile = await repo.getProfilesFile();
  
  // Leer perfiles actuales
  final profiles = await repo.listProfiles();
  if (profiles.isEmpty) {
    print('❌ No hay perfiles en el sistema. Crea un admin primero.');
    return;
  }

  final ahora = DateTime.now();

  // Crear 4 objetos perdidos de prueba
  final objetos = [
    {
      'id': 'OBJ-BILLETERA-001',
      'titulo': 'Billetera azul de cuero',
      'categoria': 'Accesorios',
      'descripcion': 'Billetera azul oscuro de cuero con iníciales JM grabadas',
      'fecha': DateTime(ahora.year, ahora.month - 7, ahora.day).toIso8601String(), // Hace 7 meses
      'lugar': 'Estación de Metro Central',
    },
    {
      'id': 'OBJ-ANILLO-001',
      'titulo': 'Anillo de oro con diamante',
      'categoria': 'Joyas',
      'descripcion': 'Anillo de oro 18 quilates con diamante en centro. Sentimental.',
      'fecha': DateTime(ahora.year, ahora.month - 8, ahora.day).toIso8601String(), // Hace 8 meses
      'lugar': 'Centro Comercial Plaza Mayor',
    },
    {
      'id': 'OBJ-LENTES-001',
      'titulo': 'Lentes de sol Ray-Ban',
      'categoria': 'Accesorios',
      'descripcion': 'Gafas de sol Ray-Ban Aviador, cristales azules espejados',
      'fecha': DateTime(ahora.year, ahora.month - 3, ahora.day).toIso8601String(), // Hace 3 meses
      'lugar': 'Parque Principal',
    },
    {
      'id': 'OBJ-RELOJ-001',
      'titulo': 'Reloj inteligente Apple Watch Serie 8',
      'categoria': 'Electrónica',
      'descripcion': 'Apple Watch Series 8 plateado con correa negra',
      'fecha': DateTime(ahora.year, ahora.month - 2, ahora.day).toIso8601String(), // Hace 2 meses
      'lugar': 'Terminal de Buses Norte',
    },
  ];

  try {
    // Actualizar el archivo de perfiles con los objetos agregados
    String contenido = await profilesFile.readAsString();
    
    final List<dynamic> perfilesData = jsonDecode(contenido);
    
    // Agregar objetos al primer perfil (o al admin si existe)
    if (perfilesData.isNotEmpty) {
      final firstProfile = perfilesData[0] as Map<String, dynamic>;
      
      // Inicializar array de objetos si no existe
      if (!firstProfile.containsKey('objetos')) {
        firstProfile['objetos'] = [];
      }
      
      // Agregar los 4 objetos
      for (final obj in objetos) {
        firstProfile['objetos'].add(obj);
      }
      
      // Guardar cambios
      await profilesFile.writeAsString(jsonEncode(perfilesData), flush: true);
      
      print('✅ Se agregaron 4 objetos de prueba exitosamente:');
      for (final obj in objetos) {
        print('  ✓ ${obj['titulo']} (${obj['categoria']})');
      }
      print('\nObjetos guardados en: ${profilesFile.path}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
