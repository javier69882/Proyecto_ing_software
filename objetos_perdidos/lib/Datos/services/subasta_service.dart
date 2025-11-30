import 'dart:io';
import 'dart:convert';
import '../models/subasta.dart';
import '../models/profile_record.dart';
import '../models/exceptions.dart';
import '../repositories/subastas_repository.dart';
import '../repositories/profiles_repository.dart';

/// Servicio de lógica de negocio para realizar pujas en subastas.
///
/// Maneja:
/// - Validación de saldo del usuario
/// - Validación de que la puja supera la anterior
/// - Cobro inmediato de puntos al usuario ganador actual
/// - Reembolso de puntos al usuario anterior si existía
/// - Persistencia atómica de cambios (Subasta, Usuario actual, Usuario anterior)
///
/// El modelo es de "pago por adelantado" para asegurar que el usuario ganador
/// siempre tenga los puntos comprometidos y evitar fraudes al cerrar la subasta.
class SubastaService {
  final SubastasRepository _subastaRepo;
  final ProfilesRepository _profileRepo;

  SubastaService({
    required SubastasRepository subastaRepository,
    required ProfilesRepository profileRepository,
  })  : _subastaRepo = subastaRepository,
        _profileRepo = profileRepository;

  /// Realiza una puja inicial en una subasta.
  ///
  /// Parámetros:
  /// - [subastaId]: ID de la subasta
  /// - [userId]: ID/nombre del usuario que realiza la puja
  /// - [cantidad]: Cantidad de puntos a pujar (debe ser entero)
  ///
  /// Validaciones:
  /// 1. El usuario debe tener al menos [cantidad] puntos (levanta InsufficientFunds)
  /// 2. La [cantidad] debe ser mayor que la puja actual (levanta InvalidBidAmount)
  ///
  /// Acciones (si pasa validaciones):
  /// 1. Carga el estado actual de la subasta
  /// 2. Descuenta los puntos del usuario actual
  /// 3. Si existe un mayorPostor anterior, le reembolsa sus puntos
  /// 4. Actualiza la subasta con nueva puja y nuevo mayorPostor
  /// 5. Persiste los cambios de forma secuencial y segura
  ///
  /// Lanzamientos:
  /// - [InsufficientFunds]: Si el usuario no tiene suficientes puntos
  /// - [InvalidBidAmount]: Si la puja no supera la actual
  /// - [SubastaNotFound]: Si la subasta no existe
  /// - [UserNotFound]: Si el usuario no existe en los perfiles
  /// - [PersistenceError]: Si hay error al guardar cambios
  Future<Subasta> pujaInicial({
    required String subastaId,
    required String userId,
    required int cantidad,
  }) async {
    if (cantidad <= 0) {
      throw ArgumentError('cantidad debe ser mayor que 0');
    }

    // 1. Cargar subasta
    final subasta = await _loadSubasta(subastaId);

    // 2. Validación 1: Saldo del usuario
    final userProfile = await _loadUserProfile(userId);
    if (userProfile.puntos < cantidad) {
      throw InsufficientFunds(
        userId: userId,
        requiredPoints: cantidad,
        availablePoints: userProfile.puntos,
      );
    }

    // 3. Validación 2: La puja debe ser mayor que la actual
    if (cantidad <= subasta.actualPuja.toInt()) {
      throw InvalidBidAmount(
        bidAmount: cantidad.toDouble(),
        currentBidAmount: subasta.actualPuja,
        subastaId: subastaId,
      );
    }

    // 4. Preparar cambios
    final previousBidder = subasta.mayorPostorId;
    final previousBidAmount = subasta.actualPuja.toInt();

    // Actualizar subasta
    final updatedSubasta = Subasta(
      subastaId: subasta.subastaId,
      itemId: subasta.itemId,
      minPuja: subasta.minPuja,
      actualPuja: cantidad.toDouble(),
      mayorPostorId: userId,
      fechaFin: subasta.fechaFin,
    );

    // Actualizar perfil del usuario actual (descuentar puntos)
    final updatedCurrentUser = userProfile.copyWith(
      puntos: userProfile.puntos - cantidad,
    );

    // 5. Persistencia secuencial y segura
    try {
      // Primero: guardar cambios de la subasta
      await _saveSubasta(updatedSubasta);

      // Segundo: guardar cambios del usuario actual (descuento)
      await _saveUserProfile(updatedCurrentUser);

      // Tercero: si había un mayor postor anterior, reembolsarle
      if (previousBidder != null && previousBidder.isNotEmpty) {
        final previousUserProfile = await _loadUserProfile(previousBidder);
        final refundedUser = previousUserProfile.copyWith(
          puntos: previousUserProfile.puntos + previousBidAmount,
        );
        await _saveUserProfile(refundedUser);
      }

      return updatedSubasta;
    } catch (e) {
      // Si algo falla, intentar recuperar (rollback best-effort)
      throw PersistenceError(
        'Error al guardar cambios de puja para $subastaId: $e',
        e,
      );
    }
  }

  /// Carga una subasta desde el repositorio.
  Future<Subasta> _loadSubasta(String subastaId) async {
    try {
      final subastaDir = await _subastaRepo.getSubastasDir();
      final file = File('${subastaDir.path}${Platform.pathSeparator}$subastaId.json');

      if (!await file.exists()) {
        throw SubastaNotFound(subastaId);
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        throw SubastaNotFound(subastaId);
      }

      final json = jsonDecode(content) as Map<String, dynamic>;
      return Subasta.fromJson(json);
    } on SubastaNotFound {
      rethrow;
    } catch (e) {
      throw PersistenceError(
        'Error al cargar subasta $subastaId: $e',
        e,
      );
    }
  }

  /// Carga un perfil de usuario desde el repositorio.
  Future<ProfileRecord> _loadUserProfile(String userId) async {
    try {
      final profiles = await _profileRepo.listProfiles();
      final profile = profiles.firstWhere(
        (p) => p.nombre == userId || p.id == userId,
        orElse: () => throw UserNotFound(userId),
      );
      return profile;
    } on UserNotFound {
      rethrow;
    } catch (e) {
      throw PersistenceError(
        'Error al cargar perfil de usuario $userId: $e',
        e,
      );
    }
  }

  /// Guarda una subasta en el repositorio.
  Future<void> _saveSubasta(Subasta subasta) async {
    try {
      final subastaDir = await _subastaRepo.getSubastasDir();
      final file = File(
        '${subastaDir.path}${Platform.pathSeparator}${subasta.subastaId}.json',
      );
      await file.writeAsString(
        jsonEncode(subasta.toJson()),
        flush: true,
      );
    } catch (e) {
      throw PersistenceError(
        'Error al guardar subasta ${subasta.subastaId}: $e',
        e,
      );
    }
  }

  /// Guarda un perfil de usuario en el repositorio.
  Future<void> _saveUserProfile(ProfileRecord profile) async {
    try {
      final file = await _profileRepo.getProfilesFile();
      final currentProfiles = await _profileRepo.listProfiles();

      final updated = currentProfiles.map((p) {
        if (p.id == profile.id) {
          return profile;
        }
        return p;
      }).toList();

      await file.writeAsString(
        ProfileRecord.encodeList(updated),
        flush: true,
      );
    } catch (e) {
      throw PersistenceError(
        'Error al guardar perfil de usuario ${profile.nombre}: $e',
        e,
      );
    }
  }
}
