import 'package:flutter/material.dart';
import '../api.dart';
import '../mail_store.dart';
import '../models.dart';
import '../session.dart';
import '../ui/theme.dart';
import 'mail_detail_screen.dart';

/// 邮件列表（收件箱 / 发件箱 / 星标 / 全部 共用）
class MailListScreen extends StatefulWidget {
  /// 'inbox' | 'sent' | 'star' | 'all'
  final String mode;
  const MailListScreen({super.key, required this.mode});

  @override
  State<MailListScreen> createState() => MailListScreenState();
}

class MailListScreenState extends State<MailListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _items = <EmailItem>[];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _noMore = false;
  String? _error;
  int _cursor = 0; // emailId 游标（倒序）
  int? _accountKey; // 账号变化时刷新
  int _storeSeq = 0; // 已消费的 store 事件序号

  /// 供外部（回到前台刷新）调用
  Future<void> refresh() => _refresh();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    session.addListener(_onSession);
    mailStore.addListener(_onStore);
    _storeSeq = mailStore.seq;
    _accountKey = session.currentAccount?.accountId;
    _refresh();
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    mailStore.removeListener(_onStore);
    _scroll.dispose();
    super.dispose();
  }

  /// 消费共享事件：别的 tab 标已读/标星/删除，这里同步更新
  void _onStore() {
    final evs = mailStore.eventsAfter(_storeSeq);
    if (evs.isEmpty) return;
    _storeSeq = evs.last.seq;
    var changed = false;
    for (final e in evs) {
      switch (e.type) {
        case 'read':
        case 'unread':
          final i = _items.indexWhere((m) => m.emailId == e.emailId);
          if (i >= 0) {
            _items[i] =
                _items[i].copyWith(unread: e.type == 'read' ? 1 : 0);
            changed = true;
          }
          break;
        case 'star':
          final star = e.isStar == 1;
          final i = _items.indexWhere((m) => m.emailId == e.emailId);
          if (widget.mode == 'star') {
            if (!star && i >= 0) {
              _items.removeAt(i);
              changed = true;
            } else if (star && i < 0 && e.item != null) {
              final item = e.item!.copyWith(isStar: 1);
              final pos =
                  _items.indexWhere((m) => m.emailId < item.emailId);
              if (pos < 0) {
                _items.add(item);
              } else {
                _items.insert(pos, item);
              }
              changed = true;
            } else if (i >= 0) {
              _items[i] = _items[i].copyWith(isStar: 1);
              changed = true;
            }
          } else if (i >= 0) {
            _items[i] =
                _items[i].copyWith(isStar: star ? 1 : 0);
            changed = true;
          }
          break;
        case 'delete':
          final n = _items.length;
          _items.removeWhere((m) => m.emailId == e.emailId);
          if (_items.length != n) changed = true;
          break;
      }
    }
    if (changed && mounted) setState(() {});
  }

  void _onSession() {
    final key = session.currentAccount?.accountId;
    if (key != _accountKey) {
      _accountKey = key;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    // 必须重置 _loading，否则刷新期间 _loadMore 会直接 return 导致列表不再加载
    _loading = false;
    setState(() {
      _items.clear();
      _cursor = 0;
      _noMore = false;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _noMore) return;
    if (widget.mode == 'inbox' || widget.mode == 'sent') {
      final acc = session.currentAccount;
      if (acc == null) {
        setState(() => _error = '还没有邮箱账号');
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<EmailItem> got;
      if (widget.mode == 'star') {
        final list = await api.starList(emailId: _cursor);
        got = list
            .map((e) => EmailItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (widget.mode == 'all') {
        final data = await api.allEmailList(emailId: _cursor);
        final list = (data['list'] as List?) ?? [];
        got = list
            .map((e) => EmailItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        final acc = session.currentAccount!;
        final data = await api.emailList(
          accountId: acc.accountId,
          allReceive: acc.allReceive,
          type: widget.mode == 'sent' ? 1 : 0,
          emailId: _cursor,
        );
        final list = (data['list'] as List?) ?? [];
        got = list
            .map((e) => EmailItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        if (got.isEmpty) {
          _noMore = true;
        } else {
          _cursor = got.last.emailId;
          // 去重：store 事件可能已乐观插入（如星标页），避免重复
          final existing = _items.map((e) => e.emailId).toSet();
          for (final m in got) {
            if (!existing.contains(m.emailId)) _items.add(m);
          }
          if (got.length < 20) _noMore = true;
        }
        _loading = false;
      });
    } on AuthException {
      if (mounted) {
        await session.logout();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '加载失败：$e';
      });
    }
  }

  void _replaceItem(EmailItem m) {
    final i = _items.indexWhere((e) => e.emailId == m.emailId);
    if (i >= 0 && mounted) setState(() => _items[i] = m);
  }

  Future<void> _toggleStar(EmailItem m) async {
    final nowStar = m.isStar != 1;
    final updated = m.copyWith(isStar: nowStar ? 1 : 0);
    _replaceItem(updated); // 乐观更新
    mailStore.setStar(updated, nowStar); // 同步其他 tab
    try {
      if (nowStar) {
        await api.starAdd(m.emailId);
      } else {
        await api.starCancel(m.emailId);
      }
    } catch (e) {
      _replaceItem(m); // 失败回滚
      mailStore.setStar(m, !nowStar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e is ApiException ? e.message : '操作失败')));
      }
    }
  }

  Future<void> _delete(EmailItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除邮件'),
        content: const Text('确定删除这封邮件吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteEmails([m.emailId]);
      mailStore.remove(m.emailId); // 同步其他 tab
      if (mounted) setState(() => _items.removeWhere((e) => e.emailId == m.emailId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e is ApiException ? e.message : '删除失败')));
      }
    }
  }

  /// 打开详情；详情页返回最新的 EmailItem（null 表示已删除），原地更新列表
  Future<void> _open(EmailItem m) async {
    final result = await Navigator.push<EmailItem?>(
      context,
      MaterialPageRoute(
        builder: (_) => MailDetailScreen(
          mail: m,
          autoMarkRead: true,
          allEmailMode: widget.mode == 'all',
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _items.removeWhere((e) => e.emailId == m.emailId));
    } else {
      _replaceItem(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null && _items.isEmpty) {
      return Center(
        child: GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 44, color: AppColors.faint),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.sub)),
              const SizedBox(height: 12),
              GradientButton(label: '重试', onPressed: _refresh),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.blue,
        child: ListView(
          children: const [
            SizedBox(height: 140),
            Center(
              child: Column(
                children: [
                  Icon(Icons.mark_email_read_outlined,
                      size: 56, color: AppColors.faint),
                  SizedBox(height: 12),
                  Text('暂无邮件', style: TextStyle(color: AppColors.faint)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.blue,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
        itemCount: _items.length + 1,
        itemBuilder: (c, i) {
          if (i == _items.length) {
            if (_noMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: Text('— 到底了 —',
                        style: TextStyle(color: AppColors.faint, fontSize: 12))),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final m = _items[i];
          return _MailCard(
            mail: m,
            onTap: () => _open(m),
            onStar: () => _toggleStar(m),
            onDelete: () => _delete(m),
          );
        },
      ),
    );
  }
}

class _MailCard extends StatelessWidget {
  final EmailItem mail;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final VoidCallback onDelete;

  const _MailCard({
    required this.mail,
    required this.onTap,
    required this.onStar,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 已读状态只对收件有意义，发件箱不显示未读点
    final unread = mail.type == 0 && mail.isUnread;
    final peers = mail.type == 1
        ? mail.recipientDisplay
        : mail.displayName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(mail.emailId),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFF87171), Color(0xFFEF4444)],
            ),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 26),
        ),
        confirmDismiss: (_) async {
          onDelete();
          return false;
        },
        child: GlassCard(
          onTap: onTap,
          opacity: unread ? 0.85 : 0.6,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientAvatar(
                  name: mail.type == 1 ? peers : mail.displayName, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (unread) ...[
                          const UnreadDot(),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            mail.type == 1
                                ? (peers.isNotEmpty ? '发给 $peers' : '发件箱')
                                : peers,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          friendlyTime(mail.createTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: unread ? AppColors.blue : AppColors.faint,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mail.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            unread ? FontWeight.w600 : FontWeight.normal,
                        color: unread
                            ? AppColors.ink
                            : AppColors.ink.withValues(alpha: 0.75),
                      ),
                    ),
                    if (mail.snippet.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        mail.snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.sub),
                      ),
                    ],
                    if (mail.attachments.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.attach_file_rounded,
                                size: 13, color: AppColors.faint),
                            SizedBox(width: 2),
                            Text('附件',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.faint)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              InkWell(
                onTap: onStar,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    mail.isStar == 1
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: mail.isStar == 1
                        ? const Color(0xFFFBBF24)
                        : AppColors.faint,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
