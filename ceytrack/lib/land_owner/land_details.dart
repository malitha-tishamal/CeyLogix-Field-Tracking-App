// land_details.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'land_owner_drawer.dart'; // Import your drawer
import 'landowner_dashbord.dart'; // Import dashboard
import 'user_profile.dart'; // Import profile page
import 'land_location.dart'; // Import location page
import 'developer_info.dart'; // Import developer info
import '../Auth/login_page.dart'; // Import login page

class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
  static const Color headerGradientStart = Color.fromARGB(255, 134, 164, 236);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

// Responsive Helper Extension
extension ResponsiveExtensions on BuildContext {
  // Responsive padding
  double get paddingSmall {
    final width = MediaQuery.of(this).size.width;
    if (width < 600) return 12.0;
    if (width < 900) return 16.0;
    return 20.0;
  }
  
  double get paddingMedium {
    final width = MediaQuery.of(this).size.width;
    if (width < 600) return 16.0;
    if (width < 900) return 20.0;
    return 24.0;
  }
  
  double get paddingLarge {
    final width = MediaQuery.of(this).size.width;
    if (width < 600) return 20.0;
    if (width < 900) return 24.0;
    return 32.0;
  }
  
  // Screen size detection
  bool get isSmallScreen => MediaQuery.of(this).size.width < 600;
  bool get isMediumScreen => MediaQuery.of(this).size.width >= 600 && MediaQuery.of(this).size.width < 900;
  bool get isLargeScreen => MediaQuery.of(this).size.width >= 900;
  
  // Photo grid columns
  int get photoGridColumns {
    final width = MediaQuery.of(this).size.width;
    if (width < 400) return 2;
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 5;
  }
  
  // Font size based on screen
  double get fontSizeSmall => isSmallScreen ? 12.0 : 14.0;
  double get fontSizeMedium => isSmallScreen ? 14.0 : 16.0;
  double get fontSizeLarge => isSmallScreen ? 16.0 : 18.0;
  double get fontSizeExtraLarge => isSmallScreen ? 18.0 : 20.0;
}

class LandDetails extends StatefulWidget {
  const LandDetails({super.key});

  @override
  State<LandDetails> createState() => _LandDetailsState();
}

