import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:${AppConstants.supportPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _emailSupport() async {
    final uri = Uri.parse('mailto:${AppConstants.supportEmail}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsappSupport() async {
    final uri = Uri.parse(
        'https://wa.me/${AppConstants.supportWhatsApp}?text=Hi, I need help with PrintHub');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Options
            Text('Contact Us', style: AppTextStyles.h6),
            const SizedBox(height: 16),

            _buildContactCard(
              icon: Icons.phone,
              title: 'Call Support',
              subtitle: AppConstants.supportPhone,
              color: AppColors.primary,
              onTap: _callSupport,
            ),
            const SizedBox(height: 12),

            _buildContactCard(
              icon: Icons.chat_bubble,
              title: 'WhatsApp',
              subtitle: 'Chat with us',
              color: Colors.green,
              onTap: _whatsappSupport,
            ),
            const SizedBox(height: 12),

            _buildContactCard(
              icon: Icons.email,
              title: 'Email',
              subtitle: AppConstants.supportEmail,
              color: AppColors.accent,
              onTap: _emailSupport,
            ),
            const SizedBox(height: 32),

            // FAQs
            Text('Frequently Asked Questions', style: AppTextStyles.h6),
            const SizedBox(height: 16),

            _buildFaqItem(
              'How do I print a document?',
              'Upload your PDF or image file through the app, select print options, and pay via UPI. Your document will be ready at the printing station within seconds.',
            ),
            _buildFaqItem(
              'What file formats are supported?',
              'We support PDF, JPG, JPEG, and PNG files up to 10MB in size and maximum 50 pages per document.',
            ),
            _buildFaqItem(
              'How long will my print be available?',
              'Your printed documents will be available for pickup for 30 minutes. After that, uncollected documents are shredded for security.',
            ),
            _buildFaqItem(
              'What if my print fails?',
              'If printing fails due to any technical issue, your payment will be automatically refunded to your UPI account within 5-7 business days.',
            ),
            _buildFaqItem(
              'Where is the printing station located?',
              AppConstants.stationLocation,
            ),
            _buildFaqItem(
              'What are the printing charges?',
              'Black & White: ₹${AppConstants.pricePerBwPage.toInt()} per page\nColor: ₹${AppConstants.pricePerColorPage.toInt()} per page\nNo minimum order required!',
            ),
            const SizedBox(height: 32),

            // Operating Hours
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '24/7 Printing Available',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The self-service printing station is available round the clock. Support team available from 9 AM to 9 PM.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelLarge),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: AppTextStyles.labelMedium,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
