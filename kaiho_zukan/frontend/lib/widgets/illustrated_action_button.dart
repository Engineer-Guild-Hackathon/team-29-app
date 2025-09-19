import 'package:flutter/material.dart';

class IllustratedActionButton extends StatelessWidget {
  const IllustratedActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.color,
    this.isSelected = false,
    this.illustrationHeight = 96,
    this.solidFill = false, // ← 追加
    this.backgroundColor,
  });

  final bool solidFill; // ← 追加
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? backgroundColor;
  final bool isSelected;
  final double illustrationHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color baseColor = color ?? scheme.primary;
    final Color borderColor = isSelected
        ? baseColor
        : (scheme.outlineVariant.withOpacity(0.7));
    final Color bg =
        backgroundColor ?? (isSelected ? baseColor.withOpacity(0.18) : scheme.surface);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      focusColor: baseColor.withOpacity(0.15),
      hoverColor: baseColor.withOpacity(0.06),
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: baseColor.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: illustrationHeight,
              child: _Illustration(icon: icon, color: baseColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.icon,
    required this.color,
    this.solidFill = false,
  });

  final IconData icon;
  final Color color;
  final bool solidFill;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration decoration = BoxDecoration(
      // 単色塗りかグラデかを切り替え
      color: solidFill ? color : null,
      gradient: solidFill
          ? null
          : LinearGradient(
              colors: [
                color,
                color.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      borderRadius: BorderRadius.circular(16),
    );

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: decoration,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 12,
              left: 16,
              child: _AccentCircle(color: Colors.white.withOpacity(0.25)),
            ),
            Positioned(
              bottom: 16,
              right: 20,
              child: _AccentCircle(
                color: Colors.white.withOpacity(0.18),
                size: 36,
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Icon(icon, size: 44, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentCircle extends StatelessWidget {
  const _AccentCircle({required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
