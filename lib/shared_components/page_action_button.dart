import 'dart:async';
import 'package:flutter/material.dart';

class PageActionButton extends StatelessWidget {
  const PageActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.fontSize = 16,
    this.elevation = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final String text;
  final IconData icon;
  final FutureOr<void> Function() onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double fontSize;
  final double elevation;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: () async => onPressed(),
      icon: Icon(icon, color: foregroundColor ?? scheme.onPrimaryContainer),
      style: ButtonStyle(
        padding: WidgetStateProperty.all(padding),
        elevation: WidgetStateProperty.all(elevation),
        backgroundColor:
            WidgetStateProperty.all(backgroundColor ?? scheme.primaryContainer),
        side: WidgetStateProperty.all(
          BorderSide(color: borderColor ?? scheme.outline, width: 2),
        ),
      ),
      label: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: foregroundColor ?? scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}