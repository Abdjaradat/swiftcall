import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'سياسة الخصوصية',
          body:
              'نحن في SwiftCall نأخذ خصوصيتك بجدية تامة. توضح هذه السياسة كيفية جمع معلوماتك واستخدامها وحمايتها.',
        ),
        _Section(
          title: '١. المعلومات التي نجمعها',
          body:
              'نجمع المعلومات الأساسية من حساب Google الخاص بك (الاسم، صورة الملف الشخصي، والبريد الإلكتروني) لإنشاء حسابك في SwiftCall. لا نجمع أي معلومات إضافية دون موافقتك.',
        ),
        _Section(
          title: '٢. كيف نستخدم معلوماتك',
          body:
              'نستخدم معلوماتك لتوفير خدمة المكالمات والمحادثات، وعرض ملفك الشخصي للمستخدمين الآخرين، وإرسال الإشعارات المتعلقة بالمكالمات والرسائل.',
        ),
        _Section(
          title: '٣. تشفير الاتصالات',
          body:
              'جميع مكالماتك الصوتية والمرئية ومحادثاتك النصية مشفرة بالكامل. نستخدم بروتوكولات WebRTC مع تشفير DTLS-SRTP لضمان أمان اتصالاتك.',
        ),
        _Section(
          title: '٤. مشاركة البيانات',
          body:
              'لا نبيع أو نشارك بياناتك الشخصية مع أطراف ثالثة لأغراض تجارية. نستخدم Firebase من Google لتخزين البيانات وإرسال الإشعارات، وهي تخضع لسياسة خصوصية Google.',
        ),
        _Section(
          title: '٥. حذف البيانات',
          body:
              'يحق لك في أي وقت طلب حذف جميع بياناتك من خوادمنا. يمكنك القيام بذلك من إعدادات التطبيق أو بالتواصل معنا مباشرة.',
        ),
        _Section(
          title: '٦. الأطفال',
          body:
              'لا يُسمح باستخدام التطبيق لمن هم دون سن ١٣ عاماً. إذا علمنا بأن طفلاً دون هذه السن قد أنشأ حساباً، سنحذفه فوراً.',
        ),
        _Section(
          title: '٧. التواصل معنا',
          body:
              'لأي استفسارات تتعلق بخصوصيتك: privacy@swiftcall.app',
        ),
      ],
    );
  }
}
