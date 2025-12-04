import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'land_owner_drawer.dart';
import '../Auth/login_page.dart'; // Import login page

// -----------------------------------------------------------------------------
// --- 1. COLOR PALETTE ---
class AppColors {
  static const Color background = Color(0xFFF8FAFF);
  static const Color cardBackground = Colors.white;
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color accentBlue = Color(0xFF3D7AFF);
  static const Color darkText = Color(0xFF1E293B);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color lightBlue = Color(0xFFEFF6FF);
  
  // Header gradient colors
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
}

// -----------------------------------------------------------------------------
// --- 2. MAIN SCREEN ---
class AddNewOrderPage extends StatefulWidget {
  const AddNewOrderPage({super.key});

  @override
  State<AddNewOrderPage> createState() => _AddNewOrderPageState();
}

class _AddNewOrderPageState extends State<AddNewOrderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _teaQuantityController = TextEditingController();
  final _cinnamonQuantityController = TextEditingController();
  
  // State variables
  String? _selectedFactoryId;
  String? _selectedFactoryName;
  String? _selectedCropType;
  DateTime? _selectedDate;
  List<XFile> _selectedPhotos = [];
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableFactories = [];
  Map<String, dynamic>? _landData;
  
  // Header data - Responsive
  String _loggedInUserName = 'Loading...';
  String _landName = 'Loading...';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;
  late bool _isPortrait;
  late double _screenWidth;
  late double _screenHeight;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

  Future<void> _loadInitialData() async {
    if (_currentUser == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Load user data
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Land Owner';
        });
      }
      
      // Load land data
      final landDoc = await _firestore.collection('lands').doc(_currentUser!.uid).get();
      if (landDoc.exists) {
        _landData = landDoc.data();
        setState(() {
          _landName = _landData?['landName'] ?? 'Land';
          _selectedCropType = _landData?['cropType'];
        });
        
        // Load associated factories
        final List<dynamic> associatedFactoryIds = _landData?['factoryIds'] ?? [];
        if (associatedFactoryIds.isNotEmpty) {
          final List<Map<String, dynamic>> loadedFactories = [];
          
          for (final factoryId in associatedFactoryIds) {
            try {
              final factoryDoc = await _firestore.collection('factories').doc(factoryId).get();
              if (factoryDoc.exists) {
                final factoryData = factoryDoc.data();
                loadedFactories.add({
                  'id': factoryDoc.id,
                  'factoryName': factoryData?['factoryName'] ?? 'Unknown Factory',
                  'cropType': factoryData?['cropType'] ?? 'N/A',
                });
              }
            } catch (e) {
              debugPrint('Error loading factory $factoryId: $e');
            }
          }
          
          setState(() {
            _availableFactories = loadedFactories;
            if (loadedFactories.isNotEmpty) {
              _selectedFactoryId = loadedFactories.first['id'];
              _selectedFactoryName = loadedFactories.first['factoryName'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      _showMessage('Failed to load data', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context); // Close drawer
    // Handle navigation if needed
  }

  void _onLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _pickPhotos() async {
    try {
      final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          _selectedPhotos.addAll(pickedFiles);
        });
      }
    } catch (e) {
      _showMessage('Failed to pick photos: ${e.toString()}', isError: true);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<List<String>> _uploadPhotos() async {
    List<String> uploadedUrls = [];
    final cloudName = "dqeptzlsb";
    final uploadPreset = "flutter_ceytrack_upload";
    
    for (final photo in _selectedPhotos) {
      try {
        final bytes = await photo.readAsBytes();
        final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'order_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ));
        
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          uploadedUrls.add(responseData['secure_url']);
        }
      } catch (e) {
        debugPrint('Error uploading photo: $e');
      }
    }
    
    return uploadedUrls;
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Please fill all required fields correctly', isError: true);
      return;
    }
    
    if (_selectedFactoryId == null) {
      _showMessage('Please select a factory', isError: true);
      return;
    }
    
    if (_selectedDate == null) {
      _showMessage('Please select an export date', isError: true);
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Upload photos
      List<String> orderPhotoUrls = [];
      if (_selectedPhotos.isNotEmpty) {
        orderPhotoUrls = await _uploadPhotos();
      }
      
      // Calculate quantities
      double teaQuantity = double.tryParse(_teaQuantityController.text.trim()) ?? 0;
      double cinnamonQuantity = double.tryParse(_cinnamonQuantityController.text.trim()) ?? 0;
      double totalQuantity = 0;
      
      if (_selectedCropType == 'Tea') {
        totalQuantity = teaQuantity;
      } else if (_selectedCropType == 'Cinnamon') {
        totalQuantity = cinnamonQuantity;
      } else if (_selectedCropType == 'Both') {
        totalQuantity = teaQuantity + cinnamonQuantity;
      }
      
      // Prepare order data
      final orderData = {
        'landOwnerId': _currentUser!.uid,
        'landOwnerName': _landData?['landName'] ?? 'Unknown Land',
        'factoryId': _selectedFactoryId,
        'factoryName': _selectedFactoryName ?? 'Unknown Factory',
        'cropType': _selectedCropType,
        'teaQuantity': teaQuantity,
        'cinnamonQuantity': cinnamonQuantity,
        'totalQuantity': totalQuantity,
        'unit': 'kg',
        'description': _descriptionController.text.trim(),
        'orderDate': _selectedDate!,
        'orderPhotos': orderPhotoUrls,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Save to Firestore
      await _firestore.collection('land_orders').add(orderData);
      
      _showMessage('Order submitted successfully!', isError: false);
      _resetForm();
      
    } catch (e) {
      _showMessage('Error submitting order: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _descriptionController.clear();
    _teaQuantityController.clear();
    _cinnamonQuantityController.clear();
    _selectedPhotos.clear();
    _selectedDate = null;
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateScreenDimensions();
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;
    
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onNavigate: _handleDrawerNavigate,
        onLogout: _onLogout,
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
                    child: _buildContent(isSmallScreen, isMediumScreen),
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

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryBlue,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading...',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 16,
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
                icon: Icon(Icons.menu, color: AppColors.darkText, size: menuIconSize),
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
                        color: AppColors.darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    //Land Name Name and Role
                    Text(
                      'Land Name: $_landName \n($_userRole)', 
                      style: TextStyle(
                        fontSize: landFontSize,
                        color: AppColors.darkText.withOpacity(0.7),
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
            'Create New Order',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4.0 : 6.0),
          Text(
            'Export your crop products to factories',
            style: TextStyle(
              fontSize: isSmallScreen ? 12.0 : 13.0,
              color: AppColors.darkText.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isSmallScreen, bool isMediumScreen) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: _screenHeight * 0.2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryBlue),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              Text('Loading order form...'),
            ],
          ),
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
            // Factory Selection Card
            _buildFactorySelectionCard(isSmallScreen, isMediumScreen),
            SizedBox(height: isSmallScreen ? 16.0 : 20.0),
            
            // Crop Type Card
            if (_selectedCropType != null) 
              _buildCropTypeCard(isSmallScreen, isMediumScreen),
            if (_selectedCropType != null) 
              SizedBox(height: isSmallScreen ? 16.0 : 20.0),
            
            // Quantity Card
            _buildQuantityCard(isSmallScreen, isMediumScreen),
            SizedBox(height: isSmallScreen ? 16.0 : 20.0),
            
            // Date Selection Card
            _buildDateCard(isSmallScreen, isMediumScreen),
            SizedBox(height: isSmallScreen ? 16.0 : 20.0),
            
            // Description Card
            _buildDescriptionCard(isSmallScreen, isMediumScreen),
            SizedBox(height: isSmallScreen ? 16.0 : 20.0),
            
            // Photos Card
            _buildPhotosCard(isSmallScreen, isMediumScreen),
            SizedBox(height: isSmallScreen ? 20.0 : 30.0),
            
            // Submit Button
            _buildSubmitButton(isSmallScreen, isMediumScreen),
            SizedBox(height: isSmallScreen ? 20.0 : 30.0),
          ],
        ),
      ),
    );
  }

  Widget _buildFactorySelectionCard(bool isSmallScreen, bool isMediumScreen) {
    return _buildCard(
      title: 'Factory Selection',
      icon: Icons.factory_rounded,
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select the factory you want to export to',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          
          if (_availableFactories.isEmpty)
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.errorRed,
                    size: isSmallScreen ? 20.0 : 24.0,
                  ),
                  SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No factories available',
                          style: TextStyle(
                            color: AppColors.darkText,
                            fontWeight: FontWeight.w500,
                            fontSize: isSmallScreen ? 13.0 : 14.0,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                        Text(
                          'Add factories to your land profile first',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: isSmallScreen ? 12.0 : 13.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10.0 : 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedFactoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Select a factory',
                  hintStyle: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                  ),
                ),
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: isSmallScreen ? 14.0 : 16.0,
                ),
                items: _availableFactories.map((factory) {
                  final isMatch = _selectedCropType == 'Both' || 
                                 factory['cropType'] == _selectedCropType;
                  return DropdownMenuItem<String>(
                    value: factory['id'],
                    enabled: isMatch,
                    child: Opacity(
                      opacity: isMatch ? 1.0 : 0.5,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isMatch ? AppColors.successGreen : AppColors.secondaryText,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                          Expanded(
                            child: Text(
                              factory['factoryName'],
                              style: TextStyle(
                                color: isMatch ? AppColors.darkText : AppColors.secondaryText,
                                fontSize: isSmallScreen ? 14.0 : 16.0,
                              ),
                            ),
                          ),
                          if (!isMatch)
                            Padding(
                              padding: EdgeInsets.only(left: isSmallScreen ? 4.0 : 8.0),
                              child: Text(
                                '(Crop mismatch)',
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: isSmallScreen ? 10.0 : 12.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    final factory = _availableFactories.firstWhere(
                      (factory) => factory['id'] == value,
                      orElse: () => {'id': value, 'factoryName': 'Unknown Factory'}
                    );
                    setState(() {
                      _selectedFactoryId = value;
                      _selectedFactoryName = factory['factoryName'];
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a factory';
                  }
                  return null;
                },
                dropdownColor: Colors.white,
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.primaryBlue,
                  size: isSmallScreen ? 20.0 : 24.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCropTypeCard(bool isSmallScreen, bool isMediumScreen) {
    Color cropColor;
    String cropLabel;
    IconData cropIcon;
    
    switch (_selectedCropType) {
      case 'Tea':
        cropColor = const Color(0xFF10B981);
        cropLabel = 'Tea';
        cropIcon = Icons.emoji_food_beverage_rounded;
        break;
      case 'Cinnamon':
        cropColor = const Color(0xFFF59E0B);
        cropLabel = 'Cinnamon';
        cropIcon = Icons.spa_rounded;
        break;
      case 'Both':
        cropColor = AppColors.primaryBlue;
        cropLabel = 'Both (Tea & Cinnamon)';
        cropIcon = Icons.category_rounded;
        break;
      default:
        cropColor = AppColors.secondaryText;
        cropLabel = 'Unknown';
        cropIcon = Icons.question_mark_rounded;
    }
    
    return _buildCard(
      title: 'Crop Type',
      icon: Icons.agriculture_rounded,
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: cropColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
          border: Border.all(color: cropColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: isSmallScreen ? 40.0 : 48.0,
              height: isSmallScreen ? 40.0 : 48.0,
              decoration: BoxDecoration(
                color: cropColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                cropIcon,
                color: Colors.white,
                size: isSmallScreen ? 18.0 : 24.0,
              ),
            ),
            SizedBox(width: isSmallScreen ? 12.0 : 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cropLabel,
                    style: TextStyle(
                      color: cropColor,
                      fontSize: isSmallScreen ? 16.0 : 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                  Text(
                    'Based on your land profile',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: isSmallScreen ? 12.0 : 14.0,
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

  Widget _buildQuantityCard(bool isSmallScreen, bool isMediumScreen) {
    return _buildCard(
      title: 'Product Quantity',
      icon: Icons.scale_rounded,
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter quantity in kilograms (kg)',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          
          if (_selectedCropType == 'Tea' || _selectedCropType == 'Both')
            _buildQuantityInput(
              label: 'Tea Quantity',
              controller: _teaQuantityController,
              icon: Icons.emoji_food_beverage_rounded,
              color: const Color(0xFF10B981),
              isRequired: _selectedCropType == 'Tea',
              isSmallScreen: isSmallScreen,
              isMediumScreen: isMediumScreen,
            ),
          
          if (_selectedCropType == 'Tea' || _selectedCropType == 'Both') 
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          
          if (_selectedCropType == 'Cinnamon' || _selectedCropType == 'Both')
            _buildQuantityInput(
              label: 'Cinnamon Quantity',
              controller: _cinnamonQuantityController,
              icon: Icons.spa_rounded,
              color: const Color(0xFFF59E0B),
              isRequired: _selectedCropType == 'Cinnamon',
              isSmallScreen: isSmallScreen,
              isMediumScreen: isMediumScreen,
            ),
          
          if (_selectedCropType == 'Both') 
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          
          // Quantity validation helper
          if (_selectedCropType == 'Both')
            Builder(
              builder: (context) {
                final teaQty = double.tryParse(_teaQuantityController.text.trim()) ?? 0;
                final cinnamonQty = double.tryParse(_cinnamonQuantityController.text.trim()) ?? 0;
                
                if (teaQty == 0 && cinnamonQty == 0) {
                  return Text(
                    'At least one quantity must be greater than 0',
                    style: TextStyle(
                      color: AppColors.errorRed,
                      fontSize: isSmallScreen ? 11.0 : 13.0,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuantityInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required bool isRequired,
    required bool isSmallScreen,
    required bool isMediumScreen,
  }) {
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final padding = isSmallScreen ? const EdgeInsets.symmetric(vertical: 12.0, horizontal: 14.0) : 
                   const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
              ),
              child: Icon(
                icon,
                color: color,
                size: isSmallScreen ? 16.0 : 20.0,
              ),
            ),
            SizedBox(width: isSmallScreen ? 8.0 : 10.0),
            Text(
              label,
              style: TextStyle(
                color: AppColors.darkText,
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 14.0 : 15.0,
              ),
            ),
            if (!isRequired)
              Padding(
                padding: EdgeInsets.only(left: isSmallScreen ? 4.0 : 8.0),
                child: Text(
                  '(Optional)',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: isSmallScreen ? 11.0 : 13.0,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 6.0 : 8.0),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: fontSize,
          ),
          decoration: InputDecoration(
            hintText: 'Enter quantity in kg',
            hintStyle: TextStyle(
              color: AppColors.secondaryText.withOpacity(0.7),
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
            suffixText: 'kg',
            suffixStyle: TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
              borderSide: BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
              borderSide: BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
              borderSide: BorderSide(color: AppColors.primaryBlue),
            ),
            contentPadding: padding,
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'This field is required';
            }
            if (value != null && value.isNotEmpty) {
              final numericValue = double.tryParse(value);
              if (numericValue == null) {
                return 'Please enter a valid number';
              }
              if (numericValue <= 0) {
                return 'Quantity must be greater than 0';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDateCard(bool isSmallScreen, bool isMediumScreen) {
    return _buildCard(
      title: 'Export Date',
      icon: Icons.calendar_today_rounded,
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select when you want to export',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(DateTime.now().year + 1),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primaryBlue,
                        onPrimary: Colors.white,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                border: Border.all(
                  color: _selectedDate == null 
                      ? AppColors.borderColor 
                      : AppColors.primaryBlue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 36.0 : 40.0,
                    height: isSmallScreen ? 36.0 : 40.0,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primaryBlue,
                      size: isSmallScreen ? 18.0 : 20.0,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDate == null
                              ? 'Select a date'
                              : DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!),
                          style: TextStyle(
                            color: _selectedDate == null 
                                ? AppColors.secondaryText 
                                : AppColors.darkText,
                            fontWeight: FontWeight.w500,
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                          ),
                        ),
                        if (_selectedDate != null)
                          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                        if (_selectedDate != null)
                          Text(
                            DateFormat('yyyy-MM-dd').format(_selectedDate!),
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.primaryBlue,
                    size: isSmallScreen ? 14.0 : 16.0,
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDate == null)
            Padding(
              padding: EdgeInsets.only(top: isSmallScreen ? 6.0 : 8.0),
              child: Text(
                'Please select a date',
                style: TextStyle(
                  color: AppColors.errorRed,
                  fontSize: isSmallScreen ? 11.0 : 13.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(bool isSmallScreen, bool isMediumScreen) {
    return _buildCard(
      title: 'Additional Notes',
      icon: Icons.note_alt_rounded,
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add any special instructions or notes',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: isSmallScreen ? 14.0 : 16.0,
            ),
            decoration: InputDecoration(
              hintText: 'Example: Special packaging required, specific quality notes, etc.',
              hintStyle: TextStyle(
                color: AppColors.secondaryText.withOpacity(0.7),
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                borderSide: BorderSide(color: AppColors.primaryBlue),
              ),
              contentPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(bool isSmallScreen, bool isMediumScreen) {
    return _buildCard(
      title: 'Order Photos',
      icon: Icons.photo_library_rounded,
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add photos of the products (optional)',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          
          if (_selectedPhotos.isNotEmpty)
            SizedBox(
              height: isSmallScreen ? 80.0 : 100.0,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPhotos.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: isSmallScreen ? 8.0 : 12.0),
                    child: Stack(
                      children: [
                        Container(
                          width: isSmallScreen ? 80.0 : 100.0,
                          height: isSmallScreen ? 80.0 : 100.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                            child: Image.file(
                              File(_selectedPhotos[index].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              width: isSmallScreen ? 20.0 : 24.0,
                              height: isSmallScreen ? 20.0 : 24.0,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: isSmallScreen ? 12.0 : 16.0,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 9.0 : 10.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          
          if (_selectedPhotos.isNotEmpty) 
            SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          
          ElevatedButton.icon(
            onPressed: _pickPhotos,
            icon: Icon(
              Icons.add_photo_alternate_rounded,
              size: isSmallScreen ? 18.0 : 20.0,
            ),
            label: Text(
              _selectedPhotos.isEmpty ? 'Add Photos' : 'Add More Photos',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 14.0 : 16.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightBlue,
              foregroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                side: BorderSide(color: AppColors.borderColor),
              ),
              minimumSize: Size(double.infinity, isSmallScreen ? 44.0 : 50.0),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12.0 : 16.0,
              ),
            ),
          ),
          
          if (_selectedPhotos.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: isSmallScreen ? 6.0 : 8.0),
              child: Text(
                '${_selectedPhotos.length} photo(s) selected',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: isSmallScreen ? 11.0 : 13.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isSmallScreen, bool isMediumScreen) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 48.0 : 56.0,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          ),
          elevation: 4,
          shadowColor: AppColors.primaryBlue.withOpacity(0.3),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: isSmallScreen ? 20.0 : 24.0,
                height: isSmallScreen ? 20.0 : 24.0,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send_rounded, 
                    size: isSmallScreen ? 18.0 : 22.0
                  ),
                  SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                  Text(
                    'Submit Order',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15.0 : 17.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isSmallScreen,
    required bool isMediumScreen,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 5.0 : 6.0),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isSmallScreen ? 16.0 : 18.0,
                ),
              ),
              SizedBox(width: isSmallScreen ? 8.0 : 10.0),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: isSmallScreen ? 15.0 : 17.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8.0 : 12.0),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
              border: Border.all(color: AppColors.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}