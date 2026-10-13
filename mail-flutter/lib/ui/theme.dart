import 'dart:ui';
import 'package:flutter/material.dart';

/// 设计系统：iOS 液态玻璃风 + 清爽蓝 + 粉蓝
class AppColors {
  static const blue = Color(0xFF2F7CF6);
  static const blueDeep = Color(0xFF1D5FD1);
  static const pink = Color(0xFFF472B6);
  static const ink = Color(0xFF1E293B);
  static const sub = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);

  static const bgTop = Color(0xFFEAF3FF);
  static const bgMid = Color(0xFFF6F9FF);
  static const bgBottom = Color(0xFFFFF1F7);

  static const glassWhite = Color(0xB3FFFFFF);
  static const glassBorder = Color(0x66FFFFFF);

  static const List<Color> brandGradient = [blue, Color(0xFF6D9BFF), pink];
  static const List<Color> bgGradient = [bgTop, bgMid, bgBottom];
}

/// 头像渐变：按名字 hash 取一组粉蓝渐变
List<Color> avatarGradient(String seed) {
  const sets = [
    [Color(0xFF2F7CF6), Color(0xFF6D9BFF)],
    [Color(0xFF8B5CF6), Color(0xFFF472B6)],
    [Color(0xFF06B6D4), Color(0xFF2F7CF6)],
    [Color(0xFFF472B6), Color(0xFFFB923C)],
    [Color(0xFF10B981), Color(0xFF06B6D4)],
    [Color(0xFF6366F1), Color(0xFFA855F7)],
  ];
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return sets[h % sets.length];
}

/// 页面底：柔和三色渐变背景
class PageBackground extends StatelessWidget {
  final Widget child;
  const PageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.bgGradient,
        ),
      ),
      child: child,
    );
  }
}

/// 液态玻璃卡片：半透明白 + 高斯模糊 + 细边框 + 柔阴影
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double opacity;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 20,
    this.opacity = 0.72,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F7CF6).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// 渐变圆形头像
class GradientAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const GradientAvatar({super.key, required this.name, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final g = avatarGradient(name);
    final ch = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
        boxShadow: [
          BoxShadow(
            color: g.first.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 未读小蓝点
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue,
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

/// 渐变主按钮
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: AppColors.brandGradient),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : onPressed,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 全局浅色玻璃主题
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.ink),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
