import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'land_owner_drawer.dart';

// --- 1. COLOR PALETTE ---
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color accentPurple = Color.fromRGBO(134, 164, 236, 1);
  static const Color errorRed = Color(0xFFD32F2F);
  
  // Header gradient colors matching DeveloperInfoPage
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
}

// --- 2. MAIN SCREEN (User Details - Handles the Header) ---
class UserDetails extends StatefulWidget {
  const UserDetails({super.key});

  @override
  State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variables for dynamic user info - Same as DeveloperInfoPage
  String _loggedInUserName = 'Loading User...';
  String _landName = 'Loading Land...';
  String _userRole = 'Land Owner';
  String _landID = 'L-ID';
  String? _profileImageUrl;

  // Responsive variables
  late bool _isPortrait;
  late double _screenWidth;
  late double _screenHeight;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScreenDimensions();
  }

  void _updateScreenDimensions() {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
    _isPortrait = mediaQuery.orientation == Orientation.portrait;
  }

  // --- DATA FETCHING FUNCTION (Same as DeveloperInfoPage) ---
  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    
    final String uid = user.uid;
    setState(() {
      _landID = uid.length >= 8 ? uid.substring(0, 8) : uid.padRight(8, '0'); 
    });

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

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    _updateScreenDimensions();
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;
    
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onLogout: () {
          FirebaseAuth.instance.signOut();
          Navigator.of(context).pop();
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: Column(
        children: [
          // 🌟 FIXED HEADER - Responsive
          _buildDashboardHeader(context, isSmallScreen, isMediumScreen),
          
          // 🌟 SCROLLABLE CONTENT ONLY with Footer
          Expanded(
            child: Column(
              children: [
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: UserProfileContentOnly(
                      userUID: currentUser!.uid,
                      screenWidth: _screenWidth,
                      screenHeight: _screenHeight,
                      isPortrait: _isPortrait,
                      onProfileUpdated: _fetchHeaderData,
                    ),
                  ),
                ),
                
                // Footer (Fixed at bottom of content area)
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Text(
                    'Developed by Malitha Tishamal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.darkText.withOpacity(0.7),
                      fontSize: isSmallScreen ? 11.0 : 12.0,
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

  // 🌟 FIXED HEADER - Responsive version
  Widget _buildDashboardHeader(BuildContext context, bool isSmallScreen, bool isMediumScreen) {
    final topPadding = MediaQuery.of(context).padding.top + 10;
    final horizontalPadding = isSmallScreen ? 16.0 : 20.0;
    final profileSize = isSmallScreen ? 60.0 : 70.0;
    final menuIconSize = isSmallScreen ? 24.0 : 28.0;
    final nameFontSize = isSmallScreen ? 16.0 : 20.0;
    final landFontSize = isSmallScreen ? 14.0 : 16.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: isSmallScreen ? 16.0 : 20.0,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF869AEC), AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
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
                icon: Icon(Icons.menu, color: AppColors.headerTextDark, size: menuIconSize),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: menuIconSize + 16,
                  minHeight: menuIconSize + 16,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 8.0 : 10.0),
          
          Row(
            children: [
              // Profile Picture with Firebase image
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
                    width: isSmallScreen ? 2.0 : 3.0
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: isSmallScreen ? 8.0 : 10.0,
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
                        size: isSmallScreen ? 32.0 : 40.0, 
                        color: Colors.white
                      )
                    : null,
              ),
              
              SizedBox(width: isSmallScreen ? 12.0 : 15.0),
              
              // User Info Display from Firebase
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Land Owner Name
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
                    //Land Name Name and Role
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
          
          SizedBox(height: isSmallScreen ? 20.0 : 25.0), 
          
          // Page Title
          Text(
            'Manage User Details',
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
}

// -----------------------------------------------------------------------------
// --- 3. USER PROFILE CONTENT (With Profile Picture Update) ---
// -----------------------------------------------------------------------------

class UserProfileContentOnly extends StatefulWidget {
  final String userUID;
  final double screenWidth;
  final double screenHeight;
  final bool isPortrait;
  final VoidCallback? onProfileUpdated;
  
  const UserProfileContentOnly({
    required this.userUID, 
    required this.screenWidth,
    required this.screenHeight,
    required this.isPortrait,
    this.onProfileUpdated,
    super.key
  });

  @override
  State<UserProfileContentOnly> createState() => _UserProfileContentOnlyState();
}

class _UserProfileContentOnlyState extends State<UserProfileContentOnly> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _imagePicker = ImagePicker();

  // Cloudinary Configuration
  final String _cloudName = "dqeptzlsb";
  final String _uploadPreset = "flutter_ceytrack_upload";

  // Text Controllers for Editable User Fields
  late TextEditingController _ownerNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _nicController;
  
  // Profile Image State
  String? _profileImageUrl;
  XFile? _pickedImageFile;
  bool _uploadingImage = false;
  int? _pickedImageFileSize;
  
  // Stored Fixed/Read-only Fields
  String _fetchedEmail = 'N/A';
  String _fetchedRole = 'N/A';
  
  bool _isSaving = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _ownerNameController = TextEditingController();
    _contactNumberController = TextEditingController();
    _nicController = TextEditingController();
    
    // Fetch initial user data
    _fetchUserData(); 
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _contactNumberController.dispose();
    _nicController.dispose();
    super.dispose();
  }

  // --- Data Fetching Logic (Only for 'users' collection) ---
  Future<void> _fetchUserData() async {
    final userDoc = await _firestore.collection('users').doc(widget.userUID).get();
    
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (mounted) {
        // Populate editable user fields
        _ownerNameController.text = userData?['name'] ?? '';
        _contactNumberController.text = userData?['mobile'] ?? '';
        _nicController.text = userData?['nic'] ?? '';
        
        // Populate profile image
        _profileImageUrl = userData?['profileImageUrl'];
        
        // Populate fixed fields
        _fetchedEmail = userData?['email'] ?? currentUser?.email ?? 'N/A';
        _fetchedRole = userData?['role'] ?? 'Land owner';
        
        setState(() {});
      }
    } else if (mounted) {
      // Fallback for new user or missing doc
      _fetchedEmail = currentUser?.email ?? 'N/A';
      _fetchedRole = 'Land owner';
      setState(() {}); 
    }
  }

  // --- Image Picking Methods ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (pickedFile != null) {
        // Get file size and other details
        final file = File(pickedFile.path);
        final stat = await file.stat();
        
        setState(() {
          _pickedImageFile = pickedFile;
          _pickedImageFileSize = stat.size;
        });
        
        // Show file info
        _showStatusMessage('Image selected: ${pickedFile.name} (${(stat.size / 1024).toStringAsFixed(1)} KB)');
      }
    } catch (e) {
      _showStatusMessage('Failed to pick image: ${e.toString()}');
    }
  }

  void _openImageOptions() {
    final isSmallScreen = widget.screenWidth < 360;
    final isMediumScreen = widget.screenWidth >= 360 && widget.screenWidth < 400;
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show current selection info if any
                if (_pickedImageFile != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Selection:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                            fontSize: isSmallScreen ? 13.0 : 14.0,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 3.0 : 4.0),
                        Text(
                          _pickedImageFile!.name,
                          style: TextStyle(
                            color: AppColors.darkText.withOpacity(0.7),
                            fontSize: isSmallScreen ? 12.0 : 13.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_pickedImageFileSize != null)
                          Text(
                            '${(_pickedImageFileSize! / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              color: AppColors.darkText.withOpacity(0.5),
                              fontSize: isSmallScreen ? 11.0 : 12.0,
                            ),
                          ),
                      ],
                    ),
                  ),
                
                ListTile(
                  leading: Icon(Icons.photo_camera, color: AppColors.primaryBlue, size: isSmallScreen ? 22.0 : 24.0),
                  title: Text('Take Photo', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0)),
                  subtitle: Text('Capture a new photo with camera', style: TextStyle(fontSize: isSmallScreen ? 12.0 : 13.0)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: AppColors.primaryBlue, size: isSmallScreen ? 22.0 : 24.0),
                  title: Text('Choose from Gallery', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0)),
                  subtitle: Text('Select from your device gallery', style: TextStyle(fontSize: isSmallScreen ? 12.0 : 13.0)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_profileImageUrl != null || _pickedImageFile != null)
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red, size: isSmallScreen ? 22.0 : 24.0),
                    title: Text('Remove Current Photo', style: TextStyle(color: Colors.red, fontSize: isSmallScreen ? 14.0 : 16.0)),
                    subtitle: Text('Remove profile picture', style: TextStyle(color: Colors.red, fontSize: isSmallScreen ? 12.0 : 13.0)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _removeProfileImage();
                    },
                  ),
                SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeProfileImage() async {
    setState(() {
      _pickedImageFile = null;
      _profileImageUrl = null;
      _pickedImageFileSize = null;
    });
    
    // Update Firestore to remove profile image
    try {
      await _firestore.collection('users').doc(widget.userUID).update({
        'profileImageUrl': FieldValue.delete(),
      });
      _showStatusMessage('Profile photo removed');
    } catch (e) {
      _showStatusMessage('Failed to remove photo: ${e.toString()}');
    }
  }

  // --- Cloudinary Upload Method ---
  Future<String?> _uploadImageToCloudinary(XFile imageFile) async {
    try {
      debugPrint('Starting Cloudinary upload...');
      
      // Convert XFile to bytes
      final bytes = await imageFile.readAsBytes();
      final fileSizeKB = (bytes.length / 1024).toStringAsFixed(1);
      
      _showStatusMessage('Uploading image (${imageFile.name}) - $fileSizeKB KB...');
      
      // Check file size (max 1MB)
      if (bytes.length > 1000000) {
        _showStatusMessage('Image is too large. Please choose a smaller image (max 1MB).');
        return null;
      }

      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
      
      // Create multipart request
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: imageFile.name,
        ));

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Cloudinary upload timed out');
        },
      );

      // Get response
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);
      
      if (response.statusCode == 200) {
        final imageUrl = responseData['secure_url'];
        debugPrint('Cloudinary upload successful! URL: $imageUrl');
        _showStatusMessage('Image uploaded successfully: ${imageFile.name}');
        return imageUrl;
      } else {
        String errorMessage = 'Unknown error';
        if (responseData['error'] != null) {
          errorMessage = responseData['error']['message'] ?? 'Unknown Cloudinary error';
        }
        _showStatusMessage('Upload failed for ${imageFile.name}: $errorMessage');
        return null;
      }
      
    } on TimeoutException catch (e) {
      debugPrint('Upload timeout: $e');
      _showStatusMessage('Upload timed out for ${imageFile.name}. Please try again.');
      return null;
    } catch (e) {
      debugPrint('Upload error: $e');
      _showStatusMessage('Failed to upload ${imageFile.name}. Please try again.');
      return null;
    }
  }

  // --- Data Update Logic for Editable User Data (Only 'users' collection) ---
  Future<void> _updateUserData() async {
    if (!_formKey.currentState!.validate()) {
      _showStatusMessage("Please correct the errors in the form before saving details.");
      return;
    }
    
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      String? finalProfileImageUrl = _profileImageUrl;

      // Upload new image to Cloudinary if one was picked
      if (_pickedImageFile != null) {
        setState(() {
          _uploadingImage = true;
        });
        
        final cloudinaryUrl = await _uploadImageToCloudinary(_pickedImageFile!);
        if (cloudinaryUrl != null) {
          finalProfileImageUrl = cloudinaryUrl;
        } else {
          setState(() {
            _isSaving = false;
            _uploadingImage = false;
          });
          return; // Stop the save process if image upload fails
        }
        
        setState(() {
          _uploadingImage = false;
        });
      }

      // Prepare update data
      final userDataToUpdate = {
        'name': _ownerNameController.text.trim(),
        'mobile': _contactNumberController.text.trim(),
        'nic': _nicController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add profile image URL if available
      if (finalProfileImageUrl != null && finalProfileImageUrl.isNotEmpty) {
        userDataToUpdate['profileImageUrl'] = finalProfileImageUrl;
      } else if (_pickedImageFile == null && _profileImageUrl == null) {
        // Remove profile image if it was deleted
        userDataToUpdate['profileImageUrl'] = FieldValue.delete();
      }

      // Save to the 'users' collection
      await _firestore.collection('users').doc(widget.userUID).set(userDataToUpdate, SetOptions(merge: true));
      
      // Update local state
      setState(() {
        _profileImageUrl = finalProfileImageUrl;
        _pickedImageFile = null;
        _pickedImageFileSize = null;
      });

      _showStatusMessage("Profile details updated successfully!");

      // Notify parent to refresh header
      widget.onProfileUpdated?.call();

    } catch (e) {
      _showStatusMessage("Error updating profile: $e");
      debugPrint('Update Error: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showStatusMessage(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  // --- Profile Image Widget ---
  Widget _buildProfileImageSection() {
    final isSmallScreen = widget.screenWidth < 360;
    final isMediumScreen = widget.screenWidth >= 360 && widget.screenWidth < 400;
    final profileSize = isSmallScreen ? 100.0 : 120.0;
    final cameraIconSize = isSmallScreen ? 16.0 : 18.0;
    final cameraButtonSize = isSmallScreen ? 32.0 : 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Profile Picture', isSmallScreen, isMediumScreen),
        SizedBox(height: isSmallScreen ? 6.0 : 8.0),
        Center(
          child: Stack(
            children: [
              Container(
                width: profileSize,
                height: profileSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.3), 
                    width: isSmallScreen ? 2.0 : 3.0
                  ),
                ),
                child: _uploadingImage
                    ? Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                            strokeWidth: isSmallScreen ? 2.0 : 3.0,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: profileSize / 2,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _getProfileImage(),
                        child: _getProfileImage() == null
                            ? Icon(
                                Icons.person, 
                                size: profileSize * 0.4, 
                                color: AppColors.primaryBlue
                              )
                            : null,
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: cameraButtonSize,
                  height: cameraButtonSize,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white, 
                      width: isSmallScreen ? 2.0 : 3.0
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, size: cameraIconSize, color: Colors.white),
                    onPressed: _openImageOptions,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Show selected file name
        if (_pickedImageFile != null)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: isSmallScreen ? 8.0 : 12.0),
            padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.image, size: isSmallScreen ? 14.0 : 16.0, color: AppColors.primaryBlue),
                    SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                    Text(
                      'Selected Image:',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13.0 : 14.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 3.0 : 4.0),
                Text(
                  _pickedImageFile!.name,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.0 : 13.0,
                    color: AppColors.darkText.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: isSmallScreen ? 3.0 : 4.0),
                if (_pickedImageFileSize != null)
                  Text(
                    'Size: ${(_pickedImageFileSize! / 1024).toStringAsFixed(1)} KB',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11.0 : 12.0,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          )
        else if (_profileImageUrl != null)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: isSmallScreen ? 8.0 : 12.0),
            padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
              border: Border.all(color: AppColors.secondaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_done, size: isSmallScreen ? 14.0 : 16.0, color: AppColors.secondaryColor),
                SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                Expanded(
                  child: Text(
                    'Current image stored in Cloudinary',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12.0 : 13.0,
                      color: AppColors.darkText.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        
        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
      ],
    );
  }

  ImageProvider? _getProfileImage() {
    // Priority: New picked image > Cloudinary URL
    if (_pickedImageFile != null) {
      return FileImage(File(_pickedImageFile!.path));
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = widget.screenWidth < 360;
    final isMediumScreen = widget.screenWidth >= 360 && widget.screenWidth < 400;
    
    // Show loading while fetching initial user data
    if (_ownerNameController.text.isEmpty && !_isSaving && currentUser?.email != null && _fetchedEmail == 'N/A') {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: widget.screenHeight * 0.2),
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 
                            isMediumScreen ? 16.0 : 
                            20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_statusMessage != null)
              InfoCard(
                message: _statusMessage!,
                color: _statusMessage!.toLowerCase().contains('success') ? AppColors.secondaryColor : Colors.red,
                isSmallScreen: isSmallScreen,
                isMediumScreen: isMediumScreen,
              ),

            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
            
            // Profile Picture Section
            _buildProfileImageSection(),

            // -----------------------------------------------------------------
            // --- EDITABLE USER FIELDS (Registration Data) ---
            // -----------------------------------------------------------------
            
            _buildInputLabel('Full Name', isSmallScreen, isMediumScreen),
            _buildTextField(
              _ownerNameController, 
              'Enter your full name', 
              (value) {
                if (value == null || value.isEmpty) return 'Name is required.';
                return null;
              },
              isSmallScreen,
              isMediumScreen
            ),

            _buildInputLabel('Contact Number (Mobile)', isSmallScreen, isMediumScreen),
            _buildTextField(
              _contactNumberController, 
              'e.g., 0712345678', 
              (value) {
                if (value == null || value.isEmpty) return 'Mobile number is required.';
                if (value.length != 10) return 'Mobile number must be 10 digits.';
                return null;
              },
              isSmallScreen,
              isMediumScreen,
              keyboardType: TextInputType.phone
            ),
            
            _buildInputLabel('NIC Number', isSmallScreen, isMediumScreen),
            _buildTextField(
              _nicController, 
              'Enter your NIC', 
              (value) {
                if (value == null || value.isEmpty) return 'NIC is required.';
                if (value.length < 10) return 'Enter a valid NIC (10 or 12 digits).';
                return null;
              },
              isSmallScreen,
              isMediumScreen,
              keyboardType: TextInputType.text
            ),
            
            // -----------------------------------------------------------------
            // --- FIXED (READ-ONLY) FIELDS ---
            // -----------------------------------------------------------------
            
            _buildInputLabel('Email Address (Fixed)', isSmallScreen, isMediumScreen),
            FixedInfoBox(
              value: _fetchedEmail,
              isSmallScreen: isSmallScreen,
              isMediumScreen: isMediumScreen
            ),

            _buildInputLabel('User Role (Fixed)', isSmallScreen, isMediumScreen),
            FixedInfoBox(
              value: _fetchedRole,
              isSmallScreen: isSmallScreen,
              isMediumScreen: isMediumScreen
            ),

            SizedBox(height: isSmallScreen ? 20.0 : 30.0),

            // Update Button
            GradientButton(
              text: _isSaving ? 'Updating...' : 'Update Profile Details',
              onPressed: (_isSaving || _uploadingImage) ? null : _updateUserData, 
              isEnabled: !_isSaving && !_uploadingImage,
              isSmallScreen: isSmallScreen,
              isMediumScreen: isMediumScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 30.0 : 50.0),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildInputLabel(String text, bool isSmallScreen, bool isMediumScreen) {
    final fontSize = isSmallScreen ? 14.0 : 
                    isMediumScreen ? 15.0 : 
                    16.0;
    final padding = isSmallScreen ? const EdgeInsets.only(top: 12.0, bottom: 6.0) : 
                   const EdgeInsets.only(top: 16.0, bottom: 8.0);

    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.darkText,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hintText, 
    String? Function(String?)? validator,
    bool isSmallScreen,
    bool isMediumScreen,
    {TextInputType keyboardType = TextInputType.text} 
  ) {
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final padding = isSmallScreen ? const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0) : 
                   const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: AppColors.darkText, fontSize: fontSize),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
          contentPadding: padding,
          border: InputBorder.none,
        ),
        validator: validator,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// --- 4. REUSABLE WIDGETS ---
