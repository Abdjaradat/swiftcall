import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/phone_contact_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../call_history/bloc/call_history_bloc.dart';
import '../../call_history/screens/call_history_screen.dart';
import '../bloc/home_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    context.read<HomeBloc>().add(HomeLoadChats());
    context.read<HomeBloc>().add(HomeLoadContacts());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (ctx, _) {
        final onCalls = _tabCtrl.index == 2;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [_buildAppBar(onCalls: onCalls)],
            body: TabBarView(
              controller: _tabCtrl,
              children: [_ChatsTab(), _ContactsTab(), const CallHistoryTab()],
            ),
          ),
          floatingActionButton: onCalls
              ? null
              : FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  onPressed: _showNewChatSheet,
                  child: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
        );
      },
    );
  }

  Widget _buildAppBar({bool onCalls = false}) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 56),
        title: Text(
          'SwiftCall',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            foreground: Paint()
              ..shader = AppColors.primaryGradient.createShader(
                const Rect.fromLTWH(0, 0, 140, 30),
              ),
          ),
        ),
      ),
      actions: [
        if (onCalls)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'مسح السجل',
            onPressed: () => _confirmClearHistory(context),
          )
        else
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () =>
                showSearch(context: context, delegate: _ChatSearch()),
          ),
        FutureBuilder<UserModel?>(
          future: AuthService.instance.getCurrentUserModel(),
          builder: (_, snap) {
            final user = snap.data;
            return GestureDetector(
              onTap: () => context.push(AppRouter.settings),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.card,
                  backgroundImage: user?.photoUrl != null
                      ? CachedNetworkImageProvider(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? Text(
                          user?.initials ?? '?',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabCtrl,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textHint,
        labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'المحادثات'),
          Tab(text: 'جهات الاتصال'),
          Tab(text: 'المكالمات'),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'مسح سجل المكالمات بالكامل؟',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'سيتم حذف جميع المكالمات نهائياً ولا يمكن استعادتها',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('إلغاء', style: GoogleFonts.cairo(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<CallHistoryBloc>().add(CallHistoryClearAll());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.callRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'مسح الكل',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showNewChatSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NewChatSheet(),
    );
  }
}

// ── Chats Tab ──────────────────────────────────────────────

class _ChatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (_, state) {
        if (state is HomeLoading) return _LoadingList();
        if (state is HomeLoaded) {
          final chats = state.filteredChats;
          if (chats.isEmpty) return _EmptyChats();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            itemBuilder: (ctx, i) => _ChatTile(chat: chats[i])
                .animate(delay: (i * 50).ms)
                .fadeIn()
                .slideX(begin: -0.1, end: 0),
          );
        }
        return const SizedBox();
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final other = chat.otherUser;
    final myUid = AuthService.instance.currentUserId ?? '';
    final unread = chat.unreadCountFor(myUid);
    final last = chat.lastMessage;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push(
        '${AppRouter.chat}/${chat.id}',
        extra: other,
      ),
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.callRed),
                title: Text('حذف المحادثة', style: GoogleFonts.cairo(color: AppColors.callRed)),
                onTap: () {
                  Navigator.pop(context);
                  context.read<HomeBloc>().add(HomeDeleteChat(chat.id));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.card,
            backgroundImage: other?.photoUrl != null
                ? CachedNetworkImageProvider(other!.photoUrl!)
                : null,
            child: other?.photoUrl == null
                ? Text(
                    other?.initials ?? '?',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          if (other?.isOnline == true)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        other?.name ?? '...',
        style: GoogleFonts.poppins(
          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
      ),
      subtitle: last?.isDeleted == true
          ? Text(
              'تم حذف الرسالة',
              style: GoogleFonts.cairo(
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            )
          : Text(
              _preview(last),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: unread > 0 ? AppColors.textSecondary : AppColors.textHint,
                fontSize: 13,
                fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            last != null ? timeago.format(last.timestamp, locale: 'ar') : '',
            style: GoogleFonts.cairo(
              color: unread > 0 ? AppColors.primary : AppColors.textHint,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _preview(last) {
    if (last == null) return '';
    switch (last.type) {
      case MessageType.image: return '📷 صورة';
      case MessageType.video: return '🎥 فيديو';
      case MessageType.audio: return '🎵 رسالة صوتية';
      case MessageType.file:  return '📎 ${last.fileName ?? "ملف"}';
      case MessageType.call:  return '📞 مكالمة';
      default:                return last.content;
    }
  }
}

// ── Contacts Tab ───────────────────────────────────────────

class _ContactsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (_, state) {
        if (state is HomeLoading || state is HomeInitial) {
          return _LoadingList();
        }
        if (state is! HomeLoaded) return const SizedBox();

        final appUsers = state.contacts;
        final phoneContacts = state.phoneContacts;
        final permDenied = state.contactsPermissionDenied;

        if (appUsers.isEmpty && phoneContacts.isEmpty) {
          return _EmptyContacts(permDenied: permDenied);
        }

        final items = <Widget>[];

        // ── App users section ──
        if (appUsers.isNotEmpty) {
          items.add(_SectionHeader(title: 'على التطبيق', count: appUsers.length));
          for (var i = 0; i < appUsers.length; i++) {
            items.add(_AppContactTile(user: appUsers[i])
                .animate(delay: (i * 40).ms)
                .fadeIn()
                .slideX(begin: 0.1, end: 0));
          }
        }

        // ── Phone contacts section ──
        if (phoneContacts.isNotEmpty) {
          items.add(_SectionHeader(
              title: 'جهات الاتصال',
              subtitle: 'دعوتهم للانضمام',
              count: phoneContacts.length));
          for (var i = 0; i < phoneContacts.length; i++) {
            items.add(_PhoneContactTile(contact: phoneContacts[i])
                .animate(delay: (i * 30).ms)
                .fadeIn()
                .slideX(begin: 0.1, end: 0));
          }
        }

        if (permDenied) {
          items.add(_PermissionBanner());
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: items,
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int count;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(
              '· $subtitle',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppContactTile extends StatelessWidget {
  final UserModel user;
  const _AppContactTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('${AppRouter.chat}/new_${user.uid}', extra: user),
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: AppColors.callRed),
                title: Text('إخفاء جهة الاتصال', style: GoogleFonts.cairo(color: AppColors.callRed)),
                subtitle: Text('لن يظهر هذا الشخص في قائمة جهات الاتصال', style: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  context.read<HomeBloc>().add(HomeRemoveContact(user.uid));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.card,
            backgroundImage: user.photoUrl != null
                ? CachedNetworkImageProvider(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Text(user.initials,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ))
                : null,
          ),
          if (user.isOnline)
            Positioned(
              bottom: 1,
              right: 1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(user.name,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontSize: 15)),
      subtitle: Text(
        user.isOnline ? 'متصل الآن' : 'غير متصل',
        style: GoogleFonts.cairo(
          color: user.isOnline ? AppColors.online : AppColors.textHint,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconBtn(Icons.call_rounded, AppColors.callGreen, () {
            context.push('${AppRouter.voiceCall}/call_${user.uid}', extra: user);
          }),
          const SizedBox(width: 8),
          _iconBtn(Icons.videocam_rounded, AppColors.primary, () {
            context.push('${AppRouter.videoCall}/call_${user.uid}', extra: user);
          }),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _PhoneContactTile extends StatelessWidget {
  final PhoneContactModel contact;
  const _PhoneContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.card,
        backgroundImage: contact.photo != null
            ? MemoryImage(contact.photo!)
            : null,
        child: contact.photo == null
            ? Text(
                contact.name.isNotEmpty
                    ? contact.name[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              )
            : null,
      ),
      title: Text(
        contact.name,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
      ),
      subtitle: contact.phone != null
          ? Text(
              contact.phone!,
              style: GoogleFonts.poppins(
                color: AppColors.textHint,
                fontSize: 12,
              ),
            )
          : null,
      trailing: TextButton.icon(
        onPressed: () => _invite(contact),
        icon: const Icon(Icons.share_rounded, size: 16),
        label: Text('دعوة', style: GoogleFonts.cairo(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
      ),
    );
  }

  Future<void> _invite(PhoneContactModel c) async {
    const msg = 'جرّب معي SwiftCall — تطبيق المكالمات والمحادثات الخاص!';
    if (c.phone != null) {
      final uri = Uri.parse('sms:${c.phone}?body=${Uri.encodeComponent(msg)}');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }
}

class _PermissionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.contacts_rounded, color: AppColors.textHint, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'امنح الإذن لعرض جهات الاتصال من هاتفك',
              style: GoogleFonts.cairo(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  final bool permDenied;
  const _EmptyContacts({required this.permDenied});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👥', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            permDenied ? 'لا يوجد إذن لجهات الاتصال' : 'لا توجد جهات اتصال',
            style: GoogleFonts.cairo(
              fontSize: 17,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            permDenied
                ? 'افتح الإعدادات وامنح إذن جهات الاتصال'
                : 'ادعُ أصدقاءك لاستخدام SwiftCall',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textHint,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── New Chat Sheet ─────────────────────────────────────────

class _NewChatSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'محادثة جديدة',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<HomeBloc, HomeState>(
              builder: (_, state) {
                if (state is! HomeLoaded) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  controller: ctrl,
                  itemCount: state.contacts.length,
                  itemBuilder: (ctx, i) {
                    final user = state.contacts[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.card,
                        backgroundImage: user.photoUrl != null
                            ? CachedNetworkImageProvider(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(user.initials,
                                style: const TextStyle(color: AppColors.primary))
                            : null,
                      ),
                      title: Text(user.name,
                          style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                      subtitle: Text(
                        user.isOnline ? 'متصل' : 'غير متصل',
                        style: GoogleFonts.cairo(
                          color: user.isOnline ? AppColors.online : AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        ctx.push('${AppRouter.chat}/new_${user.uid}', extra: user);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.surface,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const CircleAvatar(radius: 28, backgroundColor: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Container(height: 12, width: 180, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💬', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'لا توجد محادثات بعد',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ محادثة جديدة بالضغط على زر +',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSearch extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (_, state) {
        if (state is! HomeLoaded) return const SizedBox();
        final q = query.toLowerCase();

        final chats = q.isEmpty
            ? state.chats
            : state.chats.where((c) {
                return c.otherUser?.name.toLowerCase().contains(q) ?? false;
              }).toList();

        final contacts = q.isEmpty
            ? state.contacts
            : state.contacts.where((u) {
                return u.name.toLowerCase().contains(q);
              }).toList();

        if (chats.isEmpty && contacts.isEmpty) {
          return Center(
            child: Text(
              q.isEmpty ? 'ابدأ الكتابة للبحث' : 'لا توجد نتائج',
              style: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 14),
            ),
          );
        }

        return ListView(
          children: [
            if (chats.isNotEmpty) ...[
              _SearchHeader(title: 'المحادثات'),
              ...chats.map((c) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.card,
                      backgroundImage: c.otherUser?.photoUrl != null
                          ? CachedNetworkImageProvider(c.otherUser!.photoUrl!)
                          : null,
                      child: c.otherUser?.photoUrl == null
                          ? Text(c.otherUser?.initials ?? '?',
                              style: const TextStyle(color: AppColors.primary))
                          : null,
                    ),
                    title: Text(c.otherUser?.name ?? '',
                        style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                    subtitle: Text(
                      c.lastMessage?.content ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          color: AppColors.textHint, fontSize: 12),
                    ),
                    onTap: () {
                      close(context, c.id);
                      context.push('${AppRouter.chat}/${c.id}',
                          extra: c.otherUser);
                    },
                  )),
            ],
            if (contacts.isNotEmpty) ...[
              _SearchHeader(title: 'جهات الاتصال'),
              ...contacts.map((u) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.card,
                      backgroundImage: u.photoUrl != null
                          ? CachedNetworkImageProvider(u.photoUrl!)
                          : null,
                      child: u.photoUrl == null
                          ? Text(u.initials,
                              style: const TextStyle(color: AppColors.primary))
                          : null,
                    ),
                    title: Text(u.name,
                        style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                    subtitle: Text(
                      u.isOnline ? 'متصل الآن' : 'غير متصل',
                      style: GoogleFonts.cairo(
                        color: u.isOnline ? AppColors.online : AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call_rounded, size: 20),
                          color: AppColors.callGreen,
                          onPressed: () {
                            close(context, '');
                            context.push(
                                '${AppRouter.voiceCall}/call_${u.uid}',
                                extra: u);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.videocam_rounded, size: 20),
                          color: AppColors.primary,
                          onPressed: () {
                            close(context, '');
                            context.push(
                                '${AppRouter.videoCall}/call_${u.uid}',
                                extra: u);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      close(context, '');
                      context.push('${AppRouter.chat}/new_${u.uid}', extra: u);
                    },
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final String title;
  const _SearchHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textHint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
