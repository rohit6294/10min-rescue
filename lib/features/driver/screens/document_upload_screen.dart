import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

// ─── Document entry descriptor ───────────────────────────────────────────────

class _DocEntry {
  final String docType;
  final String label;
  final bool isRequired;

  const _DocEntry({
    required this.docType,
    required this.label,
    this.isRequired = true,
  });
}

const _docList = [
  _DocEntry(docType: 'aadhaar_front', label: 'Aadhaar Card — Front'),
  _DocEntry(docType: 'aadhaar_back',  label: 'Aadhaar Card — Back'),
  _DocEntry(docType: 'license_front', label: 'Driving License — Front'),
  _DocEntry(docType: 'license_back',  label: 'Driving License — Back'),
  _DocEntry(docType: 'vehicle_photo', label: 'Car / Vehicle Photo'),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _picker = ImagePicker();
  final _uid    = FirebaseAuth.instance.currentUser!.uid;

  /// docType → preview File for thumbnail display
  final Map<String, File> _previews = {};

  /// docType → base64-encoded JPEG string (without data: prefix)
  final Map<String, String> _base64Map = {};

  /// docType → currently encoding (true while busy)
  final Map<String, bool> _encoding = {};

  bool _isSubmitting = false;

  int  get _readyCount => _base64Map.length;
  bool get _allReady   => _readyCount == _docList.length;

  // ── pick & encode ──────────────────────────────────────────────────────────

  Future<void> _pickAndEncode(String docType) async {
    final source = await _showSourceDialog();
    if (source == null) return;

    setState(() => _encoding[docType] = true);
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 45,   // keeps each image ~25-50 KB
        maxWidth:  800,
        maxHeight: 800,
      );
      if (xFile == null) return;

      final bytes  = await File(xFile.path).readAsBytes();
      final b64    = base64Encode(bytes);          // ~33% overhead = ~35-70 KB

      setState(() {
        _previews[docType]  = File(xFile.path);
        _base64Map[docType] = b64;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not process image: $e'),
          backgroundColor: AppColors.emergency,
        ));
      }
    } finally {
      if (mounted) setState(() => _encoding.remove(docType));
    }
  }

  // ── submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_allReady) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_uid)
          .set(
        {
          'verificationStatus': 'pending',
          'documents': Map<String, String>.from(_base64Map),
          'docsSubmittedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) context.go('/driver/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: AppColors.emergency,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── dialogs ────────────────────────────────────────────────────────────────

  Future<ImageSource?> _showSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentBlue,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            title: const Text('Document Verification'),
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _docList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildCard(_docList[i]),
                ),
              ),
              _buildSubmitBar(),
            ],
          ),
        ),

        // Full-screen loading overlay while submitting
        if (_isSubmitting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.emergency),
                  SizedBox(height: 16),
                  Text(
                    'Submitting documents…',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final progress = _docList.isEmpty ? 0.0 : _readyCount / _docList.length;
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_readyCount of ${_docList.length} documents ready',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.onlineGreen),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Upload clear, well-lit photos. Documents are stored securely.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_DocEntry doc) {
    final preview   = _previews[doc.docType];
    final isReady   = _base64Map.containsKey(doc.docType);
    final isEncoding = _encoding[doc.docType] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady
              ? AppColors.onlineGreen.withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Thumbnail / placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72, height: 72,
                child: preview != null
                    ? Image.file(preview, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.lightBg,
                        child: Icon(
                          _iconFor(doc.docType),
                          color: AppColors.textLight,
                          size: 32,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Label + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        doc.label,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: doc.isRequired
                            ? AppColors.emergency.withValues(alpha: 0.1)
                            : AppColors.accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doc.isRequired ? 'Required' : 'Optional',
                        style: TextStyle(
                          color: doc.isRequired
                              ? AppColors.emergency
                              : AppColors.accentBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  if (isEncoding)
                    Row(children: const [
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text('Processing…',
                          style: TextStyle(
                              color: AppColors.accentBlue, fontSize: 11)),
                    ])
                  else if (isReady)
                    const Row(children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.onlineGreen, size: 14),
                      SizedBox(width: 4),
                      Text('Ready',
                          style: TextStyle(
                              color: AppColors.onlineGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ])
                  else
                    const Text('Tap the button to upload',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Pick button
            GestureDetector(
              onTap: isEncoding ? null : () => _pickAndEncode(doc.docType),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isReady
                      ? AppColors.onlineGreen.withValues(alpha: 0.1)
                      : AppColors.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isEncoding
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accentBlue),
                      )
                    : Icon(
                        isReady ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                        color: isReady
                            ? AppColors.onlineGreen
                            : AppColors.accentBlue,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _allReady && !_isSubmitting ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.grey.shade500,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(
            _allReady
                ? 'Submit for Verification'
                : 'Upload all ${_docList.length} documents to continue',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String docType) {
    switch (docType) {
      case 'aadhaar_front':
      case 'aadhaar_back':
        return Icons.credit_card_rounded;
      case 'license_front':
      case 'license_back':
        return Icons.badge_rounded;
      case 'vehicle_photo':
        return Icons.directions_car_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
