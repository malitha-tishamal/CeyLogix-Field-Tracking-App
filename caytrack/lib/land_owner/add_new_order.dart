import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';

class AddNewOrderPage extends StatefulWidget {
  const AddNewOrderPage({super.key});

  @override
  State<AddNewOrderPage> createState() => _AddNewOrderPageState();
}

class _AddNewOrderPageState extends State<AddNewOrderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  // State variables
  String? _selectedFactoryId;
  String? _selectedCropType;
  double? _teaQuantity;
  double? _cinnamonQuantity;
  DateTime? _selectedDate;
  List<XFile> _selectedPhotos = [];
  List<String> _uploadedPhotoUrls = [];
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _availableFactories = [];
  Map<String, dynamic>? _landData;
  
  final String _cloudName = "dqeptzlsb";
  final String _uploadPreset = "flutter_ceytrack_upload";
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    if (_currentUser == null) return;
    
    try {
      // Load land data
      final landDoc = await _firestore.collection('lands').doc(_currentUser!.uid).get();
      if (landDoc.exists) {
        setState(() {
          _landData = landDoc.data();
          _selectedCropType = _landData?['cropType'];
        });
      }
      
      // Load associated factories
      final factoriesSnapshot = await _firestore.collection('factories').get();
      setState(() {
        _availableFactories = factoriesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'factoryName': data['factoryName'] ?? 'Unknown Factory',
          };
        }).toList();
        
        // If land has factory IDs, set first one as default
        if (_landData?['factoryIds'] != null && _landData!['factoryIds'].isNotEmpty) {
          _selectedFactoryId = _landData!['factoryIds'][0];
        }
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
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
      debugPrint('Error picking photos: $e');
    }
  }
  
  Future<List<String>> _uploadPhotosToCloudinary() async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < _selectedPhotos.length; i++) {
      try {
        final photo = _selectedPhotos[i];
        final bytes = await photo.readAsBytes();
        
        final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'order_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFactoryId == null) {
      _showMessage('Please select a factory', isError: true);
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Upload photos if any
      List<String> orderPhotoUrls = [];
      if (_selectedPhotos.isNotEmpty) {
        orderPhotoUrls = await _uploadPhotosToCloudinary();
      }
      
      // Calculate total quantity
      double totalQuantity = 0;
      if (_selectedCropType == 'Tea' && _teaQuantity != null) {
        totalQuantity = _teaQuantity!;
      } else if (_selectedCropType == 'Cinnamon' && _cinnamonQuantity != null) {
        totalQuantity = _cinnamonQuantity!;
      } else if (_selectedCropType == 'Both') {
        totalQuantity = (_teaQuantity ?? 0) + (_cinnamonQuantity ?? 0);
      }
      
      // Prepare order data
      final orderData = {
        'landOwnerId': _currentUser!.uid,
        'landOwnerName': _landData?['landName'] ?? 'Unknown Land',
        'factoryId': _selectedFactoryId,
        'factoryName': _availableFactories
            .firstWhere((factory) => factory['id'] == _selectedFactoryId)['factoryName'],
        'cropType': _selectedCropType,
        'teaQuantity': _teaQuantity,
        'cinnamonQuantity': _cinnamonQuantity,
        'totalQuantity': totalQuantity,
        'unit': 'kg',
        'description': _descriptionController.text.trim(),
        'orderDate': _selectedDate ?? DateTime.now(),
        'orderPhotos': orderPhotoUrls,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add to orders collection
      await _firestore.collection('land_orders').add(orderData);
      
      _showMessage('Order submitted successfully!');
      _resetForm();
      
    } catch (e) {
      _showMessage('Error submitting order: $e', isError: true);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  void _resetForm() {
    _formKey.currentState?.reset();
    _descriptionController.clear();
    _teaQuantity = null;
    _cinnamonQuantity = null;
    _selectedPhotos.clear();
    _selectedDate = null;
  }
  
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Order'),
        backgroundColor: const Color(0xFF2764E7),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Factory Selection
              _buildSectionTitle('Select Factory'),
              _buildFactoryDropdown(),
              
              const SizedBox(height: 20),
              
              // Crop Type (display only)
              if (_selectedCropType != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Crop Type'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        
                      ),
                      child: Text(
                        _selectedCropType!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 20),
              
              // Quantity Input based on crop type
              _buildQuantitySection(),
              
              const SizedBox(height: 20),
              
              // Date Selection
              _buildSectionTitle('Order Date'),
              _buildDatePicker(),
              
              const SizedBox(height: 20),
              
              // Description
              _buildSectionTitle('Description (Optional)'),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any notes about this order...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Photos
              _buildSectionTitle('Order Photos (Optional)'),
              _buildPhotoSection(),
              
              const SizedBox(height: 30),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2764E7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
  
  Widget _buildFactoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: _selectedFactoryId,
        isExpanded: true,
        underline: const SizedBox(),
        hint: const Text('Select Factory'),
        items: _availableFactories.map((factory) {
          return DropdownMenuItem<String>(
            value: factory['id'],
            child: Text(factory['factoryName']),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedFactoryId = value;
          });
        },
      ),
    );
  }
  
  Widget _buildQuantitySection() {
    if (_selectedCropType == 'Tea') {
      return _buildQuantityInput(
        label: 'Tea Quantity (kg)',
        value: _teaQuantity,
        onChanged: (value) => setState(() => _teaQuantity = value),
      );
    } else if (_selectedCropType == 'Cinnamon') {
      return _buildQuantityInput(
        label: 'Cinnamon Quantity (kg)',
        value: _cinnamonQuantity,
        onChanged: (value) => setState(() => _cinnamonQuantity = value),
      );
    } else if (_selectedCropType == 'Both') {
      return Column(
        children: [
          _buildQuantityInput(
            label: 'Tea Quantity (kg)',
            value: _teaQuantity,
            onChanged: (value) => setState(() => _teaQuantity = value),
          ),
          const SizedBox(height: 12),
          _buildQuantityInput(
            label: 'Cinnamon Quantity (kg)',
            value: _cinnamonQuantity,
            onChanged: (value) => setState(() => _cinnamonQuantity = value),
          ),
        ],
      );
    }
    return const SizedBox();
  }
  
  Widget _buildQuantityInput({
    required String label,
    required double? value,
    required Function(double?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label),
        TextFormField(
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter quantity in kg',
            suffixText: 'kg',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (text) {
            final val = double.tryParse(text);
            onChanged(val);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Quantity is required';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            if (double.parse(value) <= 0) {
              return 'Quantity must be greater than 0';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null
                  ? 'Select Date'
                  : DateFormat('yyyy-MM-dd').format(_selectedDate!),
              style: TextStyle(
                color: _selectedDate == null ? Colors.grey : Colors.black,
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedPhotos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedPhotos.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_selectedPhotos[index].path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPhotos.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
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
        
        const SizedBox(height: 12),
        
        ElevatedButton.icon(
          onPressed: _pickPhotos,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Add Photos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.black87,
          ),
        ),
      ],
    );
  }
}