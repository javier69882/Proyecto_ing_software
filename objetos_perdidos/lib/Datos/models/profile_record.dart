import 'dart:convert';

import 'package:objetos_perdidos/persona.dart' show Persona;
import 'package:objetos_perdidos/perfil.dart' show Perfil;
import 'package:objetos_perdidos/admin.dart' show Admin;
import 'package:objetos_perdidos/objeto_perdido.dart' show ObjetoPerdido;
/// Tipo de usuario persistido en JSON.
enum Tipo { perfil, admin }

Tipo tipoFromString(String s) {
  switch (s.toLowerCase()) {
    case 'admin':
      return Tipo.admin;
    case 'perfil':
    default:
      return Tipo.perfil;
  }
}

String tipoToString(Tipo t) => t == Tipo.admin ? 'admin' : 'perfil';

/// DTO minimalista para persistencia en profiles.json
/// Formato: { id, nombre, tipo }
class ProfileRecord {
  final String id;
  final String nombre;
  final Tipo tipo;
  final int puntos;

  ProfileRecord({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.puntos = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipoToString(tipo),
        'puntos': puntos,
      };

  factory ProfileRecord.fromJson(Map<String, dynamic> json) {
    final tipoStr = (json['tipo'] as String?) ?? 'perfil';
    return ProfileRecord(
      id: (json['id'] as String?) ?? '',
      nombre: (json['nombre'] as String?) ?? '',
      tipo: tipoFromString(tipoStr),
      puntos: (json['puntos'] is int)
          ? (json['puntos'] as int)
          : int.tryParse((json['puntos']?.toString() ?? '0')) ?? 0,
    );
  }

  /// Construye una instancia de dominio usando tus clases existentes.
  Persona toPersona() {
    switch (tipo) {
      case Tipo.admin:
        return Admin(nombre);
      case Tipo.perfil:
      default:
        return Perfil(nombre, puntos, <ObjetoPerdido>[]);
    }
  }

  ProfileRecord copyWith({String? id, String? nombre, Tipo? tipo, int? puntos}) {
    return ProfileRecord(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      puntos: puntos ?? this.puntos,
    );
  }

  /// Decodifica una lista desde string JSON. JSON inválido => []
  static List<ProfileRecord> decodeList(String source) {
    if (source.trim().isEmpty) return <ProfileRecord>[];
    try {
      final dynamic data = jsonDecode(source);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ProfileRecord.fromJson)
            .toList();
      }
    } catch (_) {
      // JSON inválido => []
    }
    return <ProfileRecord>[];
  }

  /// Codifica una lista a string JSON.
  static String encodeList(List<ProfileRecord> records) {
    final list = records.map((e) => e.toJson()).toList();
    return jsonEncode(list);
  }
}
