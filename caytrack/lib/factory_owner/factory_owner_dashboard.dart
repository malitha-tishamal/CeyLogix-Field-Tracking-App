import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'factory_owner_drawer.dart'; 

// Reusing AppColors locally
class AppColors {
 static const Color background = Color(0xFFEEEBFF);
 static const Color darkText = Color(0xFF2C2A3A);
 static const Color primaryBlue = Color(0xFF2764E7);
 static const Color accentRed = Color(0xFFE53935); 
 static const Color accentTeal = Color(0xFF00BFA5);
 static const Color cardBackground = Colors.white;
 static const Color secondaryText = Color(0xFF6A798A);
 static const Color secondaryColor = Color(0xFF6AD96A);
 
 // Custom colors based on the image's gradient header
 static const Color headerGradientStart = Color(0xFF869AEC); // Adjusted to match the blue
 static const Color headerGradientEnd = Color(0xFFF7FAFF);  
 static const Color headerTextDark = Color(0xFF333333);
}

// -----------------------------------------------------------------------------
// --- 1. MAIN SCREEN (FactoryOwnerDashboard) ---
// -----------------------------------------------------------------------------
class FactoryOwnerDashboard extends StatefulWidget {
 const FactoryOwnerDashboard({super.key});

 @override
 State<FactoryOwnerDashboard> createState() => _FactoryOwnerDashboardState();
}

class _FactoryOwnerDashboardState extends State<FactoryOwnerDashboard> {
 final User? currentUser = FirebaseAuth.instance.currentUser;
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 
 // State variables to hold fetched data
 String _loggedInUserName = 'Loading User...'; // name from users collection
 String _factoryName = 'Loading Factory...'; // factoryName from factories collection
 String _userRole = 'Factory Owner'; // role from users collection (for secondary line)
 String _factoryID = 'F-ID';
 String? _profileImageUrl; // ADDED: For profile picture

 @override
 void initState() {
  super.initState();
  _fetchHeaderData();
 }

 // --- DATA FETCHING FUNCTION ---
 void _fetchHeaderData() async {
  final user = currentUser;
  if (user == null) {
   // Handle unauthenticated state if necessary
   return;
  }
  
  final String uid = user.uid;
  // Use a shortened version of the UID for the ID display
  setState(() {
   _factoryID = uid.substring(0, 8); 
  });

  try {
   // 1. Fetch User Name and Role from 'users' collection
   final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
   if (userDoc.exists) {
    final userData = userDoc.data();
    setState(() {
     _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
     _userRole = userData?['role'] ?? 'Factory Owner';
     _profileImageUrl = userData?['profileImageUrl']; // ADDED: Load profile image
    });
   }
   
   // 2. Fetch Factory Name from 'factories' collection
   final factoryDoc = await FirebaseFirestore.instance.collection('factories').doc(uid).get();
   if (factoryDoc.exists) {
    setState(() {
     _factoryName = factoryDoc.data()?['factoryName'] ?? 'Factory Name Missing';
    });
   }

  } catch (e) {
   debugPrint("Error fetching header data: $e");
   setState(() {
    _loggedInUserName = 'Data Error';
    _factoryName = 'Data Error';
   });
  }
 }

