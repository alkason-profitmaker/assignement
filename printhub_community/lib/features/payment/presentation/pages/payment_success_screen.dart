import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String printJobId;
  final double amount;
  final String pickupCode;

  const PaymentSuccessScreen({
    super.key,
    required this.printJobId,
    required this.amount,
    required this.pickupCode,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _copyPickupCode() {
    Clipboard.setData(ClipboardData(text: widget.pickupCode));
    AppHelpers.showSuccessSnackBar(context, 'Pickup code copied!');
  }

  void _sharePickupCode() {
    Share.share(
      'My PrintHub pickup code: ${widget.pickupCode}\n\nCollect from the society printing station.',
      subject: 'PrintHub Pickup Code',
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.go('/home');
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // Success Animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Success Message
                Text(
                  'Payment Successful!',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppHelpers.formatCurrencyShort(widget.amount),
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 32),

                // Pickup Code Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Pickup Code',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pickup Code Display
                      GestureDetector(
                        onTap: _copyPickupCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.pickupCode,
                                style: AppTextStyles.h2.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.copy,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Tap to copy',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Instructions
                      _buildInstructionItem(
                        Icons.print_rounded,
                        'Your document is being printed',
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionItem(
                        Icons.location_on_outlined,
                        'Collect from the society station',
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionItem(
                        Icons.timer_outlined,
                        'Please collect within 30 minutes',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Share Button
                OutlinedButton.icon(
                  onPressed: _sharePickupCode,
                  icon: const Icon(Icons.share),
                  label: const Text('Share Pickup Code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),

                const Spacer(),

                // Track Order Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.push('/print-status/${widget.printJobId}');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(
                      'Track Print Status',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Home Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(
                      'Back to Home',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
