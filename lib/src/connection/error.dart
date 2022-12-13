class AyameConnectionError extends Error {
  AyameConnectionError({required this.reason, this.error});
  String reason;
  Object? error;
}
