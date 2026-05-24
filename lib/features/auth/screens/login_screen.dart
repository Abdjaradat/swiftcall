import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../data/services/auth_service.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (ctx, state) {
        if (state is AuthError) _showError(ctx, state.message);
        // Navigation handled by GoRouter redirect via _AuthNotifier
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Animated background blobs ──
            _AnimatedBlob(
                ctrl: _bgCtrl,
                alignment: const Alignment(-0.9, -0.9),
                color: AppColors.primary,
                size: 320,
                delay: 0.0),
            _AnimatedBlob(
                ctrl: _bgCtrl,
                alignment: const Alignment(0.9, -0.5),
                color: AppColors.secondary,
                size: 250,
                delay: 0.3),
            _AnimatedBlob(
                ctrl: _bgCtrl,
                alignment: const Alignment(-0.4, 1.0),
                color: AppColors.primary,
                size: 200,
                delay: 0.6),

            // ── Subtle dot grid ──
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),

            // ── Main content ──
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _LogoSection(),
                  const Spacer(flex: 2),
                  const _FeatureRow(),
                  const Spacer(flex: 2),
                  const _AuthForm(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _localizeError(msg),
                style: GoogleFonts.cairo(
                    color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localizeError(String e) {
    if (e.contains('network')) return 'تحقق من اتصالك بالإنترنت';
    if (e.contains('cancel')) return 'تم إلغاء تسجيل الدخول';
    if (e.contains('account-exists')) return 'هذا البريد مرتبط بحساب آخر';
    if (e.contains('sign_in_failed')) return 'فشل تسجيل الدخول — تأكد من إعداد Google Sign-In';
    return 'حدث خطأ، حاول مجدداً';
  }
}

// ── Logo Section ───────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.55),
                blurRadius: 36,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              const SwiftCallLogoIcon(size: 48),
            ],
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.4, 0.4),
              end: const Offset(1, 1),
              duration: 700.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 300.ms),

        const SizedBox(height: 24),

        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text(
            'SwiftCall',
            style: GoogleFonts.poppins(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.5,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 600.ms)
            .slideY(
                begin: 0.4,
                end: 0,
                delay: 200.ms,
                duration: 600.ms,
                curve: Curves.easeOutCubic),

        const SizedBox(height: 10),

        Text(
          'تواصل بسرعة • ابقَ على تواصل',
          style: GoogleFonts.cairo(
            fontSize: 15,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        )
            .animate()
            .fadeIn(delay: 350.ms, duration: 600.ms)
            .slideY(
                begin: 0.3,
                end: 0,
                delay: 350.ms,
                duration: 600.ms,
                curve: Curves.easeOutCubic),
      ],
    );
  }
}

