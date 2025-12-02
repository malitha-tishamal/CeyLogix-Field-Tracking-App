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
 static const Color successGreen = Color(0xFF4CAF50);
 static const Color warningOrange = Color(0xFFFF9800);
 static const Color cardBackground = Colors.white;
 static const Color secondaryText = Color(0xFF6A798A);
 static const Color secondaryColor = Color(0xFF6AD96A);
 
 // Custom colors based on the image's gradient header
 static const Color headerGradientStart = Color(0xFF869AEC);
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
 final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 
 // State variables to hold fetched data
 String _loggedInUserName = 'Loading User...';
 String _factoryName = 'Loading Factory...';
 String _userRole = 'Factory Owner';
 String _factoryID = 'F-ID';
 String? _profileImageUrl;

 // State variables for associated lands
 List<Map<String, dynamic>> _allAssociatedLands = [];
 List<Map<String, dynamic>> _teaLands = [];
 List<Map<String, dynamic>> _cinnamonLands = [];
 List<Map<String, dynamic>> _multiCropLands = [];
 bool _isLoadingLands = true;
 String? _errorMessage;

 @override
 void initState() {
  super.initState();
  _fetchHeaderData();
  _fetchAssociatedLands();
 }

 // --- DATA FETCHING FUNCTION ---
 void _fetchHeaderData() async {
  final user = currentUser;
  if (user == null) {
   return;
  }
  
  final String uid = user.uid;
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
     _profileImageUrl = userData?['profileImageUrl'];
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

 // Fetch associated lands for this factory
 void _fetchAssociatedLands() async {
  final user = currentUser;
  if (user == null) return;

  setState(() {
   _isLoadingLands = true;
   _errorMessage = null;
  });

  try {
   // Get all lands and filter those that have this factory in their factoryIds array
   final landsQuery = await _firestore.collection('lands').get();
   
   if (landsQuery.docs.isEmpty) {
    setState(() {
     _allAssociatedLands = [];
     _teaLands = [];
     _cinnamonLands = [];
     _multiCropLands = [];
     _isLoadingLands = false;
    });
    return;
   }

   List<Map<String, dynamic>> associatedLands = [];
   final factoryId = user.uid; // Current factory's ID

   for (var landDoc in landsQuery.docs) {
    final landData = landDoc.data() as Map<String, dynamic>;
    final factoryIds = List<String>.from(landData['factoryIds'] ?? []);
    
    // Check if this factory is in the land's factoryIds array
    if (factoryIds.contains(factoryId)) {
     // Fetch land owner details
     String? ownerUid = landData['owner'] ?? landDoc.id;
     String ownerName = 'Unknown Owner';
     
     if (ownerUid != null && ownerUid.isNotEmpty) {
      try {
       final userDoc = await _firestore
           .collection('users')
           .doc(ownerUid)
           .get();
       
       if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        ownerName = userData['name'] ?? 'Unknown Owner';
       }
      } catch (e) {
       debugPrint("Error fetching owner info for $ownerUid: $e");
      }
     }
     
     associatedLands.add({
      'id': landDoc.id,
      ...landData,
      'ownerName': ownerName,
     });
    }
   }

   _categorizeLands(associatedLands);
  } catch (e) {
   debugPrint("Error fetching associated lands: $e");
   setState(() {
    _errorMessage = "Failed to load land data";
    _isLoadingLands = false;
   });
  }
 }

 // Categorize lands by crop type
 void _categorizeLands(List<Map<String, dynamic>> lands) {
  List<Map<String, dynamic>> teaLands = [];
  List<Map<String, dynamic>> cinnamonLands = [];
  List<Map<String, dynamic>> multiLands = [];

  for (var land in lands) {
   final cropType = land['cropType'] ?? 'N/A';
   if (cropType == 'Tea') {
    teaLands.add(land);
   } else if (cropType == 'Cinnamon') {
    cinnamonLands.add(land);
   } else if (cropType == 'Both') {
    multiLands.add(land);
   }
  }

  setState(() {
   _allAssociatedLands = lands;
   _teaLands = teaLands;
   _cinnamonLands = cinnamonLands;
   _multiCropLands = multiLands;
   _isLoadingLands = false;
  });
 }

 // Show land details modal
 void _showLandDetailsModal(Map<String, dynamic> land) {
  showModalBottomSheet(
   context: context,
   isScrollControlled: true,
   backgroundColor: Colors.transparent,
   builder: (context) => LandDetailsModal(land: land),
  );
 }

 @override
 Widget build(BuildContext context) {
  void handleDrawerNavigate(String routeName) {
   Navigator.pop(context);
  }
  
  return Scaffold(
   key: _scaffoldKey,
   backgroundColor: AppColors.background,
   
   drawer: FactoryOwnerDrawer(
    onLogout: () {
     Navigator.pop(context);
    },
    onNavigate: handleDrawerNavigate,
   ),

   body: Column(
    children: [
     _buildDashboardHeader(context),
     
     Expanded(
      child: Column(
       children: [
        Expanded(
         child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
            _buildSectionTitle('Associated Lands', Icons.landscape_rounded),
            const SizedBox(height: 10),
            _buildAssociatedLandsSection(),
            const SizedBox(height: 30),          
            const SizedBox(height: 50),
           ],
          ),
         ),
        ),
        
        Container(
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
       ],
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
       
       Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         Text(
          _loggedInUserName, 
          style: const TextStyle(
           fontSize: 20,
           fontWeight: FontWeight.bold,
           color: AppColors.headerTextDark,
          ),
         ),
         Text(
          'Factory Name: $_factoryName \n($_userRole)', 
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

 // --- Dashboard Content Widgets ---

 Widget _buildSectionTitle(String title, IconData icon) {
  return Padding(
   padding: const EdgeInsets.only(bottom: 4.0),
   child: Row(
    children: [
     Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
       color: AppColors.primaryBlue.withOpacity(0.1),
       borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.primaryBlue, size: 20),
     ),
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

Widget _buildAssociatedLandsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_allAssociatedLands.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌟 First row: 3 cards
                Row(
                  children: [
                    _buildLandStatCard(
                      title: 'Total Lands',
                      value: _allAssociatedLands.length.toString(),
                      icon: Icons.landscape,
                      color: AppColors.primaryBlue,
                      iconColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    _buildLandStatCard(
                      title: 'Tea',
                      value: _teaLands.length.toString(),
                      icon: Icons.agriculture,
                      color: AppColors.successGreen,
                      iconColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    _buildLandStatCard(
                      title: 'Cinnamon',
                      value: _cinnamonLands.length.toString(),
                      icon: Icons.spa,
                      color: AppColors.warningOrange,
                      iconColor: Colors.white,
                    ),
                  ],
                ),

                const SizedBox(height: 12), // ⭐ break / new row

                // 🌟 Second row: Multi-Crop
                Row(
                  children: [
                    _buildLandStatCard(
                      title: 'Multi-Crop',
                      value: _multiCropLands.length.toString(),
                      icon: Icons.all_inclusive,
                      color: AppColors.accentTeal,
                      iconColor: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

      if (_isLoadingLands)
        _buildLoadingLands()
      else if (_errorMessage != null)
        _buildErrorLands()
      else if (_allAssociatedLands.isEmpty)
        _buildNoLandsCard()
      else
        _buildLandsByCategory(),
    ],
  );
}


 Widget _buildLandStatCard({
   required String title,
   required String value,
   required IconData icon,
   required Color color,
   required Color iconColor,
 }) {
  return Container(
   width: 100,
   padding: const EdgeInsets.all(12),
   decoration: BoxDecoration(
    gradient: LinearGradient(
     colors: [color, Color.lerp(color, Colors.black, 0.1)!],
     begin: Alignment.topLeft,
     end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
     BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
     ),
    ],
   ),
   child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
     Icon(icon, size: 18, color: iconColor),
     const SizedBox(height: 6),
     Text(
      value,
      style: const TextStyle(
       fontSize: 18,
       fontWeight: FontWeight.bold,
       color: Colors.white,
      ),
     ),
     const SizedBox(height: 4),
     Text(
      title,
      style: TextStyle(
       fontSize: 10,
       color: Colors.white.withOpacity(0.9),
      ),
      textAlign: TextAlign.center,
     ),
    ],
   ),
  );
 }

 Widget _buildLandsByCategory() {
  return Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
    if (_cinnamonLands.isNotEmpty)
     _buildLandCategorySection(
      title: 'Cinnamon Lands',
      icon: Icons.spa,
      color: AppColors.warningOrange,
      lands: _cinnamonLands,
     ),
    if (_teaLands.isNotEmpty)
     _buildLandCategorySection(
      title: 'Tea Lands',
      icon: Icons.agriculture,
      color: AppColors.successGreen,
      lands: _teaLands,
     ),
    if (_multiCropLands.isNotEmpty)
     _buildLandCategorySection(
      title: 'Multi-Crop Lands',
      icon: Icons.all_inclusive,
      color: AppColors.accentTeal,
      lands: _multiCropLands,
     ),
   ],
  );
 }

 Widget _buildLandCategorySection({
   required String title,
   required IconData icon,
   required Color color,
   required List<Map<String, dynamic>> lands,
 }) {
  return Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
    const SizedBox(height: 16),
    Row(
     mainAxisAlignment: MainAxisAlignment.spaceBetween,
     children: [
      Row(
       children: [
        Container(
         padding: const EdgeInsets.all(6),
         decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
         ),
         child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Text(
         title,
         style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
         ),
        ),
       ],
      ),
      Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
       decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
       ),
       child: Text(
        '${lands.length} lands',
        style: TextStyle(
         fontSize: 12,
         fontWeight: FontWeight.w600,
         color: color,
        ),
       ),
      ),
     ],
    ),
    const SizedBox(height: 10),
    Column(
     children: lands.asMap().entries.map((entry) {
      final index = entry.key;
      final land = entry.value;
      return _buildLandCard(land, index, color);
     }).toList(),
    ),
   ],
  );
 }

 Widget _buildLandCard(Map<String, dynamic> land, int index, Color categoryColor) {
  final landName = land['landName'] ?? 'Unknown Land';
  final ownerName = land['ownerName'] ?? 'N/A';
  final cropType = land['cropType'] ?? 'N/A';
  final landSize = land['landSize'] ?? 'N/A';
  final landSizeUnit = land['landSizeUnit'] ?? 'ha';
  final address = land['address'] ?? 'N/A';
  final district = land['district'] ?? 'N/A';

  final mainColor = categoryColor;
  final icon = _getCropIcon(cropType);

  return GestureDetector(
   onTap: () {
    _showLandDetailsModal(land);
   },
   child: Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
     elevation: 2,
     borderRadius: BorderRadius.circular(12),
     child: Container(
      decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: mainColor.withOpacity(0.1)),
      ),
      child: Padding(
       padding: const EdgeInsets.all(16),
       child: Row(
        children: [
         Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
           color: mainColor.withOpacity(0.1),
           borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: mainColor, size: 26),
         ),
         const SizedBox(width: 12),
         Expanded(
          child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
            Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
              Expanded(
               child: Text(
                landName,
                style: const TextStyle(
                 fontSize: 16,
                 fontWeight: FontWeight.w600,
                 color: AppColors.darkText,
                ),
                overflow: TextOverflow.ellipsis,
               ),
              ),
              Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
               decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: mainColor.withOpacity(0.3)),
               ),
               child: Text(
                cropType,
                style: TextStyle(
                 fontSize: 11,
                 fontWeight: FontWeight.w600,
                 color: mainColor,
                ),
               ),
              ),
             ],
            ),
            const SizedBox(height: 4),
            Text(
             'Owner: $ownerName',
             style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
             ),
            ),
            const SizedBox(height: 4),
            Row(
             children: [
              Icon(Icons.square_foot, size: 14, color: mainColor),
              const SizedBox(width: 4),
              Text(
               '$landSize $landSizeUnit',
               style: TextStyle(
                fontSize: 13,
                color: AppColors.darkText,
               ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.location_on, size: 14, color: mainColor),
              const SizedBox(width: 4),
              Expanded(
               child: Text(
                district,
                style: TextStyle(
                 fontSize: 13,
                 color: AppColors.darkText,
                ),
                overflow: TextOverflow.ellipsis,
               ),
              ),
             ],
            ),
           ],
          ),
         ),
        ],
       ),
      ),
     ),
    ),
   ),
  );
 }

 Widget _buildLoadingLands() {
  return Container(
   padding: const EdgeInsets.all(30),
   decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
   ),
   child: Column(
    children: [
     CircularProgressIndicator(color: AppColors.primaryBlue),
     const SizedBox(height: 16),
     const Text(
      'Loading land data...',
      style: TextStyle(
       fontSize: 14,
       color: AppColors.darkText,
      ),
     ),
    ],
   ),
  );
 }

 Widget _buildErrorLands() {
  return Container(
   padding: const EdgeInsets.all(20),
   decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
   ),
   child: Column(
    children: [
     Icon(Icons.error_outline, size: 36, color: AppColors.accentRed),
     const SizedBox(height: 12),
     Text(
      _errorMessage ?? 'Unable to load land data',
      textAlign: TextAlign.center,
      style: const TextStyle(
       fontSize: 14,
       fontWeight: FontWeight.w600,
       color: AppColors.darkText,
      ),
     ),
     const SizedBox(height: 8),
     ElevatedButton.icon(
      onPressed: _fetchAssociatedLands,
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('Retry'),
      style: ElevatedButton.styleFrom(
       backgroundColor: AppColors.primaryBlue,
       foregroundColor: Colors.white,
       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
       ),
      ),
     ),
    ],
   ),
  );
 }

 Widget _buildNoLandsCard() {
  return Container(
   padding: const EdgeInsets.all(24),
   decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
   ),
   child: Column(
    children: [
     Icon(Icons.landscape, size: 48, color: AppColors.primaryBlue),
     const SizedBox(height: 16),
     const Text(
      'No Associated Lands',
      style: TextStyle(
       fontSize: 16,
       fontWeight: FontWeight.w700,
       color: AppColors.darkText,
      ),
     ),
     const SizedBox(height: 8),
     Text(
      'You are not currently associated with any lands. Lands will appear here once they add your factory.',
      textAlign: TextAlign.center,
      style: TextStyle(
       color: AppColors.secondaryText,
       fontSize: 14,
      ),
     ),
    ],
   ),
  );
 }

 // Helper method to get crop icon
 IconData _getCropIcon(String cropType) {
  switch (cropType) {
   case 'Cinnamon':
    return Icons.spa;
   case 'Tea':
    return Icons.agriculture;
   case 'Both':
    return Icons.all_inclusive;
   default:
    return Icons.landscape;
  }
 }
}

