import 'informe.dart';
import 'nota.dart';

class InformeRetiro extends Informe {
  Nota texto;

  InformeRetiro(super.titulo, super.objeto, super.usuario, this.texto);
}
