import 'package:flutter/foundation.dart';
import 'models.dart';

/// 跨列表共享的邮件状态事件总线（对标网页端的 emailStore.markListRead）
/// 在任一 tab 标已读/标星/删除，所有 tab 的列表都会同步更新，
/// 避免"这边已读那边还显示未读"的割裂。
class MailEvent {
  final int seq;
  final String type; // 'read' | 'unread' | 'star' | 'delete'
  final int emailId;
  final int? isStar;
  final EmailItem? item; // star 事件携带完整对象，供星标页插入
  MailEvent(this.seq, this.type, this.emailId, {this.isStar, this.item});
}

class MailStore extends ChangeNotifier {
  int _seq = 0;
  final List<MailEvent> _events = [];

  int get seq => _seq;

  List<MailEvent> eventsAfter(int seq) =>
      _events.where((e) => e.seq > seq).toList();

  void _emit(String type, int emailId, {int? isStar, EmailItem? item}) {
    _seq++;
    _events.add(MailEvent(_seq, type, emailId, isStar: isStar, item: item));
    if (_events.length > 50) _events.removeAt(0);
    notifyListeners();
  }

  void markRead(int emailId) => _emit('read', emailId);
  void markUnread(int emailId) => _emit('unread', emailId);
  void setStar(EmailItem item, bool star) =>
      _emit('star', item.emailId, isStar: star ? 1 : 0, item: item);
  void remove(int emailId) => _emit('delete', emailId);
}

final mailStore = MailStore();
