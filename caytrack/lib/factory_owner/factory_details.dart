import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'factory_owner_drawer.dart'; // <-- IMPORTANT IMPORT

// --- Placeholder/Utility Imports ---
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
  
  // Custom colors based on the image's gradient header
  static const Color headerGradientStart = Color.fromARGB(255, 134, 164, 236); // Light blue top
  static const Color headerGradientEnd = Color(0xFFF7FAFF);   // Very light blue bottom
  static const Color headerTextDark = Color(0xFF333333);
}

// --- Factory Owner Profile Screen (Single Tab Version) ---
class FactoryDetails extends StatefulWidget {
  const FactoryDetails({super.key});

  @override
  State<FactoryDetails> createState() => _FactoryDetailsState();
}

class _FactoryDetailsState extends State<FactoryDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Placeholder for user data (to match the image's text)
  String _userName = 'Loading';
  String _userRole = 'Factory Owner';
  String? _profileImageUrl; // ADDED: For profile picture

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  // Fetch name and role from Firestore/Auth if needed
  void _fetchUserInfo() async {
    final user = currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _userName = data?['name'] ?? 'Factory Owner';
            _userRole = data?['role'] ?? 'Factory Owner';
            _profileImageUrl = data?['profileImageUrl']; // ADDED: Load profile image
          });
        }
      } catch (e) {
        // Handle error
        print("Error fetching user info: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
    }

    // You may need to create a dummy function if your FactoryOwnerDrawer expects the FactoryOwnerDashboard
    void handleDrawerNavigate(String routeName) {
      Navigator.pop(context); // Close drawer first
      // Placeholder for actual navigation logic if not Dashboard
      if (routeName == 'dashboard') {
         // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const FactoryOwnerDashboard()));
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          // Add your proper logout implementation here
          FirebaseAuth.instance.signOut();
          Navigator.pop(context);
        },
        onNavigate: handleDrawerNavigate, // Use the dummy handler
      ),
      body: Stack( // Use Stack to ensure the Update button stays above the footer text
        children: [
          SafeArea(
            child: Column(
              children: [
                // 1. Header Profile Card (UPDATED)
                _buildProfileHeader(context),
                
                // 2. Main Content - Scrollable Form
                Expanded(
                  child: SingleChildScrollView(
                    child: FactoryOwnerProfileContent(
                      factoryOwnerUID: currentUser!.uid,
                      onProfileUpdated: _fetchUserInfo, // ADDED: Refresh header when profile updates
                    ),
                  ),
                ),
                
                // 3. Footer Text (Moved to Stack for better positioning)
                // We'll handle the footer text placement outside the column for the fixed bottom text
              ],
            ),
          ),
          
          // 4. Fixed Footer Text
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
  
  // Custom Profile Header Widget - MATCHING IMAGE STYLE 🌟
  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      // 1. Gradient Background
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        // 2. Rounded Bottom Corners
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), // Slightly larger radius looks better
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000), // Subtle black shadow
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Menu Icon & Notification Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu Button (Hamburger)
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              // Notification Icon
              
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Row: Profile Picture & User Info
          Row(
            children: [
              // Profile Picture (UPDATED with actual image support)
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
              
              // User Info (Name and Role)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName, // Using fetched/placeholder name
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  Text(
                    _userRole, // Using fetched/placeholder role
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.headerTextDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 25), // Space before the "Manage" text
          
          // "Manage Profile Details" Text
          const Text(
            'Manage Factory Details',
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

// --- Factory Owner Profile Content Widget ---
class FactoryOwnerProfileContent extends StatefulWidget {
  final String factoryOwnerUID;
  final VoidCallback? onProfileUpdated; // ADDED: Callback to refresh header
  
  const FactoryOwnerProfileContent({
    required this.factoryOwnerUID, 
    this.onProfileUpdated,
    super.key
  });

  @override
  State<FactoryOwnerProfileContent> createState() => _FactoryOwnerProfileContentState();
}

class _FactoryOwnerProfileContentState extends State<FactoryOwnerProfileContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _imagePicker = ImagePicker();

  // Cloudinary Configuration
  final String _cloudName = "dqeptzlsb"; // Your cloud name
  final String _uploadPreset = "flutter_ceytrack_upload"; // Your upload preset

  // Text Controllers
  late TextEditingController _factoryNameController;
  late TextEditingController _addressController;
  late TextEditingController _ownerNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _agDivisionController;
  late TextEditingController _gnDivisionController;

  // Profile Image State
  String? _profileImageUrl;
  XFile? _pickedImageFile;
  bool _uploadingImage = false;
  int? _pickedImageFileSize;
  
  // Dropdown State
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedCropType;
  
  // Utility State
  bool _isSaving = false;
  String? _statusMessage;

  // Geo Data structure - Only for Province and District now
  static final Map<String, List<String>> _geoData = _getGeoData();

  @override
  void initState() {
    super.initState();
    _factoryNameController = TextEditingController();
    _addressController = TextEditingController();
    _ownerNameController = TextEditingController();
    _contactNumberController = TextEditingController();
    _agDivisionController = TextEditingController();
    _gnDivisionController = TextEditingController();
    
    // Fetch initial user data
    _fetchUserData(); 
  }

  @override
  void dispose() {
    _factoryNameController.dispose();
    _addressController.dispose();
    _ownerNameController.dispose();
    _contactNumberController.dispose();
    _agDivisionController.dispose();
    _gnDivisionController.dispose();
    super.dispose();
  }

  // --- Data Fetching Logic ---
  Future<void> _fetchUserData() async {
    final userDoc = await _firestore.collection('users').doc(widget.factoryOwnerUID).get();
    
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (mounted) {
        // Populate profile image
        _profileImageUrl = userData?['profileImageUrl'];
        
        setState(() {}); // Rebuild to display initial data
      }
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchFactoryData() {
    return _firestore.collection('factories').doc(widget.factoryOwnerUID).get();
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
              
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppColors.primaryBlue),
                title: const Text('Take Photo'),
                subtitle: const Text('Capture a new photo with camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
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
    
    // Update Firestore to remove profile image
    try {
      await _firestore.collection('users').doc(widget.factoryOwnerUID).update({
        'profileImageUrl': FieldValue.delete(),
      });
      _showStatusMessage('Profile photo removed');
      widget.onProfileUpdated?.call(); // Refresh header
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

  // --- Data Update Logic ---
  Future<void> _updateFactoryData() async {
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
      String? finalProfileImageUrl = _profileImageUrl;

      // Upload new image to Cloudinary if one was picked
      if (_pickedImageFile != null) {
        setState(() {
          _uploadingImage = true;
        });
        
        final cloudinaryUrl = await _uploadImageToCloudinary(_pickedImageFile!);
        if (cloudinaryUrl != null) {
          finalProfileImageUrl = cloudinaryUrl;
          
          // Update user profile with new image
          await _firestore.collection('users').doc(widget.factoryOwnerUID).update({
            'profileImageUrl': cloudinaryUrl,
          });
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

      // Prepare factory data update
      final factoryDataToUpdate = {
        'factoryName': _factoryNameController.text.trim(),
        'address': _addressController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'cropType': _selectedCropType,
        'country': 'Sri Lanka',
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'agDivision': _agDivisionController.text.trim(),
        'gnDivision': _gnDivisionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to the 'factories' collection
      await _firestore.collection('factories').doc(widget.factoryOwnerUID).set(factoryDataToUpdate, SetOptions(merge: true));
      
      // Update local state
      setState(() {
        _profileImageUrl = finalProfileImageUrl;
        _pickedImageFile = null;
        _pickedImageFileSize = null;
      });

      _showStatusMessage("Factory details updated successfully!");

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
        
        // Show selected file name
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
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _fetchFactoryData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading data: ${snapshot.error}'));
        }
        
        final data = snapshot.data?.data();
        if (data != null && mounted) {
          _factoryNameController.text = data['factoryName'] ?? '';
          _addressController.text = data['address'] ?? '';
          _ownerNameController.text = data['ownerName'] ?? '';
          _contactNumberController.text = data['contactNumber'] ?? '';
          _agDivisionController.text = data['agDivision'] ?? '';
          _gnDivisionController.text = data['gnDivision'] ?? '';
          
          _selectedProvince = data['province'];
          _selectedDistrict = data['district'];
          _selectedCropType = data['cropType'];

          if (_selectedProvince != null && !_geoData.containsKey(_selectedProvince)) {
            _selectedProvince = null;
          }
          if (_selectedDistrict != null && !(_geoData[_selectedProvince] ?? []).contains(_selectedDistrict)) {
            _selectedDistrict = null;
          }
        }
        
        final bool isNewDocument = snapshot.data?.exists == false;
        
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNewDocument)
                  const InfoCard(
                    message: "Welcome! Please enter your factory details below to complete your profile.",
                    color: Colors.orange,
                  ),
                
                if (_statusMessage != null)
                  InfoCard(
                    message: _statusMessage!,
                    color: _statusMessage!.toLowerCase().contains('success') ? AppColors.secondaryColor : Colors.red,
                  ),

                const SizedBox(height: 16),
                
                // Profile Picture Section - ADDED
                _buildProfileImageSection(),

                // Form Fields
                _buildInputLabel('Factory Name'),
                _buildTextField(_factoryNameController, 'Sunshine Tea Factory'),
                               
                _buildInputLabel('Contact Number'),
                _buildTextField(_contactNumberController, '0771234567', TextInputType.phone),

                _buildInputLabel('Address Line'),
                _buildTextField(_addressController, 'e.g., Kandy Road'),

                _buildInputLabel('Crop Type Handled'),
                _buildDropdown<String>(
                  value: _selectedCropType,
                  hint: 'Select Crop Type (Tea, Cinnamon, or Both)',
                  items: ['Tea', 'Cinnamon', 'Both'],
                  onChanged: (newValue) {
                    setState(() {
                      _selectedCropType = newValue;
                    });
                  },
                ),
                
                _buildInputLabel('Country (Fixed)'),
                const FixedInfoBox(value: 'Sri Lanka'),
                
                _buildInputLabel('Province'),
                _buildDropdown<String>(
                  value: _selectedProvince,
                  hint: 'Select Province',
                  items: _geoData.keys.toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedProvince = newValue;
                      _selectedDistrict = null;
                    });
                  },
                ),
                
                if (_selectedProvince != null) ...[
                  _buildInputLabel('District'),
                  _buildDropdown<String>(
                    value: _selectedDistrict,
                    hint: 'Select District',
                    items: _geoData[_selectedProvince] ?? [],
                    onChanged: (newValue) {
                      setState(() {
                        _selectedDistrict = newValue;
                      });
                    },
                  ),
                ],
                
                // A/G Division as text input
                _buildInputLabel('A/G Division'),
                _buildTextField(
                  _agDivisionController, 
                  'Enter A/G Division (e.g., Kandy Divisional Secretariat)',
                  TextInputType.text,
                  false // Not required
                ),
                
                // G/N Division as text input
                _buildInputLabel('G/N Division'),
                _buildTextField(
                  _gnDivisionController, 
                  'Enter G/N Division (e.g., Kandy Town)',
                  TextInputType.text,
                  false // Not required
                ),
                
                const SizedBox(height: 30),

                // Update Button
                GradientButton(
                  text: _isSaving ? 'Updating...' : 'Update Factory Details',
                  onPressed: (_isSaving || _uploadingImage) ? null : _updateFactoryData,
                  isEnabled: !_isSaving && !_uploadingImage,
                ),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---

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

// --- Simplified Geo Data Structure - Only Province and District ---
Map<String, List<String>> _getGeoData() {
  return {
    'Western Province': [
      'Colombo District', 'Gampaha District', 'Kalutara District'
    ],
    'Central Province': [
      'Kandy District', 'Matale District', 'Nuwara Eliya District'
    ],
    'Southern Province': [
      'Galle District', 'Matara District', 'Hambantota District'
    ],
    'Eastern Province': [
      'Trincomalee District', 'Batticaloa District', 'Ampara District'
    ],
    'Northern Province': [
      'Jaffna District', 'Vavuniya District', 'Kilinochchi District', 'Mannar District', 'Mullaitivu District'
    ],
    'North Western Province': [
      'Kurunegala District', 'Puttalam District'
    ],
    'North Central Province': [
      'Anuradhapura District', 'Polonnaruwa District'
    ],
    'Uva Province': [
      'Badulla District', 'Monaragala District'
    ],
    'Sabaragamuwa Province': [
      'Ratnapura District', 'Kegalle District'
    ],
  };
}

// --- Reusable Widgets (Remains the same) ---
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