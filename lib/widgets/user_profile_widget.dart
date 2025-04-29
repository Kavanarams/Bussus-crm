import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../models/user.dart';
import '../widgets/password_reset_widget.dart'; // Import the password reset widget

class UserProfileWidget extends StatelessWidget {
  const UserProfileWidget({Key? key}) : super(key: key);

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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please log in to view profile')),
              );
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
              Navigator.pop(context);
              authProvider.logout().then((_) {
                // Navigate to login screen or handle logout as needed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
                
                // You can add navigation to login screen here if needed
                Navigator.of(context).pushReplacementNamed('/login');
              });
            },
          ),
        ],
      ),
    );
  }
}