import 'package:flutter/material.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';

/// iOS-style press feedback: the child dims and shrinks very slightly while a
/// finger is down, instead of a Material ink ripple. Respects Reduce Motion
/// (no scale, opacity only).
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double pressedOpacity;
  final HitTestBehavior behavior;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.pressedOpacity = 0.7,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) == true;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _enabled ? (_) => _set(true) : null,
      onTapUp: _enabled ? (_) => _set(false) : null,
      onTapCancel: _enabled ? () => _set(false) : null,
      child: AnimatedOpacity(
        opacity: _down ? widget.pressedOpacity : 1,
        duration: AppTheme.dFast,
        curve: AppTheme.curveSnappy,
        child: AnimatedScale(
          scale: _down && !reduceMotion ? widget.pressedScale : 1,
          duration: AppTheme.dFast,
          curve: AppTheme.curveSnappy,
          child: widget.child,
        ),
      ),
    );
  }
}
