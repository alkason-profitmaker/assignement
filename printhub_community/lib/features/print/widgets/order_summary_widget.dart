import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/providers.dart';
import 'document_preview_widget.dart';

class OrderSummaryWidget extends ConsumerWidget {
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const OrderSummaryWidget({
    super.key,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderState = ref.watch(orderProvider);
    final document = orderState.selectedDocument!;
    final station = orderState.selectedStation!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Document preview
                DocumentPreviewWidget(
                  document: document,
                  copies: orderState.copies,
                  onCopiesChanged: (copies) {
                    ref.read(orderProvider.notifier).setCopies(copies);
                  },
                ),

                // Station info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppConstants.successColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Print Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                station.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (station.locationDescription != null)
                                Text(
                                  station.locationDescription!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: onBack,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Price breakdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price Breakdown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PriceRow(
                          label:
                              'B/W Pages (${document.bwPageCount} x ${orderState.copies})',
                          amount: document.bwPageCount *
                              orderState.copies *
                              orderState.bwPricePerPagePaise,
                        ),
                        if (document.colorPageCount > 0)
                          _PriceRow(
                            label:
                                'Color Pages (${document.colorPageCount} x ${orderState.copies})',
                            amount: document.colorPageCount *
                                orderState.copies *
                                orderState.colorPricePerPagePaise,
                          ),
                        if (orderState.creditsUsedPaise > 0) ...[
                          const Divider(),
                          _PriceRow(
                            label: 'Credits Applied',
                            amount: -orderState.creditsUsedPaise,
                            isDiscount: true,
                          ),
                        ],
                        const Divider(),
                        _PriceRow(
                          label: 'Total',
                          amount: orderState.finalAmountPaise,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),

                // Credits info
                if (orderState.creditSummary?.hasCredits ?? false)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppConstants.successColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.card_giftcard,
                            color: AppConstants.successColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have ${orderState.creditSummary!.totalBwPages} free B/W pages available!',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppConstants.successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 100), // Space for button
              ],
            ),
          ),
        ),

        // Bottom button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: orderState.isLoading ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: orderState.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Pay ₹${(orderState.finalAmountPaise / 100).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool isBold;
  final bool isDiscount;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isBold = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final amountRupees = (amount.abs() / 100).toStringAsFixed(0);
    final prefix = isDiscount ? '-' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? null : Colors.grey.shade700,
            ),
          ),
          Text(
            '$prefix₹$amountRupees',
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? AppConstants.successColor : null,
            ),
          ),
        ],
      ),
    );
  }
}
