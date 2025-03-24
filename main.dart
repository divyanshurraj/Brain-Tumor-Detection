import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCUDjD_ndtfqdKjow2L3VqeY1fHx0hpIfA",
      authDomain: "brain-tumor-detection-b7101.firebaseapp.com",
      projectId: "brain-tumor-detection-b7101",
      storageBucket: "brain-tumor-detection-b7101.firebasestorage.app",
      messagingSenderId: "629378189873",
      appId: "1:629378189873:web:57a1aa5342b2d5ddb56310",
    ),
  );
  runApp(const BrainTumorDetectorApp());
}

class BrainTumorDetectorApp extends StatelessWidget {
  const BrainTumorDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brain Tumor Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ImageUploadScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ImageUploadScreen extends StatefulWidget {
  const ImageUploadScreen({super.key});

  @override
  State<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  File? _selectedImage;
  Uint8List? _webImageBytes;
  String _predictionResult = '';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _predictionResult = '';
      });

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() => _webImageBytes = bytes);
      }
    }
  }

  Future<void> _uploadAndAnalyzeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('mri_scans/${DateTime.now().millisecondsSinceEpoch}.jpg');

      if (kIsWeb) {
        await storageRef.putData(
          _webImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        await storageRef.putFile(_selectedImage!);
      }

      final imageUrl = await storageRef.getDownloadURL();

      // In _uploadAndAnalyzeImage():
      final response = await http.post(
        Uri.parse(
            'http://192.168.209.95:5001/predict'), // Use this IP from your logs
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _predictionResult = '''
          Diagnosis: ${_formatDiagnosis(result['class'])}
          Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%
          ''';
        });
      } else {
        setState(() => _predictionResult = 'API Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _predictionResult = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDiagnosis(String diagnosis) {
    return diagnosis.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brain Tumor Detection'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: kIsWeb
                              ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                              : Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Text(
                            'No image selected',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Select MRI Image'),
                        onPressed: _isLoading ? null : _pickImage,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(250, 50),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.analytics),
                        label: const Text('Analyze Image'),
                        onPressed: _isLoading || _selectedImage == null
                            ? null
                            : _uploadAndAnalyzeImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(250, 50),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: _isLoading
                      ? const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text('Analyzing MRI Image...'),
                          ],
                        )
                      : _predictionResult.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _predictionResult.contains('NO TUMOR')
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _predictionResult,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _predictionResult.contains('NO TUMOR')
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            )
                          : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
