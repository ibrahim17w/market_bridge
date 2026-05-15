import '../lang/translations.dart';

String mapBackendError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('not verified') ||
      lower.contains('email not verified') ||
      lower.contains('verify your email') || // FIX: match backend login message
      lower.contains('before logging in')) {
    // FIX: match backend login message
    return t('email_not_verified');
  }
  if (lower.contains('invalid credentials') ||
      lower.contains('wrong password') ||
      lower.contains('email or password is incorrect')) {
    // FIX: match backend exact message
    return t('invalid_credentials');
  }
  if (lower.contains('already registered') ||
      lower.contains('already exists')) {
    return t('already_registered');
  }
  if (lower.contains('not found')) {
    return t('not_found');
  }
  if (lower.contains('too many requests') || lower.contains('rate limit')) {
    return t('too_many_requests');
  }
  if (lower.contains('weak password') ||
      lower.contains('not strong enough') ||
      lower.contains('too weak') || // FIX: match backend
      lower.contains('medium strength')) {
    // FIX: match backend
    return t('password_not_strong');
  }
  if (lower.contains('same as previous') ||
      lower.contains('cannot reuse') ||
      lower.contains('same as your previous')) {
    // FIX: match backend
    return t('password_reuse');
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return t('request_timeout');
  }
  if (lower.contains('network') || lower.contains('connection')) {
    return t('network_error');
  }
  if (lower.contains('unauthorized') || lower.contains('401')) {
    return t('session_expired');
  }
  if (lower.contains('forbidden') || lower.contains('403')) {
    return t('access_denied');
  }
  if (lower.contains('server error') ||
      lower.contains('500') ||
      lower.contains('something went wrong')) {
    return t('server_error');
  }
  return t('unknown_error');
}
