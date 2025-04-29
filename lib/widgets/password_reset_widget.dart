import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PasswordResetWidget extends StatefulWidget {
  const PasswordResetWidget({Key? key}) : super(key: key);

  @override
  _PasswordResetWidgetState createState() => _PasswordResetWidgetState();
}

class _PasswordResetWidgetState extends State<PasswordResetWidget> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = authProvider.user.email;
      
      final response = await http.post(
        Uri.parse('https://qa.api.bussus.com/v2/reset_password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}', // Add token if needed
        },
        body: jsonEncode({
          'email': email,
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
          'confirm_password': _confirmPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        // Password reset successful
        Navigator.of(context).pop(); // Close the reset form
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Password reset failed
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to reset password. Please try again.';
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Network error. Please check your connection and try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset Password', style: AppTextStyles.heading),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(AppDimensions.spacingM),
                  margin: EdgeInsets.only(bottom: AppDimensions.spacingM),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              
              // Current Password
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  hintText: 'Enter your current password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppDimensions.spacingM),
              
              // New Password
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Enter your new password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters long';
                  }
                  // Check for at least one uppercase letter
                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                    return 'Password must contain at least one uppercase letter';
                  }
                  // Check for at least one number
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'Password must contain at least one number';
                  }
                  // Check for at least one special character
                  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                    return 'Password must contain at least one special character';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppDimensions.spacingM),
              
              // Confirm New Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  hintText: 'Re-enter your new password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _resetPassword(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}