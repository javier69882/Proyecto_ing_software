import 'informe.dart';
import 'nota.dart';
import 'objeto_perdido.dart';
import 'perfil.dart';

class InformeEntrega extends Informe {
  Nota texto;

  InformeEntrega(String titulo, ObjetoPerdido objeto, Perfil usuario, this.texto)
      : super(titulo, objeto, usuario);
}
