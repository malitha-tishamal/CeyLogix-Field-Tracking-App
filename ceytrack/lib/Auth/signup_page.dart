import 'package:flutter/material.dart';
import '../land_owner/farmer_registration.dart';
import '../factory_owner/factory_owner_registration.dart';

class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color buttonGradientStart = Color(0xFF2764E7);
  static const Color buttonGradientEnd = Color(0xFF457AED); 
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
}

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  void _onRoleSelected(BuildContext context, String role) {
    Widget nextPage;

    if (role == 'Land Owner') {
      nextPage = const FarmerRegistrationPage();
    } else if (role == 'Factory Owner') {
      nextPage = const FactoryOwnerRegistrationPage();
    } else {
      return; 
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to $role registration.', style: const TextStyle(color: AppColors.darkText)),
        backgroundColor: AppColors.secondaryColor,
        duration: const Duration(milliseconds: 1500),
      ),
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/logo/logo.png',
                      width: 250,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.local_cafe,
                        color: AppColors.secondaryColor,
                        size: 100,
                      ),
                    ),
                    
                    const SizedBox(height: 10),

                    // Title and Subtitle
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Please select account type for registration.',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Land Owner Card
                    _RoleSelectionCard(
                      title: 'Land Owner',
                      imageUrl: 'assets/logo/land.jpg', 
                      onTap: () => _onRoleSelected(context, 'Land Owner'),
                    ),

                    const SizedBox(height: 20),

                    // Factory Owner Card
                    _RoleSelectionCard(
                      title: 'Factory Owner',
                      imageUrl: 'assets/logo/fac.png', 
                      onTap: () => _onRoleSelected(context, 'Factory Owner'),
                    ),

                    // Spacer to push footer to bottom
                    const Spacer(),

                    Column(
                      children: [
                        // Already have an account link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(color: AppColors.darkText),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 200),

                        // Footer Text - Fixed at bottom
                        const Text(
                          'Developed By Malitha Tishamal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.darkText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _ImagePlaceholder({
    required this.imageUrl,
    this.size = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.image_not_supported,
            size: size * 0.6,
            color: AppColors.darkText.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectionCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  const _RoleSelectionCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            _ImagePlaceholder(
              imageUrl: imageUrl,
              size: 50,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }
}