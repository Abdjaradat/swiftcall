import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/token_model.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/token_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isAdmin = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final uid = await AdminService.instance.currentUid();
    if (uid == null) {
      setState(() { _checking = false; _isAdmin = false; });
      return;
    }
    final admin = await AdminService.instance.isAdmin(uid);
    setState(() { _isAdmin = admin; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('لوحة التحكم', style: GoogleFonts.cairo()),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _isAdmin
              ? const _AdminPanel()
              : Center(
                  child: Text(
                    'ليس لديك صلاحية الوصول',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
    );
  }
}

class _AdminPanel extends StatefulWidget {
  const _AdminPanel();

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'الباقات'),
              Tab(text: 'إضافة توكنز'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PackagesTab(),
                _CreditTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Packages Tab ────────────────────────────────────────────

class _PackagesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TokenPackage>>(
      stream: TokenService.instance.tokenPackagesStream(),
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('خطأ في تحميل الباقات', style: GoogleFonts.cairo()),
          );
        }
        final pkgs = snap.data ?? [];
        return Column(
          children: [
            Expanded(
              child: pkgs.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد باقات بعد',
                        style: GoogleFonts.cairo(color: AppColors.textHint),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: pkgs.length,
                      itemBuilder: (_, i) {
                        final p = pkgs[i];
                        return Card(
                          color: AppColors.surface,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(p.name,
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${p.tokens} توكنز - \$${p.price.toStringAsFixed(2)}',
                              style: GoogleFonts.cairo(fontSize: 13),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: p.isActive,
                                  activeColor: AppColors.primary,
                                  onChanged: (v) =>
                                      TokenService.instance
                                          .toggleTokenPackage(p.id, v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded,
                                      color: AppColors.callRed),
                                  onPressed: () =>
                                      _confirmDelete(context, p),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('إضافة باقة جديدة',
                      style: GoogleFonts.cairo()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, TokenPackage pkg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('حذف الباقة', style: GoogleFonts.cairo()),
        content: Text(
          'هل أنت متأكد من حذف "${pkg.name}"؟',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () {
              TokenService.instance.deleteTokenPackage(pkg.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: AppColors.callRed)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final tokensCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('باقة جديدة', style: GoogleFonts.cairo()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الباقة',
                border: OutlineInputBorder(),
              ),
              style: GoogleFonts.cairo(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر (\$)',
                border: OutlineInputBorder(),
              ),
              style: GoogleFonts.cairo(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tokensCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد التوكنز',
                border: OutlineInputBorder(),
              ),
              style: GoogleFonts.cairo(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
              final tokens = int.tryParse(tokensCtrl.text.trim()) ?? 0;
              if (name.isEmpty || price <= 0 || tokens <= 0) return;
              TokenService.instance.addTokenPackage(TokenPackage(
                id: '',
                name: name,
                price: price,
                tokens: tokens,
              ));
              Navigator.pop(context);
            },
            child: Text('إضافة', style: GoogleFonts.cairo(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ── Credit Tab ──────────────────────────────────────────────

class _CreditTab extends StatefulWidget {
  const _CreditTab();

  @override
  State<_CreditTab> createState() => _CreditTabState();
}

class _CreditTabState extends State<_CreditTab> {
  final _uidCtrl = TextEditingController();
  TokenPackage? _selectedPkg;
  List<TokenPackage> _packages = [];
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _uidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TokenPackage>>(
      stream: TokenService.instance.tokenPackagesStream(),
      builder: (_, snap) {
        _packages = snap.data ?? [];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _uidCtrl,
                decoration: const InputDecoration(
                  labelText: 'معرف المستخدم (UID)',
                  border: OutlineInputBorder(),
                ),
                style: GoogleFonts.cairo(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TokenPackage>(
                value: _selectedPkg,
                decoration: const InputDecoration(
                  labelText: 'اختر الباقة',
                  border: OutlineInputBorder(),
                ),
                items: _packages.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(
                    '${p.name} — ${p.tokens} توكنز (\$${p.price.toStringAsFixed(2)})',
                    style: GoogleFonts.cairo(fontSize: 13),
                  ),
                )).toList(),
                onChanged: (p) => setState(() => _selectedPkg = p),
                style: GoogleFonts.cairo(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _credit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('إضافة توكنز', style: GoogleFonts.cairo()),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, style: GoogleFonts.cairo(
                  color: _message!.contains('تم')
                      ? AppColors.online
                      : AppColors.callRed,
                )),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _credit() async {
    final uid = _uidCtrl.text.trim();
    final pkg = _selectedPkg;
    if (uid.isEmpty) {
      setState(() => _message = 'يرجى إدخال معرف المستخدم');
      return;
    }
    if (pkg == null) {
      setState(() => _message = 'يرجى اختيار باقة');
      return;
    }

    setState(() { _loading = true; _message = null; });

    try {
      await TokenService.instance.creditTokensManually(
        uid,
        pkg.tokens,
        'مشتراة: ${pkg.name} (\$${pkg.price.toStringAsFixed(2)})',
      );
      setState(() {
        _message = 'تم إضافة ${pkg.tokens} توكنز للمستخدم $uid';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _message = 'خطأ: $e';
        _loading = false;
      });
    }
  }
}
