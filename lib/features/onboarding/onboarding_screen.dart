import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';

class _OnboardPage {
  final String emoji;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final Color accent;

  const _OnboardPage({
    required this.emoji,
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    required this.accent,
  });
}

const _pages = [
  _OnboardPage(
    emoji: '📹',
    titleAr: 'مكالمات فيديو عالية الجودة',
    titleEn: 'Crystal Clear Video Calls',
    descAr: 'استمتع بمكالمات فيديو واضحة مع أصدقائك وعائلتك في أي مكان',
    descEn: 'Enjoy crystal clear video calls with friends & family anywhere',
    accent: Color(0xFF6C63FF),
  ),
  _OnboardPage(
    emoji: '💬',
    titleAr: 'شات احترافي وسريع',
    titleEn: 'Fast & Secure Messaging',
    descAr: 'أرسل رسائل ومصور وملفات مع تشفير كامل لحماية خصوصيتك',
    descEn: 'Send messages, photos & files with full end-to-end encryption',
    accent: Color(0xFF03DAC6),
  ),
  _OnboardPage(
    emoji: '🔒',
    titleAr: 'خصوصيتك أولويتنا',
    titleEn: 'Your Privacy Matters',
    descAr: 'كل محادثاتك مشفرة بالكامل. لا أحد يستطيع قراءة رسائلك',
    descEn: 'All your conversations are fully encrypted. Nobody can read your messages.',
    accent: Color(0xFFFF6B6B),
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingDoneKey, true);
    if (mounted) context.go(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated background blob
          Positioned(
            top: -80,
            right: -80,
            child: _blob(_pages[_page].accent.withValues(alpha: 0.15), 300),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _blob(_pages[_page].accent.withValues(alpha: 0.10), 250),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'تخطي',
                      style: GoogleFonts.cairo(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _buildPage(_pages[i]),
                  ),
                ),

                // Dots + Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: i == _page
                                  ? _pages[_page].accent
                                  : AppColors.divider,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _pages[_page].accent,
                                _pages[_page].accent.withBlue(255),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _pages[_page].accent.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              if (_page < _pages.length - 1) {
                                _ctrl.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                _finish();
                              }
                            },
                            child: Text(
                              _page < _pages.length - 1 ? 'التالي' : 'ابدأ الآن',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji in glowing circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.accent.withValues(alpha: 0.12),
              border: Border.all(
                color: page.accent.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: page.accent.withValues(alpha: 0.25),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 72),
              ),
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 48),

          Text(
            page.titleAr,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),

          const SizedBox(height: 16),

          Text(
            page.descAr,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
