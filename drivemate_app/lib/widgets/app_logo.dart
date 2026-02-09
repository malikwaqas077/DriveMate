import 'package:flutter/material.dart';

/// Reusable app logo widget that displays the DriveMate icon
class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final BoxDecoration? decoration;

  const AppLogo({
    super.key,
    this.size = 48,
    this.borderRadius = 12,
    this.backgroundColor,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: decoration ??
          BoxDecoration(
            color: backgroundColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
