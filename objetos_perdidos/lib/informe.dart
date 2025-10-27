import 'objeto_perdido.dart';
import 'perfil.dart';

abstract class Informe {
  String titulo;
  ObjetoPerdido objeto;
  Perfil usuario;

  Informe(this.titulo, this.objeto, this.usuario);
}
