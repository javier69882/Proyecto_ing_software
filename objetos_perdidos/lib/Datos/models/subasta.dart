import 'dart:convert';

class Subasta {
  String subastaId;
  String itemId;
  double minPuja;
  double actualPuja;
  String? mayorPostorId;
  DateTime fechaFin;

  Subasta({
    required this.subastaId,
    required this.itemId,
    required this.minPuja,
    required this.actualPuja,
    required this.mayorPostorId,
    required this.fechaFin,
  });

  bool get activa => fechaFin.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'subastaId': subastaId,
        'itemId': itemId,
        'minPuja': minPuja,
        'actualPuja': actualPuja,
        'mayorPostorId': mayorPostorId,
        'fechaFin': fechaFin.toIso8601String(),
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
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
