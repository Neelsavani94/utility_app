import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Controller/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeController = Get.find<ThemeController>();

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.2)
                : colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => NavigationService.goBack(),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Premium Banner
            _buildPremiumBanner(context, colorScheme, isDark),

            const SizedBox(height: AppConstants.spacingL),

            // Settings Sections
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
              ),
              child: Column(
                children: [
                  // Main Settings
                  _buildSettingsSection(context, colorScheme, isDark, [
                    _SettingsItem(
                      icon: Icons.auto_awesome_rounded,
                      title: 'ScanifyAI Tools',
                      trailing: _SettingsArrow(),
                    ),
                    _SettingsItem(
                      icon: Icons.label_rounded,
                      title: 'Manage Tags',
                      trailing: _SettingsArrow(),
                      onTap: () => NavigationService.toManageTags(),
                    ),
                    _SettingsItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Trash',
                      trailing: _SettingsArrow(),
                    ),
                    _SettingsItem(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      trailing: _SettingsArrow(),
                    ),
                    _SettingsItem(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      trailing: _SettingsSwitch(
                        value: isDark,
                        onChanged: (value) {
                          themeController.toggleTheme();
                        },
                      ),
                    ),
                    _SettingsItem(
                      icon: Icons.lock_rounded,
                      title: 'Privacy Policy',
                      trailing: _SettingsArrow(),
                    ),
                  ]),

                  const SizedBox(height: AppConstants.spacingM),

                  // Divider
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outline.withOpacity(0.1),
                  ),

                  const SizedBox(height: AppConstants.spacingM),

                  // Additional Settings
                  _buildSettingsSection(context, colorScheme, isDark, [
                    _SettingsItem(
                      icon: Icons.star_outline_rounded,
                      title: 'Rate us',
                      trailing: _SettingsArrow(),
                    ),
                    _SettingsItem(
                      icon: Icons.share_rounded,
                      title: 'Refer Friends',
                      trailing: _SettingsArrow(),
                    ),
                    _SettingsItem(
                      icon: Icons.headphones_rounded,
                      title: 'Help',
                      subtitle: 'FAQ\'s, Contact',
                      trailing: _SettingsArrow(),
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About Us',
                      trailing: _SettingsArrow(),
                    ),
                  ]),

                  const SizedBox(height: AppConstants.spacingXL),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.yellow.shade800,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppConstants.spacingM),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Go to PREMIUM!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enjoy all the benefits',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Upgrade Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => NavigationService.toPremium(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Upgrade',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    List<_SettingsItem> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = items.last == item;
          return _buildSettingItem(context, item, colorScheme, isDark, isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    _SettingsItem item,
    ColorScheme colorScheme,
    bool isDark,
    bool isLast,
  ) {
    return InkWell(
      onTap: item.onTap ?? () {},
      borderRadius: BorderRadius.vertical(
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
        top: Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingM,
          vertical: AppConstants.spacingM,
        ),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withOpacity(0.08),
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.trailing != null) item.trailing!,
          ],
        ),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
}

class _SettingsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsSwitch({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: colorScheme.primary,
    );
  }
}

class _SettingsArrow extends StatelessWidget {
  const _SettingsArrow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.chevron_right_rounded,
      color: colorScheme.onSurface.withOpacity(0.3),
      size: 24,
    );
  }
}
