import 'perfil.dart';
import 'objeto_perdido.dart';

/// Clase de administrador que hereda de Perfil y fuerza `isAdmin = true`.
class Admin extends Perfil {
  Admin(String usuario) : super(usuario, 0, <ObjetoPerdido>[], isAdmin: true);
}
