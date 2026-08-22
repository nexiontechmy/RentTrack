import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// An AppBar wrapped in the navy gradient used across every screen.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
      child: AppBar(
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: actions,
        leading: leading,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
