/// 邮件正文 HTML 构建：修复服务端原始内容的各类渲染问题
library;

import 'api.dart';

const String _ossBase = '$kApiBase/oss';

const String _style = '''
body{font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif;
font-size:15px;line-height:1.7;color:#1e293b;word-wrap:break-word;margin:0;padding:4px 2px}
img{max-width:100%!important;height:auto!important;border-radius:8px}
pre{white-space:pre-wrap;word-wrap:break-word;background:#f1f5f9;border-radius:8px;padding:10px;font-size:13px}
table{max-width:100%!important;border-collapse:collapse}
td,th{font-size:13px}
a{color:#2563eb;word-break:break-all}
blockquote{margin:8px 0;padding:4px 12px;border-left:3px solid #bfdbfe;color:#475569;background:#f8fafc;border-radius:0 8px 8px 0}
''';

const String _viewport =
    '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=2">';

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// 更鲁棒的 HTML 判定：<!DOCTYPE、<?xml、<!--、</div>、<a>、<img> 等都算 HTML
/// 之前只认 <html|<div|<p 等白名单，导致 <!DOCTYPE 开头的完整邮件被当成纯文本转义显示
bool _looksLikeHtml(String s) {
  final t = s.trimLeft();
  return RegExp(r'^<[a-zA-Z!/?]').hasMatch(t);
}

/// 把服务端返回的 content/text 构造成可在手机 WebView 正常渲染的完整 HTML
String buildEmailHtml(String? content, String? text) {
  var body = (content?.trim().isNotEmpty == true ? content! : (text ?? '')).trim();
  if (body.isEmpty) {
    body = '<p style="color:#94a3b8">（无正文）</p>';
    return '<html><head>$_viewport<style>$_style</style></head><body>$body</body></html>';
  }

  // 替换附件/内嵌图片的 {{domain}} 占位符（与网页端 formatImage 逻辑一致）
  body = body.replaceAll('{{domain}}', _ossBase);

  if (_looksLikeHtml(body)) {
    final lower = body.toLowerCase();
    // 完整 HTML 文档：以 <html 开头，或先有 <!DOCTYPE / <?xml / <!-- 再接 <html>
    final head = lower.substring(0, lower.length < 300 ? lower.length : 300);
    final isFullDoc = RegExp(r'<html[\s>]').hasMatch(head);
    if (isFullDoc) {
      // 完整 HTML：缺 viewport 时注入，保证手机上字号正常
      if (!lower.contains('viewport')) {
        if (lower.contains('<head')) {
          body = body.replaceFirstMapped(
              RegExp(r'<head[^>]*>', caseSensitive: false),
              (m) => '${m.group(0)}$_viewport<style>$_style</style>');
        } else {
          body = body.replaceFirstMapped(
              RegExp(r'<html[^>]*>', caseSensitive: false),
              (m) => '${m.group(0)}<head>$_viewport<style>$_style</style></head>');
        }
      }
      return body;
    }
    // HTML 片段：包一层带 viewport 的壳
    return '<html><head>$_viewport<style>$_style</style></head><body>$body</body></html>';
  }

  // 纯文本：转义后换行转 <br>，否则 HTML 会把换行折叠成一段
  final html = _escape(body).split('\n').map((l) => l.isEmpty ? '<br>' : '$l<br>').join();
  return '<html><head>$_viewport<style>$_style</style></head><body>$html</body></html>';
}
