/// Validation utilities for PrintHub Community

class Validators {
  Validators._();

  /// Validate phone number (10 digits)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Please enter a valid Indian mobile number';
    }
    return null;
  }

  /// Validate OTP (6 digits)
  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }
    if (value.length != 6) {
      return 'Please enter a valid 6-digit OTP';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'OTP must contain only numbers';
    }
    return null;
  }

  /// Validate name
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Name must be less than 100 characters';
    }
    return null;
  }

  /// Validate flat number
  static String? validateFlatNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Flat number is required';
    }
    if (value.trim().length > 20) {
      return 'Flat number must be less than 20 characters';
    }
    return null;
  }

  /// Validate email (optional)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email is optional
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate pincode
  static String? validatePincode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pincode is required';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Please enter a valid 6-digit pincode';
    }
    return null;
  }

  /// Validate file size (in bytes)
  static bool isValidFileSize(int sizeBytes, {int maxSizeMB = 25}) {
    return sizeBytes <= maxSizeMB * 1024 * 1024;
  }

  /// Validate page count
  static bool isValidPageCount(int pages, {int maxPages = 50}) {
    return pages > 0 && pages <= maxPages;
  }

  /// Validate file extension
  static bool isValidFileExtension(String fileName) {
    final supportedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
    final extension = fileName.split('.').last.toLowerCase();
    return supportedExtensions.contains(extension);
  }
}
