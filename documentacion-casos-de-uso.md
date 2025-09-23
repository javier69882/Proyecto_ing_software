# Caso de Uso 1: Ver la Lista Principal de Objetos Perdidos (Feed)
## Actor Principal
### 1. Usuario

## Actores Involucrados e Intereses
### Usuario 
Quiere navegar fácilmente por los objetos perdidos mas relevantes en la aplicación, accediendo a ellos de manera intuitiva y sin esfuerzo extra

## Precondiciones
- La aplicación debe estar instalada y funcionando correctamente
- El usuario debe estar logeado con su cuenta UdeC
- La interfaz de usuario debe estar cargada completamente

## Postcondiciones (garantías de éxito)
- El usuario puede acceder exitosamente a las diferentes publicaciones que el sistema le despliega en el menú principal
- La navegación es fluida y sin errores

## Escenario principal de éxito (Flujo Básico)
1. El usuario se logea y accede a la navegacion
2. El sistema muestra la pantalla principal con los diferentes objetos extraviados a modo de lista navegable.
3. El usuario selecciona un post del feed principal
4. El sistema navega a la publicación correspondiente
5. El usuario puede ver el contenido de la publicación seleccionada
6. El usuario puede regresar al menú principal o navegar a otros objetos sugeridos
7. El sistema mantiene la consistencia en la navegación

## Extensiones (Flujos Alternativos)
1-7' Si hay problemas de conectividad, el sistema muestra un mensaje informativo
5' Muestra un mensaje de error si el contenido accedido no está disponible (borrado o editado)

---

# Caso de Uso 2: Filtrar Búsqueda
## Actor Principal
### 1. Usuario

## Actores Involucrados e Intereses
### Usuario
Quiere filtrar los resultados de busqueda para encontrar información especifica de manera precisa.

## Precondiciones
- El usuario debe estar en la sección de busqueda de la aplicación
- Debe existir contenido disponible para buscar
- Los filtros deben estar configurados en el sistema

## Postcondiciones (garantías de éxito)
- Los resultados mostrados corresponden a los criterios de filtrado seleccionados
- El usuario puede identificar fácilmente la información que busca
- Los filtros aplicados son visibles y pueden ser modificados

## Escenario principal de éxito (Flujo Básico)
1. El usuario accede a la función de busqueda
2. El usuario ingresa un filtro de busqueda por tipo de objeto
3. El sistema muestra los resultados iniciales
4. El usuario selecciona opciones de filtrado adicionales (categoría, fecha, tipo, etc.)
5. El sistema aplica los filtros seleccionados
6. El sistema muestra los resultados filtrados
7. El usuario puede seguir refinando más la busqueda o limpiar los filtros aplicados

## Extensiones (Flujos Alternativos)
2' Si no existe el filtro ingresado, el sistema muestra una lista en blanco
3-6' Si no hay objetos que coincidan con los filtros, se muestra la busqueda en blanco