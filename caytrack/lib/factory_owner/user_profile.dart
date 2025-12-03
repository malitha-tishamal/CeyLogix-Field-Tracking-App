import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'factory_owner_drawer.dart';

// --- 1. COLOR PALETTE ---
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
  static const Color errorRed = Color(0xFFD32F2F);
  
  // Header gradient colors matching Developer Info Page
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

// --- 2. MAIN SCREEN (User Details - StatefulWidget for Key) ---
class UserDetails extends StatefulWidget {
  const UserDetails({super.key});

  @override
  State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // State variables for header data
  String _loggedInUserName = 'Loading User...';
  String _factoryName = 'Loading Factory...';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  // --- HEADER DATA FETCHING FUNCTION (Matching Developer Info Page) ---
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

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    
    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Error: User not logged in.",
            style: TextStyle(fontSize: screenWidth * 0.04),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          FirebaseAuth.instance.signOut();
          Navigator.pop(context);
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🌟 FIXED HEADER - Matching Developer Info Page Style with Firebase Data
            _buildDashboardHeader(context, screenWidth, screenHeight),
            
            // 🌟 SCROLLABLE CONTENT ONLY with Footer
            Expanded(
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      child: UserProfileContentOnly(
                        userUID: currentUser!.uid,
                        onProfileUpdated: _fetchHeaderData,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                      ),
                    ),
                  ),
                  
                  // Footer (Fixed at bottom of content area)
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    child: Text(
                      'Developed by Malitha Tishamal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.7),
                        fontSize: screenWidth * 0.03,
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

  // 🌟 FIXED HEADER - Matching Developer Info Page Style with Firebase Data
  Widget _buildDashboardHeader(BuildContext context, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isSmallScreen ? 8 : 10),
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        bottom: isSmallScreen ? 16 : 20,
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
            ],
          ),
          
          SizedBox(height: screenHeight * 0.01),
          
          Row(
            children: [
              // Profile Picture with Firebase image
              Container(
                width: isSmallScreen ? 60 : 70,
                height: isSmallScreen ? 60 : 70,
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
                    width: isSmallScreen ? 2.5 : 3.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.4),
                      blurRadius: 10.0,
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
                        size: isSmallScreen ? 32 : 40,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              SizedBox(width: screenWidth * 0.04),
              
              // User Info Display from Firebase
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.004),
                    Text(
                      'Factory Name: $_factoryName \n($_userRole)',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: AppColors.headerTextDark.withOpacity(0.7),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: screenHeight * 0.02),
          
          // Page Title
          Text(
            'Manage User Details',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
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
  final VoidCallback? onProfileUpdated;
  final double screenWidth;
  final double screenHeight;
  
  const UserProfileContentOnly({
    required this.userUID, 
    this.onProfileUpdated,
    required this.screenWidth,
    required this.screenHeight,
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
        
        setState(() {}); // Rebuild to display initial data
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
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              // Show current selection info if any
              if (_pickedImageFile != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.05),
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
                          fontSize: isSmallScreen ? 13 : 14,
                        ),
                      ),
                      SizedBox(height: widget.screenHeight * 0.004),
                      Text(
                        _pickedImageFile!.name,
                        style: TextStyle(
                          color: AppColors.darkText.withOpacity(0.7),
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_pickedImageFileSize != null)
                        Text(
                          '${(_pickedImageFileSize! / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            color: AppColors.darkText.withOpacity(0.5),
                            fontSize: isSmallScreen ? 11 : 12,
                          ),
                        ),
                    ],
                  ),
                ),
              
              ListTile(
                leading: Icon(
                  Icons.photo_camera,
                  color: AppColors.primaryBlue,
                  size: isSmallScreen ? 20 : 24,
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                subtitle: Text(
                  'Capture a new photo with camera',
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: AppColors.primaryBlue,
                  size: isSmallScreen ? 20 : 24,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                subtitle: Text(
                  'Select from your device gallery',
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImageUrl != null || _pickedImageFile != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  title: Text(
                    'Remove Current Photo',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                  subtitle: Text(
                    'Remove profile picture',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeProfileImage();
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.close,
                  color: AppColors.primaryBlue,
                  size: isSmallScreen ? 20 : 24,
                ),
                title: Text(
                  'Cancel',
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
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
          return;
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
    final profileImageSize = isSmallScreen ? widget.screenWidth * 0.25 : 120.0;
    final cameraButtonSize = isSmallScreen ? widget.screenWidth * 0.1 : 40.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Profile Picture', isSmallScreen),
        SizedBox(height: widget.screenHeight * 0.008),
        Center(
          child: Stack(
            children: [
              Container(
                width: profileImageSize,
                height: profileImageSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    width: isSmallScreen ? 2.5 : 3.0,
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
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: profileImageSize / 2 - 4,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _getProfileImage(),
                        child: _getProfileImage() == null
                            ? Icon(
                                Icons.person,
                                size: profileImageSize * 0.4,
                                color: AppColors.primaryBlue,
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
                      width: isSmallScreen ? 2.0 : 3.0,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      size: cameraButtonSize * 0.4,
                      color: Colors.white,
                    ),
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
            margin: EdgeInsets.only(top: widget.screenHeight * 0.012),
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.image,
                      size: isSmallScreen ? 14 : 16,
                      color: AppColors.primaryBlue,
                    ),
                    SizedBox(width: widget.screenWidth * 0.02),
                    Text(
                      'Selected Image:',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.screenHeight * 0.004),
                Text(
                  _pickedImageFile!.name,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    color: AppColors.darkText.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: widget.screenHeight * 0.004),
                if (_pickedImageFileSize != null)
                  Text(
                    'Size: ${(_pickedImageFileSize! / 1024).toStringAsFixed(1)} KB',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          )
        else if (_profileImageUrl != null)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: widget.screenHeight * 0.012),
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_done,
                  size: isSmallScreen ? 14 : 16,
                  color: AppColors.secondaryColor,
                ),
                SizedBox(width: widget.screenWidth * 0.02),
                Expanded(
                  child: Text(
                    'Current image stored in Cloudinary',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: AppColors.darkText.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        SizedBox(height: widget.screenHeight * 0.016),
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
    
    // Show loading while fetching initial user data
    if (_ownerNameController.text.isEmpty && !_isSaving && currentUser?.email != null && _fetchedEmail == 'N/A') {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: widget.screenHeight * 0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryBlue),
              SizedBox(height: widget.screenHeight * 0.02),
              Text(
                'Loading user data...',
                style: TextStyle(
                  fontSize: widget.screenWidth * 0.04,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_statusMessage != null)
              InfoCard(
                message: _statusMessage!,
                color: _statusMessage!.toLowerCase().contains('success') ? AppColors.secondaryColor : Colors.red,
                screenWidth: widget.screenWidth,
              ),

            SizedBox(height: widget.screenHeight * 0.016),
            
            // Profile Picture Section
            _buildProfileImageSection(),

            // -----------------------------------------------------------------
            // --- EDITABLE USER FIELDS (Registration Data) ---
            // -----------------------------------------------------------------
            
            _buildInputLabel('Full Name', isSmallScreen),
            _buildTextField(
              _ownerNameController, 
              'Enter your full name', 
              (value) {
                if (value == null || value.isEmpty) return 'Name is required.';
                return null;
              },
              isSmallScreen,
            ),

            _buildInputLabel('Contact Number (Mobile)', isSmallScreen),
            _buildTextField(
              _contactNumberController, 
              'e.g., 0712345678', 
              (value) {
                if (value == null || value.isEmpty) return 'Mobile number is required.';
                if (value.length != 10) return 'Mobile number must be 10 digits.';
                return null;
              }, 
              isSmallScreen,
              keyboardType: TextInputType.phone,
            ),
            
            _buildInputLabel('NIC Number', isSmallScreen),
            _buildTextField(
              _nicController, 
              'Enter your NIC', 
              (value) {
                if (value == null || value.isEmpty) return 'NIC is required.';
                if (value.length < 10) return 'Enter a valid NIC (10 or 12 digits).';
                return null;
              }, 
              isSmallScreen,
              keyboardType: TextInputType.text,
            ),
            
            // -----------------------------------------------------------------
            // --- FIXED (READ-ONLY) FIELDS ---
            // -----------------------------------------------------------------
            
            _buildInputLabel('Email Address (Fixed)', isSmallScreen),
            FixedInfoBox(value: _fetchedEmail, screenWidth: widget.screenWidth),

            _buildInputLabel('User Role (Fixed)', isSmallScreen),
            FixedInfoBox(value: _fetchedRole, screenWidth: widget.screenWidth),

            SizedBox(height: widget.screenHeight * 0.03),

            // Update Button
            GradientButton(
              text: _isSaving ? 'Updating...' : 'Update Profile Details',
              onPressed: (_isSaving || _uploadingImage) ? null : _updateUserData, 
              isEnabled: !_isSaving && !_uploadingImage,
            ),
            
            SizedBox(height: widget.screenHeight * 0.05),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildInputLabel(String text, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(
        top: widget.screenHeight * 0.016,
        bottom: widget.screenHeight * 0.008,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.darkText,
          fontWeight: FontWeight.w600,
          fontSize: isSmallScreen ? 14 : 16,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hintText, 
    String? Function(String?)? validator,
    bool isSmallScreen,
    {TextInputType keyboardType = TextInputType.text} 
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
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
            vertical: widget.screenHeight * 0.016,
            horizontal: widget.screenWidth * 0.04,
          ),
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

  const GradientButton({required this.text, required this.onPressed, this.isEnabled = true, super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 14.0 : 16.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 18 : 20,
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
  final double screenWidth;
  
  const FixedInfoBox({required this.value, required this.screenWidth, super.key});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.04,
        horizontal: screenWidth * 0.05,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.darkText.withOpacity(0.7),
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String message;
  final Color color;
  final double screenWidth;
  
  const InfoCard({required this.message, required this.color, required this.screenWidth, super.key});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      margin: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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