# Perfiles – Persistencia y uso con Persona/Perfil (sin UI extra)

Este módulo persiste perfiles como registros mínimos `{ id, nombre, tipo }` y permite convertirlos a tus **clases de dominio**:
- `tipo == "admin"` → `Admin(nombre)`
- `tipo == "perfil"` → `Perfil(nombre, 0, [])`  *(puntos en 0 y lista de objetos vacía)*

> **Ubicación (desktop):** `lib/Datos/datos_perfil/profiles.json`  
> **Web:** aun no sirve
---

## Archivos involucrados

- `lib/Datos/models/profile_record.dart`  
  - `enum Tipo { perfil, admin }`
  - `class ProfileRecord { id, nombre, tipo, toJson, fromJson, encodeList, decodeList, toPersona() }`
- `lib/Datos/repositories/profiles_repository.dart`  
  - (Desktop) guarda en `lib/Datos/datos_perfil/profiles.json`  
 



---

## API pública

```dart
// DTO
class ProfileRecord {
  final String id;
  final String nombre;
  final Tipo tipo;

  Persona toPersona(); // Admin(nombre) o Perfil(nombre, 0, [])
}

// Repositorio
class ProfilesRepository {
  Future<List<ProfileRecord>> listProfiles();
  Future<ProfileRecord> createProfile({required String nombre, required Tipo tipo});
  Future<String> debugFilePath(); // ruta efectiva (desktop) o descripción (web)
}


crear perfiles

import 'package:objetos_perdidos/Datos/models/profile_record.dart';
import 'package:objetos_perdidos/Datos/repositories/profiles_repository.dart';

final repo = ProfilesRepository();

await repo.createProfile(nombre: 'María', tipo: Tipo.perfil); // común
await repo.createProfile(nombre: 'Oficina UdeC', tipo: Tipo.admin); // admin



Listar registros y convertir a Persona (Admin / Perfil)

final registros = await repo.listProfiles();

// Convertir a tus clases de dominio
final personas = registros.map((r) => r.toPersona()).toList();

// Diferenciar por tipo en runtime
for (final p in personas) {
  if (p is Admin) {
    print('Es Admin: ${p.usuario}');
  } else if (p is Perfil) {
    print('Es Perfil común: ${p.usuario} (puntos=${p.puntos}, objetos=${p.objetos.length})');
  }
}
