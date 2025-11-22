import 'persona.dart';
import 'objeto_perdido.dart';

class Perfil extends Persona {
  int puntos;
  List<ObjetoPerdido> objetos;
  bool isAdmin; // indica si el perfil tiene privilegios de administrador

  Perfil(super.usuario, this.puntos, this.objetos, {this.isAdmin = false});
}
