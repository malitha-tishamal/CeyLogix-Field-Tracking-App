// user_details.dart - DASHBOARD-STYLE HEADER + GREEN THEME + COMPACT UI
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'factory_owner_drawer.dart';

class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentTeal = Color(0xFF00BFA5);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color cardBackground = Colors.white;
  static const Color secondaryText = Color(0xFF6A798A);
  static const Color secondaryColor = Color(0xFF6AD96A);
  static const Color purpleAccent = Color(0xFF9C27B0);
  static const Color amberAccent = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
  static const Color textTertiary = Color(0xFF999999);
  static const Color hover = Color(0xFFF5F7FA);
  static const Color border = Color(0xFFE1E5E9);
  
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);  
  static const Color headerTextDark = Color(0xFF333333);
  
  static const Color errorRed = Color(0xFFD32F2F);
}

class UserDetails extends StatefulWidget {
  const UserDetails({super.key});

  @override
  State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String _loggedInUserName = 'Loading User...';
  String _factoryName = 'Loading Factory...';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) return;
    final String uid = user.uid;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Land Owner';
        });
      }
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

  void _handleDrawerNavigate(String routeName) => Navigator.pop(context);

  // ===================== DASHBOARD-STYLE HEADER =====================
  Widget _buildDashboardHeader(BuildContext context, double screenWidth) {
    final isSmall = screenWidth < 360;
    final isMedium = screenWidth >= 360 && screenWidth < 400;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 2,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 24),
                ),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loggedInUserName,
                    style: TextStyle(
                      fontSize: isSmall ? 14 : isMedium ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userRole,
                    style: TextStyle(
                      fontSize: isSmall ? 10 : isMedium ? 11 : 12,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildProfileAvatar(),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Manage User Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_profileImageUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) => setState(() => _profileImageUrl = null),
      );
    } else {
      return CircleAvatar(
        radius: 40,
        backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
        child: Icon(Icons.person, color: AppColors.primaryGreen, size: 48),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (currentUser == null) {
      return Scaffold(body: Center(child: Text("Error: User not logged in.", style: TextStyle(fontSize: screenWidth * 0.04))));
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
            _buildDashboardHeader(context, screenWidth),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    UserProfileContentOnly(
                      userUID: currentUser!.uid,
                      onProfileUpdated: _fetchHeaderData,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
              child: Text(
                'Developed By Malitha Tishamal',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.darkText.withOpacity(0.7), fontSize: screenWidth * 0.025),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== USER PROFILE CONTENT (COMPACT MODERN) =====================
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

  final String _cloudName = "dqeptzlsb";
  final String _uploadPreset = "flutter_ceytrack_upload";

  late TextEditingController _ownerNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _nicController;
  
  String? _profileImageUrl;
  XFile? _pickedImageFile;
  bool _uploadingImage = false;
  int? _pickedImageFileSize;
  
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
    _fetchUserData();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _contactNumberController.dispose();
    _nicController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final userDoc = await _firestore.collection('users').doc(widget.userUID).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (mounted) {
        _ownerNameController.text = userData?['name'] ?? '';
        _contactNumberController.text = userData?['mobile'] ?? '';
        _nicController.text = userData?['nic'] ?? '';
        _profileImageUrl = userData?['profileImageUrl'];
        _fetchedEmail = userData?['email'] ?? currentUser?.email ?? 'N/A';
        _fetchedRole = userData?['role'] ?? 'Land owner';
        setState(() {});
      }
    } else if (mounted) {
      _fetchedEmail = currentUser?.email ?? 'N/A';
      _fetchedRole = 'Land owner';
      setState(() {});
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final stat = await file.stat();
        setState(() {
          _pickedImageFile = pickedFile;
          _pickedImageFileSize = stat.size;
        });
        _showStatusMessage('Image selected: ${pickedFile.name} (${(stat.size / 1024).toStringAsFixed(1)} KB)');
      }
    } catch (e) {
      _showStatusMessage('Failed to pick image: ${e.toString()}');
    }
  }

  void _openImageOptions() {
    final isSmall = widget.screenWidth < 360;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (_pickedImageFile != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.05),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Selection:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 14)),
                    const SizedBox(height: 4),
                    Text(_pickedImageFile!.name, style: TextStyle(fontSize: isSmall ? 12 : 13), maxLines: 2),
                    if (_pickedImageFileSize != null)
                      Text('${(_pickedImageFileSize! / 1024).toStringAsFixed(1)} KB', style: TextStyle(fontSize: isSmall ? 11 : 12)),
                  ],
                ),
              ),
            ListTile(
              leading: Icon(Icons.photo_camera, color: AppColors.primaryGreen),
              title: Text('Take Photo', style: TextStyle(fontSize: isSmall ? 14 : 16)),
              subtitle: Text('Capture a new photo', style: TextStyle(fontSize: isSmall ? 12 : 14)),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.primaryGreen),
              title: Text('Choose from Gallery', style: TextStyle(fontSize: isSmall ? 14 : 16)),
              subtitle: Text('Select from gallery', style: TextStyle(fontSize: isSmall ? 12 : 14)),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            if (_profileImageUrl != null || _pickedImageFile != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Remove Current Photo', style: TextStyle(color: Colors.red, fontSize: isSmall ? 14 : 16)),
                subtitle: Text('Remove profile picture', style: TextStyle(color: Colors.red, fontSize: isSmall ? 12 : 14)),
                onTap: () { Navigator.pop(ctx); _removeProfileImage(); },
              ),
            ListTile(
              leading: Icon(Icons.close, color: AppColors.primaryGreen),
              title: Text('Cancel', style: TextStyle(fontSize: isSmall ? 14 : 16)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeProfileImage() async {
    setState(() {
      _pickedImageFile = null;
      _profileImageUrl = null;
    });
    try {
      await _firestore.collection('users').doc(widget.userUID).update({
        'profileImageUrl': FieldValue.delete(),
      });
      _showStatusMessage('Profile photo removed');
    } catch (e) {
      _showStatusMessage('Failed to remove photo: ${e.toString()}');
    }
  }

  Future<String?> _uploadImageToCloudinary(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.length > 1000000) {
        _showStatusMessage('Image too large (max 1MB)');
        return null;
      }
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: imageFile.name));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final imageUrl = json.decode(response.body)['secure_url'];
        return imageUrl;
      } else {
        _showStatusMessage('Upload failed');
        return null;
      }
    } catch (e) {
      _showStatusMessage('Upload error: ${e.toString()}');
      return null;
    }
  }

  Future<void> _updateUserData() async {
    if (!_formKey.currentState!.validate()) {
      _showStatusMessage("Please correct the errors in the form.");
      return;
    }
    setState(() { _isSaving = true; _statusMessage = null; });

    try {
      String? finalProfileImageUrl = _profileImageUrl;
      if (_pickedImageFile != null) {
        setState(() => _uploadingImage = true);
        final cloudinaryUrl = await _uploadImageToCloudinary(_pickedImageFile!);
        if (cloudinaryUrl != null) {
          finalProfileImageUrl = cloudinaryUrl;
        } else {
          setState(() { _isSaving = false; _uploadingImage = false; });
          return;
        }
        setState(() => _uploadingImage = false);
      }

      final userDataToUpdate = {
        'name': _ownerNameController.text.trim(),
        'mobile': _contactNumberController.text.trim(),
        'nic': _nicController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (finalProfileImageUrl != null && finalProfileImageUrl.isNotEmpty) {
        userDataToUpdate['profileImageUrl'] = finalProfileImageUrl;
      } else if (_pickedImageFile == null && _profileImageUrl == null) {
        userDataToUpdate['profileImageUrl'] = FieldValue.delete();
      }

      await _firestore.collection('users').doc(widget.userUID).set(userDataToUpdate, SetOptions(merge: true));
      setState(() {
        _profileImageUrl = finalProfileImageUrl;
        _pickedImageFile = null;
      });
      _showStatusMessage("Profile updated successfully!");
      widget.onProfileUpdated?.call();
    } catch (e) {
      _showStatusMessage("Error updating profile: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showStatusMessage(String msg) => setState(() => _statusMessage = msg);

  // ===================== COMPACT UI BUILDERS =====================
  @override
  Widget build(BuildContext context) {
    final isSmall = widget.screenWidth < 360;
    if (_ownerNameController.text.isEmpty && !_isSaving && currentUser?.email != null && _fetchedEmail == 'N/A') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 12),
            Text('Loading user data...', style: TextStyle(fontSize: widget.screenWidth * 0.035)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_statusMessage != null)
              Container(
                padding: EdgeInsets.all(isSmall ? 8 : 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _statusMessage!.toLowerCase().contains('success') ? AppColors.successGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _statusMessage!.toLowerCase().contains('success') ? AppColors.successGreen : Colors.red),
                ),
                child: Text(_statusMessage!, style: TextStyle(fontSize: isSmall ? 12 : 13)),
              ),
            
            // Profile Picture (compact)
            _buildProfileImageSection(isSmall),
            
            // Form fields
            _buildInputLabel('Full Name', isSmall),
            _buildTextField(_ownerNameController, 'Enter your full name', (v) => v == null || v.isEmpty ? 'Required' : null, isSmall),
            
            _buildInputLabel('Contact Number', isSmall),
            _buildTextField(_contactNumberController, '0712345678', (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length != 10) return '10 digits required';
              return null;
            }, isSmall, TextInputType.phone),
            
            _buildInputLabel('NIC Number', isSmall),
            _buildTextField(_nicController, 'Enter your NIC', (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 10) return 'Invalid NIC';
              return null;
            }, isSmall),
            
            _buildInputLabel('Email Address', isSmall),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 14, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.hover,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(_fetchedEmail, style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.darkText)),
            ),
            
            _buildInputLabel('User Role', isSmall),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 14, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.hover,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(_fetchedRole, style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.darkText)),
            ),
            
            const SizedBox(height: 24),
            GradientButton(
              text: _isSaving ? 'Updating...' : 'Update Profile Details',
              onPressed: (_isSaving || _uploadingImage) ? null : _updateUserData,
              isEnabled: !_isSaving && !_uploadingImage,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImageSection(bool isSmall) {
    final size = isSmall ? 80.0 : 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Profile Picture', isSmall),
        const SizedBox(height: 8),
        Center(
          child: Stack(
            children: [
              Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3), width: 2),
                ),
                child: _uploadingImage
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                    : CircleAvatar(
                        radius: size / 2,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _getProfileImage(),
                        child: _getProfileImage() == null
                            ? Icon(Icons.person, size: size * 0.4, color: AppColors.primaryGreen)
                            : null,
                      ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: isSmall ? 28 : 32,
                  height: isSmall ? 28 : 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, size: isSmall ? 14 : 16, color: Colors.white),
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
            margin: const EdgeInsets.only(top: 12),
            padding: EdgeInsets.all(isSmall ? 8 : 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.image, size: 14, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Text('Selected Image:', style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text(_pickedImageFile!.name, style: TextStyle(fontSize: isSmall ? 11 : 12), maxLines: 1),
                if (_pickedImageFileSize != null)
                  Text('${(_pickedImageFileSize! / 1024).toStringAsFixed(1)} KB', style: TextStyle(fontSize: isSmall ? 10 : 11)),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  ImageProvider? _getProfileImage() {
    if (_pickedImageFile != null) return FileImage(File(_pickedImageFile!.path));
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) return NetworkImage(_profileImageUrl!);
    return null;
  }

  Widget _buildInputLabel(String text, bool isSmall) => Padding(
    padding: EdgeInsets.only(top: 12, bottom: 4),
    child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 14, color: AppColors.darkText)),
  );

  Widget _buildTextField(TextEditingController ctrl, String hint, String? Function(String?)? validator, bool isSmall, [TextInputType? type]) => Container(
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: TextFormField(
      controller: ctrl,
      keyboardType: type ?? TextInputType.text,
      style: TextStyle(fontSize: isSmall ? 13 : 14),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: InputBorder.none,
      ),
      validator: validator,
    ),
  );
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;
  const GradientButton({required this.text, this.onPressed, this.isEnabled = true, super.key});

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isEnabled
              ? const LinearGradient(colors: [AppColors.primaryGreen, Color(0xFF66BB6A)])
              : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade300]),
          boxShadow: isEnabled ? [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}