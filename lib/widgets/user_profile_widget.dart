import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../models/user.dart';
import '../widgets/password_reset_widget.dart'; 
import '../theme/app_snackbar.dart';

class UserProfileWidget extends StatelessWidget {
  const UserProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            if (authProvider.isAuth) {
              _showUserProfileMenu(context, authProvider);
            } else {
              // Handle not authenticated state
              AppSnackBar.showError(context, 'Please login to view profile');
            }
          },
        );
      },
    );
  }

  void _showUserProfileMenu(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes the modal take the appropriate height
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (context) => _buildUserProfileSheet(context, authProvider),
    );
  }

  void _showPasswordResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const PasswordResetWidget();
      },
    );
  }

  // Fixed logout handler that properly handles navigation
  void _handleLogout(BuildContext context, AuthProvider authProvider) async {
    // Store a reference to BuildContext before async operation
    final NavigatorState navigator = Navigator.of(context);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Execute logout
      await authProvider.logout();
      
      // Dismiss loading dialog first
      if (navigator.mounted) {
        navigator.pop(); // Close loading dialog
      }
      
      // Use a post-frame callback to ensure navigation happens after current build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Navigate to login screen safely
        if (navigator.mounted) {
          navigator.pushNamedAndRemoveUntil(
            '/login',
            (route) => false, // Remove all previous routes
          );
        }
      });
    } catch (e) {
      // Dismiss loading dialog on error
      if (navigator.mounted) {
        navigator.pop(); // Close loading dialog
      }
      
      // Show error in a safe way
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && context.mounted) {
          AppSnackBar.showError(context, 'Logout failed: ${e.toString()}');
        }
      });
      
      debugPrint('Logout error: ${e.toString()}');
    }
  }

  Widget _buildUserProfileSheet(BuildContext context, AuthProvider authProvider) {
    // Get actual user data from the AuthProvider
    final User user = authProvider.user;
    final String username = user.username.isNotEmpty ? user.username : 'User';
    final String email = user.email.isNotEmpty ? user.email : 'No email available';

    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            ),
          ),
          SizedBox(height: AppDimensions.spacingL),
          
          // User avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null ? Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ) : null,
          ),
          
          SizedBox(height: AppDimensions.spacingL),
          
          // Username
          Text(
            username,
            style: AppTextStyles.heading,
          ),
          
          SizedBox(height: AppDimensions.spacingS),
          
          // Email
          Text(
            email,
            style: AppTextStyles.secondaryText,
          ),
          
          SizedBox(height: AppDimensions.spacingXl),
          
          // Profile actions
          ListTile(
            leading: const Icon(Icons.lock_reset, color: AppColors.primary),
            title: const Text('Reset Password'),
            onTap: () {
              // Close the bottom sheet
              Navigator.pop(context);
              // Show the password reset dialog
              _showPasswordResetDialog(context);
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Logout'),
            onTap: () {
              // Close the bottom sheet first
              Navigator.pop(context);
              // Handle logout with proper API call and navigation
              _handleLogout(context, authProvider);
            },
          ),
        ],
      ),
    );
  }
}