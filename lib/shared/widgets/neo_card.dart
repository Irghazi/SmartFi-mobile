import 'package:flutter/material.dart';
import '../../core/services/audio_service.dart';
import '../../core/theme/neo_colors.dart';

class NeoCard extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double shadowOffset;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const NeoCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 4.0,
    this.shadowOffset = 8.0,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
  });

  @override
  State<NeoCard> createState() => _NeoCardState();
}

class _NeoCardState extends State<NeoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;
    final currentOffset = (_isPressed && isClickable) ? 2.0 : widget.shadowOffset;
    final translation = (_isPressed && isClickable)
        ? Offset(widget.shadowOffset - 2.0, widget.shadowOffset - 2.0)
        : Offset.zero;

    final bgColor = widget.backgroundColor ?? NeoColors.surface(context);
    final bColor = widget.borderColor ??
        (widget.backgroundColor == null ? NeoColors.border(context) : NeoColors.black);
    final isDarkBg =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: bColor,
          width: widget.borderWidth,
        ),
        boxShadow: NeoColors.hardShadow(
          offset: currentOffset,
          color: NeoColors.shadow(context),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: isDarkBg ? NeoColors.textLight : NeoColors.textDark,
        ),
        child: widget.child,
      ),
    );

    if (!isClickable) return card;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        AudioService().playClickSound();
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Transform.translate(
        offset: translation,
        child: card,
      ),
    );
  }
}