// -----------------------------------------------------------------
// --- LAND DETAILS MODAL WIDGET ---
// -----------------------------------------------------------------

class LandDetailsModal extends StatelessWidget {
 final Map<String, dynamic> land;

 const LandDetailsModal({super.key, required this.land});

 @override
 Widget build(BuildContext context) {
  final landName = land['landName'] ?? 'Unknown Land';
  final ownerName = land['ownerName'] ?? 'N/A';
  final cropType = land['cropType'] ?? 'N/A';
  final landSize = land['landSize'] ?? 'N/A';
  final landSizeUnit = land['landSizeUnit'] ?? 'ha';
  final address = land['address'] ?? 'N/A';
  final district = land['district'] ?? 'N/A';
  final agDivision = land['agDivision'] ?? 'N/A';
  final gnDivision = land['gnDivision'] ?? 'N/A';
  final village = land['village'] ?? 'N/A';
  final province = land['province'] ?? 'N/A';
  final country = land['country'] ?? 'Sri Lanka';
  final cinnamonLandSize = land['cinnamonLandSize'] ?? 'N/A';
  final teaLandSize = land['teaLandSize'] ?? 'N/A';
  final landPhotos = List<String>.from(land['landPhotos'] ?? []);
  final ownerUid = land['owner'] ?? '';

  final Map<String, Color> cropColors = {
   'Cinnamon': AppColors.warningOrange,
   'Tea': AppColors.successGreen,
   'Both': AppColors.accentTeal,
  };

  final mainColor = cropColors[cropType] ?? AppColors.primaryBlue;

  return Container(
   height: MediaQuery.of(context).size.height * 0.85,
   decoration: const BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.only(
     topLeft: Radius.circular(30),
     topRight: Radius.circular(30),
    ),
   ),
   child: Column(
    children: [
     Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
       gradient: LinearGradient(
        colors: [
         mainColor.withOpacity(0.1),
         mainColor.withOpacity(0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
       ),
       borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
       ),
      ),
      child: Row(
       children: [
        Container(
         width: 50,
         height: 50,
         decoration: BoxDecoration(
          color: mainColor,
          borderRadius: BorderRadius.circular(12),
         ),
         child: Icon(
          _getCropIcon(cropType),
          color: Colors.white,
          size: 28,
         ),
        ),
        const SizedBox(width: 16),
        Expanded(
         child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           Text(
            landName,
            style: const TextStyle(
             fontSize: 20,
             fontWeight: FontWeight.bold,
             color: AppColors.darkText,
            ),
           ),
           const SizedBox(height: 4),
           Text(
            '$cropType Land',
            style: TextStyle(
             fontSize: 14,
             color: mainColor,
             fontWeight: FontWeight.w600,
            ),
           ),
          ],
         ),
        ),
        IconButton(
         onPressed: () => Navigator.pop(context),
         icon: const Icon(Icons.close, color: AppColors.secondaryText),
        ),
       ],
      ),
     ),
     Expanded(
      child: SingleChildScrollView(
       padding: const EdgeInsets.all(20),
       child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         _buildDetailSection(
          title: 'Basic Information',
          icon: Icons.info_outline,
          children: [
           _buildDetailRow('Land Name', landName),
           _buildDetailRow('Owner Name', ownerName),
           _buildDetailRow('Crop Type', cropType),
           _buildDetailRow('Total Land Size', '$landSize $landSizeUnit'),
           if (cropType == 'Both' || cropType == 'Tea')
            _buildDetailRow('Tea Land Size', '$teaLandSize $landSizeUnit'),
           if (cropType == 'Both' || cropType == 'Cinnamon')
            _buildDetailRow('Cinnamon Land Size', '$cinnamonLandSize $landSizeUnit'),
          ],
         ),
         const SizedBox(height: 24),
         _buildDetailSection(
          title: 'Location Details',
          icon: Icons.location_on,
          children: [
           if (address.isNotEmpty) _buildDetailRow('Address', address),
           if (village.isNotEmpty) _buildDetailRow('Village/Town', village),
           if (district.isNotEmpty) _buildDetailRow('District', district),
           if (province.isNotEmpty) _buildDetailRow('Province', province),
           if (agDivision.isNotEmpty) _buildDetailRow('A/G Division', agDivision),
           if (gnDivision.isNotEmpty) _buildDetailRow('G/N Division', gnDivision),
           _buildDetailRow('Country', country),
          ],
         ),
         const SizedBox(height: 24),
         if (landPhotos.isNotEmpty)
          Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
            _buildDetailSection(
             title: 'Land Photos',
             icon: Icons.photo_camera,
             children: [
              GridView.builder(
               shrinkWrap: true,
               physics: const NeverScrollableScrollPhysics(),
               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
               ),
               itemCount: landPhotos.length,
               itemBuilder: (context, index) {
                return ClipRRect(
                 borderRadius: BorderRadius.circular(8),
                 child: Image.network(
                  landPhotos[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                   if (loadingProgress == null) return child;
                   return Center(
                    child: CircularProgressIndicator(
                     value: loadingProgress.expectedTotalBytes != null
                         ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                         : null,
                     color: mainColor,
                    ),
                   );
                  },
                  errorBuilder: (context, error, stackTrace) {
                   return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                   );
                  },
                 ),
                );
               },
              ),
             ],
            ),
            const SizedBox(height: 24),
           ],
          ),
         _buildDetailSection(
          title: 'Land Identification',
          icon: Icons.fingerprint,
          children: [
           _buildDetailRow('Land ID', land['id']?.toString() ?? 'N/A'),
           Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
             color: AppColors.background,
             borderRadius: BorderRadius.circular(10),
             border: Border.all(color: mainColor.withOpacity(0.2)),
            ),
            child: Row(
             children: [
              Icon(Icons.shield, color: mainColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
               child: Text(
                'Associated with your factory',
                style: TextStyle(
                 fontSize: 14,
                 color: AppColors.darkText,
                ),
               ),
              ),
             ],
            ),
           ),
          ],
         ),
         const SizedBox(height: 30),
        ],
       ),
      ),
     ),
    ],
   ),
  );
 }

 Widget _buildDetailSection({
   required String title,
   required IconData icon,
   required List<Widget> children,
 }) {
  return Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
    Row(
     children: [
      Container(
       padding: const EdgeInsets.all(6),
       decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
       ),
       child: Icon(icon, size: 18, color: AppColors.primaryBlue),
      ),
      const SizedBox(width: 10),
      Text(
       title,
       style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
       ),
      ),
     ],
    ),
    const SizedBox(height: 12),
    Container(
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
     ),
     child: Column(
      children: children,
     ),
    ),
   ],
  );
 }

 Widget _buildDetailRow(String label, String value) {
  return Padding(
   padding: const EdgeInsets.symmetric(vertical: 8.0),
   child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
     SizedBox(
      width: 120,
      child: Text(
       '$label:',
       style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.secondaryText,
       ),
      ),
     ),
     const SizedBox(width: 8),
     Expanded(
      child: Text(
       value,
       style: const TextStyle(
        fontSize: 14,
        color: AppColors.darkText,
       ),
      ),
     ),
    ],
   ),
  );
 }

 // Helper method to get crop icon for modal
 IconData _getCropIcon(String cropType) {
  switch (cropType) {
   case 'Cinnamon':
    return Icons.spa;
   case 'Tea':
    return Icons.agriculture;
   case 'Both':
    return Icons.all_inclusive;
   default:
    return Icons.landscape;
  }
 }
}