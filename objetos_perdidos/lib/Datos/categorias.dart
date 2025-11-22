/// Lista centralizada de categorías válidas para objetos perdidos y publicaciones.
/// Añade/ordena según tus necesidades; mantener consistencia evita duplicados.
const List<String> kCategorias = <String>[
  'Electrónica',
  'Documentos',
  'Ropa',
  'Accesorios',
  'Otros',
];

/// Normaliza un texto libre a la primera coincidencia exacta dentro de [kCategorias].
/// Si no coincide, retorna 'Otros'.
String normalizarCategoria(String? raw) {
  if (raw == null) return 'Otros';
  final buscada = raw.trim();
  for (final c in kCategorias) {
    if (c.toLowerCase() == buscada.toLowerCase()) return c;
  }
  return 'Otros';
}
