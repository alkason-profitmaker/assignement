import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/helpers.dart';
import '../bloc/upload_bloc.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int fileSize;

  const DocumentPreviewScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  int _copies = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Preview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<UploadBloc, UploadState>(
        listener: (context, state) {
          if (state is UploadError) {
            AppHelpers.showErrorSnackBar(context, state.message);
          } else if (state is PrintJobCreated) {
            // Navigate to payment screen
            context.push('/payment', extra: {
              'printJobId': state.printJobId,
              'amount': state.totalAmount,
              'pageCount': state.document.totalPages,
              'colorPages': state.document.colorPages,
              'bwPages': state.document.bwPages,
            });
          }
        },
        builder: (context, state) {
          if (state is! DocumentAnalyzed && state is! UploadLoading) {
            // Trigger analysis if not done
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<UploadBloc>().add(AnalyzeDocumentEvent(
                    filePath: widget.filePath,
                    fileName: widget.fileName,
                    fileSize: widget.fileSize,
                  ));
            });
          }

          final isLoading = state is UploadLoading;
          final document = state is DocumentAnalyzed ? state.document : null;

          return SafeArea(
            child: Column(
              children: [
                // Preview Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildPreviewArea(document, isLoading),
                  ),
                ),

                // Bottom Panel
                if (document != null)
                  _buildBottomPanel(context, document, isLoading),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewArea(dynamic document, bool isLoading) {
    final extension = widget.fileName.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png'].contains(extension);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        children: [
          // Preview Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isImage ? Icons.image : Icons.picture_as_pdf,
                  color: isImage ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: AppTextStyles.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        AppHelpers.formatFileSize(widget.fileSize),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Preview Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Analyzing document...'),
                      ],
                    ),
                  )
                : isImage
                    ? _buildImagePreview()
                    : _buildPdfPreview(document),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.0,
        child: Image.file(
          File(widget.filePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image,
                    size: 64,
                    color: AppColors.grey400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load preview',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPdfPreview(dynamic document) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.picture_as_pdf,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            widget.fileName,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (document != null)
            Text(
              '${document.totalPages} page(s)',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(
      BuildContext context, dynamic document, bool isLoading) {
    final bwCost = document.bwPages * AppConstants.pricePerBwPage * _copies;
    final colorCost =
        document.colorPages * AppConstants.pricePerColorPage * _copies;
    final totalCost = bwCost + colorCost;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Document Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                'Pages',
                '${document.totalPages}',
                Icons.description_outlined,
              ),
              _buildInfoItem(
                'B/W',
                '${document.bwPages}',
                Icons.format_color_reset,
              ),
              _buildInfoItem(
                'Color',
                '${document.colorPages}',
                Icons.palette_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Copies Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Copies',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _copies > 1
                        ? () => setState(() => _copies--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.primary,
                    disabledColor: AppColors.grey300,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_copies',
                      style: AppTextStyles.h5,
                    ),
                  ),
                  IconButton(
                    onPressed: _copies < 10
                        ? () => setState(() => _copies++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                    disabledColor: AppColors.grey300,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pricing Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (document.bwPages > 0)
                  _buildPriceRow(
                    'B/W (${document.bwPages} × ₹${AppConstants.pricePerBwPage.toInt()} × $_copies)',
                    bwCost,
                  ),
                if (document.colorPages > 0)
                  _buildPriceRow(
                    'Color (${document.colorPages} × ₹${AppConstants.pricePerColorPage.toInt()} × $_copies)',
                    colorCost,
                  ),
                const Divider(),
                _buildPriceRow('Total', totalCost, isTotal: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Proceed Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      context.read<UploadBloc>().add(CreatePrintJobEvent(
                            document: document,
                            copies: _copies,
                          ));
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Proceed to Pay ${AppHelpers.formatCurrencyShort(totalCost)}',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          Text(
            AppHelpers.formatCurrencyShort(amount),
            style: isTotal
                ? AppTextStyles.h5.copyWith(
                    color: AppColors.primary,
                  )
                : AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
