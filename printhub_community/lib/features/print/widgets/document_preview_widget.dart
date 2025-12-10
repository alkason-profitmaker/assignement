import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/document.dart';

class DocumentPreviewWidget extends StatelessWidget {
  final PrintDocument document;
  final int copies;
  final ValueChanged<int>? onCopiesChanged;

  const DocumentPreviewWidget({
    super.key,
    required this.document,
    this.copies = 1,
    this.onCopiesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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
          // Document info header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  document.type == DocumentType.pdf
                      ? Icons.picture_as_pdf
                      : Icons.image,
                  color: AppConstants.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${document.fileSizeMB.toStringAsFixed(1)} MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Page details
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: 'Total Pages',
                  value: '${document.totalPages}',
                  icon: Icons.description,
                ),
              ),
              Expanded(
                child: _DetailItem(
                  label: 'B/W Pages',
                  value: '${document.bwPageCount}',
                  icon: Icons.article,
                ),
              ),
              Expanded(
                child: _DetailItem(
                  label: 'Color Pages',
                  value: '${document.colorPageCount}',
                  icon: Icons.palette,
                ),
              ),
            ],
          ),

          if (onCopiesChanged != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Copies selector
            Row(
              children: [
                const Text(
                  'Number of Copies',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _CopiesSelector(
                  value: copies,
                  onChanged: onCopiesChanged!,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _CopiesSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _CopiesSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 20),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: value < AppConstants.maxCopies
                ? () => onChanged(value + 1)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
        ],
      ),
    );
  }
}
