import 'dart:convert';

class Subasta {
  String subastaId;
  String itemId;
  double minPuja;
  double actualPuja;
  String? mayorPostorId;
  DateTime fechaFin;
  bool cerrada;
  String? ganadorId;
  DateTime? fechaCierre;

  Subasta({
    required this.subastaId,
    required this.itemId,
    required this.minPuja,
    required this.actualPuja,
    required this.mayorPostorId,
    required this.fechaFin,
    this.cerrada = false,
    this.ganadorId,
    this.fechaCierre,
  });

  bool get activa => !cerrada && fechaFin.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'subastaId': subastaId,
        'itemId': itemId,
        'minPuja': minPuja,
        'actualPuja': actualPuja,
        'mayorPostorId': mayorPostorId,
        'fechaFin': fechaFin.toIso8601String(),
        'cerrada': cerrada,
        'ganadorId': ganadorId,
        'fechaCierre': fechaCierre?.toIso8601String(),
      };

  factory Subasta.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return Subasta(
      subastaId: (json['subastaId'] as String?) ?? '',
      itemId: (json['itemId'] as String?) ?? '',
      minPuja: _toDouble(json['minPuja']),
      actualPuja: _toDouble(json['actualPuja']),
      mayorPostorId: json['mayorPostorId'] as String?,
      fechaFin: DateTime.tryParse((json['fechaFin'] as String?) ?? '') ?? DateTime.now(),
      cerrada: (json['cerrada'] as bool?) ?? false,
      ganadorId: json['ganadorId'] as String?,
      fechaCierre: DateTime.tryParse((json['fechaCierre'] as String?) ?? ''),
    );
  }

  Subasta copyWith({
    String? subastaId,
    String? itemId,
    double? minPuja,
    double? actualPuja,
    String? mayorPostorId,
    DateTime? fechaFin,
    bool? cerrada,
    String? ganadorId,
    DateTime? fechaCierre,
  }) {
    return Subasta(
      subastaId: subastaId ?? this.subastaId,
      itemId: itemId ?? this.itemId,
      minPuja: minPuja ?? this.minPuja,
      actualPuja: actualPuja ?? this.actualPuja,
      mayorPostorId: mayorPostorId ?? this.mayorPostorId,
      fechaFin: fechaFin ?? this.fechaFin,
      cerrada: cerrada ?? this.cerrada,
      ganadorId: ganadorId ?? this.ganadorId,
      fechaCierre: fechaCierre ?? this.fechaCierre,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
