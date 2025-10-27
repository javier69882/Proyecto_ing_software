import 'persona.dart';
import 'objeto_perdido.dart';

class Perfil extends Persona {
  int puntos;
  List<ObjetoPerdido> objetos;

  Perfil(super.usuario, this.puntos, this.objetos);
}
