import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/page_content.dart';
import '../application/auth_providers.dart';

enum AuthFormMode { login, register, forgotPassword, resetPassword }

/// Shared form layout; route mode defines the fields and repository action.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({required this.mode, super.key});
  final AuthFormMode mode;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _title => switch (widget.mode) {
    AuthFormMode.login => 'Sign in',
    AuthFormMode.register => 'Create account',
    AuthFormMode.forgotPassword => 'Forgot password',
    AuthFormMode.resetPassword => 'Set new password',
  };

  void _navigate(String route) {
    ref.read(authControllerProvider.notifier).clearMessage();
    context.go(route);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    switch (widget.mode) {
      case AuthFormMode.login:
        await controller.login(_email.text, _password.text);
      case AuthFormMode.register:
        await controller.register(_email.text, _password.text, _name.text);
      case AuthFormMode.forgotPassword:
        await controller.forgotPassword(_email.text);
      case AuthFormMode.resetPassword:
        await controller.resetPassword(_password.text);
        if (mounted && !ref.read(authControllerProvider).hasError) {
          context.go('/home');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final operation = ref.watch(authControllerProvider);
    final register = widget.mode == AuthFormMode.register;
    final reset = widget.mode == AuthFormMode.resetPassword;
    final forgot = widget.mode == AuthFormMode.forgotPassword;
    final message = operation.asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('SkillCheck')),
      body: SafeArea(
        child: PageContent(
          title: _title,
          description: 'Your knowledge. Your next learning step.',
          children: [
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (register) ...[
                      TextFormField(
                        controller: _name,
                        enabled: !operation.isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                        maxLength: 80,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a display name.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!reset) ...[
                      TextFormField(
                        controller: _email,
                        enabled: !operation.isLoading,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value != null &&
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value.trim())
                            ? null
                            : 'Enter a valid email.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!forgot) ...[
                      TextFormField(
                        controller: _password,
                        enabled: !operation.isLoading,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        autofillHints: [
                          register || reset
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password.';
                          }
                          if ((register || reset) && value.length < 8) {
                            return 'Use at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (register || reset) ...[
                      TextFormField(
                        controller: _confirm,
                        enabled: !operation.isLoading,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        validator: (value) => value == _password.text
                            ? null
                            : 'Passwords do not match.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (operation.hasError)
                      Text(
                        friendlyFailure(operation.error!, 'auth form').message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (message != null) Text(message),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: operation.isLoading ? null : _submit,
                      child: Text(
                        operation.isLoading
                            ? 'Please wait…'
                            : forgot
                            ? 'Send reset link'
                            : _title,
                      ),
                    ),
                    if (operation.isLoading) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    if (widget.mode == AuthFormMode.login) ...[
                      TextButton(
                        onPressed: operation.isLoading
                            ? null
                            : () => _navigate('/register'),
                        child: const Text('Create account'),
                      ),
                      TextButton(
                        onPressed: operation.isLoading
                            ? null
                            : () => _navigate('/forgot-password'),
                        child: const Text('Forgot password?'),
                      ),
                    ] else if (!reset)
                      TextButton(
                        onPressed: operation.isLoading
                            ? null
                            : () => _navigate('/login'),
                        child: const Text('Back to sign in'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
