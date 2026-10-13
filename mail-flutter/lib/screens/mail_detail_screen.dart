import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../api.dart';
import '../html_render.dart';
import '../mail_store.dart';
import '../models.dart';
import '../ui/theme.dart';

/// 邮件详情：返回最新的 [EmailItem]，null 表示已删除
class MailDetailScreen extends StatefulWidget {
  final EmailItem mail;

  /// 是否在打开时自动标已读。
  final bool autoMarkRead;

  /// 管理员全部邮件列表使用跨用户的管理接口，其余列表仅更新当前用户的邮件。
  final bool allEmailMode;

  const MailDetailScreen({
    super.key,
    required this.mail,
    this.autoMarkRead = true,
    this.allEmailMode = false,
  });

  @override
  State<MailDetailScreen> createState() => _MailDetailScreenState();
}

class _MailDetailScreenState extends State<MailDetailScreen> {
  late EmailItem _mail;
  late final WebViewController _web;
  bool _webReady = false;
  bool _markingRead = false;
  double _webHeight = 220;

  @override
  void initState() {
    super.initState();
    _mail = widget.mail;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _fitWebHeight(),
          // 正文里的链接用外部浏览器打开
          onNavigationRequest: (req) {
            final url = req.url;
            if (url.startsWith('http')) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(
        buildEmailHtml(_mail.content, _mail.text),
        baseUrl: '$kSiteBase/',
      );

    // 不做前端假已读：等待服务端确认数据库更新成功，再同步界面和其他列表。
    if (widget.autoMarkRead && _mail.isUnread && _mail.type == 0) {
      unawaited(_markRead());
    }
  }

  Future<void> _markRead() async {
    if (_markingRead || !_mail.isUnread || _mail.type != 0) return;
    _markingRead = true;
    final emailId = _mail.emailId;
    try {
      if (widget.allEmailMode) {
        await api.markAllRead([emailId]);
      } else {
        await api.markRead([emailId]);
      }
      // 后端已确认更新成功后，才改变本地状态。
      mailStore.markRead(emailId);
      if (mounted) {
        setState(() => _mail = _mail.copyWith(unread: 1));
      }
    } catch (e) {
      if (mounted) {
        _snack(e is ApiException ? '标记已读失败：${e.message}' : '标记已读失败');
      }
    } finally {
      _markingRead = false;
    }
  }

  /// 测量正文实际高度，让 WebView 自适应（图片后加载再复测一次）
  Future<void> _fitWebHeight() async {
    for (var i = 0; i < 2; i++) {
      try {
        final r = await _web.runJavaScriptReturningResult(
            'document.documentElement.scrollHeight');
        final h = double.tryParse('$r') ?? 0;
        if (h > 0 && mounted) {
          setState(() {
            _webHeight = h.clamp(120, 6000).toDouble();
            _webReady = true;
          });
        }
      } catch (_) {}
      if (i == 0) await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  Future<void> _toggleStar() async {
    final nowStar = _mail.isStar != 1;
    final updated = _mail.copyWith(isStar: nowStar ? 1 : 0);
    setState(() => _mail = updated);
    mailStore.setStar(updated, nowStar);
    try {
      if (nowStar) {
        await api.starAdd(_mail.emailId);
      } else {
        await api.starCancel(_mail.emailId);
      }
    } catch (e) {
      if (mounted) {
        final rolledBack = _mail.copyWith(isStar: nowStar ? 0 : 1);
        setState(() => _mail = rolledBack);
        mailStore.setStar(rolledBack, !nowStar);
        _snack(e is ApiException ? e.message : '操作失败');
      }
    }
  }

  Future<void> _delete() async {
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
      await api.deleteEmails([_mail.emailId]);
      mailStore.remove(_mail.emailId); // 同步所有 tab
      if (mounted) Navigator.pop(context, null); // null = 已删除
    } catch (e) {
      _snack(e is ApiException ? e.message : '删除失败');
    }
  }

  void _snack(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> _openAttachment(Attachment a) async {
    final url = Uri.parse(api.attachmentUrl(a.key));
    try {
      final ok =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack('无法打开附件');
    } catch (_) {
      _snack('无法打开附件');
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope：系统返回/手势返回时把最新状态带回去，列表原地更新
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _mail);
      },
      child: PageBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              onPressed: () => Navigator.pop(context, _mail),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _mail.isStar == 1
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: _mail.isStar == 1
                      ? const Color(0xFFFBBF24)
                      : AppColors.ink,
                  size: 26,
                ),
                onPressed: _toggleStar,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onSelected: (v) {
                  if (v == 'copy_html') {
                    Clipboard.setData(ClipboardData(
                        text: _mail.content ?? _mail.text ?? ''));
                    _snack('HTML 源码已复制');
                  }
                },
                itemBuilder: (c) => const [
                  PopupMenuItem(
                    value: 'copy_html',
                    child: Row(
                      children: [
                        Icon(Icons.code_rounded,
                            size: 18, color: AppColors.sub),
                        SizedBox(width: 10),
                        Text('复制 HTML 源码',
                            style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GradientAvatar(
                            name: _mail.displayName, radius: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _mail.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SelectableText(
                                _mail.sendEmail,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.sub),
                              ),
                            ],
                          ),
                        ),
                        if (_mail.isUnread)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: AppColors.brandGradient),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('未读',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _mail.subject,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                        Icons.inbox_rounded,
                        _mail.type == 1
                            ? '发给 ${_mail.recipientDisplay.isNotEmpty ? _mail.recipientDisplay : (_mail.toEmail ?? '')}'
                            : '收件人 ${_mail.toEmail?.isNotEmpty == true ? _mail.toEmail! : ''}'),
                    const SizedBox(height: 6),
                    _infoRow(Icons.schedule_rounded, fullTime(_mail.createTime)),
                    if ((_mail.code ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.blue.withValues(alpha: 0.12),
                              AppColors.pink.withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('验证码',
                                style: TextStyle(
                                    color: AppColors.sub, fontSize: 13)),
                            const SizedBox(width: 10),
                            SelectableText(
                              _mail.code!,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.blue,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_mail.attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.attach_file_rounded,
                              size: 15, color: AppColors.sub),
                          SizedBox(width: 4),
                          Text('附件',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.sub)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _mail.attachments
                            .map((a) => _AttachmentChip(
                                  attachment: a,
                                  onTap: () => _openAttachment(a),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    SizedBox(
                      height: _webHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: WebViewWidget(controller: _web),
                      ),
                    ),
                    if (!_webReady)
                      const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.faint),
        const SizedBox(width: 6),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
          ),
        ),
      ],
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onTap;
  const _AttachmentChip({required this.attachment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.blue.withValues(alpha: 0.1),
              AppColors.pink.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_rounded,
                size: 16, color: AppColors.blue),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${attachment.filename} · ${friendlySize(attachment.size)}',
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
