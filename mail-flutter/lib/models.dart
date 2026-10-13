import 'dart:convert';

class Account {
  final int accountId;
  final String email;
  final String name;
  final int allReceive; // 1=收全部
  final int sort;

  Account({
    required this.accountId,
    required this.email,
    required this.name,
    required this.allReceive,
    required this.sort,
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        accountId: (j['accountId'] as num?)?.toInt() ?? 0,
        email: '${j['email'] ?? ''}',
        name: '${j['name'] ?? ''}',
        allReceive: (j['allReceive'] as num?)?.toInt() ?? 0,
        sort: (j['sort'] as num?)?.toInt() ?? 0,
      );
}

class Attachment {
  final int attId;
  final String key;
  final String filename;
  final String mimeType;
  final int size;

  Attachment({
    required this.attId,
    required this.key,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        attId: (j['attId'] as num?)?.toInt() ?? 0,
        key: '${j['key'] ?? ''}',
        filename: '${j['filename'] ?? '附件'}',
        mimeType: '${j['mimeType'] ?? ''}',
        size: (j['size'] as num?)?.toInt() ?? 0,
      );
}

class EmailItem {
  final int emailId;
  final int accountId;
  final String sendEmail;
  final String name;
  final String subject;
  final String? text;
  final String? content;
  final String listText;
  final int type; // 0 收件 1 已发
  final int unread; // 0 未读 1 已读
  final int isStar;
  final String createTime;
  final String? code;
  final String? toEmail;
  final String? recipient;
  final List<Attachment> attachments;

  EmailItem({
    required this.emailId,
    required this.accountId,
    required this.sendEmail,
    required this.name,
    required this.subject,
    required this.text,
    required this.content,
    required this.listText,
    required this.type,
    required this.unread,
    required this.isStar,
    required this.createTime,
    required this.code,
    required this.toEmail,
    required this.recipient,
    required this.attachments,
  });

  bool get isUnread => unread == 0;

  String get displayName =>
      name.isNotEmpty ? name : (sendEmail.isNotEmpty ? sendEmail : '未知发件人');

  /// recipient 是服务端存的 JSON 字符串：[{"address":"a@b.com","name":""}]
  /// 解析失败时原样返回，避免显示成乱码
  List<({String address, String name})> get recipientList {
    final raw = (recipient ?? '').trim();
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((m) {
          final addr = '${m['address'] ?? ''}'.trim();
          final nm = '${m['name'] ?? ''}'.trim();
          return (address: addr, name: nm);
        }).where((r) => r.address.isNotEmpty).toList();
      }
    } catch (_) {}
    // 非 JSON 时当作单个地址
    return [(address: raw, name: '')];
  }

  /// 友好的收件人显示：a@b.com, c@d.com（有名字时显示名字）
  String get recipientDisplay {
    final list = recipientList;
    if (list.isEmpty) return (toEmail ?? '').trim();
    return list
        .map((r) => r.name.isNotEmpty && r.name != r.address ? r.name : r.address)
        .join(', ');
  }

  EmailItem copyWith({int? unread, int? isStar}) => EmailItem(
        emailId: emailId,
        accountId: accountId,
        sendEmail: sendEmail,
        name: name,
        subject: subject,
        text: text,
        content: content,
        listText: listText,
        type: type,
        unread: unread ?? this.unread,
        isStar: isStar ?? this.isStar,
        createTime: createTime,
        code: code,
        toEmail: toEmail,
        recipient: recipient,
        attachments: attachments,
      );

  String get snippet {
    if (listText.isNotEmpty) return listText;
    final t = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isNotEmpty) return t.length > 120 ? '${t.substring(0, 120)}…' : t;
    return '';
  }

  factory EmailItem.fromJson(Map<String, dynamic> j) {
    final atts = <Attachment>[];
    final raw = j['attList'];
    if (raw is List) {
      for (final a in raw) {
        if (a is Map) atts.add(Attachment.fromJson(Map<String, dynamic>.from(a)));
      }
    }
    // 摘要接口可能把 text 压成 listText
    final listText = '${j['listText'] ?? ''}';
    return EmailItem(
      emailId: (j['emailId'] as num?)?.toInt() ?? 0,
      accountId: (j['accountId'] as num?)?.toInt() ?? 0,
      sendEmail: '${j['sendEmail'] ?? ''}',
      name: '${j['name'] ?? ''}',
      subject: '${j['subject'] ?? '(无主题)'}',
      text: j['text'] == null ? null : '${j['text']}',
      content: j['content'] == null ? null : '${j['content']}',
      listText: listText,
      type: (j['type'] as num?)?.toInt() ?? 0,
      unread: (j['unread'] as num?)?.toInt() ?? 1,
      isStar: (j['isStar'] as num?)?.toInt() ?? 0,
      createTime: '${j['createTime'] ?? ''}',
      code: j['code'] == null ? null : '${j['code']}',
      toEmail: j['toEmail'] == null ? null : '${j['toEmail']}',
      recipient: j['recipient'] == null ? null : '${j['recipient']}',
      attachments: atts,
    );
  }
}

/// 纯文本转简单 HTML（写信时用）
String textToHtml(String text) {
  final esc = text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return esc.split('\n').map((l) => l.isEmpty ? '<br>' : '<p>$l</p>').join();
}

/// createTime 服务端是 UTC（D1 CURRENT_TIMESTAMP），转为本地时区显示
/// "2026-10-09 12:34:56" -> 本地友好显示
String friendlyTime(String raw) {
  if (raw.isEmpty) return '';
  try {
    final dt = DateTime.parse('${raw.replaceFirst(' ', 'T')}Z').toLocal();
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    final hm = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return hm;
    if (diff == 1) return '昨天 $hm';
    if (dt.year == now.year) return '${dt.month}/${dt.day} $hm';
    return '${dt.year}/${dt.month}/${dt.day}';
  } catch (_) {
    return raw.length >= 16 ? raw.substring(0, 16) : raw;
  }
}

/// 详情页用的完整时间：UTC -> 本地 "2026-10-09 20:34"
String fullTime(String raw) {
  if (raw.isEmpty) return '';
  try {
    final dt = DateTime.parse('${raw.replaceFirst(' ', 'T')}Z').toLocal();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${p2(dt.month)}-${p2(dt.day)} ${p2(dt.hour)}:${p2(dt.minute)}';
  } catch (_) {
    return raw;
  }
}

String friendlySize(int bytes) {  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
