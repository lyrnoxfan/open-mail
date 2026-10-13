import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../session.dart';
import '../ui/theme.dart';

/// 写邮件
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _to = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  Account? _from;
  bool _busy = false;
  bool _hasSelfSmtp = false;
  String _sendChannel = 'default'; // 'default' | 'self'

  @override
  void initState() {
    super.initState();
    _from = session.currentAccount;
    api.websiteConfig().then((cfg) {
      if (mounted && cfg['hasSelfSmtp'] == true) {
        setState(() => _hasSelfSmtp = true);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final tos = _to.text
        .split(RegExp(r'[,\n;；，、\s]+'))
        .map((e) => e.trim())
        .where((e) => e.contains('@'))
        .toList();
    if (_from == null) {
      _snack('请先选择发件账号');
      return;
    }
    if (tos.isEmpty) {
      _snack('请填写收件人邮箱');
      return;
    }
    setState(() => _busy = true);
    try {
      final text = _body.text;
      await api.sendEmail(
        accountId: _from!.accountId,
        receiveEmail: tos,
        subject:
            _subject.text.trim().isEmpty ? '(无主题)' : _subject.text.trim(),
        contentHtml: textToHtml(text),
        text: text,
        sendChannel: _hasSelfSmtp ? _sendChannel : null,
      );
      if (mounted) {
        _snack('发送成功');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('发送失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = session.accounts;
    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('写邮件'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: GestureDetector(
                  onTap: _busy ? null : _send,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: AppColors.brandGradient),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            '发送',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded,
                      size: 18, color: AppColors.blue),
                  const SizedBox(width: 10),
                  const Text('发件人',
                      style:
                          TextStyle(color: AppColors.sub, fontSize: 14)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<Account>(
                      value: accounts.contains(_from) ? _from : null,
                      isExpanded: true,
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(16),
                      items: accounts
                          .map((a) => DropdownMenuItem(
                                value: a,
                                child: Text(a.email,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (a) => setState(() => _from = a),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_hasSelfSmtp) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded,
                        size: 18, color: AppColors.blue),
                    const SizedBox(width: 10),
                    const Text('发件通道',
                        style:
                            TextStyle(color: AppColors.sub, fontSize: 14)),
                    const Spacer(),
                    _ChannelChip(
                      label: '默认',
                      selected: _sendChannel == 'default',
                      onTap: () =>
                          setState(() => _sendChannel = 'default'),
                    ),
                    const SizedBox(width: 8),
                    _ChannelChip(
                      label: '自建',
                      selected: _sendChannel == 'self',
                      onTap: () =>
                          setState(() => _sendChannel = 'self'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _to,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: '收件人（多个用逗号分隔）',
                  border: InputBorder.none,
                  icon: Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.blue),
                ),
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _subject,
                decoration: const InputDecoration(
                  hintText: '主题',
                  border: InputBorder.none,
                  icon: Icon(Icons.subject_rounded,
                      size: 18, color: AppColors.blue),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: TextField(
                controller: _body,
                decoration: const InputDecoration(
                  hintText: '正文…',
                  border: InputBorder.none,
                ),
                style:
                    const TextStyle(fontSize: 14.5, height: 1.65),
                maxLines: 16,
                minLines: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 发件通道小胶囊
class _ChannelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChannelChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.blue.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.blue,
          ),
        ),
      ),
    );
  }
}
