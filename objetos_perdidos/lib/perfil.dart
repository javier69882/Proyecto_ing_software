import 'persona.dart';
import 'objeto_perdido.dart';

class Perfil extends Persona {
  int puntos;
  List<ObjetoPerdido> objetos;

  Perfil(String usuario, this.puntos, this.objetos) : super(usuario);
}
