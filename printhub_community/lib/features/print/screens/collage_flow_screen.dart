import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/document.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/document_service.dart';
import 'print_flow_screen.dart';

class CollageFlowScreen extends ConsumerStatefulWidget {
  const CollageFlowScreen({super.key});

  @override
  ConsumerState<CollageFlowScreen> createState() => _CollageFlowScreenState();
}

class _CollageFlowScreenState extends ConsumerState<CollageFlowScreen> {
  List<CollagePhoto> _selectedPhotos = [];
  CollageLayout _selectedLayout = CollageLayout.twoByTwo;
  bool _isProcessing = false;
  Uint8List? _generatedPdf;
  int _currentStep = 0; // 0: select photos, 1: select layout, 2: preview

  final DocumentService _documentService = DocumentService();

  Future<void> _pickPhotos() async {
    final photos = await _documentService.pickImages(maxImages: 20);
    if (photos != null && photos.isNotEmpty) {
      setState(() {
        _selectedPhotos = photos;
        _currentStep = 1; // Move to layout selection
      });
    }
  }

  Future<void> _generateCollage() async {
    if (_selectedPhotos.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final collage = PhotoCollage(
        photos: _selectedPhotos,
        layout: _selectedLayout,
      );

      final pdfBytes = await _documentService.generateCollage(collage);

      setState(() {
        _generatedPdf = pdfBytes;
        _currentStep = 2; // Move to preview
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate collage: $e')),
        );
      }
    }
  }

  Future<void> _proceedToPrint() async {
    if (_generatedPdf == null) return;

    setState(() => _isProcessing = true);

    try {
      // Create a PrintDocument from the generated PDF
      final totalSheets = (_selectedPhotos.length / _selectedLayout.photosPerPage).ceil();

      final document = PrintDocument(
        name: 'Photo_Collage_${DateTime.now().millisecondsSinceEpoch}.pdf',
        path: '',
        type: DocumentType.pdf,
        bytes: _generatedPdf!,
        totalPages: totalSheets,
        pages: List.generate(
          totalSheets,
          (i) => PageInfo(
            pageNumber: i + 1,
            isColor: true, // Photos are always color
          ),
        ),
        fileSizeBytes: _generatedPdf!.length,
        selectedAt: DateTime.now(),
      );

      // Reset order state and set document
      ref.read(orderProvider.notifier).resetOrder();
      ref.read(orderProvider.notifier).setDocument(document);
      ref.read(orderProvider.notifier).loadCredits();

      if (mounted) {
        // Navigate to print flow - it will start at station selection
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const PrintFlowScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Collage'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPhotoSelectionStep();
      case 1:
        return _buildLayoutSelectionStep();
      case 2:
        return _buildPreviewStep();
      default:
        return _buildPhotoSelectionStep();
    }
  }

  Widget _buildPhotoSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Photos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose up to 20 photos for your collage',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),

          // Photo selection area
          Expanded(
            child: _selectedPhotos.isEmpty
                ? _buildEmptyPhotoSelection()
                : _buildPhotoGrid(),
          ),

          // Bottom buttons
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(_selectedPhotos.isEmpty ? 'Select Photos' : 'Add More'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_selectedPhotos.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _currentStep = 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Next (${_selectedPhotos.length} photos)'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPhotoSelection() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade50,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Tap to select photos',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'JPG, PNG supported',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _selectedPhotos.length,
      itemBuilder: (context, index) {
        final photo = _selectedPhotos[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPhotos.removeAt(index);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLayoutSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Layout',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedPhotos.length} photos selected',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Layout options
          Expanded(
            child: ListView(
              children: [
                _buildLayoutOption(
                  layout: CollageLayout.single,
                  title: '1 Photo per Page',
                  subtitle: 'Full page, best quality',
                  icon: Icons.crop_portrait,
                  sheets: _selectedPhotos.length,
                ),
                _buildLayoutOption(
                  layout: CollageLayout.twoByTwo,
                  title: '4 Photos per Page (2x2)',
                  subtitle: 'Great for sharing',
                  icon: Icons.grid_view,
                  sheets: (_selectedPhotos.length / 4).ceil(),
                ),
                _buildLayoutOption(
                  layout: CollageLayout.threeByThree,
                  title: '9 Photos per Page (3x3)',
                  subtitle: 'Compact layout',
                  icon: Icons.apps,
                  sheets: (_selectedPhotos.length / 9).ceil(),
                ),
                _buildLayoutOption(
                  layout: CollageLayout.passport,
                  title: 'Passport Size (8 per page)',
                  subtitle: 'ID photo prints',
                  icon: Icons.badge,
                  sheets: (_selectedPhotos.length / 8).ceil(),
                ),
              ],
            ),
          ),

          // Generate button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _generateCollage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Generate Collage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutOption({
    required CollageLayout layout,
    required String title,
    required String subtitle,
    required IconData icon,
    required int sheets,
  }) {
    final isSelected = _selectedLayout == layout;

    return GestureDetector(
      onTap: () => setState(() => _selectedLayout = layout),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppConstants.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppConstants.primaryColor.withOpacity(0.2)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppConstants.primaryColor : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppConstants.primaryColor : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sheets',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppConstants.primaryColor : null,
                  ),
                ),
                Text(
                  sheets == 1 ? 'sheet' : 'sheets',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 12),
              const Icon(
                Icons.check_circle,
                color: AppConstants.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStep() {
    final sheets = (_selectedPhotos.length / _selectedLayout.photosPerPage).ceil();
    final societyState = ref.watch(societyProvider);
    final pricePerSheet = societyState.currentSociety?.colorPricePerPagePaise ?? 1000;
    final totalPrice = sheets * pricePerSheet;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview & Print',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Collage info card
          Container(
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
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Photo Collage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_selectedPhotos.length} photos - ${_selectedLayout.label}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildInfoRow('Layout', _selectedLayout.label),
                _buildInfoRow('Photos', '${_selectedPhotos.length}'),
                _buildInfoRow('Pages', '$sheets (Color)'),
                const Divider(height: 24),
                _buildInfoRow(
                  'Total',
                  '₹${(totalPrice / 100).toStringAsFixed(0)}',
                  isBold: true,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Print button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _proceedToPrint,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Print - ₹${(totalPrice / 100).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
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
              color: isBold ? null : Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
