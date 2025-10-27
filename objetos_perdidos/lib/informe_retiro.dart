import 'informe.dart';
import 'nota.dart';
import 'objeto_perdido.dart';
import 'perfil.dart';

class InformeRetiro extends Informe {
  Nota texto;

  InformeRetiro(super.titulo, super.objeto, super.usuario, this.texto);
}
