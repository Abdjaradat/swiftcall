import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/token_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/auth_service.dart';
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
      length: 3,
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
              Tab(text: 'التوكنز'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PackagesTab(),
                _CreditTab(),
                _TokenManagementTab(),
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

// ── Token Management Tab ────────────────────────────────────
class _TokenManagementTab extends StatefulWidget {
  const _TokenManagementTab();

  @override
  State<_TokenManagementTab> createState() => _TokenManagementTabState();
}

class _TokenManagementTabState extends State<_TokenManagementTab> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  UserModel? _selectedUser;
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  int? _currentBalance;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await AuthService.instance.getAllUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
      });
    } catch (e) {
      print('Failed to load users: $e');
    }
  }

  void _filterUsers() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredUsers = _allUsers);
    } else {
      setState(() {
        _filteredUsers = _allUsers
            .where((u) =>
                u.name.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query))
            .toList();
      });
    }
  }

  Future<void> _selectUser(UserModel user) async {
    setState(() {
      _selectedUser = user;
      _currentBalance = null;
      _message = null;
    });
    try {
      final wallet = await TokenService.instance.getTokenWallet(user.uid);
      setState(() => _currentBalance = wallet?.balance ?? 0);
    } catch (e) {
      setState(() => _message = 'خطأ في تحميل الرصيد: $e');
    }
  }

  Future<void> _addTokens() async {
    if (_selectedUser == null) return;
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _message = 'أدخل عدد صحيح');
      return;
    }
    setState(() { _loading = true; _message = null; });
    try {
      await AdminService.instance.addTokens(_selectedUser!.uid, amount);
      final newBalance = (_currentBalance ?? 0) + amount;
      setState(() {
        _currentBalance = newBalance;
        _message = 'تم إضافة $amount توكنز';
        _loading = false;
        _amountCtrl.clear();
      });
    } catch (e) {
      setState(() { _message = 'خطأ: $e'; _loading = false; });
    }
  }

  Future<void> _setBalance() async {
    if (_selectedUser == null) return;
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _message = 'أدخل عدد صحيح (0 أو أكثر)');
      return;
    }
    setState(() { _loading = true; _message = null; });
    try {
      await AdminService.instance.setTokenBalance(_selectedUser!.uid, amount);
      setState(() {
        _currentBalance = amount;
        _message = 'تم تعيين الرصيد إلى $amount';
        _loading = false;
        _amountCtrl.clear();
      });
    } catch (e) {
      setState(() { _message = 'خطأ: $e'; _loading = false; });
    }
  }

  Future<void> _deductTokens() async {
    if (_selectedUser == null) return;
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _message = 'أدخل عدد صحيح');
      return;
    }
    setState(() { _loading = true; _message = null; });
    try {
      await AdminService.instance.deductTokens(_selectedUser!.uid, amount);
      final newBalance = (_currentBalance ?? 0) - amount;
      setState(() {
        _currentBalance = newBalance < 0 ? 0 : newBalance;
        _message = 'تم خصم $amount توكنز';
        _loading = false;
        _amountCtrl.clear();
      });
    } catch (e) {
      setState(() { _message = 'خطأ: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search field
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'بحث عن مستخدم (الاسم أو الإيميل)',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            style: GoogleFonts.cairo(),
          ),
          const SizedBox(height: 16),

          // User list
          if (_selectedUser == null) ...[
            Expanded(
              child: _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد مستخدمين',
                        style: GoogleFonts.cairo(color: AppColors.textHint),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (_, i) {
                        final u = _filteredUsers[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: u.photoUrl != null
                                ? CachedNetworkImageProvider(u.photoUrl!)
                                : null,
                            child: u.photoUrl == null
                                ? Text(u.initials,
                                    style: GoogleFonts.poppins(fontSize: 12))
                                : null,
                          ),
                          title: Text(u.name, style: GoogleFonts.cairo()),
                          subtitle: Text(u.email,
                              style: GoogleFonts.cairo(fontSize: 12)),
                          onTap: () => _selectUser(u),
                        );
                      },
                    ),
            ),
          ] else ...[
            // Selected user card
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: _selectedUser!.photoUrl != null
                              ? CachedNetworkImageProvider(
                                  _selectedUser!.photoUrl!)
                              : null,
                          child: _selectedUser!.photoUrl == null
                              ? Text(_selectedUser!.initials,
                                  style: GoogleFonts.poppins(fontSize: 16))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selectedUser!.name,
                                  style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w600, fontSize: 16)),
                              Text(_selectedUser!.email,
                                  style: GoogleFonts.cairo(
                                      fontSize: 12, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _selectedUser = null;
                            _currentBalance = null;
                            _message = null;
                            _amountCtrl.clear();
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Text(
                          _currentBalance != null
                              ? '$_currentBalance'
                              : 'جاري التحميل...',
                          style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'توكنز',
                          style: GoogleFonts.cairo(
                              fontSize: 16, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount input
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'عدد التوكنز',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: GoogleFonts.cairo(),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _addTokens,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('إضافة', style: GoogleFonts.cairo()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _setBalance,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text('تعيين', style: GoogleFonts.cairo()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _deductTokens,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: Text('خصم', style: GoogleFonts.cairo()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.callRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: GoogleFonts.cairo(
                  color: _message!.contains('تم')
                      ? AppColors.online
                      : AppColors.callRed,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
