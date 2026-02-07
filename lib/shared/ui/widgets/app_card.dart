import 'package:flutter/material.dart';
import '../ui_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: UiTokens.r18,
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: UiTokens.softShadow(opacity: 0.06),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return _Pressable(
      onTap: onTap!,
      child: card,
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _down ? 0.98 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 110),
          opacity: _down ? 0.92 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
