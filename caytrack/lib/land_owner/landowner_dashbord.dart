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
    _fetchLandSizeData();
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
              
              // Get owner UID from factory data
              String? ownerUid = factoryData['owner'];
              String ownerName = 'Unknown Owner';
              
              // Fetch owner name from users table
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
              
              // Add factory data with owner name
              factories.add({
                'id': factoryId,
                ...factoryData,
                'ownerName': ownerName, // Add owner name to factory data
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

  // Helper methods for responsive design
  bool get _isSmallScreen => MediaQuery.of(context).size.width < 360;
  bool get _isMediumScreen => MediaQuery.of(context).size.width >= 360 && MediaQuery.of(context).size.width < 768;
  bool get _isLargeScreen => MediaQuery.of(context).size.width >= 768;
  double get _baseFontSize => _isSmallScreen ? 12 : (_isMediumScreen ? 14 : 16);
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;

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
                    padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Land Summary', Icons.landscape_rounded),
                        SizedBox(height: _isSmallScreen ? 8.0 : 10.0),
                        _buildKeyMetrics(context),
                        SizedBox(height: _isSmallScreen ? 20.0 : 30.0),
                        _buildAssociatedFactoriesSection(),
                        SizedBox(height: _isSmallScreen ? 20.0 : 30.0),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
                  child: Text(
                    'Developed By Malitha Tishamal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.darkText.withOpacity(0.7),
                      fontSize: _isSmallScreen ? 11.0 : 12.0,
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
    final topPadding = MediaQuery.of(context).padding.top + 10;
    final horizontalPadding = _isSmallScreen ? 16.0 : 20.0;
    final profileSize = _isSmallScreen ? 50.0 : (_isMediumScreen ? 60.0 : 70.0);
    final menuIconSize = _isSmallScreen ? 24.0 : 28.0;
    final nameFontSize = _isSmallScreen ? 16.0 : (_isMediumScreen ? 18.0 : 20.0);
    final landFontSize = _isSmallScreen ? 12.0 : 14.0;
    final titleFontSize = _isSmallScreen ? 14.0 : 16.0;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: _isSmallScreen ? 12.0 : 20.0,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF869AEC), AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20.0),
          bottomRight: Radius.circular(20.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10.0,
            offset: Offset(0, 3.0),
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
                icon: Icon(Icons.menu,
                    color: AppColors.headerTextDark, size: menuIconSize),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          SizedBox(height: _isSmallScreen ? 8.0 : 10.0),
          Row(
            children: [
              Container(
                width: profileSize,
                height: profileSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null
                      ? const LinearGradient(
                          colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: Border.all(
                    color: Colors.white, 
                    width: _isSmallScreen ? 2.0 : 3.0
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: _isSmallScreen ? 6.0 : 10.0,
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
                    ? Icon(Icons.person, 
                        size: _isSmallScreen ? 24.0 : (_isMediumScreen ? 32.0 : 40.0), 
                        color: Colors.white)
                    : null,
              ),
              SizedBox(width: _isSmallScreen ? 12.0 : 15.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName,
                      style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Land Name: $_landName \n($_userRole)',
                      style: TextStyle(
                        fontSize: landFontSize,
                        color: AppColors.headerTextDark.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: _isSmallScreen ? 15.0 : 25.0),
          Text(
            'Land Overview (ID: $_landID)',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(BuildContext context) {
    final crossAxisCount = _isSmallScreen ? 1 : 2;
    final crossAxisSpacing = _isSmallScreen ? 12.0 : 16.0;
    final mainAxisSpacing = _isSmallScreen ? 12.0 : 16.0;

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
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
          borderRadius: BorderRadius.circular(_isSmallScreen ? 12.0 : 16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(_isSmallScreen ? 8.0 : 12.0),
                decoration: BoxDecoration(
                  color: _getCropColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
                ),
                child: Icon(
                  _getCropIcon(),
                  color: _getCropColor(),
                  size: _isSmallScreen ? 16.0 : 20.0,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: _isSmallScreen ? 4.0 : 8.0),
                  Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: _isSmallScreen ? 16.0 : 20.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: _isSmallScreen ? 10.0 : 12.0,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (detailsText != null && detailsText.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: _isSmallScreen ? 4.0 : 8.0),
                      child: Text(
                        detailsText,
                        style: TextStyle(
                          fontSize: _isSmallScreen ? 9.0 : 10.0,
                          color: const Color.fromARGB(255, 61, 122, 191).withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_cropType != null)
                    Container(
                      margin: EdgeInsets.only(top: _isSmallScreen ? 4.0 : 8.0),
                      padding: EdgeInsets.symmetric(
                        horizontal: _isSmallScreen ? 6.0 : 8.0,
                        vertical: _isSmallScreen ? 2.0 : 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: _getCropColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(_isSmallScreen ? 4.0 : 6.0),
                      ),
                      child: Text(
                        _cropType!,
                        style: TextStyle(
                          fontSize: _isSmallScreen ? 9.0 : 10.0,
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
        borderRadius: BorderRadius.circular(_isSmallScreen ? 12.0 : 16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(_isSmallScreen ? 8.0 : 12.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
              ),
              child: Icon(icon, 
                color: color, 
                size: _isSmallScreen ? 20.0 : 24.0,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: _isSmallScreen ? 8.0 : 12.0),
                Text(value,
                    style: TextStyle(
                        fontSize: _isSmallScreen ? 18.0 : 22.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText)),
                SizedBox(height: _isSmallScreen ? 2.0 : 4.0),
                Text(title,
                    style:
                        TextStyle(
                          fontSize: _isSmallScreen ? 12.0 : 14.0, 
                          color: AppColors.secondaryText
                        )),
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
                padding: EdgeInsets.symmetric(
                  horizontal: _isSmallScreen ? 8.0 : 12.0, 
                  vertical: _isSmallScreen ? 3.0 : 4.0
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.purpleAccent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, 
                      size: _isSmallScreen ? 12.0 : 14.0, 
                      color: Colors.white
                    ),
                    SizedBox(width: _isSmallScreen ? 4.0 : 6.0),
                    Text(
                      '${_allAssociatedFactories.length}',
                      style: TextStyle(
                        fontSize: _isSmallScreen ? 11.0 : 12.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: _isSmallScreen ? 12.0 : 16.0),
        if (_allAssociatedFactories.isNotEmpty) _buildFactoryStatsCards(),
        SizedBox(height: _isSmallScreen ? 12.0 : 16.0),
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
  final cardWidth = _isSmallScreen ? 100.0 : 120.0;
  
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
              cardWidth: cardWidth,
            ),
            SizedBox(width: _isSmallScreen ? 8.0 : 12.0),
            _buildStatCard(
              title: 'Cinnamon',
              value: _cinnamonFactories.length.toString(),
              icon: Icons.spa,
              color: AppColors.warningOrange,
              iconColor: Colors.white,
              cardWidth: cardWidth,
            ),
            SizedBox(width: _isSmallScreen ? 8.0 : 12.0),
            _buildStatCard(
              title: 'Tea',
              value: _teaFactories.length.toString(),
              icon: Icons.agriculture,
              color: AppColors.successGreen,
              iconColor: Colors.white,
              cardWidth: cardWidth,
            ),
          ],
        ),

        SizedBox(height: _isSmallScreen ? 8.0 : 12.0),

        // Second row: Multi-Crop
        Row(
          children: [
            _buildStatCard(
              title: 'Multi-Crop',
              value: _multiCropFactories.length.toString(),
              icon: Icons.all_inclusive,
              color: AppColors.purpleAccent,
              iconColor: Colors.white,
              cardWidth: cardWidth,
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
    required double cardWidth,
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
        width: cardWidth,
        padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.1)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_isSmallScreen ? 12.0 : 16.0),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: _isSmallScreen ? 6.0 : 10.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(_isSmallScreen ? 6.0 : 8.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(_isSmallScreen ? 6.0 : 8.0),
              ),
              child: Icon(icon, 
                size: _isSmallScreen ? 16.0 : 20.0, 
                color: iconColor
              ),
            ),
            SizedBox(height: _isSmallScreen ? 8.0 : 12.0),
            Text(
              value,
              style: TextStyle(
                fontSize: _isSmallScreen ? 20.0 : 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: _isSmallScreen ? 2.0 : 4.0),
            Text(
              title,
              style: TextStyle(
                fontSize: _isSmallScreen ? 10.0 : 12.0,
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
        SizedBox(height: _isSmallScreen ? 16.0 : 24.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(_isSmallScreen ? 6.0 : 8.0),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 10.0),
                  ),
                  child: Icon(icon, 
                    size: _isSmallScreen ? 18.0 : 22.0, 
                    color: color
                  ),
                ),
                SizedBox(width: _isSmallScreen ? 8.0 : 12.0),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _isSmallScreen ? 16.0 : 18.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: _isSmallScreen ? 8.0 : 12.0, 
                vertical: _isSmallScreen ? 3.0 : 4.0
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_isSmallScreen ? 16.0 : 20.0),
              ),
              child: Text(
                '${factories.length} factories',
                style: TextStyle(
                  fontSize: _isSmallScreen ? 10.0 : 12.0,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _isSmallScreen ? 8.0 : 12.0),
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
      margin: EdgeInsets.only(bottom: _isSmallScreen ? 12.0 : 16.0),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(_isSmallScreen ? 16.0 : 20.0),
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
            borderRadius: BorderRadius.circular(_isSmallScreen ? 16.0 : 20.0),
            border: Border.all(
              color: mainColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Factory Logo/Icon Container
                    Container(
                      width: _isSmallScreen ? 48.0 : 56.0,
                      height: _isSmallScreen ? 48.0 : 56.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
                        boxShadow: [
                          BoxShadow(
                            color: mainColor.withOpacity(0.3),
                            blurRadius: _isSmallScreen ? 6.0 : 8.0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
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
                                    child: Center(
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
                                      size: _isSmallScreen ? 24.0 : 28.0,
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
                                      size: _isSmallScreen ? 24.0 : 28.0,
                                    ),
                              ),
                      ),
                    ),
                    SizedBox(width: _isSmallScreen ? 12.0 : 16.0),
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
                                  style: TextStyle(
                                    fontSize: _isSmallScreen ? 16.0 : 18.0,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _isSmallScreen ? 8.0 : 12.0, 
                                  vertical: _isSmallScreen ? 2.0 : 4.0
                                ),
                                decoration: BoxDecoration(
                                  color: mainColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(_isSmallScreen ? 16.0 : 20.0),
                                  border:
                                      Border.all(color: mainColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  cropType,
                                  style: TextStyle(
                                    fontSize: _isSmallScreen ? 10.0 : 12.0,
                                    fontWeight: FontWeight.w600,
                                    color: mainColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: _isSmallScreen ? 2.0 : 4.0),
                          Text(
                            'Owner: $ownerName',
                            style: TextStyle(
                              fontSize: _isSmallScreen ? 12.0 : 14.0,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          if (updatedAt != null) ...[
                            SizedBox(height: _isSmallScreen ? 2.0 : 4.0),
                            Text(
                              'Updated: ${DateFormat('MMM dd, yyyy').format(updatedAt)}',
                              style: TextStyle(
                                fontSize: _isSmallScreen ? 10.0 : 12.0,
                                color: AppColors.secondaryText.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _isSmallScreen ? 12.0 : 16.0),
                Container(
                  padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
                    border: Border.all(color: AppColors.background),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone, 
                            size: _isSmallScreen ? 16.0 : 18.0, 
                            color: mainColor
                          ),
                          SizedBox(width: _isSmallScreen ? 6.0 : 8.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact Number',
                                  style: TextStyle(
                                    fontSize: _isSmallScreen ? 10.0 : 12.0,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                SizedBox(height: _isSmallScreen ? 1.0 : 2.0),
                                Text(
                                  contactNumber,
                                  style: TextStyle(
                                    fontSize: _isSmallScreen ? 14.0 : 16.0,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: _isSmallScreen ? 8.0 : 12.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, 
                            size: _isSmallScreen ? 16.0 : 18.0, 
                            color: mainColor
                          ),
                          SizedBox(width: _isSmallScreen ? 6.0 : 8.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: _isSmallScreen ? 10.0 : 12.0,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                SizedBox(height: _isSmallScreen ? 1.0 : 2.0),
                                Text(
                                  '$village, $district',
                                  style: TextStyle(
                                    fontSize: _isSmallScreen ? 14.0 : 16.0,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                if (address.isNotEmpty) ...[
                                  SizedBox(height: _isSmallScreen ? 1.0 : 2.0),
                                  Text(
                                    address,
                                    style: TextStyle(
                                      fontSize: _isSmallScreen ? 11.0 : 13.0,
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
                SizedBox(height: _isSmallScreen ? 12.0 : 16.0),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _makePhoneCall(contactNumber),
                        icon: Icon(Icons.phone, 
                          size: _isSmallScreen ? 16.0 : 18.0, 
                          color: mainColor
                        ),
                        label: Text(
                          'Call Now',
                          style: TextStyle(
                            color: mainColor, 
                            fontWeight: FontWeight.w600,
                            fontSize: _isSmallScreen ? 12.0 : 14.0,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: _isSmallScreen ? 10.0 : 12.0,
                          ),
                          side: BorderSide(color: mainColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: _isSmallScreen ? 8.0 : 12.0),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showFactoryDetailsModal(factory),
                        icon: Icon(Icons.info_outline, 
                          size: _isSmallScreen ? 16.0 : 18.0, 
                          color: Colors.white
                        ),
                        label: Text(
                          'Full Details',
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.w600,
                            fontSize: _isSmallScreen ? 12.0 : 14.0,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          padding: EdgeInsets.symmetric(
                            vertical: _isSmallScreen ? 10.0 : 12.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
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
      padding: EdgeInsets.all(_isSmallScreen ? 24.0 : 32.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(_isSmallScreen ? 12.0 : 16.0),
      ),
      child: Column(
        children: [
          SizedBox(
            width: _isSmallScreen ? 48.0 : 60.0,
            height: _isSmallScreen ? 48.0 : 60.0,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ),
          SizedBox(height: _isSmallScreen ? 12.0 : 16.0),
          Text(
            'Loading Factory Details',
            style: TextStyle(
              fontSize: _isSmallScreen ? 14.0 : 16.0,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: _isSmallScreen ? 4.0 : 8.0),
          Text(
            'Fetching your associated factories...',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: _isSmallScreen ? 12.0 : 14.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorFactories() {
    return Container(
      padding: EdgeInsets.all(_isSmallScreen ? 16.0 : 24.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(_isSmallScreen ? 12.0 : 16.0),
        border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, 
            size: _isSmallScreen ? 36.0 : 48.0, 
            color: AppColors.accentRed
          ),
          SizedBox(height: _isSmallScreen ? 12.0 : 16.0),
          Text(
            _errorMessage ?? 'Unable to load factory data',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _isSmallScreen ? 14.0 : 16.0,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: _isSmallScreen ? 4.0 : 8.0),
          Text(
            'Please check your internet connection and try again',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: _isSmallScreen ? 12.0 : 14.0,
            ),
          ),
          SizedBox(height: _isSmallScreen ? 12.0 : 16.0),
          ElevatedButton.icon(
            onPressed: _fetchAssociatedFactories,
            icon: Icon(Icons.refresh, 
              size: _isSmallScreen ? 16.0 : 18.0
            ),
            label: Text('Retry',
              style: TextStyle(
                fontSize: _isSmallScreen ? 12.0 : 14.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: _isSmallScreen ? 16.0 : 24.0, 
                vertical: _isSmallScreen ? 10.0 : 12.0
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFactoriesCard() {
    return Container(
      padding: EdgeInsets.all(_isSmallScreen ? 20.0 : 24.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(_isSmallScreen ? 12.0 : 16.0),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: _isSmallScreen ? 60.0 : 70.0,
            height: _isSmallScreen ? 60.0 : 70.0,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.factory_outlined, 
                  size: _isSmallScreen ? 30.0 : 36.0, 
                  color: AppColors.primaryBlue
                ),
          ),
          SizedBox(height: _isSmallScreen ? 12.0 : 16.0),
          Text(
            'No Associated Factories',
            style: TextStyle(
              fontSize: _isSmallScreen ? 16.0 : 18.0,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: _isSmallScreen ? 8.0 : 12.0),
          Text(
            'You are not currently associated with any factories. Add factories to start supplying your crops.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: _isSmallScreen ? 12.0 : 14.0,
            ),
          ),
          SizedBox(height: _isSmallScreen ? 16.0 : 20.0),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to Land Details page
            },
            icon: Icon(Icons.add_business, 
              size: _isSmallScreen ? 16.0 : 18.0
            ),
            label: Text('Add Factories',
              style: TextStyle(
                fontSize: _isSmallScreen ? 12.0 : 14.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: _isSmallScreen ? 16.0 : 24.0, 
                vertical: _isSmallScreen ? 10.0 : 12.0
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_isSmallScreen ? 8.0 : 12.0),
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
            padding: EdgeInsets.all(_isSmallScreen ? 4.0 : 6.0),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_isSmallScreen ? 6.0 : 8.0),
            ),
            child: Icon(icon, 
              color: AppColors.primaryBlue, 
              size: _isSmallScreen ? 16.0 : 20.0
            ),
          ),
          SizedBox(width: _isSmallScreen ? 8.0 : 12.0),
          Text(
            title,
            style: TextStyle(
              fontSize: _isSmallScreen ? 16.0 : 18.0,
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
            SizedBox(width: _isSmallScreen ? 8.0 : 12.0),
            Text(title,
                style: TextStyle(
                  color: color, 
                  fontWeight: FontWeight.bold,
                  fontSize: _isSmallScreen ? 14.0 : 16.0,
                )),
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
                  child: Icon(Icons.factory, 
                    color: color,
                    size: _isSmallScreen ? 18.0 : 20.0,
                  ),
                ),
                title: Text(factory['factoryName'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: _isSmallScreen ? 12.0 : 14.0,
                  ),
                ),
                subtitle: Text('Owner: ${factory['ownerName'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: _isSmallScreen ? 10.0 : 12.0,
                  ),
                ),
                trailing: Icon(Icons.chevron_right, 
                  color: color,
                  size: _isSmallScreen ? 18.0 : 20.0,
                ),
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
            child: Text('Close',
              style: TextStyle(
                fontSize: _isSmallScreen ? 12.0 : 14.0,
              ),
            ),
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
        isSmallScreen: _isSmallScreen,
        isMediumScreen: _isMediumScreen,
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
        isSmallScreen: _isSmallScreen,
        isMediumScreen: _isMediumScreen,
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
  final bool isSmallScreen;
  final bool isMediumScreen;

  const FactoryDetailsModal({
    super.key,
    required this.factory,
    required this.makePhoneCall,
    required this.isSmallScreen,
    required this.isMediumScreen,
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
      'Cinnamon': Colors.orange,
      'Tea': Colors.green,
      'Both': Colors.purple,
    };

    final mainColor = cropColors[cropType] ?? Colors.blue;

    return Container(
      height: MediaQuery.of(context).size.height * (isSmallScreen ? 0.85 : 0.90),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isSmallScreen ? 20.0 : 30.0),
          topRight: Radius.circular(isSmallScreen ? 20.0 : 30.0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mainColor.withOpacity(0.1),
                  mainColor.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isSmallScreen ? 20.0 : 30.0),
                topRight: Radius.circular(isSmallScreen ? 20.0 : 30.0),
              ),
            ),
            child: Row(
              children: [
                // Factory Logo Container
                Container(
                  width: isSmallScreen ? 48.0 : 56.0,
                  height: isSmallScreen ? 48.0 : 56.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                    boxShadow: [
                      BoxShadow(
                        color: mainColor.withOpacity(0.3),
                        blurRadius: isSmallScreen ? 6.0 : 8.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
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
                                child: Center(
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
                                  size: isSmallScreen ? 20.0 : 24.0,
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
                              size: isSmallScreen ? 20.0 : 24.0,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        factoryName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16.0 : 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                      Text(
                        '$cropType Factory',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                          color: mainColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, 
                    color: Colors.grey[600],
                    size: isSmallScreen ? 20.0 : 24.0,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
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
                  SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                  
                  // Factory Photos Section
                  if (factoryPhotos.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection(
                          title: 'Factory Photos',
                          icon: Icons.photo_camera,
                          children: [
                            SizedBox(height: isSmallScreen ? 4.0 : 8.0),
                            Text(
                              'Total ${factoryPhotos.length} photo${factoryPhotos.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12.0 : 14.0,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isSmallScreen ? 2 : 3,
                                crossAxisSpacing: isSmallScreen ? 6.0 : 8.0,
                                mainAxisSpacing: isSmallScreen ? 6.0 : 8.0,
                                childAspectRatio: 1,
                              ),
                              itemCount: factoryPhotos.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
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
                                        child: Icon(Icons.broken_image, 
                                          color: Colors.grey,
                                          size: isSmallScreen ? 24.0 : 32.0,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 16.0 : 24.0),
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
                  SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                  _buildDetailSection(
                    title: 'Factory Identification',
                    icon: Icons.fingerprint,
                    children: [
                      _buildDetailRow(
                          'Factory ID', factory['id']?.toString() ?? 'N/A'),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                          border: Border.all(color: mainColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield, 
                              color: mainColor, 
                              size: isSmallScreen ? 16.0 : 20.0
                            ),
                            SizedBox(width: isSmallScreen ? 8.0 : 10.0),
                            Expanded(
                              child: Text(
                                'Associated via Land Details',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12.0 : 14.0,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 20.0 : 30.0),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => makePhoneCall(contactNumber),
                          icon: Icon(Icons.phone, 
                            color: mainColor,
                            size: isSmallScreen ? 16.0 : 18.0,
                          ),
                          label: Text(
                            'Call Factory',
                            style: TextStyle(
                              color: mainColor, 
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 12.0 : 14.0,
                            ),
                            side: BorderSide(color: mainColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.message, 
                            color: Colors.white,
                            size: isSmallScreen ? 16.0 : 18.0,
                          ),
                          label: Text(
                            'Send Message',
                            style: TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 12.0 : 14.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12.0 : 16.0),
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
              padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
              ),
              child: Icon(icon, 
                size: isSmallScreen ? 16.0 : 18.0, 
                color: Colors.blue
              ),
            ),
            SizedBox(width: isSmallScreen ? 8.0 : 10.0),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 14.0 : 16.0,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 8.0 : 12.0),
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
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
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6.0 : 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 100.0 : 120.0,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: isSmallScreen ? 12.0 : 14.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 6.0 : 8.0),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 12.0 : 14.0,
                color: Colors.black,
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
  final bool isSmallScreen;
  final bool isMediumScreen;

  const LandSizeDetailsModal({
    super.key,
    required this.cropType,
    required this.landSize,
    required this.landSizeUnit,
    required this.teaLandSize,
    required this.cinnamonLandSize,
    required this.landSizeDetails,
    required this.landPhotos,
    required this.isSmallScreen,
    required this.isMediumScreen,
  });

  @override
  Widget build(BuildContext context) {
    final Color mainColor = _getModalCropColor(cropType);
    final IconData mainIcon = _getModalCropIcon(cropType);

    return Container(
      height: MediaQuery.of(context).size.height * (isSmallScreen ? 0.80 : 0.85),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isSmallScreen ? 20.0 : 30.0),
          topRight: Radius.circular(isSmallScreen ? 20.0 : 30.0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mainColor.withOpacity(0.1),
                  mainColor.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isSmallScreen ? 20.0 : 30.0),
                topRight: Radius.circular(isSmallScreen ? 20.0 : 30.0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: isSmallScreen ? 40.0 : 48.0,
                  height: isSmallScreen ? 40.0 : 48.0,
                  decoration: BoxDecoration(
                    color: mainColor,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                  ),
                  child: Icon(mainIcon, 
                    color: Colors.white, 
                    size: isSmallScreen ? 20.0 : 24.0
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Land Size Details',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16.0 : 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                      Text(
                        cropType != null
                            ? '$cropType Land Information'
                            : 'Land Information',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                          color: mainColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, 
                    color: Colors.grey[600],
                    size: isSmallScreen ? 20.0 : 24.0,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                      border: Border.all(color: mainColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(_getModalCropIcon(cropType),
                            size: isSmallScreen ? 24.0 : 28.0, color: mainColor),
                        SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cropType ?? 'Not Specified',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16.0 : 18.0,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                              Text(
                                'Cultivation Type',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12.0 : 14.0,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                  _buildDetailSection(
                    title: 'Land Size Information',
                    icon: Icons.square_foot,
                    children: _buildLandSizeDetails(),
                  ),
                  SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                  
                  // Land Photos Section
                  if (landPhotos.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection(
                          title: 'Land Photos',
                          icon: Icons.photo_camera,
                          children: [
                            SizedBox(height: isSmallScreen ? 4.0 : 8.0),
                            Text(
                              'Total ${landPhotos.length} photo${landPhotos.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12.0 : 14.0,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isSmallScreen ? 2 : 3,
                                crossAxisSpacing: isSmallScreen ? 6.0 : 8.0,
                                mainAxisSpacing: isSmallScreen ? 6.0 : 8.0,
                                childAspectRatio: 1,
                              ),
                              itemCount: landPhotos.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
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
                                        child: Icon(Icons.broken_image, 
                                          color: Colors.grey,
                                          size: isSmallScreen ? 24.0 : 32.0,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                      ],
                    ),
                  
                  if (cropType == 'Both')
                    _buildDetailSection(
                      title: 'Crop-wise Breakdown',
                      icon: Icons.insights,
                      children: _buildCropBreakdownDetails(),
                    ),
                  if (cropType == 'Both') SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                  
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8.0 : 12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                      border:
                          Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue, size: isSmallScreen ? 16.0 : 20.0),
                        SizedBox(width: isSmallScreen ? 8.0 : 10.0),
                        Expanded(
                          child: Text(
                            'All land sizes are measured in ${landSizeUnit ?? 'Hectares'} (ha)',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12.0 : 16.0),
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
      details.add(SizedBox(height: isSmallScreen ? 4.0 : 8.0));
      details.add(Text(
        landSizeDetails!,
        style: TextStyle(
          fontSize: isSmallScreen ? 12.0 : 14.0,
          fontStyle: FontStyle.italic,
          color: Colors.grey[600],
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
          Colors.green,
        ));
      }

      if (cinnamonSize > 0) {
        double cinnamonPercentage = (cinnamonSize / totalSize) * 100;
        breakdown.add(_buildPercentageRow(
          'Cinnamon Cultivation',
          cinnamonSize,
          cinnamonPercentage,
          Colors.orange,
        ));
      }

      breakdown.add(Padding(
        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8.0 : 12.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Total Land Area',
                style: TextStyle(
                  fontSize: isSmallScreen ? 8.0 : 10.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            Text( 
              '${totalSize.toStringAsFixed(1)} ${landSizeUnit ?? "ha"}',
              style: TextStyle(
                fontSize: isSmallScreen ? 12.0 : 14.0,
                fontWeight: FontWeight.w700,
                color: Colors.blue,
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
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6.0 : 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12.0 : 14.0,
                  color: Colors.black,
                ),
              ),
              Text(
                '${size.toStringAsFixed(1)} ha (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12.0 : 14.0,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: isSmallScreen ? 4.0 : 6.0,
            borderRadius: BorderRadius.circular(isSmallScreen ? 2.0 : 3.0),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6.0 : 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 110.0 : 130.0,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: isSmallScreen ? 12.0 : 14.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 6.0 : 8.0),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 12.0 : 14.0,
                fontWeight: FontWeight.w600,
                color: Colors.black,
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
              padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
              ),
              child: Icon(icon, 
                size: isSmallScreen ? 16.0 : 18.0, 
                color: Colors.blue
              ),
            ),
            SizedBox(width: isSmallScreen ? 8.0 : 10.0),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 14.0 : 16.0,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 8.0 : 12.0),
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
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
        return Colors.green;
      case 'Cinnamon':
        return Colors.orange;
      case 'Both':
        return Colors.purple;
      default:
        return Colors.blue;
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