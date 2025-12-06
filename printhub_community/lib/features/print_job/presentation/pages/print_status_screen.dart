import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/helpers.dart';
import '../../domain/entities/print_job_entity.dart';
import '../bloc/print_job_bloc.dart';

class PrintStatusScreen extends StatefulWidget {
  final String jobId;

  const PrintStatusScreen({super.key, required this.jobId});

  @override
  State<PrintStatusScreen> createState() => _PrintStatusScreenState();
}

class _PrintStatusScreenState extends State<PrintStatusScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadJob();
    _startAutoRefresh();
  }

  void _loadJob() {
    context.read<PrintJobBloc>().add(LoadPrintJobEvent(widget.jobId));
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadJob();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Print Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: BlocBuilder<PrintJobBloc, PrintJobState>(
        builder: (context, state) {
          if (state is PrintJobLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is PrintJobError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadJob,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is PrintJobLoaded) {
            return _buildJobDetails(state.job);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildJobDetails(PrintJobEntity job) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(job),
          const SizedBox(height: 24),

          // Pickup Code (if ready)
          if (job.status == PrintJobStatus.ready && job.pickupCode != null)
            _buildPickupCodeCard(job.pickupCode!),

          if (job.status == PrintJobStatus.ready) const SizedBox(height: 24),

          // Progress Timeline
          _buildProgressTimeline(job),
          const SizedBox(height: 24),

          // Job Details
          _buildJobDetailsCard(job),
          const SizedBox(height: 24),

          // Actions
          if (job.isActive) _buildActions(job),
        ],
      ),
    );
  }

  Widget _buildStatusCard(PrintJobEntity job) {
    final statusColor = AppHelpers.getStatusColor(job.status.name);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            AppHelpers.getStatusIcon(job.status.name),
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 16),
          Text(
            job.statusText,
            style: AppTextStyles.h4.copyWith(
              color: statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.statusDescription,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (job.status == PrintJobStatus.ready && job.timeRemaining != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Collect within ${job.timeRemaining!.inMinutes} min',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickupCodeCard(String pickupCode) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: pickupCode));
        AppHelpers.showSuccessSnackBar(context, 'Pickup code copied!');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
          boxShadow: AppShadows.cardShadow,
        ),
        child: Column(
          children: [
            Text(
              'Pickup Code',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  pickupCode,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.copy,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to copy',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTimeline(PrintJobEntity job) {
    final stages = [
      _TimelineStage(
        title: 'Order Placed',
        subtitle: AppHelpers.formatDateTime(job.createdAt),
        isCompleted: true,
        isCurrent: job.status == PrintJobStatus.pending,
      ),
      _TimelineStage(
        title: 'Payment Received',
        subtitle: job.paymentAt != null
            ? AppHelpers.formatDateTime(job.paymentAt!)
            : 'Pending',
        isCompleted: job.paymentAt != null,
        isCurrent: job.status == PrintJobStatus.processing,
      ),
      _TimelineStage(
        title: 'Printing',
        subtitle: job.printingStartedAt != null
            ? AppHelpers.formatDateTime(job.printingStartedAt!)
            : 'Waiting',
        isCompleted: job.printingStartedAt != null,
        isCurrent: job.status == PrintJobStatus.printing,
      ),
      _TimelineStage(
        title: 'Ready for Pickup',
        subtitle: job.readyAt != null
            ? AppHelpers.formatDateTime(job.readyAt!)
            : 'In progress',
        isCompleted: job.readyAt != null,
        isCurrent: job.status == PrintJobStatus.ready,
      ),
      _TimelineStage(
        title: 'Collected',
        subtitle: job.collectedAt != null
            ? AppHelpers.formatDateTime(job.collectedAt!)
            : 'Awaiting',
        isCompleted: job.collectedAt != null,
        isCurrent: job.status == PrintJobStatus.collected,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress', style: AppTextStyles.h6),
          const SizedBox(height: 16),
          ...stages.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final isLast = index == stages.length - 1;

            return _buildTimelineItem(stage, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineStage stage, bool isLast) {
    final color = stage.isCompleted
        ? AppColors.success
        : stage.isCurrent
            ? AppColors.primary
            : AppColors.grey300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: stage.isCompleted
                    ? AppColors.success
                    : stage.isCurrent
                        ? AppColors.primary
                        : AppColors.grey100,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: stage.isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : stage.isCurrent
                      ? Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: color,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: stage.isCompleted || stage.isCurrent
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
                Text(
                  stage.subtitle,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobDetailsCard(PrintJobEntity job) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: AppTextStyles.h6),
          const SizedBox(height: 16),
          _buildDetailRow('Document', job.fileName),
          _buildDetailRow('Pages', '${job.totalPages}'),
          _buildDetailRow('Copies', '${job.copies}'),
          _buildDetailRow('Amount', AppHelpers.formatCurrencyShort(job.totalAmount)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(PrintJobEntity job) {
    return Column(
      children: [
        if (job.status == PrintJobStatus.ready)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<PrintJobBloc>().add(
                      MarkAsCollectedEvent(job.id),
                    );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark as Collected'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.success,
              ),
            ),
          ),
        if (job.status == PrintJobStatus.pending) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await AppHelpers.showConfirmDialog(
                  context,
                  title: 'Cancel Print Job?',
                  message: 'Are you sure you want to cancel this print job?',
                  confirmText: 'Cancel Job',
                  isDestructive: true,
                );
                if (confirm) {
                  context.read<PrintJobBloc>().add(
                        CancelPrintJobEvent(job.id),
                      );
                  context.go('/home');
                }
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineStage {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;

  _TimelineStage({
    required this.title,
    required this.subtitle,
    this.isCompleted = false,
    this.isCurrent = false,
  });
}
