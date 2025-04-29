import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  
  // Password reset state
  bool _showForgotPassword = false;
  bool _showNewPasswordFields = false;
  final _resetUsernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Password validation patterns
  final RegExp _upperCasePattern = RegExp(r'[A-Z]');
  final RegExp _digitPattern = RegExp(r'[0-9]');
  final RegExp _specialCharPattern = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  @override
  void initState() {
    super.initState();
    // Add debug print for login screen initialization
    print('🔑 Login screen initialized');
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _resetUsernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter username and password'))
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
        _usernameController.text,
        _passwordController.text
    );

    setState(() => _isLoading = false);

    if (success) {
      // Navigate to home on successful login
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed. Please check credentials.'))
      );
    }
  }
  
  void _showForgotPasswordScreen() {
    setState(() {
      _showForgotPassword = true;
      _showNewPasswordFields = false;
      _resetUsernameController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }
  
  void _validateUsername() {
    if (_resetUsernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your username'))
      );
      return;
    }
    
    // Here you would typically verify the username exists in your system
    // For demo purposes, we'll just proceed to the password reset screen
    setState(() {
      _showNewPasswordFields = true;
    });
  }
  
  bool _validatePassword(String password) {
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 8 characters long'))
      );
      return false;
    }
    
    if (!_upperCasePattern.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must contain at least one uppercase letter'))
      );
      return false;
    }
    
    if (!_digitPattern.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must contain at least one number'))
      );
      return false;
    }
    
    if (!_specialCharPattern.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must contain at least one special character'))
      );
      return false;
    }
    
    return true;
  }
  
  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match'))
      );
      return;
    }
    
    if (!_validatePassword(newPassword)) {
      return;
    }
    
    setState(() => _isLoading = true);
    
    // Here you would typically call your auth provider to reset the password
    // For demo purposes, we'll just simulate a successful password reset
    await Future.delayed(Duration(seconds: 1));
    
    // In a real app, you would call something like:
    // final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // final success = await authProvider.resetPassword(
    //     _resetUsernameController.text,
    //     _newPasswordController.text
    // );
    
    setState(() {
      _isLoading = false;
      _showForgotPassword = false;
      _showNewPasswordFields = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset successfully. Please login with your new password.'))
    );
  }
  
  void _goBackToLogin() {
    setState(() {
      _showForgotPassword = false;
      _showNewPasswordFields = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showForgotPassword) {
      return _buildForgotPasswordScreen();
    } else {
      return _buildLoginScreen();
    }
  }
  
  Widget _buildLoginScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_circle,
                          size: 64,
                          color: Theme.of(context).primaryColor,
                        ),
                        // SizedBox(height: 16),
                        // Text(
                        //   'Welcome Back',
                        //   style: TextStyle(
                        //     fontSize: 24,
                        //     fontWeight: FontWeight.bold,
                        //   ),
                        // ),
                        SizedBox(height: 8),
                        Text(
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 32),
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          obscureText: true,
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordScreen,
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        _isLoading
                            ? CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Login',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildForgotPasswordScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password'),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _goBackToLogin,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: _showNewPasswordFields 
                  ? _buildNewPasswordFields()
                  : _buildUsernameVerification(),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildUsernameVerification() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_reset,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              'Reset your password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'To reset your password, please enter your username. We\'ll help you create a new password.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 32),
            TextField(
              controller: _resetUsernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 32),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _validateUsername,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNewPasswordFields() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.password,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              'Create a new password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your new password must meet the following requirements:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue[100]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequirementRow(
                    icon: Icons.check_circle,
                    text: 'At least 8 characters',
                  ),
                  SizedBox(height: 8),
                  _buildRequirementRow(
                    icon: Icons.check_circle,
                    text: 'At least one uppercase letter (A-Z)',
                  ),
                  SizedBox(height: 8),
                  _buildRequirementRow(
                    icon: Icons.check_circle,
                    text: 'At least one number (0-9)',
                  ),
                  SizedBox(height: 8),
                  _buildRequirementRow(
                    icon: Icons.check_circle,
                    text: 'At least one special character (!@#\$%^&*)',
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              obscureText: true,
            ),
            SizedBox(height: 24),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              obscureText: true,
            ),
            SizedBox(height: 32),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _resetPassword,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save New Password',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRequirementRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.blue[700],
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.blue[700],
            ),
          ),
        ),
      ],
    );
  }
}