 @override
 Widget build(BuildContext context) {
  void handleDrawerNavigate(String routeName) {
   Navigator.pop(context); 
   // Placeholder: Implement actual navigation logic here...
  }
  
  return Scaffold(
   key: _scaffoldKey,
   backgroundColor: AppColors.background,
   
   drawer: FactoryOwnerDrawer(
    onLogout: () {
     // Placeholder: Implement actual logout logic here
     Navigator.pop(context);
    },
    onNavigate: handleDrawerNavigate,
   ),

   body: Stack(
    children: [
     SafeArea(
      child: Column(
       children: [
        // 1. Updated Header Card
        _buildDashboardHeader(context),
        
        // 2. Main Content
        Expanded(
         child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
            _buildSectionTitle('Performance Summary', Icons.bar_chart_rounded),
            const SizedBox(height: 10),
            _buildKeyMetrics(context),
            const SizedBox(height: 30),

            _buildSectionTitle('Inventory & Compliance', Icons.warehouse_rounded),
            const SizedBox(height: 10),
            _buildInventorySummaryCard(context),
            const SizedBox(height: 30),

            _buildSectionTitle('Recent Export Orders', Icons.flight_takeoff),
            const SizedBox(height: 10),
            _buildExportOrderCard(context, 'ORD-2025-450', 'Dubai', 'Processing', AppColors.accentTeal),
            _buildExportOrderCard(context, 'ORD-2025-449', 'Germany', 'Shipped', AppColors.primaryBlue),
            const SizedBox(height: 30),

            _buildSectionTitle('Quick Actions', Icons.bolt_rounded),
            const SizedBox(height: 10),
            _buildQuickActionsRow(context),
            
            const SizedBox(height: 50),
           ],
          ),
         ),
        ),
       ],
      ),
     ),
     
     // 3. Fixed Footer Text
     Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
       padding: const EdgeInsets.all(16.0),
       child: Text(
        'Developed By Malitha Tishamal',
        textAlign: TextAlign.center,
        style: TextStyle(
         color: AppColors.darkText.withOpacity(0.7),
         fontSize: 12,
        ),
       ),
      ),
     ),
    ],
   ),
  );
 }

 // -----------------------------------------------------------------
 // --- 2. MODULARIZED WIDGETS (Header & Dashboard Content) ---
 // -----------------------------------------------------------------

 /// 🌟 HEADER - Custom Header Widget matching FactoryDetails style
 Widget _buildDashboardHeader(BuildContext context) {
  return Container(
   padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
   decoration: const BoxDecoration(
    gradient: LinearGradient(
     colors: [Color(0xFF869AEC), AppColors.headerGradientEnd], 
     begin: Alignment.topCenter,
     end: Alignment.bottomCenter,
    ),
    borderRadius: BorderRadius.only(
     bottomLeft: Radius.circular(30), 
     bottomRight: Radius.circular(30),
    ),
    boxShadow: [
     BoxShadow(
      color: Color(0x10000000), 
      blurRadius: 15,
      offset: Offset(0, 5),
     ),
    ],
   ),
   child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
     Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
       IconButton(
        icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
        onPressed: () {
         _scaffoldKey.currentState?.openDrawer();
        },
       ),
      ],
     ),
     
     const SizedBox(height: 10),
     
     Row(
      children: [
       // 🆕 UPDATED: Profile Picture with actual image support
       Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
         shape: BoxShape.circle,
         gradient: _profileImageUrl == null 
           ? const LinearGradient(
               colors: [AppColors.primaryBlue, Color(0xFF457AED)],
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
             )
           : null,
         border: Border.all(color: Colors.white, width: 3),
         boxShadow: [
          BoxShadow(
           color: AppColors.primaryBlue.withOpacity(0.4),
           blurRadius: 10,
           offset: const Offset(0, 3),
          ),
         ],
         image: _profileImageUrl != null 
           ? DecorationImage(
               image: NetworkImage(_profileImageUrl!),
               fit: BoxFit.cover,
             )
           : null,
        ),
        child: _profileImageUrl == null
            ? const Icon(Icons.person, size: 40, color: Colors.white)
            : null,
       ),
       
       const SizedBox(width: 15),
       
       // 🚀 UPDATED USER INFO DISPLAY
       Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         // 1. Company Name (factoryName)
         Text(
          _factoryName, 
          style: const TextStyle(
           fontSize: 20,
           fontWeight: FontWeight.bold,
           color: AppColors.headerTextDark,
          ),
         ),
         // 2. Logged-in User Name (name) and Role
         Text(
          'Logged in as: $_loggedInUserName \n($_userRole)', 
          style: TextStyle(
           fontSize: 14,
           color: AppColors.headerTextDark.withOpacity(0.7),
          ),
         ),
        ],
       ),
      ],
     ),
     
     const SizedBox(height: 25), 
     
     // "Operational Overview" Text with Factory ID
     Text(
      'Operational Overview (ID: $_factoryID)',
      style: const TextStyle(
       fontSize: 16,
       fontWeight: FontWeight.w600,
       color: AppColors.headerTextDark,
      ),
     ),
    ],
   ),
  );
 }

 // --- Dashboard Content Widgets (Modularized) - Remain the same ---

 Widget _buildSectionTitle(String title, IconData icon) {
  return Padding(
   padding: const EdgeInsets.only(bottom: 4.0),
   child: Row(
    children: [
     Icon(icon, color: AppColors.primaryBlue, size: 20),
     const SizedBox(width: 8),
     Text(
      title,
      style: const TextStyle(
       fontSize: 18, 
       fontWeight: FontWeight.w700, 
       color: AppColors.darkText,
      ),
     ),
    ],
   ),
  );
 }

 Widget _buildKeyMetrics(BuildContext context) {
  return GridView.count(
   shrinkWrap: true,
   crossAxisCount: 2,
   crossAxisSpacing: 16,
   mainAxisSpacing: 16,
   physics: const NeverScrollableScrollPhysics(),
   children: [
    _buildMetricCard(context, 'Total Raw Stock (kg)', '42,500', Icons.storage, AppColors.primaryBlue),
    _buildMetricCard(context, 'Pending Exports', '8 Orders', Icons.schedule, AppColors.accentRed),
   ],
  );
 }

 Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
  return Card(
   color: AppColors.cardBackground,
   elevation: 4,
   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
   child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     mainAxisAlignment: MainAxisAlignment.spaceBetween,
     children: [
      Container(
       padding: const EdgeInsets.all(8),
       decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
       ),
       child: Icon(icon, color: color, size: 24),
      ),
      Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkText)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
       ],
      ),
     ],
    ),
   ),
  );
 }

 Widget _buildInventorySummaryCard(BuildContext context) {
  return Card(
   color: AppColors.cardBackground,
   elevation: 4,
   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
   child: Padding(
    padding: const EdgeInsets.all(20.0),
    child: Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
      const Text('Raw Material Inventory Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkText)),
      const Divider(height: 25, thickness: 1),
      _buildInventoryItem('Received Today:', '2,100 kg', AppColors.accentTeal),
      _buildInventoryItem('Needs Processing:', '15,000 kg', AppColors.accentRed),
      _buildInventoryItem('Finished Goods:', '12,500 kg', AppColors.primaryBlue),
     ],
    ),
   ),
  );
 }

 Widget _buildInventoryItem(String label, String value, Color color) {
  return Padding(
   padding: const EdgeInsets.symmetric(vertical: 8.0),
   child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
     Text(label, style: TextStyle(color: AppColors.darkText.withOpacity(0.8), fontSize: 15)),
     Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
    ],
   ),
  );
 }

 Widget _buildExportOrderCard(BuildContext context, String orderId, String destination, String status, Color statusColor) {
  return Card(
   color: AppColors.cardBackground,
   margin: const EdgeInsets.only(bottom: 10),
   elevation: 2,
   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
   child: ListTile(
    leading: Icon(Icons.inventory_2_rounded, color: statusColor, size: 30),
    title: Text(orderId, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText)),
    subtitle: Text('Destination: $destination', style: TextStyle(color: AppColors.secondaryText)),
    trailing: Container(
     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
     decoration: BoxDecoration(
      color: statusColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
     ),
     child: Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 12)),
    ),
    onTap: () {
     // View Order Details
    },
   ),
  );
 }

 Widget _buildQuickActionsRow(BuildContext context) {
  return Row(
   children: [
    _buildQuickActionButton(context, 'Certificates', Icons.verified_user, AppColors.accentTeal),
    const SizedBox(width: 16),
    _buildQuickActionButton(context, 'Staff Management', Icons.people, AppColors.primaryBlue),
   ],
  );
 }

 Widget _buildQuickActionButton(BuildContext context, String label, IconData icon, Color color) {
  return Expanded(
   child: ElevatedButton.icon(
    onPressed: () {
     // Action for the button
    },
    icon: Icon(icon, color: Colors.white),
    label: Padding(
     padding: const EdgeInsets.symmetric(vertical: 8.0),
     child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
    ),
    style: ElevatedButton.styleFrom(
     backgroundColor: color,
     padding: const EdgeInsets.symmetric(vertical: 10),
     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
     elevation: 5,
    ),
   ),
  );
 }
}