class _LandDetailsState extends State<LandDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variables for header - Username, Land Name, Role
  String _loggedInUserName = 'Loading User...';
  String _landName = 'Loading Land...';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  // Fetch all header data (username, land name, role, profile image)
  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    
    final String uid = user.uid;

    try {
      // 1. Fetch User Name and Role from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Land Owner';
        });
      }
      
      // 2. Fetch Land Name from 'lands' collection
      final landDoc = await FirebaseFirestore.instance.collection('lands').doc(uid).get();
      if (landDoc.exists) {
        setState(() {
          _landName = landDoc.data()?['landName'] ?? 'Land Name Missing';
        });
      } else {
        // If land doesn't exist, show user email as fallback
        setState(() {
          _landName = user.email?.split('@')[0] ?? 'User Account';
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

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
    }

    void handleDrawerNavigate(String route) {
      Navigator.of(context).pop(); // Close drawer
      
      // Handle navigation based on route
      switch (route) {
        case 'dashboard':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LandOwnerDashboard()),
          );
          break;
        case 'land_details':
          // Already on this page
          break;
        case 'profile':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserDetails()),
          );
          break;
        case 'location':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LocationSelectionPage(
              onLocationSelected: (locationData) {
                // Handle location selection
                print('Selected Location: $locationData');
              },
            )),
          );
          break;
        case 'developer_info':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DeveloperInfoPage()),
          );
          break;
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onNavigate: handleDrawerNavigate,
        onLogout: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🌟 RESPONSIVE HEADER - Adapts to screen size
            _buildResponsiveHeader(context),
            
            // Scrollable Content with Footer
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: LandOwnerProfileContent(
                      key: ValueKey(currentUser!.uid),
                      landOwnerUID: currentUser!.uid,
                      onProfileUpdated: _fetchHeaderData,
                      onDataUpdated: _showSuccessAndRefresh,
                    ),
                  ),
                  
                  // Footer (Fixed at bottom of content area)
                  Container(
                    padding: EdgeInsets.all(context.paddingSmall),
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
      ),
    );
  }

  void _showSuccessAndRefresh() {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Land details updated successfully!'),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.secondaryColor,
      ),
    );
    
    // Refresh header data
    _fetchHeaderData();
  }
  
  // 🌟 RESPONSIVE HEADER - Adapts to screen size
  Widget _buildResponsiveHeader(BuildContext context) {
    final isSmallScreen = context.isSmallScreen;
    final isMediumScreen = context.isMediumScreen;
    
    return Container(
      padding: EdgeInsets.only(
        top: isSmallScreen ? 10 : 15,
        left: isSmallScreen ? 16 : 24,
        right: isSmallScreen ? 16 : 24,
        bottom: isSmallScreen ? 16 : 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
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
          // Menu Button and Hamburger Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.menu,
                  color: AppColors.headerTextDark,
                  size: isSmallScreen ? 24 : 28,
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              // Optional: Add notification or other icons for larger screens
              if (!isSmallScreen)
                IconButton(
                  icon: Icon(Icons.notifications, size: isSmallScreen ? 22 : 26),
                  onPressed: () {
                    // Handle notifications
                  },
                ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          // Profile and User Info Section - Responsive Layout
          isSmallScreen 
            ? _buildSmallScreenHeader()
            : _buildLargeScreenHeader(isMediumScreen),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Page Title
          Text(
            'Manage Your Land Information',
            style: TextStyle(
              fontSize: isSmallScreen ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  // Header for small screens (mobile)
  Widget _buildSmallScreenHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Profile Picture
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _profileImageUrl == null 
                  ? const LinearGradient(
                      colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.4),
                    blurRadius: 8,
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
                ? const Icon(Icons.person, size: 32, color: Colors.white)
                : null,
            ),
            
            const SizedBox(width: 12),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loggedInUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 2),
                  
                  Text(
                    'Land Name: ' + _landName,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.headerTextDark.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 2),
                  
                  Text(
                    '($_userRole)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.headerTextDark.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Header for larger screens (tablet/desktop)
  Widget _buildLargeScreenHeader(bool isMediumScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Picture
        Container(
          width: isMediumScreen ? 70 : 80,
          height: isMediumScreen ? 70 : 80,
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
            ? Icon(
                Icons.person,
                size: isMediumScreen ? 40 : 45,
                color: Colors.white,
              )
            : null,
        ),
        
        SizedBox(width: isMediumScreen ? 15 : 20),
        
        // User Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _loggedInUserName,
                style: TextStyle(
                  fontSize: isMediumScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.headerTextDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: isMediumScreen ? 4 : 6),
              
              Text(
                'Land Name: ' + _landName,
                style: TextStyle(
                  fontSize: isMediumScreen ? 16 : 17,
                  color: AppColors.headerTextDark.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: isMediumScreen ? 4 : 6),
              
              Text(
                '($_userRole)',
                style: TextStyle(
                  fontSize: isMediumScreen ? 14 : 15,
                  color: AppColors.headerTextDark.withOpacity(0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LandOwnerProfileContent extends StatefulWidget {
  final String landOwnerUID;
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onDataUpdated;
  
  const LandOwnerProfileContent({
    required this.landOwnerUID, 
    this.onProfileUpdated,
    this.onDataUpdated,
    super.key,
  });

  @override
  State<LandOwnerProfileContent> createState() => _LandOwnerProfileContentState();
}

class _LandOwnerProfileContentState extends State<LandOwnerProfileContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final String _cloudName = "dqeptzlsb";
  final String _uploadPreset = "flutter_ceytrack_upload";

  // Text Controllers
  late TextEditingController _landNameController;
  late TextEditingController _addressController;
  late TextEditingController _landSizeController;
  late TextEditingController _agDivisionController;
  late TextEditingController _gnDivisionController;
  late TextEditingController _villageController;

  // State variables for LAND PHOTOS
  List<XFile> _selectedLandPhotos = [];
  List<String> _uploadedLandPhotoUrls = [];
  bool _uploadingPhotos = false;
  int _maxPhotos = 5;

  // Other state variables
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedCropType;
  List<String> _selectedFactoryIds = [];
  List<Map<String, dynamic>> _availableFactories = [];
  
  bool _isSaving = false;
  String? _statusMessage;
  bool _isLoading = true;
  Map<String, dynamic>? _loadedData;

  // Tea and Cinnamon specific land size controllers
  late TextEditingController _teaLandSizeController;
  late TextEditingController _cinnamonLandSizeController;

  static final Map<String, List<String>> _geoData = _getGeoData();

  @override
  void initState() {
    super.initState();
    _landNameController = TextEditingController();
    _addressController = TextEditingController();
    _landSizeController = TextEditingController();
    _teaLandSizeController = TextEditingController();
    _cinnamonLandSizeController = TextEditingController();
    _agDivisionController = TextEditingController();
    _gnDivisionController = TextEditingController();
    _villageController = TextEditingController();
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final factoriesSnapshot = await _firestore.collection('factories').get();
      final landDoc = await _firestore.collection('lands').doc(widget.landOwnerUID).get();

      if (mounted) {
        _availableFactories = factoriesSnapshot.docs.map((doc) {
          final factoryData = doc.data();
          return {
            'id': doc.id,
            'factoryName': factoryData['factoryName'] ?? 'Unknown Factory',
          };
        }).toList();

        final landData = landDoc.data();
        if (landData != null) {
          _loadedData = landData;
          _populateFormData(landData);
          
          // Load existing land photos
          if (landData['landPhotos'] != null && landData['landPhotos'] is List) {
            _uploadedLandPhotoUrls = List<String>.from(landData['landPhotos']);
          }
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Error loading data: $e";
        });
      }
    }
  }

  void _populateFormData(Map<String, dynamic> data) {
    _landNameController.text = data['landName'] ?? '';
    _addressController.text = data['address'] ?? '';
    _villageController.text = data['village'] ?? '';
    _agDivisionController.text = data['agDivision'] ?? '';
    _gnDivisionController.text = data['gnDivision'] ?? '';
    
    _selectedProvince = data['province'];
    _selectedDistrict = data['district'];
    _selectedCropType = data['cropType'];
    _selectedFactoryIds = List<String>.from(data['factoryIds'] ?? []);

    // Load land sizes based on crop type
    if (_selectedCropType == 'Tea') {
      if (data['landSize'] != null) {
        _landSizeController.text = data['landSize'].toString();
      } else if (data['teaLandSize'] != null) {
        _landSizeController.text = data['teaLandSize'].toString();
      }
      
      _teaLandSizeController.clear();
      _cinnamonLandSizeController.clear();
      
    } else if (_selectedCropType == 'Cinnamon') {
      if (data['landSize'] != null) {
        _landSizeController.text = data['landSize'].toString();
      } else if (data['cinnamonLandSize'] != null) {
        _landSizeController.text = data['cinnamonLandSize'].toString();
      }
      
      _teaLandSizeController.clear();
      _cinnamonLandSizeController.clear();
      
    } else if (_selectedCropType == 'Both') {
      if (data['teaLandSize'] != null) {
        _teaLandSizeController.text = data['teaLandSize'].toString();
      }
      if (data['cinnamonLandSize'] != null) {
        _cinnamonLandSizeController.text = data['cinnamonLandSize'].toString();
      }
      
      _landSizeController.clear();
    }

    if (_selectedProvince != null && !_geoData.containsKey(_selectedProvince)) {
      _selectedProvince = null;
    }
    if (_selectedDistrict != null && !(_geoData[_selectedProvince] ?? []).contains(_selectedDistrict)) {
      _selectedDistrict = null;
    }
  }

  @override
  void dispose() {
    _landNameController.dispose();
    _addressController.dispose();
    _landSizeController.dispose();
    _teaLandSizeController.dispose();
    _cinnamonLandSizeController.dispose();
    _agDivisionController.dispose();
    _gnDivisionController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _selectedLandPhotos.clear();
    });
    
    await _loadInitialData();
    
    if (mounted) {
      setState(() {
        _statusMessage = "Data refreshed successfully!";
      });
    }
  }

  // Pick Land Photos Method
  Future<void> _pickLandPhotos() async {
    try {
      if (_selectedLandPhotos.length >= _maxPhotos) {
        _showStatusMessage('Maximum $_maxPhotos photos allowed');
        return;
      }

      final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles != null) {
        int availableSlots = _maxPhotos - _selectedLandPhotos.length;
        int filesToAdd = pickedFiles.length > availableSlots ? availableSlots : pickedFiles.length;
        
        for (int i = 0; i < filesToAdd; i++) {
          final file = File(pickedFiles[i].path);
          if (await file.exists()) {
            final stat = await file.stat();
            final fileSizeMB = stat.size / (1024 * 1024);
            
            if (fileSizeMB > 10) {
              _showStatusMessage('${pickedFiles[i].name} is too large (${fileSizeMB.toStringAsFixed(1)} MB). Max 10MB per photo.');
              continue;
            }
            
            _selectedLandPhotos.add(pickedFiles[i]);
          }
        }
        
        setState(() {});
        _showStatusMessage('Added ${filesToAdd} photo(s). Total: ${_selectedLandPhotos.length}/$_maxPhotos');
      }
    } catch (e) {
      _showStatusMessage('Error selecting photos: ${e.toString()}');
    }
  }

  // Remove selected photo
  void _removeSelectedPhoto(int index) {
    setState(() {
      _selectedLandPhotos.removeAt(index);
    });
    _showStatusMessage('Photo removed');
  }

  // Remove uploaded photo
  void _removeUploadedPhoto(int index) async {
    try {
      setState(() {
        _uploadingPhotos = true;
      });
      
      final urlToRemove = _uploadedLandPhotoUrls[index];
      
      // Remove from Firestore
      await _firestore.collection('lands').doc(widget.landOwnerUID).update({
        'landPhotos': FieldValue.arrayRemove([urlToRemove]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _uploadedLandPhotoUrls.removeAt(index);
      });
      
      _showStatusMessage('Photo removed successfully');
    } catch (e) {
      _showStatusMessage('Error removing photo: ${e.toString()}');
    } finally {
      setState(() {
        _uploadingPhotos = false;
      });
    }
  }

  // Upload Land Photos to Cloudinary
  Future<List<String>> _uploadLandPhotosToCloudinary() async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < _selectedLandPhotos.length; i++) {
      final photo = _selectedLandPhotos[i];
      try {
        debugPrint('Uploading land photo ${i + 1}/${_selectedLandPhotos.length}: ${photo.name}');
        
        final bytes = await photo.readAsBytes();
        final fileSizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
        
        _showStatusMessage('Uploading photo ${i + 1} (${photo.name}) - $fileSizeMB MB...');

        final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
        
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'land_${widget.landOwnerUID}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ));

        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 45),
        );

        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final imageUrl = responseData['secure_url'];
          uploadedUrls.add(imageUrl);
          debugPrint('✅ Photo ${i + 1} uploaded successfully!');
        } else {
          debugPrint('❌ Photo upload failed: ${response.statusCode}');
          _showStatusMessage('Failed to upload photo ${i + 1}. Please try again.');
        }
      } catch (e) {
        debugPrint('❌ Error uploading photo ${i + 1}: $e');
        _showStatusMessage('Error uploading photo ${i + 1}. Please try again.');
      }
    }
    
    return uploadedUrls;
  }

  // Land Photos Gallery Widget - Responsive
  Widget _buildLandPhotosGallery() {
    final isSmallScreen = context.isSmallScreen;
    final crossAxisCount = context.photoGridColumns;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Land Photos (Max 5)'),
        const SizedBox(height: 8),
        
        // Uploaded Photos Grid
        if (_uploadedLandPhotoUrls.isNotEmpty) ...[
          const Text(
            'Currently Uploaded Photos:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isSmallScreen ? 6 : 8,
              mainAxisSpacing: isSmallScreen ? 6 : 8,
              childAspectRatio: 1,
            ),
            itemCount: _uploadedLandPhotoUrls.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                      child: Image.network(
                        _uploadedLandPhotoUrls[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppColors.primaryBlue,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.broken_image, 
                              color: Colors.grey,
                              size: isSmallScreen ? 30 : 40,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeUploadedPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: isSmallScreen ? 14 : 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 9 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        
        // Selected Photos Grid
        if (_selectedLandPhotos.isNotEmpty) ...[
          const Text(
            'New Photos to Upload:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isSmallScreen ? 6 : 8,
              mainAxisSpacing: isSmallScreen ? 6 : 8,
              childAspectRatio: 1,
            ),
            itemCount: _selectedLandPhotos.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                      border: Border.all(color: AppColors.secondaryColor.withOpacity(0.5)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                      child: Image.file(
                        File(_selectedLandPhotos[index].path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeSelectedPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: isSmallScreen ? 14 : 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 9 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        
        // Add Photos Button - Responsive
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            border: Border.all(
              color: _selectedLandPhotos.length >= _maxPhotos 
                ? Colors.grey 
                : AppColors.primaryBlue.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.photo_camera,
                size: isSmallScreen ? 32 : 40,
                color: _selectedLandPhotos.length >= _maxPhotos 
                  ? Colors.grey 
                  : AppColors.primaryBlue,
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              Text(
                _selectedLandPhotos.length >= _maxPhotos
                  ? 'Maximum $_maxPhotos photos reached'
                  : 'Add Land Photos (${_selectedLandPhotos.length}/$_maxPhotos)',
                style: TextStyle(
                  color: _selectedLandPhotos.length >= _maxPhotos 
                    ? Colors.grey 
                    : AppColors.darkText,
                  fontWeight: FontWeight.w500,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 2 : 4),
              Text(
                'Tap to select photos of your land',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isSmallScreen ? 11 : 12,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
              SizedBox(
                width: isSmallScreen ? double.infinity : null,
                child: ElevatedButton(
                  onPressed: _selectedLandPhotos.length >= _maxPhotos ? null : _pickLandPhotos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedLandPhotos.length >= _maxPhotos 
                      ? Colors.grey 
                      : AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : 24,
                      vertical: isSmallScreen ? 10 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
                    ),
                  ),
                  child: Text(
                    'Select Photos',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 12 : 16),
      ],
    );
  }

  Future<void> _updateLandData() async {
    if (!_formKey.currentState!.validate()) {
      _showStatusMessage("Please correct the errors in the form.");
      return;
    }

    if (_selectedProvince == null || _selectedDistrict == null || _selectedCropType == null) {
      _showStatusMessage("Please ensure all required fields are filled.");
      return;
    }
    
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      // Upload new land photos if any
      List<String> newPhotoUrls = [];
      if (_selectedLandPhotos.isNotEmpty) {
        setState(() {
          _uploadingPhotos = true;
        });
        
        newPhotoUrls = await _uploadLandPhotosToCloudinary();
        
        setState(() {
          _uploadingPhotos = false;
        });
      }

      // Prepare update data
      final landDataToUpdate = {
        'landName': _landNameController.text.trim(),
        'address': _addressController.text.trim(),
        'village': _villageController.text.trim(),
        'cropType': _selectedCropType,
        'country': 'Sri Lanka',
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'agDivision': _agDivisionController.text.trim(),
        'gnDivision': _gnDivisionController.text.trim(),
        'factoryIds': _selectedFactoryIds,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Handle land size based on crop type
      if (_selectedCropType == 'Tea') {
        final teaSize = double.tryParse(_landSizeController.text.trim()) ?? 0.0;
        if (teaSize <= 0) {
          throw Exception('Tea land size must be greater than 0');
        }
        landDataToUpdate['landSize'] = teaSize.toString();
        landDataToUpdate['landSizeUnit'] = 'Acre';
        landDataToUpdate['teaLandSize'] = teaSize.toString();
        
      } else if (_selectedCropType == 'Cinnamon') {
        final cinnamonSize = double.tryParse(_landSizeController.text.trim()) ?? 0.0;
        if (cinnamonSize <= 0) {
          throw Exception('Cinnamon land size must be greater than 0');
        }
        landDataToUpdate['landSize'] = cinnamonSize.toString();
        landDataToUpdate['landSizeUnit'] = 'Acre';
        landDataToUpdate['cinnamonLandSize'] = cinnamonSize.toString();
        
      } else if (_selectedCropType == 'Both') {
        final teaSize = double.tryParse(_teaLandSizeController.text.trim()) ?? 0.0;
        final cinnamonSize = double.tryParse(_cinnamonLandSizeController.text.trim()) ?? 0.0;
        
        if (teaSize <= 0 && cinnamonSize <= 0) {
          throw Exception('At least one land size must be greater than 0');
        }
        
        final totalLandSize = teaSize + cinnamonSize;
        
        // Create detailed land size description
        String landSizeDetails = '';
        if (teaSize > 0 && cinnamonSize > 0) {
          landSizeDetails = 'Tea: ${teaSize}Ac, Cinnamon: ${cinnamonSize}Ac (Total: ${totalLandSize}Ac)';
        } else if (teaSize > 0) {
          landSizeDetails = 'Tea: ${teaSize}Ac';
        } else {
          landSizeDetails = 'Cinnamon: ${cinnamonSize}Ac';
        }
        
        // Store both sizes separately AND total in landSize
        if (teaSize > 0) {
          landDataToUpdate['teaLandSize'] = teaSize.toString();
        }
        if (cinnamonSize > 0) {
          landDataToUpdate['cinnamonLandSize'] = cinnamonSize.toString();
        }
        landDataToUpdate['landSize'] = totalLandSize.toString();
        landDataToUpdate['landSizeUnit'] = 'Acre';
        landDataToUpdate['landSizeDetails'] = landSizeDetails;
      }

      // Add new photos to existing ones
      if (newPhotoUrls.isNotEmpty) {
        landDataToUpdate['landPhotos'] = FieldValue.arrayUnion(newPhotoUrls);
      }

      // Update Firestore
      await _firestore.collection('lands').doc(widget.landOwnerUID).set(
        landDataToUpdate,
        SetOptions(merge: true),
      );

      // Update local state
      if (newPhotoUrls.isNotEmpty) {
        setState(() {
          _uploadedLandPhotoUrls.addAll(newPhotoUrls);
          _selectedLandPhotos.clear();
        });
      }

      // Show success message with land size details
      String successMessage = "Land details updated successfully!";
      if (_selectedCropType == 'Both') {
        final teaSize = double.tryParse(_teaLandSizeController.text.trim()) ?? 0.0;
        final cinnamonSize = double.tryParse(_cinnamonLandSizeController.text.trim()) ?? 0.0;
        final totalLandSize = teaSize + cinnamonSize;
        
        if (teaSize > 0 && cinnamonSize > 0) {
          successMessage = "Land details updated successfully! Tea: ${teaSize}Ac, Cinnamon: ${cinnamonSize}Ac (Total: ${totalLandSize}Ac)";
        } else if (teaSize > 0) {
          successMessage = "Land details updated successfully! Tea: ${teaSize}Ac";
        } else {
          successMessage = "Land details updated successfully! Cinnamon: ${cinnamonSize}Ac";
        }
      } else if (_selectedCropType == 'Tea') {
        final teaSize = double.tryParse(_landSizeController.text.trim()) ?? 0.0;
        successMessage = "Land details updated successfully! Tea: ${teaSize}Ac";
      } else if (_selectedCropType == 'Cinnamon') {
        final cinnamonSize = double.tryParse(_landSizeController.text.trim()) ?? 0.0;
        successMessage = "Land details updated successfully! Cinnamon: ${cinnamonSize}Ac";
      }
      
      _showStatusMessage(successMessage);
      
      // Call callbacks
      widget.onProfileUpdated?.call();
      widget.onDataUpdated?.call();

      // Refresh data automatically
      await _refreshDataAutomatically();

    } catch (e) {
      _showStatusMessage("Error updating land details: $e");
      debugPrint('Update Error: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _refreshDataAutomatically() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadInitialData();
    
    if (mounted) {
      setState(() {
        _statusMessage = "Data refreshed successfully!";
      });
    }
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: message.toLowerCase().contains('success') 
            ? AppColors.secondaryColor 
            : Colors.red,
      ),
    );
    
    setState(() {
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = context.isSmallScreen;
    final isMediumScreen = context.isMediumScreen;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Loading land details...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Refresh Button - Responsive
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : 16,
            vertical: isSmallScreen ? 6 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: Icon(
                  Icons.refresh,
                  size: isSmallScreen ? 14 : 16,
                ),
                label: Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 8 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Form Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 20,
              vertical: isSmallScreen ? 12 : 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMediumScreen ? 700 : 900,
              ),
              child: Center(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Message
                      if (_statusMessage != null)
                        InfoCard(
                          message: _statusMessage!,
                          color: _statusMessage!.toLowerCase().contains('success') 
                              ? AppColors.secondaryColor 
                              : Colors.red,
                        ),

                      SizedBox(height: isSmallScreen ? 12 : 16),
                      
                      // Land Photos Section
                      _buildLandPhotosGallery(),
                      
                      // Land Information Form
                      _buildInputLabel('Land Name'),
                      _buildTextField(_landNameController, 'Green Valley Plantation'),

                      // Crop Type Dropdown
                      _buildInputLabel('Crop Type'),
                      _buildCropTypeDropdown(),
                      
                      // Dynamic Land Size Field based on Crop Type
                      if (_selectedCropType == 'Tea')
                        _buildLandSizeField(
                          label: 'Tea Land Size',
                          hint: 'Enter tea land size in Acre (e.g., 5)',
                          controller: _landSizeController,
                          unit: 'Ac',
                        )
                      else if (_selectedCropType == 'Cinnamon')
                        _buildLandSizeField(
                          label: 'Cinnamon Land Size',
                          hint: 'Enter cinnamon land size in Acre (e.g., 3)',
                          controller: _landSizeController,
                          unit: 'Ac',
                        )
                      else if (_selectedCropType == 'Both')
                        _buildBothCropsLandSizeFields(),
                                     
                      _buildInputLabel('Village'),
                      _buildTextField(_villageController, 'e.g., Peradeniya'),

                      _buildInputLabel('Address Line'),
                      _buildTextField(_addressController, 'e.g., Kandy Road'),

                      // Associated Factories Section
                      _buildFactorySelection(),
                      
                      _buildInputLabel('Country (Fixed)'),
                      const FixedInfoBox(value: 'Sri Lanka'),
                      
                      _buildInputLabel('Province'),
                      _buildProvinceDropdown(),
                      
                      if (_selectedProvince != null) ...[
                        _buildInputLabel('District'),
                        _buildDistrictDropdown(),
                      ],
                      
                      _buildInputLabel('A/G Division'),
                      _buildTextField(
                        _agDivisionController, 
                        'Enter A/G Division (e.g., Kandy Divisional Secretariat)',
                        TextInputType.text,
                        false
                      ),
                      
                      _buildInputLabel('G/N Division'),
                      _buildTextField(
                        _gnDivisionController, 
                        'Enter G/N Division (e.g., Kandy Town)',
                        TextInputType.text,
                        false
                      ),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),

                      // Update Button - Responsive
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 0 : 20,
                        ),
                        child: GradientButton(
                          text: _isSaving ? 'Updating...' : 'Update Land Details',
                          onPressed: (_isSaving || _uploadingPhotos) ? null : _updateLandData,
                          isEnabled: !_isSaving && !_uploadingPhotos,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                      
                      SizedBox(height: isSmallScreen ? 30 : 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Land Size Field for Single Crop
  Widget _buildLandSizeField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String unit,
  }) {
    final isSmallScreen = context.isSmallScreen;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildInputLabel(label),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 6 : 8,
                vertical: isSmallScreen ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 4 : 6),
              ),
              child: Text(
                'in $unit',
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        
        // Text field with unit indicator
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 14.0 : 16.0,
                      horizontal: isSmallScreen ? 16.0 : 20.0,
                    ),
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Land size is required';
                    }
                    
                    final numericValue = double.tryParse(value);
                    if (numericValue == null) {
                      return 'Please enter a valid number';
                    }
                    
                    if (numericValue <= 0) {
                      return 'Land size must be greater than 0';
                    }
                    
                    return null;
                  },
                ),
              ),
              
              // Unit display on the right
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                ),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Land Size Fields for Both Crops
  Widget _buildBothCropsLandSizeFields() {
    final isSmallScreen = context.isSmallScreen;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Land Size (Both Crops)'),
        
        // Information box
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
          margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
            border: Border.all(color: AppColors.secondaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: isSmallScreen ? 16 : 18,
                color: AppColors.secondaryColor,
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Expanded(
                child: Text(
                  'Please enter land sizes for both crops separately (in Acre)',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    color: AppColors.darkText.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Tea Land Size
        Padding(
          padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
          child: _buildCropSpecificLandSizeField(
            cropName: 'Tea',
            controller: _teaLandSizeController,
          ),
        ),
        
        // Cinnamon Land Size
        Padding(
          padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 8),
          child: _buildCropSpecificLandSizeField(
            cropName: 'Cinnamon',
            controller: _cinnamonLandSizeController,
          ),
        ),
        
        // Validation for at least one field filled
        Builder(
          builder: (context) {
            final teaSize = _teaLandSizeController.text.trim();
            final cinnamonSize = _cinnamonLandSizeController.text.trim();
            
            if (teaSize.isEmpty && cinnamonSize.isEmpty) {
              return Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'At least one land size must be provided',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.red,
                  ),
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ],
    );
  }

  // Helper widget for crop-specific land size field
  Widget _buildCropSpecificLandSizeField({
    required String cropName,
    required TextEditingController controller,
  }) {
    final isSmallScreen = context.isSmallScreen;
    final color = cropName == 'Tea' ? Colors.green : Colors.orange;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$cropName Land Size',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 6 : 8,
                vertical: isSmallScreen ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 4 : 6),
              ),
              child: Text(
                'in Acre',
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter $cropName land size (e.g., 2.5)',
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 14.0 : 16.0,
                      horizontal: isSmallScreen ? 16.0 : 20.0,
                    ),
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                    ),
                  ),
                  validator: (value) {
                    // Only validate if field is not empty
                    if (value != null && value.isNotEmpty) {
                      final numericValue = double.tryParse(value);
                      if (numericValue == null) {
                        return 'Please enter a valid number';
                      }
                      if (numericValue <= 0) {
                        return 'Land size must be greater than 0';
                      }
                    }
                    return null;
                  },
                ),
              ),
              
              // Unit display
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                ),
                child: Text(
                  'Ac',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Crop Type Dropdown
  Widget _buildCropTypeDropdown() {
    return _buildDropdown<String>(
      value: _selectedCropType,
      hint: 'Select Crop Type (Tea, Cinnamon, or Both)',
      items: ['Tea', 'Cinnamon', 'Both'],
      onChanged: (newValue) {
        setState(() {
          _selectedCropType = newValue;
          // Clear appropriate fields when crop type changes
          if (newValue != 'Both') {
            _teaLandSizeController.clear();
            _cinnamonLandSizeController.clear();
          } else {
            _landSizeController.clear();
          }
        });
      },
    );
  }

  // Associated Factories Widget with Responsive UI
  Widget _buildFactorySelection() {
    final isSmallScreen = context.isSmallScreen;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Associated Factories'),
        SizedBox(height: isSmallScreen ? 6 : 8),
        
        // Info box for selection guidance
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
          margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: isSmallScreen ? 16 : 18,
                color: AppColors.primaryBlue,
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Expanded(
                child: Text(
                  'Select factories you supply your crops to',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    color: AppColors.darkText.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isSmallScreen ? 10 : 12),
                    topRight: Radius.circular(isSmallScreen ? 10 : 12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.factory,
                          size: isSmallScreen ? 18 : 20,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Text(
                          'Available Factories',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedFactoryIds.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 8,
                          vertical: isSmallScreen ? 2 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_selectedFactoryIds.length} selected',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Factory List
              if (_availableFactories.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 8 : 12,
                  ),
                  child: Column(
                    children: _availableFactories.map((factory) {
                      final isSelected = _selectedFactoryIds.contains(factory['id']);
                      return Padding(
                        padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
                        child: FactorySelectionCard(
                          factoryName: factory['factoryName'] ?? 'Unknown Factory',
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedFactoryIds.remove(factory['id']);
                              } else {
                                _selectedFactoryIds.add(factory['id']);
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Selected factories summary
                if (_selectedFactoryIds.isNotEmpty) ...[
                  Divider(
                    height: 1,
                    color: AppColors.primaryBlue.withOpacity(0.1),
                  ),
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Factories:',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText.withOpacity(0.8),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Wrap(
                          spacing: isSmallScreen ? 6 : 8,
                          runSpacing: isSmallScreen ? 6 : 8,
                          children: _availableFactories
                              .where((factory) => _selectedFactoryIds.contains(factory['id']))
                              .map((factory) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 10 : 12,
                                vertical: isSmallScreen ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    factory['factoryName'],
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 13,
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: isSmallScreen ? 4 : 6),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedFactoryIds.remove(factory['id']);
                                      });
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: isSmallScreen ? 14 : 16,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.factory_outlined,
                        size: isSmallScreen ? 40 : 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Text(
                        'No factories available',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Text(
                        'Factories will appear here once they are registered',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Helper text
        Padding(
          padding: EdgeInsets.only(top: isSmallScreen ? 6 : 8, left: 4),
          child: Text(
            'You can select multiple factories',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: AppColors.darkText.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String text) {
    final isSmallScreen = context.isSmallScreen;
    
    return Padding(
      padding: EdgeInsets.only(
        top: isSmallScreen ? 12.0 : 16.0,
        bottom: isSmallScreen ? 6.0 : 8.0,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.darkText,
          fontWeight: FontWeight.w600,
          fontSize: isSmallScreen ? 15 : 16,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hintText, 
    [TextInputType keyboardType = TextInputType.text,
    bool isRequired = true]
  ) {
    final isSmallScreen = context.isSmallScreen;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppColors.darkText,
          fontSize: isSmallScreen ? 14 : 16,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          contentPadding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 14.0 : 16.0,
            horizontal: isSmallScreen ? 16.0 : 20.0,
          ),
          border: InputBorder.none,
          hintStyle: TextStyle(
            fontSize: isSmallScreen ? 14 : 15,
          ),
        ),
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required.';
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildProvinceDropdown() {
    return _buildDropdown<String>(
      value: _selectedProvince,
      hint: 'Select Province',
      items: _geoData.keys.toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedProvince = newValue;
          _selectedDistrict = null;
        });
      },
    );
  }

  Widget _buildDistrictDropdown() {
    return _buildDropdown<String>(
      value: _selectedDistrict,
      hint: 'Select District',
      items: _geoData[_selectedProvince] ?? [],
      onChanged: (newValue) {
        setState(() {
          _selectedDistrict = newValue;
        });
      },
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    final isSmallScreen = context.isSmallScreen;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12.0 : 16.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
              color: AppColors.darkText.withOpacity(0.5),
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppColors.primaryBlue,
            size: isSmallScreen ? 24 : 28,
          ),
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: isSmallScreen ? 14 : 16,
          ),
          items: items.map<DropdownMenuItem<T>>((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// Factory Selection Card Widget
class FactorySelectionCard extends StatelessWidget {
  final String factoryName;
  final bool isSelected;
  final VoidCallback onTap;

  const FactorySelectionCard({
    required this.factoryName,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = context.isSmallScreen;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppColors.primaryBlue.withOpacity(0.1)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
          border: Border.all(
            color: isSelected 
              ? AppColors.primaryBlue.withOpacity(0.3)
              : AppColors.primaryBlue.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: isSmallScreen ? 18 : 20,
              height: isSmallScreen ? 18 : 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(isSmallScreen ? 3 : 4),
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: isSmallScreen ? 12 : 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            
            SizedBox(width: isSmallScreen ? 10 : 12),
            
            // Factory Icon
            Icon(
              Icons.factory,
              size: isSmallScreen ? 20 : 24,
              color: isSelected ? AppColors.primaryBlue : Colors.grey[600],
            ),
            
            SizedBox(width: isSmallScreen ? 10 : 12),
            
            // Factory Name
            Expanded(
              child: Text(
                factoryName,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.darkText : AppColors.darkText.withOpacity(0.7),
                ),
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: isSmallScreen ? 18 : 20,
                color: AppColors.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }
}

// Helper functions and widgets
Map<String, List<String>> _getGeoData() {
  return {
    'Western Province': ['Colombo District', 'Gampaha District', 'Kalutara District'],
    'Central Province': ['Kandy District', 'Matale District', 'Nuwara Eliya District'],
    'Southern Province': ['Galle District', 'Matara District', 'Hambantota District'],
    'Eastern Province': ['Trincomalee District', 'Batticaloa District', 'Ampara District'],
    'Northern Province': ['Jaffna District', 'Vavuniya District', 'Kilinochchi District', 'Mannar District', 'Mullaitivu District'],
    'North Western Province': ['Kurunegala District', 'Puttalam District'],
    'North Central Province': ['Anuradhapura District', 'Polonnaruwa District'],
    'Uva Province': ['Badulla District', 'Monaragala District'],
    'Sabaragamuwa Province': ['Ratnapura District', 'Kegalle District'],
  };
}

// Responsive Gradient Button
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final bool isSmallScreen;

  const GradientButton({
    required this.text,
    required this.onPressed,
    this.isEnabled = true,
    this.isSmallScreen = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 14.0 : 16.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            gradient: isEnabled
              ? const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade500, Colors.grey.shade400],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
            boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.5),
                    blurRadius: isSmallScreen ? 8 : 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class FixedInfoBox extends StatelessWidget {
  final String value;
  const FixedInfoBox({required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = context.isSmallScreen;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 14.0 : 16.0,
        horizontal: isSmallScreen ? 16.0 : 20.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.darkText.withOpacity(0.7),
          fontSize: isSmallScreen ? 14 : 16,
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String message;
  final Color color;
  const InfoCard({required this.message, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = context.isSmallScreen;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: isSmallScreen ? 13 : 14,
        ),
      ),
    );
  }
}