// -----------------------------------------------------------------------------

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final bool isSmallScreen;
  final bool isMediumScreen;

  const GradientButton({
    required this.text,
    required this.onPressed,
    required this.isEnabled,
    required this.isSmallScreen,
    required this.isMediumScreen,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = isSmallScreen ? 16.0 : 
                    isMediumScreen ? 18.0 : 
                    20.0;
    final padding = isSmallScreen ? const EdgeInsets.symmetric(vertical: 14.0) : 
                   const EdgeInsets.symmetric(vertical: 16.0);

    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
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
                    blurRadius: isSmallScreen ? 8.0 : 10.0,
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
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }
}

class FixedInfoBox extends StatelessWidget {
  final String value;
  final bool isSmallScreen;
  final bool isMediumScreen;

  const FixedInfoBox({
    required this.value,
    required this.isSmallScreen,
    required this.isMediumScreen,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final padding = isSmallScreen ? const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0) : 
                   const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.darkText.withOpacity(0.7),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String message;
  final Color color;
  final bool isSmallScreen;
  final bool isMediumScreen;

  const InfoCard({
    required this.message,
    required this.color,
    required this.isSmallScreen,
    required this.isMediumScreen,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = isSmallScreen ? 12.0 : 
                    isMediumScreen ? 13.0 : 
                    14.0;
    final padding = isSmallScreen ? const EdgeInsets.all(10.0) : 
                   const EdgeInsets.all(12.0);

    return Container(
      width: double.infinity,
      padding: padding,
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 6.0 : 8.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color, 
          fontWeight: FontWeight.w500,
          fontSize: fontSize,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}