import 'dart:math';

/// Generates a cryptographically-random nonce string.
///
/// Used as a unique identifier for each redirect operation, enabling
/// concurrent redirect flows across all platforms.
///
/// The generated nonce is 16 characters long, using lowercase alphanumeric
/// characters, yielding ~82 bits of entropy.
String generateRedirectNonce() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
}
