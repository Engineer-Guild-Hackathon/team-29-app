import 'package:flutter/material.dart';

import '../constants/home_section_theme.dart';

/// Provides a consistent background and safe area for embedded home sections.
class HomeSectionSurface extends StatelessWidget {
  const HomeSectionSurface({
    super.key,
    required this.theme,
    required this.child,
    this.maxContentWidth = 880,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    this.scrollable = false,
    this.expandChild = false,
  });

  final HomeSectionTheme theme;
  final Widget child;
  final double maxContentWidth;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (!expandChild) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: content,
        ),
      );
    } else if (maxContentWidth < double.infinity) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: content,
        ),
      );
    }

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: theme.background),
      child: SafeArea(
        top: false,
        bottom: false,
        child: content,
      ),
    );
  }
}

/// Card component that matches the dashboard surface styling.
class HomeSectionCard extends StatelessWidget {
  const HomeSectionCard({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final HomeSectionTheme theme;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
