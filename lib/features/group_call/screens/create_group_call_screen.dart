import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/user_model.dart';
import '../../home/bloc/home_bloc.dart';
import '../bloc/group_call_bloc.dart';

class CreateGroupCallScreen extends StatefulWidget {
  const CreateGroupCallScreen({super.key});

  @override
  State<CreateGroupCallScreen> createState() => _CreateGroupCallScreenState();
}

class _CreateGroupCallScreenState extends State<CreateGroupCallScreen> {
  final Set<UserModel> _selected = {};
  bool _isVideo = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(HomeLoadContacts());
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GroupCallBloc, GroupCallState>(
      listener: (ctx, state) {
        if (state is GroupCallActive) {
          ctx.pushReplacement(AppRouter.groupCall);
        } else if (state is GroupCallError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.cairo()),
              backgroundColor: AppColors.callRed,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            'مكالمة جماعية جديدة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _TypeToggle(
                isVideo: _isVideo,
                onToggle: (v) => setState(() => _isVideo = v),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Selected chips ──────────────────────────────────
            if (_selected.isNotEmpty)
              _SelectedChips(
                selected: _selected.toList(),
                onRemove: (u) => setState(() => _selected.remove(u)),
              ),

            // ── Search bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.cairo(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'ابحث عن جهة اتصال...',
                  hintStyle: GoogleFonts.cairo(color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // ── Contacts list ───────────────────────────────────
            Expanded(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (_, state) {
                  if (state is HomeLoading || state is HomeInitial) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  if (state is! HomeLoaded) return const SizedBox();

                  final contacts = state.contacts
                      .where((u) => _query.isEmpty ||
                          u.name.toLowerCase().contains(_query))
                      .toList();

                  if (contacts.isEmpty) {
                    return Center(
                      child: Text(
                        'لا توجد جهات اتصال',
                        style: GoogleFonts.cairo(color: AppColors.textHint),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: contacts.length,
                    itemBuilder: (ctx, i) {
                      final user     = contacts[i];
                      final isChosen = _selected.contains(user);
                      return _ContactCheckTile(
                        user:     user,
                        checked:  isChosen,
                        onToggle: () => setState(() {
                          if (isChosen) {
                            _selected.remove(user);
                          } else {
                            _selected.add(user);
                          }
                        }),
                      )
                          .animate(delay: (i * 30).ms)
                          .fadeIn()
                          .slideX(begin: 0.05, end: 0);
                    },
                  );
                },
              ),
            ),
          ],
        ),

        // ── Start Call button ───────────────────────────────────
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: BlocBuilder<GroupCallBloc, GroupCallState>(
              builder: (ctx, state) {
                final loading = state is GroupCallConnecting;
                return ElevatedButton.icon(
                  onPressed: _selected.isEmpty || loading
                      ? null
                      : () => ctx.read<GroupCallBloc>().add(
                            GroupCallCreate(
                              participants: _selected.toList(),
                              isVideo:      _isVideo,
                            ),
                          ),
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          color: Colors.white,
                        ),
                  label: Text(
                    loading
                        ? 'جارٍ الاتصال...'
                        : 'بدء المكالمة (${_selected.length})',
                    style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isVideo
                        ? AppColors.primary
                        : AppColors.callGreen,
                    disabledBackgroundColor: AppColors.divider,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final bool isVideo;
  final ValueChanged<bool> onToggle;
  const _TypeToggle({required this.isVideo, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            icon: Icons.call_rounded,
            active: !isVideo,
            color: AppColors.callGreen,
            onTap: () => onToggle(false),
          ),
          const SizedBox(width: 2),
          _Chip(
            icon: Icons.videocam_rounded,
            active: isVideo,
            color: AppColors.primary,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _Chip({
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon,
            size: 18, color: active ? color : AppColors.textHint),
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  final List<UserModel> selected;
  final ValueChanged<UserModel> onRemove;
  const _SelectedChips({required this.selected, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: AppColors.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: selected.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final u = selected[i];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.card,
                    backgroundImage: u.photoUrl != null
                        ? CachedNetworkImageProvider(u.photoUrl!)
                        : null,
                    child: u.photoUrl == null
                        ? Text(u.initials,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary))
                        : null,
                  ),
                ],
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => onRemove(u),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.callRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 10, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ContactCheckTile extends StatelessWidget {
  final UserModel user;
  final bool checked;
  final VoidCallback onToggle;
  const _ContactCheckTile({
    required this.user,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onToggle,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.card,
            backgroundImage: user.photoUrl != null
                ? CachedNetworkImageProvider(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Text(user.initials,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary))
                : null,
          ),
          if (user.isOnline)
            Positioned(
              bottom: 1,
              right: 1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.background, width: 2),
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
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: checked ? AppColors.primary : AppColors.divider,
            width: 2,
          ),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}
