import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/ad_service.dart';
import '../../../data/models/token_model.dart';
import '../bloc/token_bloc.dart';
import '../bloc/token_event.dart';
import '../bloc/token_state.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _coinController;
  late Animation<double> _coinAnim;

  @override
  void initState() {
    super.initState();
    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _coinAnim = CurvedAnimation(parent: _coinController, curve: Curves.elasticOut);
    context.read<TokenBloc>().add(TokenLoadWallet());
    _coinController.forward();
  }

  @override
  void dispose() {
    _coinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('محفظة التوكنز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocConsumer<TokenBloc, TokenState>(
        listener: (context, state) {
          if (state is TokenActionSuccess) {
            HapticFeedback.heavyImpact();
            _coinController.reset();
            _coinController.forward();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ));
          } else if (state is TokenAdLimitReached) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('وصلت للحد اليومي للإعلانات (10 إعلانات/يوم)'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ));
          } else if (state is TokenShareLimitReached) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('وصلت للحد اليومي للمشاركة (3 مرات/يوم)'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ));
          } else if (state is TokenInsufficient) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('رصيدك غير كافٍ — تحتاج ${state.required} توكن، لديك ${state.current}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        builder: (context, state) {
          if (state is TokenLoading || state is TokenInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TokenLoaded) {
            return _buildContent(state);
          }
          if (state is TokenError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(state.message,
                      style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.read<TokenBloc>().add(TokenLoadWallet()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: ElevatedButton.icon(
              onPressed: () =>
                  context.read<TokenBloc>().add(TokenLoadWallet()),
              icon: const Icon(Icons.refresh),
              label: const Text('تحميل'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(TokenLoaded state) {
    return RefreshIndicator(
      onRefresh: () async => context.read<TokenBloc>().add(TokenLoadWallet()),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBalanceCard(state.wallet),
          const SizedBox(height: 20),
          _buildEarnSection(state.wallet),
          const SizedBox(height: 20),
          _buildCostsSection(),
          const SizedBox(height: 20),
          _buildTransactionHistory(state.transactions),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(TokenWallet wallet) {
    return ScaleTransition(
      scale: _coinAnim,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3F3D8F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            const Text('💎 رصيدك', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              '${wallet.balance}',
              style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold),
            ),
            const Text('توكن', style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('كسبت', '${wallet.totalEarned}', Icons.arrow_upward),
                _statChip('أنفقت', '${wallet.totalSpent}', Icons.arrow_downward),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _buildEarnSection(TokenWallet wallet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('💰 اكسب توكنز', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _earnCard(
          icon: '📺',
          title: 'شاهد إعلاناً',
          subtitle: 'متبقي اليوم: ${wallet.remainingAds}/10',
          reward: '+50 توكن',
          available: wallet.canWatchAd,
          onTap: () => _watchAd(),
        ),
        const SizedBox(height: 10),
        _earnCard(
          icon: '📤',
          title: 'شارك التطبيق',
          subtitle: 'متبقي اليوم: ${wallet.remainingShares}/3',
          reward: '+30 توكن',
          available: wallet.canShare,
          onTap: () => _shareApp(),
        ),
      ],
    );
  }

  Widget _earnCard({
    required String icon,
    required String title,
    required String subtitle,
    required String reward,
    required bool available,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: available ? onTap : null,
      child: AnimatedOpacity(
        opacity: available ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: available ? const Color(0xFF6C63FF).withOpacity(0.5) : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: available ? const Color(0xFF6C63FF) : Colors.grey[700],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(reward, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📊 تكاليف الخدمات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _costRow('💬', 'رسالة نصية', '${TokenCosts.messagePerMessage} توكن', isFirst: true),
              _costRow('📞', 'مكالمة صوتية', '${TokenCosts.voiceCallPerMinute} توكن/دقيقة'),
              _costRow('📹', 'مكالمة فيديو', '${TokenCosts.videoCallPerMinute} توكن/دقيقة'),
              _costRow('👥', 'مكالمة جماعية', '${TokenCosts.groupCallPerMinute} توكن/دقيقة', isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _costRow(String icon, String label, String cost, {bool isFirst = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: Colors.white10),
          top: isFirst ? BorderSide.none : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15))),
          Text(cost, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(List<TokenTransaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(child: Text('لا يوجد سجل بعد', style: TextStyle(color: Colors.grey)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📋 السجل', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...transactions.take(10).map((t) => _transactionTile(t)),
      ],
    );
  }

  Widget _transactionTile(TokenTransaction t) {
    final isEarn = t.amount > 0;
    final icon = switch (t.type) {
      'bonus' => '🎁',
      'ad' => '📺',
      'share' => '📤',
      'spend' => '💸',
      _ => '💎',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.description, style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text(
                  _formatDate(t.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isEarn ? '+' : ''}${t.amount}',
            style: TextStyle(
              color: isEarn ? Colors.green : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  Future<void> _watchAd() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('📺 مشاهدة إعلان', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('جاري تحميل الإعلان...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );

    final completed = await AdService.instance.showRewardedAd();

    if (!mounted) return;
    Navigator.of(context).pop();

    if (completed) {
      context.read<TokenBloc>().add(TokenWatchAd());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يجب إكمال الإعلان للحصول على التوكنز'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _shareApp() {
    Share.share(
      'جرب تطبيق SwiftCall — أفضل تطبيق للمكالمات والدردشة مع العائلة! 🚀\nhttps://github.com/Abdjaradat/swiftcall',
      subject: 'SwiftCall',
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) context.read<TokenBloc>().add(TokenShare());
    });
  }
}
