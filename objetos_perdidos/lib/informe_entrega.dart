import 'informe.dart';
import 'nota.dart';

class InformeEntrega extends Informe {
  Nota texto;

  InformeEntrega(super.titulo, super.objeto, super.usuario, this.texto);
}
