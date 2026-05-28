import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../data/services/ad_service.dart';
import '../../../data/services/admin_service.dart';
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
  bool _isAdmin = false;

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
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final uid = await AdminService.instance.currentUid();
    if (uid == null) return;
    final admin = await AdminService.instance.isAdmin(uid);
    if (mounted) setState(() => _isAdmin = admin);
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
        title: const Text('Ù…Ø­ÙØ¸Ø© Ø§Ù„ØªÙˆÙƒÙ†Ø²', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded),
              tooltip: 'Ù„ÙˆØ­Ø© Ø§Ù„ØªØ­ÙƒÙ…',
              onPressed: () => context.push(AppRouter.admin),
            ),
        ],
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
              content: Text('ÙˆØµÙ„Øª Ù„Ù„Ø­Ø¯ Ø§Ù„ÙŠÙˆÙ…ÙŠ Ù„Ù„Ø¥Ø¹Ù„Ø§Ù†Ø§Øª (10 Ø¥Ø¹Ù„Ø§Ù†Ø§Øª/ÙŠÙˆÙ…)'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ));
          } else if (state is TokenShareLimitReached) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('ÙˆØµÙ„Øª Ù„Ù„Ø­Ø¯ Ø§Ù„ÙŠÙˆÙ…ÙŠ Ù„Ù„Ù…Ø´Ø§Ø±ÙƒØ© (3 Ù…Ø±Ø§Øª/ÙŠÙˆÙ…)'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ));
          } else if (state is TokenInsufficient) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Ø±ØµÙŠØ¯Ùƒ ØºÙŠØ± ÙƒØ§ÙÙ â€” ØªØ­ØªØ§Ø¬ ${state.required} ØªÙˆÙƒÙ†ØŒ Ù„Ø¯ÙŠÙƒ ${state.current}'),
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
                    label: const Text('Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©'),
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
              label: const Text('ØªØ­Ù…ÙŠÙ„'),
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
          _buildBannerAd(),
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
            BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            const Text('ðŸ’Ž Ø±ØµÙŠØ¯Ùƒ', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              '${wallet.balance}',
              style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold),
            ),
            const Text('ØªÙˆÙƒÙ†', style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('ÙƒØ³Ø¨Øª', '${wallet.totalEarned}', Icons.arrow_upward),
                _statChip('Ø£Ù†ÙÙ‚Øª', '${wallet.totalSpent}', Icons.arrow_downward),
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
        const Text('ðŸ’° Ø§ÙƒØ³Ø¨ ØªÙˆÙƒÙ†Ø²', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _earnCard(
          icon: 'ðŸ“º',
          title: 'Ø´Ø§Ù‡Ø¯ Ø¥Ø¹Ù„Ø§Ù†Ø§Ù‹',
          subtitle: 'Ù…ØªØ¨Ù‚ÙŠ Ø§Ù„ÙŠÙˆÙ…: ${wallet.remainingAds}/10',
          reward: '+50 ØªÙˆÙƒÙ†',
          available: wallet.canWatchAd,
          onTap: () => _watchAd(),
        ),
        const SizedBox(height: 10),
        _earnCard(
          icon: 'ðŸ“¤',
          title: 'Ø´Ø§Ø±Ùƒ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚',
          subtitle: 'Ù…ØªØ¨Ù‚ÙŠ Ø§Ù„ÙŠÙˆÙ…: ${wallet.remainingShares}/3',
          reward: '+30 ØªÙˆÙƒÙ†',
          available: wallet.canShare,
          onTap: () => _shareApp(),
        ),
      ],
    );
  }

  Widget _buildBannerAd() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        color: AppColors.surface,
        alignment: Alignment.center,
        child: UnityBannerAd(
          placementId: AdService.bannerPlacementId,
          onLoad: (_) {},
          onFailed: (_, __, ___) {},
        ),
      ),
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
              color: available ? const Color(0xFF6C63FF).withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2),
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
        const Text('ðŸ“Š ØªÙƒØ§Ù„ÙŠÙ Ø§Ù„Ø®Ø¯Ù…Ø§Øª', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _costRow('ðŸ’¬', 'Ø±Ø³Ø§Ù„Ø© Ù†ØµÙŠØ©', '${TokenCosts.messagePerMessage} ØªÙˆÙƒÙ†', isFirst: true),
              _costRow('ðŸ“', 'Ù…Ø´Ø§Ø±ÙƒØ© Ù…ÙˆÙ‚Ø¹', '${TokenCosts.locationMessage} ØªÙˆÙƒÙ†'),
              _costRow('ðŸ–¼ï¸', 'Ø±ÙØ¹ ØµÙˆØ±Ø©', '${TokenCosts.imageUpload} ØªÙˆÙƒÙ†'),
              _costRow('ðŸ“Ž', 'Ø±ÙØ¹ Ù…Ù„Ù', '${TokenCosts.fileUpload} ØªÙˆÙƒÙ†'),
              _costRow('ðŸŽ¥', 'Ø±ÙØ¹ ÙÙŠØ¯ÙŠÙˆ', '${TokenCosts.videoUpload} ØªÙˆÙƒÙ†'),
              _costRow('ðŸ“ž', 'Ù…ÙƒØ§Ù„Ù…Ø© ØµÙˆØªÙŠØ©', '${TokenCosts.voiceCallPerMinute} ØªÙˆÙƒÙ†/Ø¯Ù‚ÙŠÙ‚Ø©'),
              _costRow('ðŸ“¹', 'Ù…ÙƒØ§Ù„Ù…Ø© ÙÙŠØ¯ÙŠÙˆ', '${TokenCosts.videoCallPerMinute} ØªÙˆÙƒÙ†/Ø¯Ù‚ÙŠÙ‚Ø©'),
              _costRow('ðŸ‘¥', 'Ù…ÙƒØ§Ù„Ù…Ø© Ø¬Ù…Ø§Ø¹ÙŠØ©', '${TokenCosts.groupCallPerMinute} ØªÙˆÙƒÙ†/Ø¯Ù‚ÙŠÙ‚Ø©', isLast: true),
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
      return const Center(child: Text('Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø³Ø¬Ù„ Ø¨Ø¹Ø¯', style: TextStyle(color: Colors.grey)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ðŸ“‹ Ø§Ù„Ø³Ø¬Ù„', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...transactions.take(10).map((t) => _transactionTile(t)),
      ],
    );
  }

  Widget _transactionTile(TokenTransaction t) {
    final isEarn = t.amount > 0;
    final icon = switch (t.type) {
      'bonus' => 'ðŸŽ',
      'ad' => 'ðŸ“º',
      'share' => 'ðŸ“¤',
      'spend' => 'ðŸ’¸',
      _ => 'ðŸ’Ž',
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
    if (diff.inMinutes < 60) return 'Ù…Ù†Ø° ${diff.inMinutes} Ø¯Ù‚ÙŠÙ‚Ø©';
    if (diff.inHours < 24) return 'Ù…Ù†Ø° ${diff.inHours} Ø³Ø§Ø¹Ø©';
    return 'Ù…Ù†Ø° ${diff.inDays} ÙŠÙˆÙ…';
  }

  Future<void> _watchAd() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('ðŸ“º Ù…Ø´Ø§Ù‡Ø¯Ø© Ø¥Ø¹Ù„Ø§Ù†', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Ø¬Ø§Ø±ÙŠ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø¥Ø¹Ù„Ø§Ù†...', style: TextStyle(color: Colors.white70)),
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
        content: Text('ÙŠØ¬Ø¨ Ø¥ÙƒÙ…Ø§Ù„ Ø§Ù„Ø¥Ø¹Ù„Ø§Ù† Ù„Ù„Ø­ØµÙˆÙ„ Ø¹Ù„Ù‰ Ø§Ù„ØªÙˆÙƒÙ†Ø²'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _shareApp() {
    const appName   = 'SwiftCall';
    const appLink   = 'https://github.com/Abdjaradat/swiftcall/releases/latest';
    const shareText = 'ðŸš€ Ø¬Ø±Ù‘Ø¨ ØªØ·Ø¨ÙŠÙ‚ SwiftCall!\n'
        'Ø£ÙØ¶Ù„ ØªØ·Ø¨ÙŠÙ‚ Ù…ÙƒØ§Ù„Ù…Ø§Øª ÙÙŠØ¯ÙŠÙˆ ÙˆØµÙˆØª ÙˆØ¯Ø±Ø¯Ø´Ø© Ù…Ø¬Ø§Ù†Ø§Ù‹ ðŸ’¬ðŸ“ž\n'
        'ðŸ‘‡ Ø­Ù…Ù‘Ù„Ù‡ Ø§Ù„Ø¢Ù†:\n$appLink';
    final whatsappTxt = Uri.encodeComponent(shareText);
    final telegramTxt = Uri.encodeComponent(shareText);
    final twitterTxt  = Uri.encodeComponent(
        'ðŸš€ Ø¬Ø±Ù‘Ø¨ SwiftCall â€” Ø£ÙØ¶Ù„ ØªØ·Ø¨ÙŠÙ‚ Ù…ÙƒØ§Ù„Ù…Ø§Øª Ù…Ø¬Ø§Ù†ÙŠ!\n$appLink');
    final facebookUrl = 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(appLink)}';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('ðŸ“¤', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ø´Ø§Ø±Ùƒ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17)),
                    Text('Ø§Ø­ØµÙ„ Ø¹Ù„Ù‰ +30 ØªÙˆÙƒÙ† Ù„ÙƒÙ„ Ù…Ø´Ø§Ø±ÙƒØ© (3/ÙŠÙˆÙ…)',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SharePlatform(
                  color: const Color(0xFF25D366),
                  icon: 'ðŸ“±',
                  label: 'ÙˆØ§ØªØ³Ø§Ø¨',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final launched = await launchUrl(
                      Uri.parse('whatsapp://send?text=$whatsappTxt'),
                      mode: LaunchMode.externalApplication,
                    ).catchError((_) => false);
                    if (!launched) {
                      await launchUrl(Uri.parse('https://wa.me/?text=$whatsappTxt'),
                          mode: LaunchMode.externalApplication);
                    }
                    _awardShareToken();
                  },
                ),
                _SharePlatform(
                  color: const Color(0xFF2AABEE),
                  icon: 'âœˆï¸',
                  label: 'ØªÙŠÙ„ÙŠØºØ±Ø§Ù…',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await launchUrl(
                      Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(appLink)}&text=$telegramTxt'),
                      mode: LaunchMode.externalApplication,
                    );
                    _awardShareToken();
                  },
                ),
                _SharePlatform(
                  color: const Color(0xFF1DA1F2),
                  icon: 'ðŸ¦',
                  label: 'ØªÙˆÙŠØªØ±/X',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await launchUrl(
                      Uri.parse('https://twitter.com/intent/tweet?text=$twitterTxt'),
                      mode: LaunchMode.externalApplication,
                    );
                    _awardShareToken();
                  },
                ),
                _SharePlatform(
                  color: const Color(0xFF1877F2),
                  icon: 'ðŸ“˜',
                  label: 'ÙÙŠØ³Ø¨ÙˆÙƒ',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await launchUrl(
                      Uri.parse(facebookUrl),
                      mode: LaunchMode.externalApplication,
                    );
                    _awardShareToken();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SharePlatform(
                  color: const Color(0xFFE1306C),
                  icon: 'ðŸ“¸',
                  label: 'Ø§Ù†Ø³ØªØºØ±Ø§Ù…',
                  onTap: () async {
                    Navigator.pop(ctx);
                    // Copy link then open Instagram
                    await Clipboard.setData(const ClipboardData(text: appLink));
                    final launched = await launchUrl(
                      Uri.parse('instagram://app'),
                      mode: LaunchMode.externalApplication,
                    ).catchError((_) => false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(launched
                            ? 'ØªÙ… Ù†Ø³Ø® Ø§Ù„Ø±Ø§Ø¨Ø· â€” Ø§Ù„ØµÙ‚Ù‡ ÙÙŠ Ù‚ØµØªÙƒ Ø£Ùˆ Ù…Ù†Ø´ÙˆØ±Ùƒ!'
                            : 'ØªÙ… Ù†Ø³Ø® Ø§Ù„Ø±Ø§Ø¨Ø·: $appLink'),
                        backgroundColor: const Color(0xFFE1306C),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                    _awardShareToken();
                  },
                ),
                _SharePlatform(
                  color: const Color(0xFF4CAF50),
                  icon: 'ðŸ”—',
                  label: 'Ù†Ø³Ø® Ø§Ù„Ø±Ø§Ø¨Ø·',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Clipboard.setData(const ClipboardData(text: appLink));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('âœ… ØªÙ… Ù†Ø³Ø® Ø±Ø§Ø¨Ø· Ø§Ù„ØªØ­Ù…ÙŠÙ„!'),
                        backgroundColor: Color(0xFF4CAF50),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                    _awardShareToken();
                  },
                ),
                _SharePlatform(
                  color: AppColors.primary,
                  icon: 'ðŸ“¤',
                  label: 'Ù…Ø´Ø§Ø±ÙƒØ©',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await Share.share(shareText, subject: appName);
                    if (result.status == ShareResultStatus.success) {
                      _awardShareToken();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _awardShareToken() {
    if (mounted) context.read<TokenBloc>().add(TokenShare());
  }
}

class _SharePlatform extends StatelessWidget {
  final Color color;
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _SharePlatform({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
