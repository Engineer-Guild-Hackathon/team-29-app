import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Color palette information shared by the home dashboard sections.
class HomeSectionTheme {
  const HomeSectionTheme({
    required this.background,
    required this.card,
    required this.border,
    required this.accent,
    this.secondaryAccent,
  });

  final Color background;
  final Color card;
  final Color border;
  final Color accent;
  final Color? secondaryAccent;
}

/// Predefined themes for each section in the home dashboard.
class HomeSectionThemes {
  static const HomeSectionTheme profile = HomeSectionTheme(
    background: AppColors.dashboard_profile,
    card: AppColors.dashboard_card,
    border: AppColors.dashboard_border,
    accent: AppColors.primary,
    secondaryAccent: AppColors.primary_light,
  );

  static const HomeSectionTheme solve = HomeSectionTheme(
    background: AppColors.dashboard_solve,
    card: AppColors.dashboard_card,
    border: AppColors.dashboard_border,
    accent: AppColors.accent1,
    secondaryAccent: AppColors.accent1_light,
  );

  static const HomeSectionTheme post = HomeSectionTheme(
    background: AppColors.dashboard_post,
    card: AppColors.dashboard_card,
    border: AppColors.dashboard_border,
    accent: AppColors.secondary,
    secondaryAccent: AppColors.secondary_light,
  );

  static const HomeSectionTheme review = HomeSectionTheme(
    background: AppColors.dashboard_review,
    card: AppColors.dashboard_card,
    border: AppColors.dashboard_border,
    accent: AppColors.accent2,
    secondaryAccent: AppColors.accent2_light,
  );

  static const HomeSectionTheme ranking = HomeSectionTheme(
    background: AppColors.dashboard_ranking,
    card: AppColors.dashboard_card,
    border: AppColors.dashboard_border,
    accent: AppColors.primary,
    secondaryAccent: AppColors.primary_light,
  );
}
