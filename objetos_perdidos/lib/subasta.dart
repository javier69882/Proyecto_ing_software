import 'objeto_perdido.dart';
import 'perfil.dart';

class Subasta {
  ObjetoPerdido objeto;
  DateTime tiempo;
  List<Perfil> participantes;
  Perfil? ganador;

  Subasta(this.objeto, this.tiempo, this.participantes, [this.ganador]);
}
