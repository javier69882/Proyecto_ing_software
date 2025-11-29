import 'objeto_perdido.dart';
import 'perfil.dart';
import 'nota.dart';

// Clase base para los distintos tipos de informes
abstract class Informe {
  String id;              // identificador único
  String titulo;          // título del informe
  ObjetoPerdido objeto;   // objeto asociado
  Perfil admin;           // perfil administrador que genera el informe
  DateTime fechaCreacion; // fecha del informe
  Nota? nota;             // nota

  Informe(
    this.id,
    this.titulo,
    this.objeto,
    this.admin,
    this.fechaCreacion, {
    this.nota,
  });

  // entrega o retiro
  String get tipo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'titulo': titulo,
        'objeto': objeto.toJson(),
        'admin': admin.usuario,
        'adminIsAdmin': admin.isAdmin,
        'fechaCreacion': fechaCreacion.toIso8601String(),
        if (this is InformeEntrega)
          ...{
            'entregadoPor': (this as InformeEntrega).entregadoPorUsuario,
            if ((this as InformeEntrega).retiroId != null)
              'retiroId': (this as InformeEntrega).retiroId,
            if ((this as InformeEntrega).retiradoPor != null)
              'retiradoPor': (this as InformeEntrega).retiradoPor,
            if ((this as InformeEntrega).retiradoFecha != null)
              'retiradoFecha':
                  (this as InformeEntrega).retiradoFecha!.toIso8601String(),
          },
        if (this is InformeRetiro)
          'retiradoPor': (this as InformeRetiro).retiradoPorUsuario,
        if (nota != null) 'nota': nota!.toJson(),
      };

  // Reconstruye un Informe desde JSON.
  static Informe? fromJson(
    Map<String, dynamic> json,
    Perfil Function(String usuario) perfilResolver,
  ) {
    final tipo = (json['tipo'] as String?) ?? '';

    final objetoMap =
        (json['objeto'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final adminUsuario = (json['admin'] as String?) ?? '';
    final perfil = perfilResolver(adminUsuario);
    perfil.isAdmin = (json['adminIsAdmin'] as bool?) ?? perfil.isAdmin;

    final notaMap = json['nota'] as Map<String, dynamic>?;
    final nota = notaMap == null ? null : Nota.fromJson(notaMap);
    final objeto = ObjetoPerdido.fromJson(objetoMap);

    final id = json['id'] as String? ?? '';
    final titulo = json['titulo'] as String? ?? '';
    final fecha = DateTime.tryParse(
          json['fechaCreacion'] as String? ?? '',
        ) ??
        DateTime.now();

    switch (tipo) {
      case 'entrega':
        return InformeEntrega(
          id,
          titulo,
          objeto,
          perfil,
          fecha,
          (json['entregadoPor'] as String?) ?? '',
          retiroId: json['retiroId'] as String?,
          retiradoPor: json['retiradoPor'] as String?,
          retiradoFecha: DateTime.tryParse(
            (json['retiradoFecha'] as String?) ?? '',
          ),
          nota: nota,
        );
      case 'retiro':
        return InformeRetiro(
          id,
          titulo,
          objeto,
          perfil,
          fecha,
          (json['retiradoPor'] as String?) ?? '',
          nota: nota,
        );
      default:
        return null;
    }
  }
}

// Informe generado cuando el objeto es entregado a la oficina por la persona que lo encontró
class InformeEntrega extends Informe {
  String entregadoPorUsuario; // usuario que entregó el objeto
  String? retiroId;
  String? retiradoPor;
  DateTime? retiradoFecha;

  @override
  String get tipo => 'entrega';

  InformeEntrega(
    super.id,
    super.titulo,
    super.objeto,
    super.admin,
    super.fechaCreacion,
    this.entregadoPorUsuario, {
    this.retiroId,
    this.retiradoPor,
    this.retiradoFecha,
    super.nota,
  });

  bool get estaRetirado => retiroId != null;
}

// Informe generado cuando el objeto se devuelve al dueño.
class InformeRetiro extends Informe {
  /// Nombre del dueño que retira el objeto.
  String retiradoPorUsuario;

  @override
  String get tipo => 'retiro';

  InformeRetiro(
    super.id,
    super.titulo,
    super.objeto,
    super.admin,
    super.fechaCreacion,
    this.retiradoPorUsuario, {
    super.nota,
  });
}
