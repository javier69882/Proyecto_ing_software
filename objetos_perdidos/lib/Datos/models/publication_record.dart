import 'dart:convert';

// esta clase representa un registro de publicación de un objeto perdido
class PublicationRecord {
  final String id;
  final String titulo;
  final String descripcion;
  final String categoria;
  final String fechaIso; // Fecha en formato ISO 8601 (String)
  final String lugar;
  final String autorId;
  final String autorNombre;

  // constructor
  PublicationRecord({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.fechaIso,
    required this.lugar,
    required this.autorId,
    required this.autorNombre,
  });

  // convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'categoria': categoria,
        'fechaIso': fechaIso,
        'lugar': lugar,
        'autorId': autorId,
        'autorNombre': autorNombre,
      };

  // crea una instancia a partir de un mapa JSON
  factory PublicationRecord.fromJson(Map<String, dynamic> json) => PublicationRecord(
        id: (json['id'] as String?) ?? '',
        titulo: (json['titulo'] as String?) ?? '',
        descripcion: (json['descripcion'] as String?) ?? '',
        categoria: (json['categoria'] as String?) ?? '',
        fechaIso: (json['fechaIso'] as String?) ?? DateTime.now().toIso8601String(),
        lugar: (json['lugar'] as String?) ?? '',
        autorId: (json['autorId'] as String?) ?? '',
        autorNombre: (json['autorNombre'] as String?) ?? '',
      );

  // decodifica una lista de registros de publicación desde la cadena JSON
  static List<PublicationRecord> decodeList(String source) {
    if (source.trim().isEmpty) return <PublicationRecord>[];
    try {
      final dynamic data = jsonDecode(source);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(PublicationRecord.fromJson)
            .toList();
      }
    } catch (_) {}
    return <PublicationRecord>[];
  }
  
  // lo mismo al reves
  static String encodeList(List<PublicationRecord> records) {
    final list = records.map((e) => e.toJson()).toList();
    return jsonEncode(list);
  }
}
