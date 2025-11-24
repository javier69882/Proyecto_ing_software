import 'persona.dart';
import 'objeto_perdido.dart';


class Perfil extends Persona {
  // Puntos acumulados por devolver objetos
  int puntos;

  // Objetos asociados a este perfil
  List<ObjetoPerdido> objetos;

  // Indica si el perfil tiene privilegios de administrador.
  bool isAdmin;

  Perfil(
    super.usuario,
    this.puntos,
    this.objetos, {
    this.isAdmin = false,
  });

  // Alias conveniente para usar este perfil como `usuarioId` en informes.
  String get id => usuario;
}