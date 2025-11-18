import 'package:flutter/material.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  int selectedPlanIndex = 1; // Default to Quarterly (Best Value)
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> subscriptionPlans = [
    {
      'title': 'Monthly',
      'price': '\$1.99',
      'period': 'per month',
      'description': 'Auto-renewing subscription - Monthly',
      'duration': 'monthly',
    },
    {
      'title': 'Quarterly',
      'price': '\$3.99',
      'period': 'per 3 months',
      'description': 'Auto-renewing subscription - Quarterly',
      'duration': 'quarterly',
      'isBestValue': true,
    },
    {
      'title': 'Yearly',
      'price': '\$9.99',
      'period': 'per year',
      'description': 'Auto-renewing subscription - Yearly',
      'duration': 'yearly',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header with Close Button
                _buildHeader(context, colorScheme, isDark),

                const SizedBox(height: AppConstants.spacingXS),

                // Title Section
                _buildTitleSection(context, colorScheme),

                const SizedBox(height: AppConstants.spacingXL),

                // Crown Icon with Animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildCrownIcon(context, colorScheme),
                ),

                const SizedBox(height: AppConstants.spacingL),

                // Premium Features
                _buildPremiumFeatures(context, colorScheme, isDark),

                const SizedBox(height: AppConstants.spacingXL),

                // Subscription Plans
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                  ),
                  child: _buildSubscriptionPlans(context, colorScheme, isDark),
                ),

                const SizedBox(height: AppConstants.spacingXL),

                // Subscription Terms
                _buildSubscriptionTerms(context, colorScheme, isDark),

                const SizedBox(height: AppConstants.spacingXL),

                // Subscribe Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                  ),
                  child: _buildSubscribeButton(context, colorScheme),
                ),

                const SizedBox(height: AppConstants.spacingXL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          Expanded(child: Container()),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface.withOpacity(0.2)
                  : colorScheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => NavigationService.goBack(),
                borderRadius: BorderRadius.circular(10),
                child: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurface,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Column(
        children: [
          Text(
            'Get Premium',
            style: TextStyle(
              color: colorScheme.onBackground,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Unlock all the power of this mobile tool and enjoy digital experience like never before!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onBackground.withOpacity(0.6),
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrownIcon(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700), // Gold
            const Color(0xFFFFA500), // Orange Gold
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 70, color: Colors.white),
          Positioned(
            top: 20,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatures(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'No Advertising',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.workspace_premium_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Column(
      children: subscriptionPlans.asMap().entries.map((entry) {
        final index = entry.key;
        final plan = entry.value;
        final isSelected = selectedPlanIndex == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedPlanIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.1)
                    : (isDark
                          ? colorScheme.surface.withOpacity(0.15)
                          : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline.withOpacity(0.08),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan['title'] as String,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (plan['isBestValue'] == true) ...[
                              const SizedBox(width: AppConstants.spacingS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Best Value',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan['price'] as String,
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.8),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                plan['period'] as String,
                                style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan['description'] as String,
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline.withOpacity(0.3),
                        width: 2,
                      ),
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubscriptionTerms(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Subscription Terms',
            style: TextStyle(
              color: colorScheme.onBackground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: colorScheme.onBackground.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'By joining, you agree to our '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to Privacy Policy
                    },
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to Terms of Use
                    },
                    child: Text(
                      'Terms of Use',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'The subscription will be automatically renewed at the same price and for the same duration. You can manage and cancel the subscription at any time in settings of the Google Play. The subscription will be automatically renewed at the same price and for the same duration.',
            style: TextStyle(
              color: colorScheme.onBackground.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(BuildContext context, ColorScheme colorScheme) {
    final selectedPlan = subscriptionPlans[selectedPlanIndex];

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle subscription
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Subscribing to ${selectedPlan['title']} plan...',
                ),
                backgroundColor: colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              'Subscribe - ${selectedPlan['price']}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
