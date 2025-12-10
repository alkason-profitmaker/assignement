import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../home/screens/home_screen.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  final String? phone;

  const RegistrationScreen({super.key, this.phone});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _flatController = TextEditingController();
  final _emailController = TextEditingController();

  Society? _selectedSociety;
  List<Society> _societies = [];
  bool _isLoadingSocieties = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _flatController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSocieties() async {
    setState(() => _isLoadingSocieties = true);

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final societies = await supabaseService.searchSocieties();
      setState(() {
        _societies = societies;
        _isLoadingSocieties = false;
      });
    } catch (e) {
      setState(() => _isLoadingSocieties = false);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSociety == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your society')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).completeRegistration(
          phone: widget.phone ?? '',
          name: _nameController.text.trim(),
          societyId: _selectedSociety!.id,
          flatNumber: _flatController.text.trim().toUpperCase(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  List<Society> get _filteredSocieties {
    if (_searchQuery.isEmpty) return _societies;
    final query = _searchQuery.toLowerCase();
    return _societies.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.city.toLowerCase().contains(query) ||
          s.pincode.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Registration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about yourself',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This helps us serve you better',
                style: TextStyle(
                  color: AppConstants.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Society Selection
              const Text(
                'Select Your Society',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Search field
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by name, city, or pincode',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Society list
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoadingSocieties
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSocieties.isEmpty
                        ? const Center(
                            child: Text('No societies found'),
                          )
                        : ListView.builder(
                            itemCount: _filteredSocieties.length,
                            itemBuilder: (context, index) {
                              final society = _filteredSocieties[index];
                              final isSelected = _selectedSociety?.id == society.id;

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor:
                                    AppConstants.primaryColor.withOpacity(0.1),
                                title: Text(society.name),
                                subtitle: Text(
                                  '${society.city} - ${society.pincode}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: AppConstants.primaryColor,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() => _selectedSociety = society);
                                },
                              );
                            },
                          ),
              ),
              const SizedBox(height: 20),

              // Flat number
              TextFormField(
                controller: _flatController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Flat Number',
                  hintText: 'e.g., A-101, B2-304',
                  prefixIcon: const Icon(Icons.home_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your flat number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Email (optional)
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email (Optional)',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Register button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Complete Registration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              if (authState.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  authState.errorMessage!,
                  style: const TextStyle(
                    color: AppConstants.errorColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
