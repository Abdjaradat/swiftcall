import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';

enum LegalType { terms, privacy }

class LegalScreen extends StatelessWidget {
  final LegalType type;
  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isTerms = type == LegalType.terms;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          isTerms ? 'شروط الخدمة' : 'سياسة الخصوصية',
          style: GoogleFonts.cairo(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        leading: BackButton(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: isTerms ? const _TermsContent() : const _PrivacyContent(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'مرحباً بك في SwiftCall',
          body:
              'باستخدامك لتطبيق SwiftCall، فإنك توافق على الالتزام بهذه الشروط والأحكام. يُرجى قراءتها بعناية قبل استخدام الخدمة.',
        ),
        _Section(
          title: '١. استخدام الخدمة',
          body:
              'SwiftCall مجاني تماماً للاستخدام الشخصي وغير التجاري. يُحظر استخدام التطبيق لأي أغراض غير قانونية أو لإيذاء الآخرين أو انتهاك خصوصيتهم.',
        ),
        _Section(
          title: '٢. الحساب والمسؤولية',
          body:
              'أنت مسؤول عن الحفاظ على أمان حسابك وكلمة المرور. يجب عليك إخطارنا فوراً في حالة وجود أي استخدام غير مصرح به لحسابك.',
        ),
        _Section(
          title: '٣. المحتوى',
          body:
              'يُحظر نشر أي محتوى مسيء أو عنصري أو جنسي صريح أو محتوى ينتهك حقوق الملكية الفكرية. نحتفظ بالحق في إزالة أي محتوى ينتهك هذه الشروط.',
        ),
        _Section(
          title: '٤. الخدمة والتوافر',
          body:
              'نسعى لتوفير الخدمة على مدار الساعة، لكننا لا نضمن عدم انقطاعها. قد تتوقف الخدمة لأسباب تقنية أو صيانة. الاستخدام مجاني حالياً ونحتفظ بالحق في إضافة اشتراكات مميزة مستقبلاً مع إشعار مسبق.',
        ),
        _Section(
          title: '٥. التعديلات',
          body:
              'نحتفظ بالحق في تعديل هذه الشروط في أي وقت. سيتم إخطارك بأي تغييرات جوهرية عبر الإشعارات داخل التطبيق.',
        ),
        _Section(
          title: '٦. اتصل بنا',
          body:
              'إذا كانت لديك أي أسئلة حول هذه الشروط، تواصل معنا عبر: support@swiftcall.app',
        ),
      ],
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  static const _fullPolicyUrl =
      'https://abdjaradat.github.io/swiftcall/privacy_policy.html';

  Future<void> _openFullPolicy() async {
    final uri = Uri.parse(_fullPolicyUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Button to open the full HTML policy
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 28),
          child: OutlinedButton.icon(
            onPressed: _openFullPolicy,
            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
            label: Text('عرض السياسة الكاملة بالإنجليزية',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const _Section(
          title: 'سياسة الخصوصية',
          body:
              'نحن في SwiftCall نأخذ خصوصيتك بجدية تامة. توضح هذه السياسة كيفية جمع معلوماتك واستخدامها وحمايتها.',
        ),
        const _Section(
          title: '١. المعلومات التي نجمعها',
          body:
              'نجمع الاسم والبريد الإلكتروني وصورة الملف الشخصي عند تسجيل الدخول عبر Google أو البريد الإلكتروني. كما نخزّن رسائلك وسجل مكالماتك وقائمة أصدقائك في Firebase Firestore، والملفات والصور التي ترسلها في Firebase Storage.',
        ),
        const _Section(
          title: '٢. المكالمات (LiveKit)',
          body:
              'مكالماتك الصوتية والمرئية تتم عبر خوادم LiveKit (WebRTC مشفّر). لا نسجّل محتوى أي مكالمة. نحتفظ فقط ببيانات تعريفية مثل الوقت والمدة ونوع المكالمة لأغراض السجل والفوترة بالتوكنز.',
        ),
        const _Section(
          title: '٣. الإعلانات (Unity Ads)',
          body:
              'يستخدم التطبيق Unity Ads لعرض إعلانات بانر وإعلانات ما بعد المكالمة وإعلانات مكافأة. قد تجمع Unity معرّف الجهاز الإعلاني وبيانات التفاعل مع الإعلانات. يمكنك تعطيل الإعلانات المخصّصة من إعدادات جهازك.',
        ),
        const _Section(
          title: '٤. مشاركة البيانات',
          body:
              'لا نبيع بياناتك الشخصية. نشارك البيانات فقط مع مزودي الخدمة الضروريين (Firebase وLiveKit وUnity) لتشغيل التطبيق، أو إذا طلب منا القانون ذلك.',
        ),
        const _Section(
          title: '٥. حقوقك',
          body:
              'يحق لك الوصول إلى بياناتك وتعديلها وحذفها في أي وقت. لحذف حسابك وجميع بياناتك، انتقل إلى الإعدادات ← حذف الحساب، أو راسلنا على: jaradatabdullah122@gmail.com',
        ),
        const _Section(
          title: '٦. الأطفال',
          body:
              'لا يُسمح باستخدام التطبيق لمن هم دون سن ١٣ عاماً. إذا علمنا بأن طفلاً دون هذه السن قد أنشأ حساباً، سنحذفه فوراً.',
        ),
        const _Section(
          title: '٧. تاريخ السريان',
          body: 'آخر تحديث: ٢٩ مايو ٢٠٢٦.',
        ),
      ],
    );
  }
}
