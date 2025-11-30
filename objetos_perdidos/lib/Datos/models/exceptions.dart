/// Excepciones personalizadas para operaciones de subastas y pujas.

/// Se lanza cuando el usuario no tiene saldo suficiente para hacer una puja.
class InsufficientFunds implements Exception {
  final String userId;
  final int requiredPoints;
  final int availablePoints;

  InsufficientFunds({
    required this.userId,
    required this.requiredPoints,
    required this.availablePoints,
  });

  @override
  String toString() => 'InsufficientFunds: Usuario "$userId" necesita $requiredPoints puntos '
      'pero solo tiene $availablePoints';
}

/// Se lanza cuando la cantidad de la puja no supera la puja anterior.
class InvalidBidAmount implements Exception {
  final double bidAmount;
  final double currentBidAmount;
  final String subastaId;

  InvalidBidAmount({
    required this.bidAmount,
    required this.currentBidAmount,
    required this.subastaId,
  });

  @override
  String toString() => 'InvalidBidAmount: Puja de $bidAmount no supera la puja actual '
      '($currentBidAmount) en la subasta "$subastaId"';
}

/// Se lanza cuando no se encuentra la subasta solicitada.
class SubastaNotFound implements Exception {
  final String subastaId;

  SubastaNotFound(this.subastaId);

  @override
  String toString() => 'SubastaNotFound: No se encontró la subasta "$subastaId"';
}

/// Se lanza cuando no se encuentra el usuario solicitado.
class UserNotFound implements Exception {
  final String userId;

  UserNotFound(this.userId);

  @override
  String toString() => 'UserNotFound: No se encontró el usuario "$userId"';
}

/// Se lanza cuando hay un error en la persistencia o inconsistencia de datos.
class PersistenceError implements Exception {
  final String message;
  final Object? originalError;

  PersistenceError(this.message, [this.originalError]);

  @override
  String toString() =>
      'PersistenceError: $message${originalError != null ? '\nCausa: $originalError' : ''}';
}
