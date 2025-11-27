import 'package:flutter/material.dart';
import 'Auth/startup_page.dart'; // Import the dedicated start page

// --- AppColors definition merged from lib/app_colors.dart ---
class AppColors {
  // Background color requested previously (EEEBFF)
  static const Color background = Color(0xFFEEEBFF);
  // Dark text color (matching the dark blue/gray from the image)
  static const Color darkText = Color(0xFF2C2A3A);
  // Primary button color (2764E7)
  static const Color primaryBlue = Color(0xFF2764E7);
  // Button Gradient colors (using primary blue as the base)
  static const Color buttonGradientStart = Color(0xFF2764E7);
  static const Color buttonGradientEnd = Color(0xFF457AED); 
  // Custom color for the logo/icon based on the new "Antibiotics" theme
  static const Color secondaryColor = Color(0xFF1B998B); 
  // White card background
  static const Color cardBackground = Colors.white;
}
// --- End of AppColors definition ---


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget is the root of your application.
    return MaterialApp(
      title: 'AMS App', // Updated title
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Set a theme based on the primary blue color using the merged constant
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue), 
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      // Set the home property to your custom StartPage
      home: const StartPage(),
    );
  }
}