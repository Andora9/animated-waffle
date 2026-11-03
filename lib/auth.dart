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
  final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
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
  bool signup = false, busy = false, hide = true, showEmail = false;
  String error = '', info = '';

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
    setState(() { busy = true; error = ''; info = ''; });
    try {
      final google = GoogleSignIn(serverClientId: AppConfig.googleWebClientId);
      final account = await google.signIn();
      if (account == null) { if (mounted) setState(() => busy = false); return; }
      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null) throw Exception('Google ID token nahi mila. Web Client ID check karo.');
      final result = await StoreScope.read(context).loginWithGoogleIdToken(token);
      if (!mounted) return;
      if (result == null) { Navigator.pop(context, true); }
      else { setState(() { busy = false; error = result; }); }
    } catch (e) {
      if (mounted) setState(() { busy = false; error = e.toString().replaceFirst('Exception: ', ''); });
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
    final r = signup ? await s.signup(name.text, e, pass.text) : await s.login(e, pass.text);
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

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: muted),
        prefixIcon: Icon(icon, size: 19, color: ink),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F4F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ink, width: 1.3)),
      );

  Widget _socialButton({required Widget icon, required String label, required VoidCallback? onTap, bool dark = false}) => SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: dark ? ink : Colors.white,
            foregroundColor: dark ? Colors.white : ink,
            side: BorderSide(color: dark ? ink : const Color(0xFFD4D4D8)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _googleMark() => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Text('G', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
      );

  @override
  Widget build(BuildContext context) {
    final appName = StoreScope.of(context).settings.appName;
    return Scaffold(
      backgroundColor: ink,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // ---------- dark hero
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              const Spacer(),
              if (Navigator.canPop(context))
                IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                child: const BrandLogo(size: 56),
              ),
              const SizedBox(height: 16),
              Text(appName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3)),
              const SizedBox(height: 6),
              const Text('Premium shopping, delivered fast', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, letterSpacing: .4)),
            ]),
          ),
          // ---------- white sheet
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(signup ? 'Create account' : 'Welcome back', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                  const SizedBox(height: 4),
                  Text(signup ? 'Join to order, track and unlock member benefits.' : 'Sign in to continue shopping.', style: const TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 22),
                  if (!AppConfig.supabaseReady)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(border: Border.all(color: danger), borderRadius: BorderRadius.circular(12)),
                      child: const Text('Supabase keys are missing in config.dart.', style: TextStyle(color: danger, fontSize: 12)),
                    ),
                  _socialButton(icon: _googleMark(), label: 'Continue with Google', onTap: busy ? null : _googleLogin),
                  const SizedBox(height: 10),
                  if (!showEmail)
                    _socialButton(
                      icon: const Icon(Icons.mail_rounded, size: 20, color: Colors.white),
                      label: 'Continue with Gmail / Email',
                      dark: true,
                      onTap: busy ? null : () => setState(() => showEmail = true),
                    ),
                  if (showEmail) ...[
                    const SizedBox(height: 8),
                    Row(children: const [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or use email', style: TextStyle(color: muted, fontSize: 11))),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 14),
                    if (signup) ...[
                      TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: _dec('Full name', Icons.person_outline)),
                      const SizedBox(height: 10),
                    ],
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: _dec('Email address', Icons.mail_outline)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pass,
                      obscureText: hide,
                      onSubmitted: (_) => _submit(),
                      decoration: _dec('Password', Icons.lock_outline,
                          suffix: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19, color: muted))),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: ink, minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(signup ? 'Create account' : 'Login', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                  if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: danger, fontSize: 12))),
                  if (info.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(info, textAlign: TextAlign.center, style: const TextStyle(color: success, fontSize: 12, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: busy ? null : () => setState(() { signup = !signup; showEmail = true; error = ''; info = ''; }),
                      child: Text(signup ? 'Already have an account? Login' : 'New here? Create an account', style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('By continuing you agree to our Terms & Privacy Policy.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 10)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
