import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PasswordResetWidget extends StatefulWidget {
  const PasswordResetWidget({super.key});

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

  // Password strength checker
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    double strength = 0;
    
    // Basic strength calculation
    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.25;
    
    // Set strength text and color
    String strengthText = '';
    Color strengthColor = Colors.grey;
    
    if (strength <= 0.25) {
      strengthText = 'Weak';
      strengthColor = Colors.red;
    } else if (strength <= 0.5) {
      strengthText = 'Medium';
      strengthColor = Colors.orange;
    } else if (strength <= 0.75) {
      strengthText = 'Strong';
      strengthColor = Colors.lightGreen;
    } else {
      strengthText = 'Very Strong';
      strengthColor = Colors.green;
    }
    
    setState(() {
      _passwordStrength = strength;
      _passwordStrengthText = strengthText;
      _passwordStrengthColor = strengthColor;
    });
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
        Uri.parse('https://dev.api.bussus.com/v2/reset_password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'email': email,
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
          'confirm_password': _confirmPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop();
          
          // Enhanced success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Password changed successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a Material widget instead of Dialog to avoid layout issues
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width > 600 
              ? 550 
              : MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(AppDimensions.spacingL),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_reset,
                        color: Colors.black87,
                        size: 24,
                      ),
                      SizedBox(width: AppDimensions.spacingM),
                      Text(
                        'Reset Password',
                        style: AppTextStyles.heading.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                
                // Content with proper scrolling
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppDimensions.spacingL),
                    child: Form(
                      key: _formKey,
                      child: _buildForm(),
                    ),
                  ),
                ),
                
                // Footer with buttons - Fixed layout
                Padding(
                  padding: EdgeInsets.all(AppDimensions.spacingM),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      SizedBox(width: AppDimensions.spacingM),
                      // FIX: Wrap with a SizedBox to constrain the button
                      SizedBox(
                        width: 140, // Fixed width for the button
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _resetPassword(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: AppDimensions.spacingL,
                              vertical: AppDimensions.spacingM,
                            ),
                          ),
                          child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error message
        if (_errorMessage.isNotEmpty)
          Container(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            margin: EdgeInsets.only(bottom: AppDimensions.spacingM),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              border: Border.all(
                color: AppColors.error.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),

        // Current Password
        _buildPasswordField(
          controller: _currentPasswordController,
          obscureText: _obscureCurrentPassword,
          toggleObscure: () {
            setState(() {
              _obscureCurrentPassword = !_obscureCurrentPassword;
            });
          },
          labelText: 'Current Password',
          hintText: 'Enter your current password',
          icon: Icons.lock_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your current password';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppDimensions.spacingM),
        
        // New Password
        _buildPasswordField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          toggleObscure: () {
            setState(() {
              _obscureNewPassword = !_obscureNewPassword;
            });
          },
          labelText: 'New Password',
          hintText: 'Enter your new password',
          icon: Icons.vpn_key_outlined,
          onChanged: _checkPasswordStrength,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a new password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters long';
            }
            if (!RegExp(r'[A-Z]').hasMatch(value)) {
              return 'Password must contain at least one uppercase letter';
            }
            if (!RegExp(r'[0-9]').hasMatch(value)) {
              return 'Password must contain at least one number';
            }
            if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
              return 'Password must contain at least one special character';
            }
            return null;
          },
        ),
        
        // Password strength indicator
        if (_newPasswordController.text.isNotEmpty) ...[
          SizedBox(height: AppDimensions.spacingS),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 5.0,
                  child: LinearProgressIndicator(
                    value: _passwordStrength,
                    backgroundColor: Colors.grey.shade300,
                    color: _passwordStrengthColor,
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.spacingM),
              Text(
                _passwordStrengthText,
                style: TextStyle(
                  color: _passwordStrengthColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
        
        SizedBox(height: AppDimensions.spacingM),
        
        // Password requirements - Simple list
        // Container(
        //   padding: const EdgeInsets.all(12),
        //   decoration: BoxDecoration(
        //     color: Colors.grey.shade100,
        //     borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        //     border: Border.all(color: Colors.grey.shade300),
        //   ),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Text(
        //         'Password Requirements:',
        //         style: TextStyle(
        //           fontSize: 14,
        //           fontWeight: FontWeight.w500,
        //           color: AppColors.primary,
        //         ),
        //       ),
        //       const SizedBox(height: 8),
        //       _buildRequirement(
        //         'At least 8 characters',
        //         _newPasswordController.text.length >= 8,
        //       ),
        //       _buildRequirement(
        //         'At least one uppercase letter (A-Z)',
        //         RegExp(r'[A-Z]').hasMatch(_newPasswordController.text),
        //       ),
        //       _buildRequirement(
        //         'At least one number (0-9)',
        //         RegExp(r'[0-9]').hasMatch(_newPasswordController.text),
        //       ),
        //       _buildRequirement(
        //         'At least one special character (!@#\$...)',
        //         RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_newPasswordController.text),
        //       ),
        //     ],
        //   ),
        // ),
        
        // SizedBox(height: AppDimensions.spacingM),
        
        // Confirm New Password
        _buildPasswordField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          toggleObscure: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
          labelText: 'Confirm New Password',
          hintText: 'Re-enter your new password',
          icon: Icons.check_circle_outline,
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
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscureText,
    required Function toggleObscure,
    required String labelText,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => toggleObscure(),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          borderSide: BorderSide(color: AppColors.error),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingM,
          vertical: AppDimensions.spacingM,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            color: isMet ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}