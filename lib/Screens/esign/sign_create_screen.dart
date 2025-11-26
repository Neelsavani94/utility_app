import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Models/signature_model.dart';

class SignCreateScreen extends StatefulWidget {
  const SignCreateScreen({super.key});

  @override
  State<SignCreateScreen> createState() => _SignCreateScreenState();
}

class _SignCreateScreenState extends State<SignCreateScreen> {
  SignatureController? _signatureController;

  final GetStorage _storage = GetStorage();
  
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  
  final List<Color> _colors = [
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];


  @override
  void initState() {
    super.initState();
    _initializeSignatureController();
  }

  void _initializeSignatureController() {
    _signatureController = SignatureController(
      penStrokeWidth: _strokeWidth,
      penColor: _selectedColor,
      exportBackgroundColor: Colors.white,
    );
  }

  void _updateSignatureController() {
    _signatureController?.dispose();
    _signatureController = SignatureController(
      penStrokeWidth: _strokeWidth,
      penColor: _selectedColor,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _signatureController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.2)
                : colorScheme.surface.withOpacity(0.65),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => NavigationService.goBack(),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'E Sign Board',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Main Content Area - Paint Board
          Expanded(
            child: _buildPaintBoard(colorScheme, isDark),
          ),
          
          // Control Panel
          _buildControlPanel(colorScheme, isDark),
          
          // Save/Cancel Buttons
          _buildActionButtons(colorScheme, isDark),
        ],
      ),
    );
  }


  Widget _buildPaintBoard(ColorScheme colorScheme, bool isDark) {
    if (_signatureController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Signature(
          controller: _signatureController!,
          backgroundColor: Colors.white,
          height: double.infinity,
        ),
      ),
    );
  }


  Widget _buildControlPanel(ColorScheme colorScheme, bool isDark) {

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingM,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.5)
            : colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: isDark
                ? colorScheme.outline.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // Color Picker
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Color:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Wrap(
                spacing: AppConstants.spacingS,
                runSpacing: AppConstants.spacingS,
                children: _colors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                        _updateSignatureController();
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          // Size Slider
          Row(
            children: [
              Text(
                'Size:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: Slider(
                  value: _strokeWidth,
                  min: 1.0,
                  max: 10.0,
                  divisions: 9,
                  label: _strokeWidth.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _strokeWidth = value;
                      _updateSignatureController();
                    });
                  },
                ),
              ),
              Text(
                _strokeWidth.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          // Clear Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  _signatureController?.clear();
                },
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme, bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          color: colorScheme.background,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? colorScheme.outline.withOpacity(0.3)
                  : colorScheme.outline.withOpacity(0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => NavigationService.goBack(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: FilledButton(
                onPressed: _saveSignature,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSignature() async {
    try {
      // Save paint signature
      if (_signatureController == null || _signatureController!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please draw a signature first'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final signatureData = await _signatureController!.toPngBytes();
      if (signatureData == null) {
        throw Exception('Failed to export signature');
      }

      await _saveSignatureToStorage(signatureData);

      if (mounted) {
        NavigationService.goBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving signature: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveSignatureToStorage(Uint8List imageData) async {
    final directory = await getApplicationDocumentsDirectory();
    final signaturesDir = Directory('${directory.path}/signatures');
    if (!await signaturesDir.exists()) {
      await signaturesDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'signature_$timestamp.png';
    final filePath = '${signaturesDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(imageData);

    // Load existing signatures
    final signaturesJson = _storage.read('signatures') as List<dynamic>? ?? [];
    final signatures = signaturesJson
        .map((json) => SignatureModel.fromMap(json as Map<String, dynamic>))
        .toList();

    // Create new signature
    final signature = SignatureModel(
      id: timestamp.toString(),
      name: 'Signature ${signatures.length + 1}',
      imagePath: filePath,
      textContent: null,
      textStyle: null,
      createdAt: DateTime.now(),
      isTextSignature: false,
    );

    signatures.insert(0, signature);
    final updatedJson = signatures.map((s) => s.toMap()).toList();
    await _storage.write('signatures', updatedJson);
  }
}
