import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'land_owner_drawer.dart';

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

class LandDetails extends StatefulWidget {
  const LandDetails({super.key});

  @override
  State<LandDetails> createState() => _LandDetailsState();
}

class _LandDetailsState extends State<LandDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _userName = 'Loading';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  void _fetchUserInfo() async {
    final user = currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              _userName = data?['name'] ?? 'Land Owner';
              _userRole = data?['role'] ?? 'Land Owner';
              _profileImageUrl = data?['profileImageUrl'];
            });
          }
        }
      } catch (e) {
        print("Error fetching user info: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
    }

    void handleDrawerNavigate(String routeName) {
      Navigator.pop(context);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onLogout: () {
          FirebaseAuth.instance.signOut();
          Navigator.pop(context);
        },
        onNavigate: handleDrawerNavigate,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildProfileHeader(context),
                Expanded(
                  child: LandOwnerProfileContent(
                    key: ValueKey(currentUser!.uid),
                    landOwnerUID: currentUser!.uid,
                    onProfileUpdated: _fetchUserInfo,
                  ),
                ),
              ],
            ),
          ),
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
  
  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
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
                    _userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  Text(
                    _userRole,
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
          
          const Text(
            'Manage Land Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }
}

class LandOwnerProfileContent extends StatefulWidget {
  final String landOwnerUID;
  final VoidCallback? onProfileUpdated;
  
  const LandOwnerProfileContent({
    required this.landOwnerUID, 
    this.onProfileUpdated,
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

  // State variables
  String? _profileImageUrl;
  XFile? _pickedImageFile;
  bool _uploadingImage = false;
  int? _pickedImageFileSize;
  
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedCropType;
  List<String> _selectedFactoryIds = [];
  List<Map<String, dynamic>> _availableFactories = [];
  
  bool _isSaving = false;
  String? _statusMessage;
  bool _isLoading = true;
  Map<String, dynamic>? _loadedData;

  static final Map<String, List<String>> _geoData = _getGeoData();

  @override
  void initState() {
    super.initState();
    _landNameController = TextEditingController();
    _addressController = TextEditingController();
    _landSizeController = TextEditingController();
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
      final userDoc = await _firestore.collection('users').doc(widget.landOwnerUID).get();
      final factoriesSnapshot = await _firestore.collection('factories').get();
      final landDoc = await _firestore.collection('lands').doc(widget.landOwnerUID).get();

      if (mounted) {
        final userData = userDoc.data();
        _profileImageUrl = userData?['profileImageUrl'];

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
    _landSizeController.text = data['landSize'] ?? '';
    _villageController.text = data['village'] ?? '';
    _agDivisionController.text = data['agDivision'] ?? '';
    _gnDivisionController.text = data['gnDivision'] ?? '';
    
    _selectedProvince = data['province'];
    _selectedDistrict = data['district'];
    _selectedCropType = data['cropType'];
    _selectedFactoryIds = List<String>.from(data['factoryIds'] ?? []);

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
    _agDivisionController.dispose();
    _gnDivisionController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    
    await _loadInitialData();
    
    if (mounted) {
      setState(() {
        _statusMessage = "Data refreshed successfully!";
      });
    }
  }

  // 🔑 FIXED & IMPROVED IMAGE PICKING METHOD
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (await file.exists()) {
          final stat = await file.stat();
          final fileSizeKB = stat.size / 1024;
          
          // Check file size (max 5MB)
          if (fileSizeKB > 5000) {
            _showStatusMessage('Image is too large (${fileSizeKB.toStringAsFixed(1)} KB). Please choose an image under 5MB.');
            return;
          }
          
          setState(() {
            _pickedImageFile = pickedFile;
            _pickedImageFileSize = stat.size;
          });
          
          _showStatusMessage('Image selected: ${pickedFile.name} (${fileSizeKB.toStringAsFixed(1)} KB)');
        } else {
          _showStatusMessage('Selected file does not exist');
        }
      }
    } catch (e) {
      _handleImagePickerError(e, source);
    }
  }

  // 🔑 IMPROVED ERROR HANDLING
  void _handleImagePickerError(dynamic error, ImageSource source) {
    String errorMessage = 'Failed to pick image: ${error.toString()}';
    
    if (error.toString().contains('unsupported') || error.toString().contains('operation')) {
      errorMessage = 'Image picking is not supported on this platform or device. '
          'Please check your device permissions and try again.';
    } else if (error.toString().contains('permission')) {
      errorMessage = 'Permission denied. Please enable camera and storage permissions in your device settings.';
    } else if (source == ImageSource.camera && error.toString().contains('camera')) {
      errorMessage = 'Camera not available. Please check if your device has a working camera.';
    } else if (error.toString().contains('photo_access_denied')) {
      errorMessage = 'Photo access denied. Please enable photo library access in your device settings.';
    }
    
    _showStatusMessage(errorMessage);
  }

  void _openImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              if (_pickedImageFile != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pickedImageFile!.name,
                        style: TextStyle(
                          color: AppColors.darkText.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      if (_pickedImageFileSize != null)
                        Text(
                          '${(_pickedImageFileSize! / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            color: AppColors.darkText.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              
              // Camera option
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppColors.primaryBlue),
                title: const Text('Take Photo'),
                subtitle: const Text('Capture a new photo with camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              
              // Gallery option
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primaryBlue),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select from your device gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              
              if (_profileImageUrl != null || _pickedImageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Current Photo', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Remove profile picture', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeProfileImage();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.primaryBlue),
                title: const Text('Cancel'),
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
    
    try {
      await _firestore.collection('users').doc(widget.landOwnerUID).update({
        'profileImageUrl': FieldValue.delete(),
      });
      _showStatusMessage('Profile photo removed successfully');
      widget.onProfileUpdated?.call();
    } catch (e) {
      _showStatusMessage('Failed to remove photo: ${e.toString()}');
    }
  }

  // 🔑 IMPROVED CLOUDINARY UPLOAD
  Future<String?> _uploadImageToCloudinary(XFile imageFile) async {
    try {
      debugPrint('Starting Cloudinary upload for: ${imageFile.name}');
      
      final bytes = await imageFile.readAsBytes();
      final fileSizeKB = (bytes.length / 1024).toStringAsFixed(1);
      
      _showStatusMessage('Uploading image... ($fileSizeKB KB)');
      
      // Validate file size (max 10MB for safety)
      if (bytes.length > 10000000) {
        _showStatusMessage('Image is too large. Please choose an image under 10MB.');
        return null;
      }

      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'profile_${widget.landOwnerUID}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Cloudinary upload timed out after 60 seconds');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imageUrl = responseData['secure_url'];
        debugPrint('✅ Cloudinary upload successful! URL: $imageUrl');
        _showStatusMessage('Image uploaded successfully!');
        return imageUrl;
      } else {
        debugPrint('❌ Cloudinary upload failed: ${response.statusCode} - ${response.body}');
        String errorMessage = 'Upload failed with status ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error']['message'] ?? errorMessage;
        } catch (_) {}
        
        _showStatusMessage('Upload failed: $errorMessage');
        return null;
      }
      
    } on TimeoutException catch (e) {
      debugPrint('⏰ Upload timeout: $e');
      _showStatusMessage('Upload timed out. Please check your internet connection and try again.');
      return null;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      _showStatusMessage('Failed to upload image. Please try again.');
      return null;
    }
  }

  // 🔑 SEPARATE PROFILE PICTURE UPDATE METHOD
  Future<void> _updateProfilePictureOnly() async {
    if (_pickedImageFile == null) {
      _showStatusMessage('Please select an image first');
      return;
    }

    setState(() {
      _uploadingImage = true;
      _statusMessage = 'Uploading profile picture...';
    });

    try {
      final cloudinaryUrl = await _uploadImageToCloudinary(_pickedImageFile!);
      
      if (cloudinaryUrl != null) {
        // Update user profile in Firestore
        await _firestore.collection('users').doc(widget.landOwnerUID).update({
          'profileImageUrl': cloudinaryUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _profileImageUrl = cloudinaryUrl;
          _pickedImageFile = null;
          _pickedImageFileSize = null;
        });

        _showStatusMessage('Profile picture updated successfully!');
        widget.onProfileUpdated?.call();
      }
    } catch (e) {
      _showStatusMessage('Error updating profile picture: $e');
      debugPrint('Profile Picture Update Error: $e');
    } finally {
      setState(() {
        _uploadingImage = false;
      });
    }
  }

  Future<void> _updateLandData() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _statusMessage = "Please correct the errors in the form.");
      return;
    }

    if (_selectedProvince == null || _selectedDistrict == null || _selectedCropType == null) {
      setState(() => _statusMessage = "Please ensure all required fields are filled.");
      return;
    }
    
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      // If there's a new image, upload it first
      if (_pickedImageFile != null) {
        setState(() {
          _uploadingImage = true;
        });
        
        final cloudinaryUrl = await _uploadImageToCloudinary(_pickedImageFile!);
        if (cloudinaryUrl != null) {
          // Update user profile with new image
          await _firestore.collection('users').doc(widget.landOwnerUID).update({
            'profileImageUrl': cloudinaryUrl,
          });
          
          setState(() {
            _profileImageUrl = cloudinaryUrl;
          });
        } else {
          // If image upload fails, stop the process
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

      // Update land data
      final landDataToUpdate = {
        'landName': _landNameController.text.trim(),
        'address': _addressController.text.trim(),
        'landSize': _landSizeController.text.trim(),
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

      await _firestore.collection('lands').doc(widget.landOwnerUID).set(landDataToUpdate, SetOptions(merge: true));
      
      // Clear the picked image after successful upload
      if (_pickedImageFile != null) {
        setState(() {
          _pickedImageFile = null;
          _pickedImageFileSize = null;
        });
      }

      _showStatusMessage("Land details updated successfully!");
      widget.onProfileUpdated?.call();

      await _refreshData();

    } catch (e) {
      _showStatusMessage("Error updating land details: $e");
      debugPrint('Update Error: $e');
    } finally {
      setState(() {
        _isSaving = false;
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

    final bool isNewDocument = _loadedData == null;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNewDocument)
                    const InfoCard(
                      message: "Welcome! Please enter your land details below to complete your profile.",
                      color: Colors.orange,
                    ),
                  
                  if (_statusMessage != null)
                    InfoCard(
                      message: _statusMessage!,
                      color: _statusMessage!.toLowerCase().contains('success') ? AppColors.secondaryColor : Colors.red,
                    ),

                  const SizedBox(height: 16),
                  
                  _buildProfileImageSection(),
                  
                  // Quick Profile Picture Update Button
                  if (_pickedImageFile != null && !_uploadingImage)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: _updateProfilePictureOnly,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Update Profile Picture Only'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  _buildInputLabel('Land Name'),
                  _buildTextField(_landNameController, 'Green Valley Plantation'),
                                 
                  _buildInputLabel('Land Size'),
                  _buildTextField(_landSizeController, '5 Acres'),

                  _buildInputLabel('Village'),
                  _buildTextField(_villageController, 'e.g., Peradeniya'),

                  _buildInputLabel('Address Line'),
                  _buildTextField(_addressController, 'e.g., Kandy Road'),

                  _buildInputLabel('Crop Type'),
                  _buildCropTypeDropdown(),
                  
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
                  
                  const SizedBox(height: 30),

                  GradientButton(
                    text: _isSaving ? 'Updating...' : 'Update Land Details',
                    onPressed: (_isSaving || _uploadingImage) ? null : _updateLandData,
                    isEnabled: !_isSaving && !_uploadingImage,
                  ),
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Profile Picture'),
        const SizedBox(height: 8),
        Center(
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 3),
                ),
                child: _uploadingImage
                    ? Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _getProfileImage(),
                        child: _getProfileImage() == null
                            ? const Icon(Icons.person, size: 50, color: AppColors.primaryBlue)
                            : null,
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    onPressed: _openImageOptions,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        if (_pickedImageFile != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
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
                    Icon(Icons.image, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Image:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _pickedImageFile!.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.darkText.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (_pickedImageFileSize != null)
                  Text(
                    'Size: ${(_pickedImageFileSize! / 1024).toStringAsFixed(1)} KB',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          )
        else if (_profileImageUrl != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_done, size: 16, color: AppColors.secondaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current image stored in Cloudinary',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.darkText.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFactorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Associated Factories'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
          ),
          child: _availableFactories.isEmpty
              ? const Text(
                  'No factories available',
                  style: TextStyle(color: Colors.grey),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select factories you supply to:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.darkText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableFactories.map((factory) {
                        final isSelected = _selectedFactoryIds.contains(factory['id']);
                        return FilterChip(
                          label: Text(factory['factoryName']),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFactoryIds.add(factory['id']);
                              } else {
                                _selectedFactoryIds.remove(factory['id']);
                              }
                            });
                          },
                          selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                          checkmarkColor: AppColors.primaryBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryBlue : AppColors.darkText,
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedFactoryIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Selected: ${_selectedFactoryIds.length} factory(ies)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.darkText.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  ImageProvider? _getProfileImage() {
    if (_pickedImageFile != null) {
      return FileImage(File(_pickedImageFile!.path));
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.darkText,
          fontWeight: FontWeight.w600,
          fontSize: 16,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.darkText),
        decoration: InputDecoration(
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          border: InputBorder.none,
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

  Widget _buildCropTypeDropdown() {
    return _buildDropdown<String>(
      value: _selectedCropType,
      hint: 'Select Crop Type (Tea, Cinnamon, or Both)',
      items: ['Tea', 'Cinnamon', 'Both'],
      onChanged: (newValue) {
        setState(() {
          _selectedCropType = newValue;
        });
      },
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(color: AppColors.darkText.withOpacity(0.5))),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
          style: const TextStyle(color: AppColors.darkText, fontSize: 16),
          items: items.map<DropdownMenuItem<T>>((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// Geo Data and reusable widgets
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

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;

  const GradientButton({required this.text, required this.onPressed, this.isEnabled = true, super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.darkText.withOpacity(0.7),
          fontSize: 16,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}