// ── Feature Row ────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  static const _features = [
    _FeatureData('📹', 'فيديو', AppColors.primary),
    _FeatureData('🎙️', 'صوت', AppColors.secondary),
    _FeatureData('💬', 'شات', Color(0xFFFF6B6B)),
    _FeatureData('🔒', 'مشفر', Color(0xFFFFB344)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _features.length; i++)
            _FeatureCard(data: _features[i])
                .animate(delay: (300 + i * 80).ms)
                .fadeIn(duration: 500.ms)
                .slideY(
                    begin: 0.5,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

class _FeatureData {
  final String emoji;
  final String label;
  final Color color;
  const _FeatureData(this.emoji, this.label, this.color);
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData data;
  const _FeatureCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: data.color.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(data.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Auth Form (Email + Google) ─────────────────────────────
class _AuthForm extends StatefulWidget {
  const _AuthForm();
  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();
  bool _isRegister   = false;
  bool _obscure      = true;
  bool _rememberMe   = false;

  static const _prefEmail  = 'saved_email';
  static const _prefRemember = 'remember_me';

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_prefRemember) ?? false;
    if (remember) {
      final email = prefs.getString(_prefEmail) ?? '';
      setState(() {
        _rememberMe = true;
        _emailCtrl.text = email;
      });
    }
  }

  Future<void> _saveEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_prefEmail, _emailCtrl.text.trim());
      await prefs.setBool(_prefRemember, true);
    } else {
      await prefs.remove(_prefEmail);
      await prefs.setBool(_prefRemember, false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    _saveEmail();
    if (_isRegister) {
      ctx.read<AuthBloc>().add(AuthEmailRegisterRequested(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
      ));
    } else {
      ctx.read<AuthBloc>().add(AuthEmailSignInRequested(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      ));
    }
  }

  Future<void> _showForgotPassword(BuildContext ctx) async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool sending = false;

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('نسيت كلمة المرور؟',
              style: GoogleFonts.cairo(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('أدخل بريدك وسنرسل لك رابط إعادة التعيين',
                  style:
                      GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.cairo(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'البريد الإلكتروني',
                  hintStyle: GoogleFonts.cairo(color: Colors.white38),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: Colors.white38, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF2A2A3E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (!email.contains('@')) return;
                      setDialogState(() => sending = true);
                      try {
                        await AuthService.instance.sendPasswordReset(email);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (ctx.mounted) {
                          showDialog(
                            context: ctx,
                            builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E2E),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: Text('📧 تم الإرسال!',
                                  style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('أُرسل إيميل إلى:',
                                      style: GoogleFonts.cairo(
                                          color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(email,
                                      style: GoogleFonts.cairo(
                                          color: AppColors.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  Text(
                                    '1️⃣ افتح إيميلك\n'
                                    '2️⃣ ابحث عن رسالة من SwiftCall أو noreply@firebase\n'
                                    '3️⃣ اضغط على الرابط داخل الإيميل\n'
                                    '4️⃣ ستفتح صفحة تحدد فيها باسورد جديد\n'
                                    '5️⃣ ارجع للتطبيق وادخل بالباسورد الجديد',
                                    style: GoogleFonts.cairo(
                                        color: Colors.white70, fontSize: 13, height: 1.8),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      '⚠️ إذا ما وصل الإيميل تحقق من مجلد Spam/جunk',
                                      style: GoogleFonts.cairo(
                                          color: Colors.orange, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('فهمت ✅',
                                      style: GoogleFonts.cairo(
                                          color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (_) {
                        setDialogState(() => sending = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('البريد غير مسجّل',
                                style: GoogleFonts.cairo()),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('إرسال', style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (ctx, state) {
        final isLoading = state is AuthLoading;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ── Name field (register only) ──
                if (_isRegister) ...[
                  _field(
                    controller: _nameCtrl,
                    hint: 'اسمك',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'أدخل اسمك' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                // ── Email ──
                _field(
                  controller: _emailCtrl,
                  hint: 'البريد الإلكتروني',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'بريد غير صحيح' : null,
                ),
                const SizedBox(height: 12),
                // ── Password ──
                _field(
                  controller: _passCtrl,
                  hint: 'كلمة المرور',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'على الأقل 6 أحرف' : null,
                ),
                // ── Remember me + Forgot password (login only) ──
                if (!_isRegister) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.9,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          activeColor: AppColors.primary,
                          checkColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      Text('تذكرني',
                          style: GoogleFonts.cairo(
                              color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _showForgotPassword(ctx),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text('نسيت كلمة المرور؟',
                            style: GoogleFonts.cairo(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // ── Submit button ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () => _submit(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text(
                            _isRegister ? 'إنشاء حساب' : 'تسجيل الدخول',
                            style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                // ── Toggle login / register ──
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister
                        ? 'عندك حساب؟ سجّل الدخول'
                        : 'ما عندك حساب؟ أنشئ واحداً',
                    style: GoogleFonts.cairo(
                        color: AppColors.primary, fontSize: 13),
                  ),
                ),
                // ── OR divider ──
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    const Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('أو',
                          style: GoogleFonts.cairo(
                              color: Colors.white38, fontSize: 13)),
                    ),
                    const Expanded(child: Divider(color: Colors.white24)),
                  ]),
                ),
                // ── Google button ──
                const _GoogleSignInButton(),
                const SizedBox(height: 12),
                const _PrivacyNote(),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 500.ms, duration: 500.ms);
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorStyle: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 11),
      ),
    );
  }
}

// ── Google Sign-In Button ──────────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (ctx, state) {
        final isLoading = state is AuthLoading;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isLoading ? AppColors.card : AppColors.surface,
            border: Border.all(
              color: isLoading
                  ? AppColors.divider
                  : AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: isLoading
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLoading
                    ? null
                    : () => ctx
                        .read<AuthBloc>()
                        .add(AuthGoogleSignInRequested()),
                splashColor: AppColors.primary.withValues(alpha: 0.1),
                highlightColor: AppColors.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _GoogleLogo(),
                            const SizedBox(width: 14),
                            Text(
                              'متابعة مع Google',
                              style: GoogleFonts.cairo(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 600.ms, duration: 600.ms)
            .slideY(
                begin: 0.6,
                end: 0,
                delay: 600.ms,
                duration: 600.ms,
                curve: Curves.easeOutCubic);
      },
    );
  }
}

// ── Google Logo (real G logo) ──────────────────────────────
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(20, 20),
          painter: _GoogleGPainter(),
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    void arc(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.79),
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.42
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(-30, 60, const Color(0xFF4285F4));   // blue
    arc(30, 90, const Color(0xFF34A853));    // green
    arc(120, 90, const Color(0xFFFBBC05));   // yellow
    arc(210, 150, const Color(0xFFEA4335));  // red

    // White inner
    canvas.drawCircle(c, r * 0.58, Paint()..color = Colors.white);

    // Blue horizontal bar (the crossbar of the G)
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r * 0.9, c.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = r * 0.36
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Privacy Note ───────────────────────────────────────────
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.cairo(fontSize: 12, color: AppColors.textHint, height: 1.5);
    final link = GoogleFonts.cairo(
        fontSize: 12,
        color: AppColors.primary,
        height: 1.5,
        decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        text: 'بالمتابعة توافق على ',
        style: base,
        children: [
          TextSpan(
            text: 'شروط الخدمة',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => context.push(AppRouter.terms),
          ),
          TextSpan(text: ' و', style: base),
          TextSpan(
            text: 'سياسة الخصوصية',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => context.push(AppRouter.privacy),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    ).animate().fadeIn(delay: 800.ms, duration: 600.ms);
  }
}

// ── Animated Background Blob ───────────────────────────────
class _AnimatedBlob extends StatelessWidget {
  final AnimationController ctrl;
  final Alignment alignment;
  final Color color;
  final double size;
  final double delay;

  const _AnimatedBlob({
    required this.ctrl,
    required this.alignment,
    required this.color,
    required this.size,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(
          ((ctrl.value + delay) % 1.0).clamp(0.0, 1.0),
        );
        final scale = 0.85 + t * 0.3;
        return Align(
          alignment: alignment,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Dot Grid Background ────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C63FF).withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
