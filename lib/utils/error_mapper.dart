import '../lang/translations.dart';

/// Maps backend English error messages to translated strings.
String mapBackendError(String raw) {
  final msg = raw.toLowerCase();

  // Rate limiting / brute force
  if (msg.contains('too many failed attempts') ||
      msg.contains('too many requests') ||
      msg.contains('too many login attempts') ||
      msg.contains('account locked')) {
    return t('too_many_attempts');
  }

  // Email not found
  if ((msg.contains('not found') || msg.contains('no account')) &&
      msg.contains('email')) {
    return t('email_not_found');
  }

  // Invalid reset code
  if (msg.contains('invalid') && msg.contains('code')) {
    return t('invalid_code');
  }

  // Invalid login credentials
  if ((msg.contains('invalid') || msg.contains('incorrect')) &&
      (msg.contains('email') || msg.contains('password'))) {
    return t('invalid_credentials');
  }

  // Email not verified
  if (msg.contains('not verified') || msg.contains('verify your email')) {
    return t('email_not_verified');
  }

  // Password strength
  if (msg.contains('too weak') ||
      msg.contains('medium strength') ||
      msg.contains('must be strong')) {
    return t('password_not_strong');
  }

  // Current password incorrect
  if (msg.contains('current password is incorrect')) {
    return t('password_incorrect');
  }

  // Already registered
  if (msg.contains('already registered')) {
    return t('email_already_registered');
  }

  // Required fields
  if (msg.contains('fill all required') || msg.contains('required fields')) {
    return t('fill_required');
  }

  // Password mismatch
  if (msg.contains('do not match') || msg.contains('not match')) {
    return t('passwords_no_match');
  }

  // Generic server error
  if (msg.contains('something went wrong') ||
      msg.contains('server error') ||
      msg.contains('failed to send')) {
    return t('server_error');
  }
  if (msg.contains('same as your previous') ||
      msg.contains('previous password')) {
    return t('same_password_not_allowed');
  }
  // Clean up raw exception noise and return as-is if no mapping found
  return raw
      .replaceAll('Exception:', '')
      .replaceAll('Exception', '')
      .replaceAll('Error:', '')
      .trim();
}
