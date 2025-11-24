import 'nota.dart';

class ObjetoPerdido {
  // Identificador lógico del objeto perdido.
  String id;

  String categoria;
  Nota descripcion;
  DateTime fecha;
  String lugar;


  ObjetoPerdido(
    this.categoria,
    this.descripcion,
    this.fecha,
    this.lugar, {
    String? id,
  }) : id = id ?? _generarId(categoria, fecha);

  // Genera un id por defecto a partir de la fecha y la categoría.
  static String _generarId(String categoria, DateTime fecha) {
    final datePart =
        '${fecha.year.toString().padLeft(4, '0')}${fecha.month.toString().padLeft(2, '0')}${fecha.day.toString().padLeft(2, '0')}';
    final timePart =
        '${fecha.hour.toString().padLeft(2, '0')}${fecha.minute.toString().padLeft(2, '0')}${fecha.second.toString().padLeft(2, '0')}';
    return 'OBJ-$datePart-$timePart-${fecha.microsecondsSinceEpoch}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoria': categoria,
        'descripcion': descripcion.texto,
        'descripcionHora': descripcion.hora.toIso8601String(),
        'fecha': fecha.toIso8601String(),
        'lugar': lugar,
      };

  static ObjetoPerdido fromJson(Map<String, dynamic> json) {
    final fecha = DateTime.tryParse((json['fecha'] as String?) ?? '') ?? DateTime.now();
    final categoria = (json['categoria'] as String?) ?? '';

    final descripcionTexto = (json['descripcion'] as String?) ?? '';
    final descripcionHora = DateTime.tryParse((json['descripcionHora'] as String?) ?? '') ?? fecha;

    final idJson = json['id'] as String?;
    final id = (idJson == null || idJson.isEmpty)
        ? _generarId(categoria, fecha)
        : idJson;

    return ObjetoPerdido(
      categoria,
      Nota(descripcionTexto, descripcionHora),
      fecha,
      (json['lugar'] as String?) ?? '',
      id: id,
    );
  }
}