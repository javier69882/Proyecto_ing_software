import 'nota.dart';

class ObjetoPerdido {
  String categoria;
  Nota descripcion;
  DateTime fecha;
  String lugar; // lugar donde se encontró

  ObjetoPerdido(this.categoria, this.descripcion, this.fecha, this.lugar);

  Map<String, dynamic> toJson() => {
        'categoria': categoria,
        'descripcion': descripcion.texto,
        'descripcionHora': descripcion.hora.toIso8601String(),
        'fecha': fecha.toIso8601String(),
        'lugar': lugar,
      };

  static ObjetoPerdido fromJson(Map<String, dynamic> json) => ObjetoPerdido(
        (json['categoria'] as String?) ?? '',
        Nota(
          (json['descripcion'] as String?) ?? '',
          DateTime.tryParse((json['descripcionHora'] as String?) ?? '') ?? DateTime.now(),
        ),
        DateTime.tryParse((json['fecha'] as String?) ?? '') ?? DateTime.now(),
        (json['lugar'] as String?) ?? '',
      );
}
