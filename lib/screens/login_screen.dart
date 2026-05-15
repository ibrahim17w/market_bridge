import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/theme_toggle.dart';
import '../providers/locale_provider.dart';
import '../lang/translations.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../widgets/app_notification.dart';
import '../utils/error_mapper.dart';
import 'main_nav_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      try {
        await ApiService.updatePreferredLanguage(
          localeNotifier.value.languageCode,
        );
      } catch (_) {}

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      final rawMsg = e.toString();
      final isVerifyError =
          rawMsg.toLowerCase().contains('not verified') ||
          rawMsg.toLowerCase().contains('verify your email');
      final msg = mapBackendError(rawMsg);
      if (mounted) {
        if (isVerifyError) {
          showAppNotification(context, message: msg, isError: true);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(t('error')),
              content: Text(msg),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await ApiService.resendVerification(
                        _emailCtrl.text.trim(),
                      );
                      showAppNotification(
                        context,
                        message: t('verification_email_sent'),
                        isSuccess: true,
                      );
                    } catch (e2) {
                      showAppNotification(
                        context,
                        message: mapBackendError(e2.toString()),
                        isError: true,
                      );
                    }
                  },
                  child: Text(t('resend')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('ok')),
                ),
              ],
            ),
          );
        } else {
          showAppNotification(context, message: msg, isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return t('enter_email');
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return t('invalid_credentials');
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return t('enter_password');
    if (value.length < 8) return t('password_not_strong');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 80,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.storefront,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Market Bridge',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('login_subtitle'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).shadowColor.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: _emailCtrl,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          validator: _validateEmail,
                                          decoration: InputDecoration(
                                            labelText: t('email'),
                                            prefixIcon: const Icon(Icons.email),
                                            border: const OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _passwordCtrl,
                                          obscureText: _obscurePassword,
                                          textInputAction: TextInputAction.done,
                                          validator: _validatePassword,
                                          onFieldSubmitted: (_) => _login(),
                                          decoration: InputDecoration(
                                            labelText: t('password'),
                                            prefixIcon: const Icon(Icons.lock),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                              ),
                                              onPressed: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                            ),
                                            border: const OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: TextButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const ForgotPasswordScreen(),
                                                  ),
                                                );
                                              },
                                              child: Text(t('forgot_password')),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GradientButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _login,
                                            isLoading: _isLoading,
                                            child: Text(
                                              t('login'),
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: TextButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const RegisterScreen(),
                                                ),
                                              );
                                            },
                                            child: Text(t('dont_have_account')),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: SafeArea(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ThemeToggle(),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            icon: ValueListenableBuilder<Locale>(
                              valueListenable: localeNotifier,
                              builder: (_, locale, __) => Text(
                                locale.languageCode.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            onPressed: () => showLanguagePicker(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
