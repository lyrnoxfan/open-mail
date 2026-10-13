import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';

/// 全局登录态：token 存安全存储，当前账号 id 存 prefs
class Session extends ChangeNotifier {
  static const _kToken = 'mail_token';
  static const _kEmail = 'mail_email';
  static const _kAccountId = 'mail_account_id';

  final _secure = const FlutterSecureStorage();

  bool ready = false;
  bool get loggedIn => api.token != null && api.token!.isNotEmpty;

  String? userEmail;
  List<Account> accounts = [];
  int? currentAccountId;

  Account? get currentAccount {
    if (accounts.isEmpty) return null;
    if (currentAccountId == null) return accounts.first;
    return accounts.where((a) => a.accountId == currentAccountId).firstOrNull ??
        accounts.first;
  }

  Future<void> init() async {
    final token = await _secure.read(key: _kToken);
    userEmail = await _secure.read(key: _kEmail);
    final prefs = await SharedPreferences.getInstance();
    final aid = prefs.getInt(_kAccountId);
    if (token != null && token.isNotEmpty) {
      api.token = token;
      currentAccountId = aid;
      try {
        await refreshAll();
      } catch (_) {
        // token 失效则登出
        await logout(silent: true);
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final token = await api.login(email.trim(), password);
    api.token = token;
    await _secure.write(key: _kToken, value: token);
    await _secure.write(key: _kEmail, value: email.trim());
    userEmail = email.trim();
    currentAccountId = null;
    await refreshAll();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    try {
      final info = await api.loginUserInfo();
      userEmail = '${info['email'] ?? userEmail ?? ''}';
    } catch (_) {}
    final list = await api.accountList();
    accounts = list
        .map((e) => Account.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (currentAccountId != null &&
        accounts.every((a) => a.accountId != currentAccountId)) {
      currentAccountId = null;
    }
  }

  Future<void> selectAccount(int accountId) async {
    currentAccountId = accountId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccountId, accountId);
    notifyListeners();
  }

  Future<void> logout({bool silent = false}) async {
    if (!silent) {
      try {
        await api.logout();
      } catch (_) {}
    }
    api.token = null;
    userEmail = null;
    accounts = [];
    currentAccountId = null;
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kEmail);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccountId);
    notifyListeners();
  }
}

final session = Session();
