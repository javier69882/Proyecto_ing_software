import 'objeto_perdido.dart';
import 'perfil.dart';
import 'nota.dart';

/// Clase base para los distintos tipos de informes.
/// Se serializa a JSON y se almacena como archivo individual.
abstract class Informe {
  String id; // identificador único
  String titulo;
  ObjetoPerdido objeto; // objeto asociado
  Perfil admin; // perfil administrador que genera el informe
  DateTime fechaCreacion; // fecha del informe
  Nota? nota; // nota opcional (especialmente para retiro)

  Informe(
    this.id,
    this.titulo,
    this.objeto,
    this.admin,
    this.fechaCreacion, {
    this.nota,
  });

  String get tipo; // solo 'entrega' ahora

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'titulo': titulo,
        'objeto': objeto.toJson(),
        'admin': admin.usuario,
        'adminIsAdmin': admin.isAdmin,
        'fechaCreacion': fechaCreacion.toIso8601String(),
        if (this is InformeEntrega) 'entregadoPor': (this as InformeEntrega).entregadoPorUsuario,
        if (nota != null) 'nota': nota!.toJson(),
      };

  static Informe? fromJson(Map<String, dynamic> json, Perfil Function(String usuario) perfilResolver) {
    final tipo = (json['tipo'] as String?) ?? '';
    if (tipo != 'entrega') return null; // ignorar informes antiguos de retiro
    final objetoMap = (json['objeto'] as Map<String, dynamic>? ) ?? <String, dynamic>{};
    final adminUsuario = (json['admin'] as String?) ?? '';
    final perfil = perfilResolver(adminUsuario);
    perfil.isAdmin = (json['adminIsAdmin'] as bool?) ?? perfil.isAdmin;
    final notaMap = json['nota'] as Map<String, dynamic>?;
    final nota = notaMap == null ? null : Nota.fromJson(notaMap);
    final objeto = ObjetoPerdido.fromJson(objetoMap);
    return InformeEntrega(
      json['id'] as String? ?? '',
      json['titulo'] as String? ?? '',
      objeto,
      perfil,
      DateTime.tryParse(json['fechaCreacion'] as String? ?? '') ?? DateTime.now(),
      (json['entregadoPor'] as String?) ?? '',
      nota: nota,
    );
  }
}

class InformeEntrega extends Informe {
  String entregadoPorUsuario; // usuario que entregó el objeto (quien lo encontró)
  @override
  String get tipo => 'entrega';

  InformeEntrega(
    super.id,
    super.titulo,
    super.objeto,
    super.admin,
    super.fechaCreacion,
    this.entregadoPorUsuario, {
    super.nota,
  });
}

// InformeRetiro eliminado: solo se mantienen informes de entrega
