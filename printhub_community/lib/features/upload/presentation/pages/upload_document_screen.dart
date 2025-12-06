import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/helpers.dart';
import '../bloc/upload_bloc.dart';

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  @override
  void initState() {
    super.initState();
    // Reset upload state when entering screen
    context.read<UploadBloc>().add(ResetUploadEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Upload Document'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<UploadBloc, UploadState>(
        listener: (context, state) {
          if (state is UploadError) {
            AppHelpers.showErrorSnackBar(context, state.message);
          } else if (state is DocumentAnalyzed) {
            // Navigate to preview screen
            context.push('/preview', extra: {
              'filePath': state.document.filePath,
              'fileName': state.document.fileName,
              'fileSize': state.document.fileSizeBytes,
            });
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Select a document',
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload PDF or image files up to ${AppConstants.maxFileSizeMb}MB',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload Area
                  Expanded(
                    child: _buildUploadArea(context, state),
                  ),

                  // Supported formats
                  const SizedBox(height: 16),
                  _buildSupportedFormats(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadArea(BuildContext context, UploadState state) {
    final isLoading = state is UploadLoading;

    return GestureDetector(
      onTap: isLoading
          ? null
          : () => context.read<UploadBloc>().add(PickDocumentEvent()),
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(16),
        dashPattern: const [8, 4],
        color: isLoading ? AppColors.grey300 : AppColors.primary,
        strokeWidth: 2,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isLoading
                ? AppColors.grey100
                : AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                const CircularProgressIndicator(
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  (state as UploadLoading).message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tap to upload',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PDF, JPG, or PNG',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Or divider
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 1,
                      color: AppColors.grey300,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'OR',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 60,
                      height: 1,
                      color: AppColors.grey300,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Browse button
                OutlinedButton.icon(
                  onPressed: () =>
                      context.read<UploadBloc>().add(PickDocumentEvent()),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse Files'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportedFormats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supported formats',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFormatChip('PDF', Icons.picture_as_pdf, Colors.red),
              const SizedBox(width: 8),
              _buildFormatChip('JPG', Icons.image, Colors.orange),
              const SizedBox(width: 8),
              _buildFormatChip('PNG', Icons.image, Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Max ${AppConstants.maxPagesPerJob} pages per document',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Dotted border package placeholder - add to pubspec.yaml
class DottedBorder extends StatelessWidget {
  final Widget child;
  final BorderType borderType;
  final Radius radius;
  final List<double> dashPattern;
  final Color color;
  final double strokeWidth;

  const DottedBorder({
    super.key,
    required this.child,
    this.borderType = BorderType.RRect,
    this.radius = Radius.zero,
    this.dashPattern = const [3, 1],
    this.color = Colors.black,
    this.strokeWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(radius),
        border: Border.all(
          color: color,
          width: strokeWidth,
          style: BorderStyle.solid,
        ),
      ),
      child: child,
    );
  }
}

enum BorderType { RRect, Rect, Oval }
