# Semillas y pruebas para Perfiles

Este documento complementa `Uso_de_perfil.md` y describe las semillas de datos incluidas y las pruebas automatizadas disponibles.

Ubicación de semillas

- `lib/Datos/datos_perfil/profiles.json` contiene perfiles semilla (admin y comunes) que puedes usar para pruebas manuales.

Formato

Cada registro usa el formato JSON mínimo:

```json
{ "id": "<id>", "nombre": "<nombre>", "tipo": "admin|perfil" }
```

Pruebas automatizadas

- `test/profiles_persistence_test.dart` valida que `ProfilesRepository` persiste registros y que una nueva instancia del repositorio (simulando reinicio) puede recargarlos.

Flujo rápido: crear / seleccionar / cambiar perfil

1. Crear perfil
   - Desde la pantalla principal pulsa "Crear perfil".
   - Introduce nombre y tipo (admin o perfil).
   - El sistema guarda el registro en `lib/Datos/datos_perfil/profiles.json`.

2. Seleccionar perfil
   - Pulsa el icono de cambio de perfil en la AppBar.
   - Elige el perfil en la lista. La app actualiza el contexto (`ProfileController.current`) y propaga el cambio a la UI.

3. Cambiar de perfil / cerrar sesión
   - Repite el paso 2 para seleccionar otro perfil.
   - Para limpiar el contexto (logout) usa `ProfileController.clear()`.

Notas

- Las pruebas usan un directorio temporal y no modifican el archivo de semillas del proyecto.
- Puedes añadir más perfiles de prueba editando `lib/Datos/datos_perfil/profiles.json`.
