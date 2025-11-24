class Nota {
  String texto;
  DateTime hora;

  Nota(this.texto, this.hora);
  factory Nota.ahora(String texto) => Nota(texto, DateTime.now());

  Map<String, dynamic> toJson() => {
        'texto': texto,
        'hora': hora.toIso8601String(),
      };

  static Nota fromJson(Map<String, dynamic> json) => Nota(
        (json['texto'] as String?) ?? '',
        DateTime.tryParse((json['hora'] as String?) ?? '') ?? DateTime.now(),
      );
}