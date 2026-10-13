import 'package:flutter_test/flutter_test.dart';
import 'package:mail/mail_store.dart';
import 'package:mail/models.dart';

EmailItem _mail(int id, {int unread = 0, int isStar = 0}) => EmailItem(
      emailId: id,
      accountId: 1,
      sendEmail: 'a@b.com',
      name: '',
      subject: 's$id',
      text: null,
      content: null,
      listText: '',
      unread: unread,
      type: 0,
      isStar: isStar,
      createTime: '',
      code: null,
      toEmail: null,
      recipient: null,
      attachments: const [],
    );

// 模拟列表页消费事件的逻辑（与 mail_list_screen._onStore 同构）
List<EmailItem> applyEvents(
    List<EmailItem> items, List<MailEvent> evs, String mode) {
  final out = List<EmailItem>.of(items);
  for (final e in evs) {
    switch (e.type) {
      case 'read':
      case 'unread':
        final i = out.indexWhere((m) => m.emailId == e.emailId);
        if (i >= 0) out[i] = out[i].copyWith(unread: e.type == 'read' ? 1 : 0);
      case 'star':
        final star = e.isStar == 1;
        final i = out.indexWhere((m) => m.emailId == e.emailId);
        if (mode == 'star') {
          if (!star && i >= 0) {
            out.removeAt(i);
          } else if (star && i < 0 && e.item != null) {
            final item = e.item!.copyWith(isStar: 1);
            final pos = out.indexWhere((m) => m.emailId < item.emailId);
            if (pos < 0) { out.add(item); } else { out.insert(pos, item); }
          } else if (i >= 0) {
            out[i] = out[i].copyWith(isStar: 1);
          }
        } else if (i >= 0) {
          out[i] = out[i].copyWith(isStar: star ? 1 : 0);
        }
      case 'delete':
        out.removeWhere((m) => m.emailId == e.emailId);
    }
  }
  return out;
}

void main() {
  test('read/unread 事件同步已读状态', () {
    final s = MailStore();
    mailStore.markRead(0); // 避免全局单例干扰，用局部实例
    var items = [_mail(1, unread: 0), _mail(2, unread: 0)];
    items = applyEvents(items, s.eventsAfter(0), 'inbox');
    expect(items.every((m) => m.unread == 0), true); // 无事件时不变
    s.markRead(1);
    s.markRead(2);
    s.markUnread(2); // 回滚
    items = applyEvents(items, s.eventsAfter(0), 'inbox');
    expect(items[0].unread, 1);
    expect(items[1].unread, 0);
  });

  test('star 事件：普通 tab 更新图标，星标 tab 增删', () {
    final s = MailStore();
    // 普通 tab
    var inbox = [_mail(1), _mail(2)];
    s.setStar(_mail(2), true);
    inbox = applyEvents(inbox, s.eventsAfter(0), 'inbox');
    expect(inbox[1].isStar, 1);

    // 星标 tab：插入并保持倒序
    var star = <EmailItem>[_mail(5, isStar: 1)];
    s.setStar(_mail(3), true);
    star = applyEvents(star, s.eventsAfter(1), 'star');
    expect(star.map((m) => m.emailId).toList(), [5, 3]);

    // 星标 tab：取消星标移除
    s.setStar(_mail(5), false);
    star = applyEvents(star, s.eventsAfter(2), 'star');
    expect(star.map((m) => m.emailId).toList(), [3]);

    // 回滚：star 事件 isStar=0 恢复
    s.setStar(_mail(2), false);
    inbox = applyEvents(inbox, s.eventsAfter(2), 'inbox');
    expect(inbox[1].isStar, 0);
  });

  test('delete 事件从所有列表移除', () {
    final s = MailStore();
    s.remove(7);
    final inbox = applyEvents([_mail(6), _mail(7)], s.eventsAfter(0), 'inbox');
    expect(inbox.map((m) => m.emailId).toList(), [6]);
  });

  test('事件序号单调递增且 eventsAfter 不丢事件', () {
    final s = MailStore();
    s.markRead(1);
    s.setStar(_mail(1), true);
    s.remove(2);
    final evs = s.eventsAfter(0);
    expect(evs.length, 3);
    expect(evs.map((e) => e.seq).toList(), [1, 2, 3]);
    expect(s.eventsAfter(3), isEmpty);
  });
}
