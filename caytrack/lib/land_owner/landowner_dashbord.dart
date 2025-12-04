// land_owner_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'land_owner_drawer.dart';

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
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color purpleAccent = Color(0xFF9C27B0);
  static const Color amberAccent = Color(0xFFFFC107);
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

// -----------------------------------------------------------------------------
// --- MAIN SCREEN (LandOwnerDashboard) ---
// -----------------------------------------------------------------------------
class LandOwnerDashboard extends StatefulWidget {
  const LandOwnerDashboard({super.key});

  @override
  State<LandOwnerDashboard> createState() => _LandOwnerDashboardState();
}

class _LandOwnerDashboardState extends State<LandOwnerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variables for header data
  String _loggedInUserName = 'Loading User...';
  String _landName = 'Loading Land...';
  String _userRole = 'Land Owner';
  String _landID = 'L-ID';
  String? _profileImageUrl;

  // State variables for associated factories
  List<Map<String, dynamic>> _allAssociatedFactories = [];
  List<Map<String, dynamic>> _teaFactories = [];
  List<Map<String, dynamic>> _cinnamonFactories = [];
  List<Map<String, dynamic>> _multiCropFactories = [];
  bool _isLoadingFactories = true;
  String? _errorMessage;

  // Land size data variables
  String? _landSize;
  String? _landSizeUnit;
  String? _cropType;
  String? _teaLandSize;
  String? _cinnamonLandSize;
  String? _landSizeDetails;
  List<String> _landPhotos = [];

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
    _fetchAssociatedFactories();
    _fetchLandSizeData(); // Fetch land size data
  }

  // Fetch header data (username, land name, profile image)
  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) return;

    final String uid = user.uid;
    setState(() {
      _landID = uid.substring(0, 8);
    });

    try {
      // Fetch User Name and Role
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
        });
      }

      // Fetch Land Name
      final landDoc =
          await FirebaseFirestore.instance.collection('lands').doc(uid).get();
      if (landDoc.exists) {
        setState(() {
          _landName = landDoc.data()?['landName'] ?? 'Land Name Missing';
        });
      }
    } catch (e) {
      debugPrint("Error fetching header data: $e");
      setState(() {
        _loggedInUserName = 'Data Error';
        _landName = 'Data Error';
      });
    }
  }

  // Fetch land size data and photos
  void _fetchLandSizeData() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final landDoc = await _firestore
          .collection('lands')
          .doc(user.uid)
          .get();

      if (landDoc.exists) {
        final landData = landDoc.data();
        setState(() {
          _landSize = landData?['landSize']?.toString();
          _landSizeUnit = landData?['landSizeUnit'] ?? 'Hectares';
          _cropType = landData?['cropType'];
          _teaLandSize = landData?['teaLandSize']?.toString();
          _cinnamonLandSize = landData?['cinnamonLandSize']?.toString();
          _landSizeDetails = landData?['landSizeDetails'];
          _landPhotos = List<String>.from(landData?['landPhotos'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error fetching land size data: $e");
    }
  }

  // Fetch associated factories with owner names
void _fetchAssociatedFactories() async {
  final user = currentUser;
  if (user == null) return;

  setState(() {
    _isLoadingFactories = true;
    _errorMessage = null;
  });

  try {
    final landDoc = await _firestore.collection('lands').doc(user.uid).get();
    if (landDoc.exists) {
      final landData = landDoc.data();
      final factoryIds = List<String>.from(landData?['factoryIds'] ?? []);

      if (factoryIds.isEmpty) {
        setState(() {
          _allAssociatedFactories = [];
          _teaFactories = [];
          _cinnamonFactories = [];
          _multiCropFactories = [];
          _isLoadingFactories = false;
        });
        return;
      }

      List<Map<String, dynamic>> factories = [];
      for (String factoryId in factoryIds) {
        try {
          final factoryDoc =
              await _firestore.collection('factories').doc(factoryId).get();
          if (factoryDoc.exists) {
            final factoryData = factoryDoc.data() as Map<String, dynamic>;
            
            // The factory document ID is the owner's UID
            // So factoryId itself is the owner UID
            String ownerUid = factoryId; // Factory document ID = owner UID
            String ownerName = 'Unknown Owner';
            
            // Fetch owner name from users table
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
            
            // Add factory data with owner name
            factories.add({
              'id': factoryId,
              ...factoryData,
              'ownerName': ownerName,
            });
          }
        } catch (e) {
          debugPrint("Error fetching factory $factoryId: $e");
        }
      }

      _categorizeFactories(factories);
    } else {
      setState(() {
        _allAssociatedFactories = [];
        _teaFactories = [];
        _cinnamonFactories = [];
        _multiCropFactories = [];
        _isLoadingFactories = false;
      });
    }
  } catch (e) {
    debugPrint("Error fetching associated factories: $e");
    setState(() {
      _errorMessage = "Failed to load factory data";
      _isLoadingFactories = false;
    });
  }
}

  // Categorize factories by crop type
  void _categorizeFactories(List<Map<String, dynamic>> factories) {
    List<Map<String, dynamic>> teaFacts = [];
    List<Map<String, dynamic>> cinnamonFacts = [];
    List<Map<String, dynamic>> multiFacts = [];

    for (var factory in factories) {
      final cropType = factory['cropType'] ?? 'N/A';
      if (cropType == 'Tea') {
        teaFacts.add(factory);
      } else if (cropType == 'Cinnamon') {
        cinnamonFacts.add(factory);
      } else if (cropType == 'Both') {
        multiFacts.add(factory);
      }
    }

    setState(() {
      _allAssociatedFactories = factories;
      _teaFactories = teaFacts;
      _cinnamonFactories = cinnamonFacts;
      _multiCropFactories = multiFacts;
      _isLoadingFactories = false;
    });
  }

  // Make phone call using url_launcher
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'N/A') {
      _showSnackBar('Phone number not available');
      return;
    }

    // Clean phone number
    final String tel = 'tel:${phoneNumber.replaceAll(RegExp(r'[-\s]'), '')}';
    
    try {
      if (await canLaunchUrl(Uri.parse(tel))) {
        await launchUrl(Uri.parse(tel));
      } else {
        _showPhoneAppErrorDialog(phoneNumber);
      }
    } catch (e) {
      debugPrint('Could not launch phone app: $e');
      _showPhoneAppErrorDialog(phoneNumber);
    }
  }

  void _showPhoneAppErrorDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Make Call'),
        content: Text(
          'Your device does not have a phone app installed.\n\nPhone number: $phoneNumber',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
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
      drawer: LandOwnerDrawer(
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
                        _buildSectionTitle('Land Summary', Icons.landscape_rounded),
                        const SizedBox(height: 10),
                        _buildKeyMetrics(context),
                        const SizedBox(height: 30),
                        _buildAssociatedFactoriesSection(),
                        const SizedBox(height: 30),
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
  // --- WIDGET BUILDING METHODS ---
  // -----------------------------------------------------------------

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
                icon: const Icon(Icons.menu,
                    color: AppColors.headerTextDark, size: 28),
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
                    'Land Name: $_landName \n($_userRole)',
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
            'Land Overview (ID: $_landID)',
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

  Widget _buildKeyMetrics(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildLandAreaMetricCard(context),
        _buildMetricCard(
          context,
          'Associated Factories',
          '${_allAssociatedFactories.length}',
          Icons.factory,
          AppColors.primaryBlue,
        ),
      ],
    );
  }

  Widget _buildLandAreaMetricCard(BuildContext context) {
    String displayValue = 'Loading...';
    String displayTitle = 'Land Area';
    String? detailsText;

    if (_cropType != null && _landSize != null) {
      if (_cropType == 'Tea') {
        displayValue = '${_landSize} ${_landSizeUnit ?? "ha"}';
        displayTitle = 'Tea Land Area';
        detailsText = 'Tea cultivation land size';
      } else if (_cropType == 'Cinnamon') {
        displayValue = '${_landSize} ${_landSizeUnit ?? "ha"}';
        displayTitle = 'Cinnamon Land Area';
        detailsText = 'Cinnamon cultivation land size';
      } else if (_cropType == 'Both') {
        double teaSize = double.tryParse(_teaLandSize ?? '0') ?? 0;
        double cinnamonSize = double.tryParse(_cinnamonLandSize ?? '0') ?? 0;
        double totalSize = teaSize + cinnamonSize;

        displayValue = '${totalSize.toStringAsFixed(1)} ${_landSizeUnit ?? "ha"}';
        displayTitle = 'Total Land Area';

        if (teaSize > 0 && cinnamonSize > 0) {
          detailsText = 'Tea: ${teaSize}ha, Cinnamon: ${cinnamonSize}ha';
        } else if (teaSize > 0) {
          detailsText = 'Tea: ${teaSize}ha';
        } else if (cinnamonSize > 0) {
          detailsText = 'Cinnamon: ${cinnamonSize}ha';
        } else {
          detailsText = 'No specific crop data';
        }
      } else {
        displayValue = '${_landSize ?? "0"} ${_landSizeUnit ?? "ha"}';
        detailsText = 'General land area';
      }
    } else {
      displayValue = 'No Data';
      detailsText = 'Land details not available';
    }

    return GestureDetector(
      onTap: () {
        _showLandSizeDetailsModal();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCropColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCropIcon(),
                  color: _getCropColor(),
                  size: 20,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    displayValue,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (detailsText != null && detailsText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        detailsText,
                        style: TextStyle(
                          fontSize: 9,
                          color: const Color.fromARGB(255, 61, 122, 191).withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_cropType != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCropColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _cropType!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getCropColor(),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(value,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText)),
                const SizedBox(height: 4),
                Text(title,
                    style:
                        TextStyle(fontSize: 14, color: AppColors.secondaryText)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssociatedFactoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Associated Factories', Icons.factory_rounded),
            if (_allAssociatedFactories.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.purpleAccent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '${_allAssociatedFactories.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_allAssociatedFactories.isNotEmpty) _buildFactoryStatsCards(),
        const SizedBox(height: 16),
        if (_isLoadingFactories)
          _buildLoadingFactories()
        else if (_errorMessage != null)
          _buildErrorFactories()
        else if (_allAssociatedFactories.isEmpty)
          _buildNoFactoriesCard()
        else
          _buildFactoriesByCategory(),
      ],
    );
  }

Widget _buildFactoryStatsCards() {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First row: 3 cards
        Row(
          children: [
            _buildStatCard(
              title: 'Total Factories',
              value: _allAssociatedFactories.length.toString(),
              icon: Icons.factory,
              color: AppColors.primaryBlue,
              iconColor: Colors.white,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              title: 'Cinnamon',
              value: _cinnamonFactories.length.toString(),
              icon: Icons.spa,
              color: AppColors.warningOrange,
              iconColor: Colors.white,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              title: 'Tea',
              value: _teaFactories.length.toString(),
              icon: Icons.agriculture,
              color: AppColors.successGreen,
              iconColor: Colors.white,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Second row: Multi-Crop
        Row(
          children: [
            _buildStatCard(
              title: 'Multi-Crop',
              value: _multiCropFactories.length.toString(),
              icon: Icons.all_inclusive,
              color: AppColors.purpleAccent,
              iconColor: Colors.white,
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: () {
        if (title == 'Cinnamon' && _cinnamonFactories.isNotEmpty) {
          _showCategoryDialog('Cinnamon Factories', _cinnamonFactories, color);
        } else if (title == 'Tea' && _teaFactories.isNotEmpty) {
          _showCategoryDialog('Tea Factories', _teaFactories, color);
        } else if (title == 'Multi-Crop' && _multiCropFactories.isNotEmpty) {
          _showCategoryDialog(
              'Multi-Crop Factories', _multiCropFactories, color);
        }
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.1)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactoriesByCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_cinnamonFactories.isNotEmpty)
          _buildCategorySection(
            title: 'Cinnamon Factories',
            icon: Icons.spa,
            color: AppColors.warningOrange,
            factories: _cinnamonFactories,
          ),
        if (_teaFactories.isNotEmpty)
          _buildCategorySection(
            title: 'Tea Factories',
            icon: Icons.agriculture,
            color: AppColors.successGreen,
            factories: _teaFactories,
          ),
        if (_multiCropFactories.isNotEmpty)
          _buildCategorySection(
            title: 'Multi-Crop Factories',
            icon: Icons.all_inclusive,
            color: AppColors.purpleAccent,
            factories: _multiCropFactories,
          ),
      ],
    );
  }

  Widget _buildCategorySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> factories,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 12),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${factories.length} factories',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: factories.asMap().entries.map((entry) {
            final index = entry.key;
            final factory = entry.value;
            return _buildModernFactoryCard(factory, index, color);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModernFactoryCard(
      Map<String, dynamic> factory, int index, Color categoryColor) {
    final factoryName = factory['factoryName'] ?? 'Unknown Factory';
    final ownerName = factory['ownerName'] ?? 'N/A';
    final contactNumber = factory['contactNumber'] ?? 'N/A';
    final cropType = factory['cropType'] ?? 'N/A';
    final address = factory['address'] ?? 'N/A';
    final village = factory['village'] ?? 'N/A';
    final district = factory['district'] ?? 'N/A';
    final updatedAt = factory['updatedAt'] != null
        ? (factory['updatedAt'] as Timestamp).toDate()
        : null;
    
    // Get factory logo URL
    final factoryLogoUrl = factory['factoryLogoUrl'];

    final mainColor = categoryColor;
    final icon = _getFactoryCropIcon(cropType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                mainColor.withOpacity(0.05),
                mainColor.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: mainColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Factory Logo/Icon Container
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: mainColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: factoryLogoUrl != null && factoryLogoUrl.isNotEmpty
                            ? Image.network(
                                factoryLogoUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          mainColor,
                                          Color.lerp(mainColor, Colors.black, 0.2)!,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          mainColor,
                                          Color.lerp(mainColor, Colors.black, 0.2)!,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      mainColor,
                                      Color.lerp(mainColor, Colors.black, 0.2)!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Icon(
                                      icon,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  factoryName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: mainColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: mainColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  cropType,
                                  style: TextStyle(
                                    fontSize: 12,
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
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          if (updatedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Updated: ${DateFormat('MMM dd, yyyy').format(updatedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.background),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone, size: 18, color: mainColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact Number',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  contactNumber,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, size: 18, color: mainColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$village, $district',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    address,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _makePhoneCall(contactNumber),
                        icon: Icon(Icons.phone, size: 18, color: mainColor),
                        label: Text(
                          'Call Now',
                          style:
                              TextStyle(color: mainColor, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: mainColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showFactoryDetailsModal(factory),
                        icon:
                            const Icon(Icons.info_outline, size: 18, color: Colors.white),
                        label: const Text(
                          'Full Details',
                          style:
                              TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingFactories() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading Factory Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching your associated factories...',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorFactories() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Unable to load factory data',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your internet connection and try again',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchAssociatedFactories,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFactoriesCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.factory_outlined, size: 40, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Associated Factories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You are not currently associated with any factories. Add factories to start supplying your crops.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to Land Details page
            },
            icon: const Icon(Icons.add_business, size: 18),
            label: const Text('Add Factories'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          const SizedBox(width: 12),
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

  // -----------------------------------------------------------------
  // --- HELPER METHODS ---
  // -----------------------------------------------------------------

  IconData _getCropIcon() {
    switch (_cropType) {
      case 'Cinnamon':
        return Icons.spa;
      case 'Tea':
        return Icons.agriculture;
      case 'Both':
        return Icons.all_inclusive;
      default:
        return Icons.factory;
    }
  }

  // NEW METHOD: Get icon for factory crop type (accepts parameter)
  IconData _getFactoryCropIcon(String cropType) {
    switch (cropType) {
      case 'Cinnamon':
        return Icons.spa;
      case 'Tea':
        return Icons.agriculture;
      case 'Both':
        return Icons.all_inclusive;
      default:
        return Icons.factory;
    }
  }

  Color _getCropColor() {
    switch (_cropType) {
      case 'Tea':
        return AppColors.successGreen;
      case 'Cinnamon':
        return AppColors.warningOrange;
      case 'Both':
        return AppColors.purpleAccent;
      default:
        return AppColors.secondaryColor;
    }
  }

  IconData _getCropIconData() {
    switch (_cropType) {
      case 'Tea':
        return Icons.agriculture;
      case 'Cinnamon':
        return Icons.spa;
      case 'Both':
        return Icons.all_inclusive;
      default:
        return Icons.landscape;
    }
  }

  void _showCategoryDialog(
      String title, List<Map<String, dynamic>> factories, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
                _getCropIcon(),
                color: color),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: factories.length,
            itemBuilder: (context, index) {
              final factory = factories[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(Icons.factory, color: color),
                ),
                title: Text(factory['factoryName'] ?? 'Unknown'),
                subtitle: Text('Owner: ${factory['ownerName'] ?? 'N/A'}'),
                trailing: Icon(Icons.chevron_right, color: color),
                onTap: () {
                  Navigator.pop(context);
                  _showFactoryDetailsModal(factory);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFactoryDetailsModal(Map<String, dynamic> factory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FactoryDetailsModal(
        factory: factory,
        makePhoneCall: _makePhoneCall,
      ),
    );
  }

  void _showLandSizeDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LandSizeDetailsModal(
        cropType: _cropType,
        landSize: _landSize,
        landSizeUnit: _landSizeUnit,
        teaLandSize: _teaLandSize,
        cinnamonLandSize: _cinnamonLandSize,
        landSizeDetails: _landSizeDetails,
        landPhotos: _landPhotos,
      ),
    );
  }
}

// -----------------------------------------------------------------
// --- MODAL WIDGETS ---
// -----------------------------------------------------------------

class FactoryDetailsModal extends StatelessWidget {
  final Map<String, dynamic> factory;
  final Function(String) makePhoneCall;

  const FactoryDetailsModal({
    super.key,
    required this.factory,
    required this.makePhoneCall,
  });

  @override
  Widget build(BuildContext context) {
    final factoryName = factory['factoryName'] ?? 'Unknown Factory';
    final ownerName = factory['ownerName'] ?? 'N/A';
    final contactNumber = factory['contactNumber'] ?? 'N/A';
    final cropType = factory['cropType'] ?? 'N/A';
    final address = factory['address'] ?? 'N/A';
    final village = factory['village'] ?? 'N/A';
    final province = factory['province'] ?? 'N/A';
    final district = factory['district'] ?? 'N/A';
    final agDivision = factory['agDivision'] ?? 'N/A';
    final gnDivision = factory['gnDivision'] ?? 'N/A';
    final country = factory['country'] ?? 'Sri Lanka';
    final updatedAt = factory['updatedAt'] != null
        ? (factory['updatedAt'] as Timestamp).toDate()
        : null;
    
    // Get factory logo URL
    final factoryLogoUrl = factory['factoryLogoUrl'];
    // Get factory photos array
    final factoryPhotos = List<String>.from(factory['factoryPhotos'] ?? []);

    final Map<String, Color> cropColors = {
      'Cinnamon': AppColors.warningOrange,
      'Tea': AppColors.successGreen,
      'Both': AppColors.purpleAccent,
    };

    final mainColor = cropColors[cropType] ?? AppColors.primaryBlue;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
                // Factory Logo Container
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: mainColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: factoryLogoUrl != null && factoryLogoUrl.isNotEmpty
                        ? Image.network(
                            factoryLogoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      mainColor,
                                      Color.lerp(mainColor, Colors.black, 0.2)!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      mainColor,
                                      Color.lerp(mainColor, Colors.black, 0.2)!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Icon(
                                  Icons.factory,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              );
                            },
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  mainColor,
                                  Color.lerp(mainColor, Colors.black, 0.2)!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              Icons.factory,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        factoryName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cropType Factory',
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
                      _buildDetailRow('Factory Name', factoryName),
                      _buildDetailRow('Owner Name', ownerName),
                      _buildDetailRow('Contact Number', contactNumber),
                      _buildDetailRow('Crop Type', cropType),
                      if (updatedAt != null)
                        _buildDetailRow(
                          'Last Updated',
                          DateFormat('MMMM dd, yyyy - hh:mm a').format(updatedAt),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Factory Photos Section
                  if (factoryPhotos.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection(
                          title: 'Factory Photos',
                          icon: Icons.photo_camera,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Total ${factoryPhotos.length} photo${factoryPhotos.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: factoryPhotos.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    factoryPhotos[index],
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
                    title: 'Location Details',
                    icon: Icons.location_on,
                    children: [
                      _buildDetailRow('Address', address),
                      _buildDetailRow('Village/Town', village),
                      _buildDetailRow('District', district),
                      _buildDetailRow('Province', province),
                      _buildDetailRow('A/G Division', agDivision),
                      _buildDetailRow('G/N Division', gnDivision),
                      _buildDetailRow('Country', country),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailSection(
                    title: 'Factory Identification',
                    icon: Icons.fingerprint,
                    children: [
                      _buildDetailRow(
                          'Factory ID', factory['id']?.toString() ?? 'N/A'),
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
                                'Associated via Land Details',
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => makePhoneCall(contactNumber),
                          icon: Icon(Icons.phone, color: mainColor),
                          label: Text(
                            'Call Factory',
                            style:
                                TextStyle(color: mainColor, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: mainColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.message, color: Colors.white),
                          label: const Text(
                            'Send Message',
                            style:
                                TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
      )
    );
  }
}

class LandSizeDetailsModal extends StatelessWidget {
  final String? cropType;
  final String? landSize;
  final String? landSizeUnit;
  final String? teaLandSize;
  final String? cinnamonLandSize;
  final String? landSizeDetails;
  final List<String> landPhotos;

  const LandSizeDetailsModal({
    super.key,
    required this.cropType,
    required this.landSize,
    required this.landSizeUnit,
    required this.teaLandSize,
    required this.cinnamonLandSize,
    required this.landSizeDetails,
    required this.landPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final Color mainColor = _getModalCropColor(cropType);
    final IconData mainIcon = _getModalCropIcon(cropType);

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
                  child: Icon(mainIcon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Land Size Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cropType != null
                            ? '$cropType Land Information'
                            : 'Land Information',
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: mainColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(_getModalCropIcon(cropType),
                            size: 32, color: mainColor),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cropType ?? 'Not Specified',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cultivation Type',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailSection(
                    title: 'Land Size Information',
                    icon: Icons.square_foot,
                    children: _buildLandSizeDetails(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Land Photos Section
                  if (landPhotos.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection(
                          title: 'Land Photos',
                          icon: Icons.photo_camera,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Total ${landPhotos.length} photo${landPhotos.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
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
                  
                  if (cropType == 'Both')
                    _buildDetailSection(
                      title: 'Crop-wise Breakdown',
                      icon: Icons.insights,
                      children: _buildCropBreakdownDetails(),
                    ),
                  if (cropType == 'Both') const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.primaryBlue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All land sizes are measured in ${landSizeUnit ?? 'Hectares'} (ha)',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLandSizeDetails() {
    final List<Widget> details = [];

    if (landSize != null) {
      details.add(_buildDetailRow(
          'Total Land Size', '$landSize ${landSizeUnit ?? "ha"}'));
    }

    if (cropType == 'Both') {
      if (teaLandSize != null && double.tryParse(teaLandSize!) != 0) {
        details.add(_buildDetailRow(
            'Tea Land Size', '$teaLandSize ${landSizeUnit ?? "ha"}'));
      }
      if (cinnamonLandSize != null && double.tryParse(cinnamonLandSize!) != 0) {
        details.add(_buildDetailRow('Cinnamon Land Size',
            '$cinnamonLandSize ${landSizeUnit ?? "ha"}'));
      }
    } else if (cropType == 'Tea' && teaLandSize != null) {
      details.add(_buildDetailRow(
          'Tea Land Size', '$teaLandSize ${landSizeUnit ?? "ha"}'));
    } else if (cropType == 'Cinnamon' && cinnamonLandSize != null) {
      details.add(_buildDetailRow('Cinnamon Land Size',
          '$cinnamonLandSize ${landSizeUnit ?? "ha"}'));
    }

    if (landSizeDetails != null && landSizeDetails!.isNotEmpty) {
      details.add(const SizedBox(height: 8));
      details.add(Text(
        landSizeDetails!,
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: AppColors.secondaryText,
        ),
      ));
    }

    return details;
  }

  List<Widget> _buildCropBreakdownDetails() {
    final List<Widget> breakdown = [];

    double teaSize = double.tryParse(teaLandSize ?? '0') ?? 0;
    double cinnamonSize = double.tryParse(cinnamonLandSize ?? '0') ?? 0;
    double totalSize = teaSize + cinnamonSize;

    if (totalSize > 0) {
      if (teaSize > 0) {
        double teaPercentage = (teaSize / totalSize) * 100;
        breakdown.add(_buildPercentageRow(
          'Tea Cultivation',
          teaSize,
          teaPercentage,
          AppColors.successGreen,
        ));
      }

      if (cinnamonSize > 0) {
        double cinnamonPercentage = (cinnamonSize / totalSize) * 100;
        breakdown.add(_buildPercentageRow(
          'Cinnamon Cultivation',
          cinnamonSize,
          cinnamonPercentage,
          AppColors.warningOrange,
        ));
      }

      breakdown.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Total Land Area',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
            ),
            Text( 
              '${totalSize.toStringAsFixed(1)} ${landSizeUnit ?? "ha"}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ));
    }

    return breakdown;
  }

  Widget _buildPercentageRow(
      String label, double size, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.darkText,
                ),
              ),
              Text(
                '${size.toStringAsFixed(1)} ha (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 15,
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
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      )
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

  Color _getModalCropColor(String? cropType) {
    switch (cropType) {
      case 'Tea':
        return AppColors.successGreen;
      case 'Cinnamon':
        return AppColors.warningOrange;
      case 'Both':
        return AppColors.purpleAccent;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getModalCropIcon(String? cropType) {
    switch (cropType) {
      case 'Tea':
        return Icons.agriculture;
      case 'Cinnamon':
        return Icons.spa;
      case 'Both':
        return Icons.all_inclusive;
      default:
        return Icons.landscape;
    }
  }
}