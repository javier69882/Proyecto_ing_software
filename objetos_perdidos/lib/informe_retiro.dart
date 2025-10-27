import 'informe.dart';
import 'nota.dart';
import 'objeto_perdido.dart';
import 'perfil.dart';

class InformeRetiro extends Informe {
  Nota texto;

  InformeRetiro(String titulo, ObjetoPerdido objeto, Perfil usuario, this.texto)
      : super(titulo, objeto, usuario);
}
