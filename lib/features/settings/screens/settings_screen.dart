import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/app_settings_notifier.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/network_bypass_service.dart';
import '../../auth/bloc/auth_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = true;
  bool _isAr = true;
  bool _proxyEnabled = false;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadUser();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = prefs.getBool(AppConstants.isDarkModeKey) ?? true;
      _isAr = (prefs.getString(AppConstants.localeKey) ?? 'ar') == 'ar';
      _proxyEnabled = NetworkBypassService.instance.isEnabled;
    });
  }

  Future<void> _loadUser() async {
    final user = await AuthService.instance.getCurrentUserModel();
    setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('الإعدادات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: Container(
        color: AppColors.background,
        child: UnityBannerAd(
          placementId: 'Banner_Android',
          onLoad: (_) {},
          onClick: (_) {},
          onShown: (_) {},
          onFailed: (_, __, ___) {},
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          _profileCard(),
          const SizedBox(height: 24),

          _SectionHeader('التفضيلات'),
          _SettingCard(children: [
            _SwitchTile(
              icon: Icons.dark_mode_rounded,
              iconColor: AppColors.primary,
              title: 'الوضع الداكن',
              value: _isDark,
              onChanged: (v) async {
                setState(() => _isDark = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(AppConstants.isDarkModeKey, v);
                AppSettingsNotifier.instance.setDark(v);
              },
            ),
            const Divider(color: AppColors.divider, height: 0),
            _SwitchTile(
              icon: Icons.translate_rounded,
              iconColor: AppColors.secondary,
              title: 'اللغة العربية',
              value: _isAr,
              onChanged: (v) async {
                setState(() => _isAr = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(AppConstants.localeKey, v ? 'ar' : 'en');
                AppSettingsNotifier.instance.setLocale(v ? 'ar' : 'en');
              },
            ),
          ]),

          const SizedBox(height: 16),
          _SectionHeader('الشبكة والاتصال'),
          _SettingCard(children: [
            _SwitchTile(
              icon: Icons.vpn_lock_rounded,
              iconColor: const Color(0xFF9B59B6),
              title: 'تجاوز الحجب (Proxy)',
              subtitle: _proxyEnabled
                  ? NetworkBypassService.instance.activeProxy?.toString()
                  : 'غير مفعّل',
              value: _proxyEnabled,
              onChanged: (v) {
                if (v) {
                  _showProxySetupSheet();
                } else {
                  NetworkBypassService.instance.saveConfig(null);
                  setState(() => _proxyEnabled = false);
                }
              },
            ),
            const Divider(color: AppColors.divider, height: 0),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.callGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.wifi_tethering_rounded,
                    color: AppColors.callGreen, size: 20),
              ),
              title: Text('اختبار الاتصال',
                  style: GoogleFonts.cairo(color: AppColors.textPrimary)),
              subtitle: Text('تحقق من اتصالك بالإنترنت',
                  style: GoogleFonts.cairo(
                      color: AppColors.textHint, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
              onTap: _testConnection,
            ),
            const Divider(color: AppColors.divider, height: 0),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.router_rounded,
                    color: AppColors.secondary, size: 20),
              ),
              title: Text('خوادم TURN/STUN',
                  style: GoogleFonts.cairo(color: AppColors.textPrimary)),
              subtitle: Text('مضبوطة تلقائياً (${NetworkBypassService.instance.iceServers.length} خوادم)',
                  style: GoogleFonts.cairo(
                      color: AppColors.textHint, fontSize: 12)),
            ),
          ]),

          const SizedBox(height: 16),
          _SectionHeader('الحساب'),
          _SettingCard(children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.accent, size: 20),
              ),
              title: Text('تسجيل الخروج',
                  style: GoogleFonts.cairo(
                      color: AppColors.accent, fontWeight: FontWeight.w600)),
              onTap: () => _confirmSignOut(context),
            ),
          ]),

          const SizedBox(height: 16),
          _SectionHeader('حول التطبيق'),
          _SettingCard(children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_rounded,
                    color: AppColors.primary, size: 20),
              ),
              title: Text('شروط الخدمة',
                  style: GoogleFonts.cairo(color: AppColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
              onTap: () => context.push(AppRouter.terms),
            ),
            const Divider(color: AppColors.divider, height: 0),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.privacy_tip_rounded,
                    color: AppColors.secondary, size: 20),
              ),
              title: Text('سياسة الخصوصية',
                  style: GoogleFonts.cairo(color: AppColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
              onTap: () => context.push(AppRouter.privacy),
            ),
          ]),
          const SizedBox(height: 16),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'SwiftCall v${AppConstants.appVersion}',
              style: GoogleFonts.poppins(
                  color: AppColors.textHint, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return GestureDetector(
      onLongPress: _editPhone,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.surface,
              backgroundImage: _user?.photoUrl != null
                  ? CachedNetworkImageProvider(_user!.photoUrl!)
                  : null,
              child: _user?.photoUrl == null
                  ? Text(_user?.initials ?? '?',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user?.name ?? '...',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _user?.email ?? '',
                    style: GoogleFonts.poppins(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                  if (_user?.phoneNumber != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          _user!.phoneNumber!,
                          style: GoogleFonts.poppins(
                              color: AppColors.textHint, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.phone_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  void _editPhone() {
    final ctrl = TextEditingController(text: _user?.phoneNumber ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('رقم الهاتف', style: GoogleFonts.cairo(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.poppins(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'أدخل رقم هاتفك',
            hintStyle: GoogleFonts.cairo(color: AppColors.textHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final phone = ctrl.text.trim();
              if (phone.isNotEmpty) {
                await AuthService.instance.updatePhoneNumber(phone);
                _loadUser();
              }
              if (mounted) Navigator.pop(context);
            },
            child: Text('حفظ', style: GoogleFonts.cairo(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showProxySetupSheet() {
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '1080');
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    ProxyType type = ProxyType.http;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (_, ss) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إعداد البروكسي',
                  style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),

              // Type selector
              Row(
                children: ProxyType.values.map((t) {
                  final selected = t == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => ss(() => type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t.name.toUpperCase(),
                            style: GoogleFonts.poppins(
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _ProxyField(ctrl: hostCtrl, hint: 'عنوان الخادم'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProxyField(ctrl: portCtrl, hint: 'البورت',
                        inputType: TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ProxyField(ctrl: userCtrl, hint: 'اسم المستخدم (اختياري)'),
              const SizedBox(height: 10),
              _ProxyField(
                  ctrl: passCtrl,
                  hint: 'كلمة المرور (اختياري)',
                  obscure: true),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final host = hostCtrl.text.trim();
                    final port = int.tryParse(portCtrl.text) ?? 1080;
                    if (host.isEmpty) return;
                    final config = ProxyConfig(
                      host: host,
                      port: port,
                      username: userCtrl.text.isNotEmpty ? userCtrl.text : null,
                      password: passCtrl.text.isNotEmpty ? passCtrl.text : null,
                      type: type,
                    );
                    await NetworkBypassService.instance.saveConfig(config);
                    if (mounted) {
                      Navigator.pop(ctx);
                      setState(() => _proxyEnabled = true);
                      _testConnection();
                    }
                  },
                  child: Text('حفظ وتفعيل',
                      style: GoogleFonts.cairo(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جارٍ اختبار الاتصال...',
            style: GoogleFonts.cairo()),
        backgroundColor: AppColors.card,
        duration: const Duration(seconds: 2),
      ),
    );
    final ok = await NetworkBypassService.instance.testConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok ? AppColors.callGreen : AppColors.accent,
            ),
            const SizedBox(width: 10),
            Text(
              ok ? 'الاتصال يعمل بشكل صحيح ✓' : 'فشل الاتصال - تحقق من الإعدادات',
              style: GoogleFonts.cairo(),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('تسجيل الخروج',
            style: GoogleFonts.cairo(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('هل أنت متأكد؟',
            style: GoogleFonts.cairo(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthSignOutRequested());
            },
            child: Text('خروج',
                style: GoogleFonts.cairo(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ProxyField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool obscure;
  final TextInputType inputType;

  const _ProxyField({
    required this.ctrl,
    required this.hint,
    this.obscure = false,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: inputType,
      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(hintText: hint),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: GoogleFonts.poppins(
                  color: AppColors.textHint, fontSize: 11))
          : null,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
