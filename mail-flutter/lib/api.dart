import 'dart:convert';
import 'package:http/http.dart' as http;

/// 服务端返回 {code, message, data}，code != 200 时抛异常
class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);
  @override
  String toString() => message;
}

class AuthException extends ApiException {
  AuthException(super.code, super.message);
}

/// 换成你自己的 cloud-mail 后端域名（例如 https://mail.example.com）
const String kSiteBase = 'https://your-mail-server.example.com';
const String kApiBase = '$kSiteBase/api';

class MailApi {
  static const String base = kApiBase;
  static const String ossBase = '$kApiBase/oss/';

  String? token;
  final _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': token!,
      };

  dynamic _unwrap(http.Response r) {
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {
      throw ApiException(r.statusCode, '服务器返回异常 (${r.statusCode})');
    }
    if (body is Map && body['code'] is int) {
      final code = body['code'] as int;
      final msg = '${body['message'] ?? ''}';
      if (code == 200) return body['data'];
      if (code == 401) throw AuthException(code, msg.isEmpty ? '登录已过期' : msg);
      throw ApiException(code, msg.isEmpty ? '请求失败' : msg);
    }
    throw ApiException(r.statusCode, '服务器返回异常');
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$base$path').replace(queryParameters: query);

  Future<dynamic> get(String path, [Map<String, String>? query]) async =>
      _unwrap(await _client.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, Object body) async => _unwrap(
      await _client.post(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> put(String path, Object body) async => _unwrap(
      await _client.put(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> delete(String path, [Map<String, String>? query]) async =>
      _unwrap(await _client.delete(_uri(path, query), headers: _headers));

  // ---- 业务接口 ----

  Future<String> login(String email, String password) async {
    final data = await post('/login', {'email': email, 'password': password});
    return '${data['token']}';
  }

  Future<void> logout() async {
    try {
      await delete('/logout');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> loginUserInfo() async =>
      Map<String, dynamic>.from(await get('/my/loginUserInfo'));

  Future<List<dynamic>> accountList() async {
    final data = await get('/account/list', {'size': '30'});
    return data is List ? data : [];
  }

  /// 邮件列表：type 0=收件 1=已发；返回 {list,total,latestEmail}
  Future<Map<String, dynamic>> emailList({
    required int accountId,
    required int allReceive,
    required int type,
    int emailId = 0,
    int size = 20,
  }) async {
    final data = await get('/email/list', {
      'accountId': '$accountId',
      'allReceive': '$allReceive',
      'type': '$type',
      'emailId': '$emailId',
      'size': '$size',
      'full': '1',
    });
    return Map<String, dynamic>.from(data);
  }

  Future<List<dynamic>> starList({int emailId = 0, int size = 20}) async {
    final data = await get('/star/list', {
      'emailId': '$emailId',
      'size': '$size',
      'full': '1',
    });
    return data is List ? data : [];
  }

  void _verifyReadConfirmation(dynamic data, List<int> requestedIds) {
    final rawIds = data is Map ? data['updatedEmailIds'] : null;
    if (rawIds is! List) {
      throw ApiException(500, '服务器未确认邮件已读状态');
    }
    final updatedIds = rawIds.whereType<num>().map((id) => id.toInt()).toSet();
    if (requestedIds.any((id) => !updatedIds.contains(id))) {
      throw ApiException(409, '服务器未确认邮件已标记为已读');
    }
  }

  /// 只在服务端确认数据库更新成功后返回。
  Future<void> markRead(List<int> emailIds) async {
    if (emailIds.isEmpty) return;
    final data = await put('/email/read', {'emailIds': emailIds});
    _verifyReadConfirmation(data, emailIds);
  }

  /// 管理员“全部邮件”可能包含其他用户的邮件，不能使用仅更新本人邮件的接口。
  Future<void> markAllRead(List<int> emailIds) async {
    if (emailIds.isEmpty) return;
    final data = await put('/allEmail/read', {'emailIds': emailIds});
    _verifyReadConfirmation(data, emailIds);
  }

  Future<void> deleteEmails(List<int> emailIds) async {
    if (emailIds.isEmpty) return;
    await delete('/email/delete', {'emailIds': emailIds.join(',')});
  }

  Future<void> starAdd(int emailId) async => await post('/star/add', {'emailId': emailId});
  Future<void> starCancel(int emailId) async =>
      await delete('/star/cancel', {'emailId': '$emailId'});

  Future<void> sendEmail({
    required int accountId,
    required List<String> receiveEmail,
    required String subject,
    required String contentHtml,
    required String text,
    String? sendChannel, // 'self' 走自建 SMTP 通道，不传走默认通道
  }) async {
    await post('/email/send', {
      'accountId': accountId,
      'receiveEmail': receiveEmail,
      'subject': subject,
      'content': contentHtml,
      'text': text,
      if (sendChannel != null) 'sendChannel': sendChannel,
    });
  }

  /// 网站配置（含 hasSelfSmtp：是否配置了自建发件通道）
  Future<Map<String, dynamic>> websiteConfig() async {
    final data = await get('/setting/websiteConfig');
    return data is Map<String, dynamic> ? data : {};
  }

  /// 全部邮件（需管理员权限）
  Future<Map<String, dynamic>> allEmailList({int emailId = 0, int size = 20, int type = 0}) async {
    final data = await get('/allEmail/list', {
      'emailId': '$emailId',
      'size': '$size',
      'type': '$type',
      'full': '1',
    });
    return Map<String, dynamic>.from(data);
  }

  String attachmentUrl(String key) =>
      key.startsWith('http') ? key : '$ossBase$key';
}

final api = MailApi();
