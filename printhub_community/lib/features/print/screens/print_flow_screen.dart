import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/providers.dart';
import '../widgets/document_preview_widget.dart';
import '../widgets/station_selector_widget.dart';
import '../widgets/order_summary_widget.dart';
import '../widgets/payment_screen_widget.dart';

class PrintFlowScreen extends ConsumerStatefulWidget {
  const PrintFlowScreen({super.key});

  @override
  ConsumerState<PrintFlowScreen> createState() => _PrintFlowScreenState();
}

class _PrintFlowScreenState extends ConsumerState<PrintFlowScreen> {
  @override
  void initState() {
    super.initState();
    // Reset order state when entering
    ref.read(orderProvider.notifier).resetOrder();
    ref.read(orderProvider.notifier).loadCredits();
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);

    return WillPopScope(
      onWillPop: () async {
        if (orderState.currentStep != OrderStep.selectDocument) {
          _showExitConfirmation();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getStepTitle(orderState.currentStep)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (orderState.currentStep == OrderStep.selectDocument) {
                Navigator.of(context).pop();
              } else {
                _showExitConfirmation();
              }
            },
          ),
        ),
        body: _buildStepContent(orderState),
      ),
    );
  }

  String _getStepTitle(OrderStep step) {
    switch (step) {
      case OrderStep.selectDocument:
        return 'Select Document';
      case OrderStep.selectStation:
        return 'Select Station';
      case OrderStep.preview:
        return 'Preview & Confirm';
      case OrderStep.payment:
        return 'Payment';
      case OrderStep.printing:
        return 'Printing...';
      case OrderStep.completed:
        return 'Completed';
      case OrderStep.failed:
        return 'Print Failed';
    }
  }

  Widget _buildStepContent(OrderState state) {
    switch (state.currentStep) {
      case OrderStep.selectDocument:
        return _buildSelectDocumentStep(state);
      case OrderStep.selectStation:
        return StationSelectorWidget(
          onStationSelected: (station) {
            ref.read(orderProvider.notifier).selectStation(station);
          },
        );
      case OrderStep.preview:
        return OrderSummaryWidget(
          onConfirm: () async {
            final success = await ref.read(orderProvider.notifier).createOrder();
            if (!success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Failed to create order'),
                  backgroundColor: AppConstants.errorColor,
                ),
              );
            }
          },
          onBack: () {
            ref.read(orderProvider.notifier).resetOrder();
          },
        );
      case OrderStep.payment:
        return PaymentScreenWidget(
          order: state.currentOrder!,
          onPaymentComplete: () {
            // Payment handled via webhook
          },
        );
      case OrderStep.printing:
        return _buildPrintingStep(state);
      case OrderStep.completed:
        return _buildCompletedStep(state);
      case OrderStep.failed:
        return _buildFailedStep(state);
    }
  }

  Widget _buildSelectDocumentStep(OrderState state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.upload_file,
              size: 64,
              color: AppConstants.primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Select a Document',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a PDF or image file to print.\nMaximum ${AppConstants.maxFileSizeMB} MB and ${AppConstants.maxPagesPerOrder} pages.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      await ref.read(orderProvider.notifier).selectDocument();
                    },
              icon: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.folder_open),
              label: Text(
                state.isLoading ? 'Processing...' : 'Choose File',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppConstants.errorColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: AppConstants.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Supported formats
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FormatChip(label: 'PDF'),
              const SizedBox(width: 8),
              _FormatChip(label: 'JPG'),
              const SizedBox(width: 8),
              _FormatChip(label: 'PNG'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrintingStep(OrderState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppConstants.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Printing Your Document',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please collect your printout from\n${state.selectedStation?.name ?? 'the station'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedStep(OrderState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppConstants.successColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Print Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your document has been printed.\nPlease collect it from ${state.selectedStation?.name ?? 'the station'}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedStep(OrderState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppConstants.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: AppConstants.errorColor,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Print Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              state.currentOrder?.printErrorCode ?? 'An error occurred during printing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your payment will be refunded automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.successColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Print?'),
        content: const Text(
          'Are you sure you want to cancel? Your progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.errorColor,
            ),
            child: const Text('Cancel Print'),
          ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;

  const _FormatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
