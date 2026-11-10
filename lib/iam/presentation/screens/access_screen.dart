import 'package:flutter/material.dart';
import '../../../shared/theme/mirage_theme.dart';
import '../../../shared/widgets/mirage_components.dart';
import '../../application/iam_controller.dart';
import '../../domain/account.dart';

enum AccessMode { signIn, register, recovery, confirmation }

class AccessScreen extends StatefulWidget {
  const AccessScreen({
    super.key,
    required this.mode,
    required this.controller,
    required this.onNavigate,
    this.initialEmail = '',
  });
  final AccessMode mode;
  final IamController controller;
  final String initialEmail;
  final void Function(AccessMode, String) onNavigate;
  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final TextEditingController _email;
  String? _message;
  bool get _register => widget.mode == AccessMode.register;
  bool get _login => widget.mode == AccessMode.signIn;
  bool get _confirmation => widget.mode == AccessMode.confirmation;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    try {
      EmailAddress(value ?? '');
      return null;
    } on AuthFailure catch (failure) {
      return failure.message;
    }
  }

  String? _validatePassword(String? value) {
    try {
      validatePassword(value ?? '', registering: _register);
      return null;
    } on AuthFailure catch (failure) {
      return failure.message;
    }
  }

  void _navigate(AccessMode mode) {
    FocusScope.of(context).unfocus();
    widget.onNavigate(mode, _email.text.trim());
  }

  Future<void> _submit() async {
    if (widget.controller.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _message = null);
    final email = _email.text.trim();
    final success = await switch (widget.mode) {
      AccessMode.signIn => widget.controller.signIn(email, _password.text),
      AccessMode.register => widget.controller.register(
        _name.text,
        email,
        _password.text,
      ),
      AccessMode.recovery => widget.controller.requestRecovery(email),
      AccessMode.confirmation => widget.controller.resendVerification(email),
    };
    if (!mounted || !success) return;
    _password.clear();
    _confirm.clear();
    if (_register && !widget.controller.signedIn) {
      _navigate(AccessMode.confirmation);
    } else if (!_login && !_register) {
      setState(
        () => _message = _confirmation
            ? 'If your account is waiting for confirmation, a new email is on its way. Check your spam folder too.'
            : 'If an account uses this email, you’ll receive a password reset link. Check your spam folder too.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final title = switch (widget.mode) {
      AccessMode.signIn => 'Your style.\nYour space.',
      AccessMode.register => 'Make yourself\nat home.',
      AccessMode.recovery => 'A little reset.\nA fresh start.',
      AccessMode.confirmation => 'Your space\nis almost ready.',
    };
    final subtitle = switch (widget.mode) {
      AccessMode.signIn => 'Log in to a closet full of possibilities.',
      AccessMode.register => 'One account. A world of possibilities.',
      AccessMode.recovery => 'We’ll send you a link to choose a new password.',
      AccessMode.confirmation =>
        'Open the newest confirmation email, then come back to log in.',
    };
    return PopScope(
      canPop: _login,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !controller.busy) _navigate(AccessMode.signIn);
      },
      child: MirageScreen(
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MirageHeader(
                onBack: _login
                    ? null
                    : controller.busy
                    ? null
                    : () => _navigate(AccessMode.signIn),
              ),
              const SizedBox(height: 28),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 12),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 26),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_register) ...[
                      MirageField(
                        label: 'Your name',
                        controller: _name,
                        hint: 'How should we call you?',
                        enabled: !controller.busy,
                        autofillHints: const [AutofillHints.name],
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter your name.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    MirageField(
                      label: 'Email',
                      controller: _email,
                      hint: 'mia@example.com',
                      enabled: !controller.busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: _validateEmail,
                      textInputAction: _login || _register
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: _login || _register
                          ? null
                          : (_) => _submit(),
                    ),
                    if (_login || _register) ...[
                      const SizedBox(height: 16),
                      MirageField(
                        label: 'Password',
                        controller: _password,
                        password: true,
                        hint: '••••••••••',
                        enabled: !controller.busy,
                        validator: _validatePassword,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: _register
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: _register ? null : (_) => _submit(),
                      ),
                    ],
                    if (_register) ...[
                      const SizedBox(height: 16),
                      MirageField(
                        label: 'Confirm password',
                        controller: _confirm,
                        password: true,
                        enabled: !controller.busy,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (value) => value != _password.text
                            ? 'Your passwords don’t match.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Use at least 8 characters and a password you haven’t used elsewhere.',
                        style: TextStyle(
                          fontSize: 12,
                          color: MirageColors.muted,
                        ),
                      ),
                    ],
                    if (_login)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: controller.busy
                              ? null
                              : () => _navigate(AccessMode.recovery),
                          style: TextButton.styleFrom(
                            foregroundColor: MirageColors.muted,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    if (!_login) const SizedBox(height: 24),
                    if (controller.error != null) ...[
                      MirageNotice(controller.error!, error: true),
                      const SizedBox(height: 16),
                      if (_login)
                        TextButton(
                          onPressed: controller.busy
                              ? null
                              : () => _navigate(AccessMode.confirmation),
                          child: const Text('Need a confirmation email?'),
                        ),
                    ],
                    if (_message != null) ...[
                      MirageNotice(_message!),
                      const SizedBox(height: 16),
                    ],
                    MirageButton(
                      label: switch (widget.mode) {
                        AccessMode.signIn => 'Log In',
                        AccessMode.register => 'Create Account',
                        AccessMode.recovery => 'Send reset link',
                        AccessMode.confirmation => 'Resend confirmation',
                      },
                      busy: controller.busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
              if (_login) ...[
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Expanded(child: Divider(color: MirageColors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 13),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                          fontSize: 12,
                          color: MirageColors.muted,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: MirageColors.border)),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: controller.busy || !controller.canUseGoogle
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          setState(() => _message = null);
                          controller.signInWithGoogle();
                        },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'G',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Continue with Google',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const OutlinedButton(
                  onPressed: null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MirageAsset('login_imgApple.svg', width: 22, height: 22),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Continue with Apple',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Apple sign-in is coming soon.',
                    style: TextStyle(fontSize: 11, color: MirageColors.muted),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'New here? Make yourself at home.',
                    style: TextStyle(fontSize: 13, color: MirageColors.muted),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => _navigate(AccessMode.register),
                    child: const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: MirageColors.muted,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => _navigate(AccessMode.signIn),
                    child: Text(
                      _register ? 'Already at home? Log In' : 'Back to Log In',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
