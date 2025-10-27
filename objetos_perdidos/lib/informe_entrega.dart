import 'informe.dart';
import 'nota.dart';
import 'objeto_perdido.dart';
import 'perfil.dart';

class InformeEntrega extends Informe {
  Nota texto;

  InformeEntrega(super.titulo, super.objeto, super.usuario, this.texto);
}
