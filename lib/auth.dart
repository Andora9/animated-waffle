import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Login zaroori ho to AuthScreen kholta hai. true = ab logged-in (ya login ki zarurat nahi).
Future<bool> ensureLogin(BuildContext context) async {
  final s = StoreScope.read(context);
  if (!s.needsLogin) return true;
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const AuthScreen()),
  );
  return ok == true;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();

  bool signup = false;
  bool busy = false;
  bool hide = true;
  String error = '';
  String info = '';

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _googleLogin() async {
    if (AppConfig.googleWebClientId.isEmpty) {
      setState(() => error = 'config.dart me Google Web Client ID add karo.');
      return;
    }

    setState(() {
      busy = true;
      error = '';
      info = '';
    });

    try {
      final google = GoogleSignIn(
        serverClientId: AppConfig.googleWebClientId,
      );
      final account = await google.signIn();

      if (account == null) {
        if (mounted) setState(() => busy = false);
        return;
      }

      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null) {
        throw Exception('Google ID token nahi mila. Web Client ID check karo.');
      }

      final result =
          await StoreScope.read(context).loginWithGoogleIdToken(token);

      if (!mounted) return;
      if (result == null) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          busy = false;
          error = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submit() async {
    final s = StoreScope.read(context);
    final e = email.text.trim();

    if (signup && name.text.trim().isEmpty) {
      setState(() => error = 'Please enter your name');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      setState(() => error = 'Enter a valid email address');
      return;
    }
    if (pass.text.length < 6) {
      setState(() => error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      busy = true;
      error = '';
      info = '';
    });

    final r = signup
        ? await s.signup(name.text.trim(), e, pass.text)
        : await s.login(e, pass.text);

    if (!mounted) return;

    if (r == null) {
      Navigator.pop(context, true);
    } else if (r == 'CONFIRM') {
      setState(() {
        busy = false;
        signup = false;
        info = 'Account created! Check your email, confirm it, then login.';
      });
    } else {
      setState(() {
        busy = false;
        error = r;
      });
    }
  }

  InputDecoration _dec(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(
        color: Color(0xFF92968D),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF555B4E)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F6F2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE8EAE3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF30382B), width: 1.3),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy ? null : _googleLogin,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF20251D),
          side: const BorderSide(color: Color(0xFFE1E4DC)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6F2),
                shape: BoxShape.circle,
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            const Text(
              'Continue with Google',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE7E9E2))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 13),
          child: Text(
            'OR CONTINUE WITH EMAIL',
            style: TextStyle(
              color: Color(0xFF92968D),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE7E9E2))),
      ],
    );
  }

  Widget _messageBox(String message, {required bool positive}) {
    final color = positive
        ? const Color(0xFF287A4B)
        : const Color(0xFFB84235);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appName = StoreScope.of(context).settings.appName;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF252C21),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Compact branded header.
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(21),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.16),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const BrandLogo(size: 54),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    appName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'A better way to shop, every day.',
                    style: TextStyle(
                      color: Color(0xFFC2C8BB),
                      fontSize: 12,
                      letterSpacing: .25,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable white login panel.
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    22,
                    25,
                    22,
                    24 + bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        signup ? 'Create your account' : 'Welcome back',
                        style: const TextStyle(
                          color: Color(0xFF20251D),
                          fontSize: 25,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        signup
                            ? 'Sign up to discover products and enjoy a smoother shopping experience.'
                            : 'Login to continue shopping and manage your orders.',
                        style: const TextStyle(
                          color: Color(0xFF777D72),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (!AppConfig.supabaseReady) ...[
                        _messageBox(
                          'Supabase keys are missing in config.dart.',
                          positive: false,
                        ),
                        const SizedBox(height: 13),
                      ],

                      _googleButton(),
                      const SizedBox(height: 20),
                      _orDivider(),
                      const SizedBox(height: 18),

                      if (signup) ...[
                        const _FieldLabel('FULL NAME'),
                        const SizedBox(height: 7),
                        TextField(
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            'Enter your full name',
                            Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      const _FieldLabel('EMAIL ADDRESS'),
                      const SizedBox(height: 7),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: _dec(
                          'Enter your email address',
                          Icons.mail_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),

                      const _FieldLabel('PASSWORD'),
                      const SizedBox(height: 7),
                      TextField(
                        controller: pass,
                        obscureText: hide,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!busy) _submit();
                        },
                        decoration: _dec(
                          'Enter your password',
                          Icons.lock_outline_rounded,
                          suffix: IconButton(
                            tooltip: hide ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => hide = !hide),
                            icon: Icon(
                              hide
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 19,
                              color: const Color(0xFF777D72),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 17),

                      const SizedBox(height: 5),
                      SizedBox(
                        height: 51,
                        child: FilledButton(
                          onPressed: busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF252C21),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFF73796D),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      signup ? 'Create account' : 'Login',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 17,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 13),
                        _messageBox(error, positive: false),
                      ],
                      if (info.isNotEmpty) ...[
                        const SizedBox(height: 13),
                        _messageBox(info, positive: true),
                      ],

                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            signup
                                ? 'Already have an account?'
                                : 'New to $appName?',
                            style: const TextStyle(
                              color: Color(0xFF777D72),
                              fontSize: 12,
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () {
                                    setState(() {
                                      signup = !signup;
                                      error = '';
                                      info = '';
                                    });
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF252C21),
                              padding: const EdgeInsets.only(left: 5),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              signup ? 'Login' : 'Create account',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'By continuing, you agree to our Terms & Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9A9E96),
                          fontSize: 10,
                          height: 1.4,
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
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF62695D),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}
