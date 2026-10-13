import 'dart:ui';
import 'package:flutter/material.dart';
import '../session.dart';
import '../ui/theme.dart';
import 'compose_screen.dart';
import 'mail_list_screen.dart';
import 'me_screen.dart';

/// 主页：悬浮玻璃 Dock 导航
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late final AppLifecycleListener _lifecycle;

  late final List<GlobalKey<MailListScreenState>> _listKeys = List.generate(
    4,
    (_) => GlobalKey<MailListScreenState>(),
  );

  static const _titles = ['收件箱', '发件箱', '星标', '全部邮件', '我的'];
  static const _icons = [
    Icons.inbox_rounded,
    Icons.send_rounded,
    Icons.star_rounded,
    Icons.all_inbox_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    // 每次回到前台都从服务端刷新，及时同步网站或其他客户端修改的已读状态。
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_tab < 4) {
          _listKeys[_tab].currentState?.refresh();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (c, _) {
        final acc = session.currentAccount;
        return PageBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: InkWell(
                onTap: _tab < 2 ? _pickAccount : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _titles[_tab],
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_tab < 2 && acc != null)
                              Text(
                                acc.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.sub,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (_tab < 2 && session.accounts.length > 1)
                        const Icon(Icons.expand_more_rounded,
                            size: 20, color: AppColors.sub),
                    ],
                  ),
                ),
              ),
              actions: [
                if (_tab == 0 || _tab == 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ComposeScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: AppColors.brandGradient),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
            body: Stack(
              children: [
                IndexedStack(
                  index: _tab,
                  children: [
                    MailListScreen(key: _listKeys[0], mode: 'inbox'),
                    MailListScreen(key: _listKeys[1], mode: 'sent'),
                    MailListScreen(key: _listKeys[2], mode: 'star'),
                    MailListScreen(key: _listKeys[3], mode: 'all'),
                    const MeScreen(),
                  ],
                ),
                // 悬浮玻璃 Dock
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18 + MediaQuery.of(context).padding.bottom * 0.4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(
                              5, (i) => _dockItem(i)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dockItem(int i) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: AppColors.brandGradient)
              : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[i],
              size: 21,
              color: active ? Colors.white : AppColors.sub,
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                _titles[i],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pickAccount() {
    final accounts = session.accounts;
    if (accounts.length <= 1) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Text('选择邮箱账号',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.ink)),
              ),
              ...accounts.map((a) {
                final cur =
                    session.currentAccount?.accountId == a.accountId;
                return ListTile(
                  leading: GradientAvatar(name: a.email, radius: 20),
                  title: Text(a.email,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: a.name.isNotEmpty ? Text(a.name) : null,
                  trailing: cur
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.brandGradient),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16),
                        )
                      : null,
                  onTap: () {
                    session.selectAccount(a.accountId);
                    Navigator.pop(c);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
