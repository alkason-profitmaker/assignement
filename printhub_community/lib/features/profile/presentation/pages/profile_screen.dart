import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../print_job/presentation/bloc/print_job_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit profile
            },
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final user = authState is AuthAuthenticated ? authState.user : null;

          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.initials,
                    style: AppTextStyles.h2.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName,
                  style: AppTextStyles.h4,
                ),
                Text(
                  user.flatInfo,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Info Cards
                _buildInfoCard(
                  'Contact Info',
                  [
                    _InfoItem(Icons.phone, 'Phone', '+91 ${user.phoneNumber}'),
                    if (user.email != null)
                      _InfoItem(Icons.email, 'Email', user.email!),
                  ],
                ),
                const SizedBox(height: 16),

                _buildInfoCard(
                  'Address',
                  [
                    _InfoItem(Icons.home, 'Flat', user.flatNumber ?? ''),
                    if (user.tower != null)
                      _InfoItem(Icons.business, 'Tower', user.tower!),
                    _InfoItem(Icons.apartment, 'Society', 'Sample Residency'),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats
                BlocBuilder<PrintJobBloc, PrintJobState>(
                  builder: (context, state) {
                    if (state is UserStatsLoaded) {
                      return _buildStatsCard(
                        state.totalPrints,
                        state.totalPages,
                        state.totalSpent,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, List<_InfoItem> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelLarge),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(item.icon, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: AppTextStyles.caption,
                        ),
                        Text(
                          item.value,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStatsCard(int totalPrints, int totalPages, double totalSpent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Statistics', style: AppTextStyles.labelLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '$totalPrints',
                  'Total Prints',
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '$totalPages',
                  'Pages Printed',
                  AppColors.secondary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  AppHelpers.formatCurrencyShort(totalSpent),
                  'Total Spent',
                  AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h5.copyWith(color: color),
        ),
        Text(
          label,
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  _InfoItem(this.icon, this.label, this.value);
}
