import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/file_storage_service.dart';
import '../../Services/database_helper.dart';
import '../../Providers/home_provider.dart';
import 'package:provider/provider.dart';

class ScanPDFProgressScreen extends StatefulWidget {
  final List<File> imageFiles;
  final String filter;
  final Map<String, Uint8List?>? filteredImages;

  const ScanPDFProgressScreen({
    super.key,
    required this.imageFiles,
    required this.filter,
    this.filteredImages,
  });

  @override
  State<ScanPDFProgressScreen> createState() => _ScanPDFProgressScreenState();
}

class _ScanPDFProgressScreenState extends State<ScanPDFProgressScreen>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  String? _savedPath;
  late AnimationController _percentageController;
  late AnimationController _waveController;
  late Animation<double> _percentageAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    
    // Percentage animation controller
    _percentageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Wave animation controller for water effect
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _percentageAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
        parent: _percentageController,
        curve: Curves.easeOut,
      ),
    );
    
    _waveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.linear,
      ),
    );
    
    _convertToPDF();
  }

  @override
  void dispose() {
    _percentageController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _convertToPDF() async {
    try {
      final totalImages = widget.imageFiles.length;
      final fileStorageService = FileStorageService.instance;
      final dbHelper = DatabaseHelper.instance;
      
      // Total steps: image processing + saving
      final totalSteps = totalImages;
      int currentStep = 0;
      
      // Store all image bytes
      final List<Uint8List> imageBytesList = [];

      // Process each image
      for (int i = 0; i < totalImages; i++) {
        currentStep++;
        
        // Update progress
        setState(() {
          _progress = currentStep / totalSteps;
        });

        // Animate percentage
        _percentageAnimation = Tween<double>(
          begin: _percentageAnimation.value,
          end: (_progress * 100),
        ).animate(
          CurvedAnimation(
            parent: _percentageController,
            curve: Curves.easeOut,
          ),
        );
        _percentageController.forward(from: 0);

        // Read image - use filtered version if available
        Uint8List imageBytes;
        final imageKey = '${i}_${widget.filter}';
        
        if (widget.filteredImages != null && 
            widget.filteredImages!.containsKey(imageKey) &&
            widget.filteredImages![imageKey] != null) {
          // Use filtered image
          imageBytes = widget.filteredImages![imageKey]!;
        } else {
          // Fallback to original image if filtered version not available
          imageBytes = await widget.imageFiles[i].readAsBytes();
        }
        
        imageBytesList.add(imageBytes);

        // Small delay for smooth animation
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Save images to database
      setState(() {
        _progress = 0.9;
      });
      
      _percentageAnimation = Tween<double>(
        begin: _percentageAnimation.value,
        end: 90,
      ).animate(
        CurvedAnimation(
          parent: _percentageController,
          curve: Curves.easeOut,
        ),
      );
      _percentageController.forward(from: 0);
      
      String? savedPath;
      
      if (totalImages == 1) {
        // Single image: Save to Document table only
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final docId = await fileStorageService.saveImageFile(
          imageBytes: imageBytesList[0],
          fileName: 'Doc_Scan_$timestamp.jpg',
          title: 'Doc_Scan',
        );
        
        if (docId != null) {
          final document = await dbHelper.getDocument(docId);
          savedPath = document?['Image_path']?.toString();
        }
      } else {
        // Multiple images: First to Document table, all to DocumentDetail table
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final baseFileName = 'Doc_Scan';
        
        // Save first image to Document table
        final documentId = await fileStorageService.saveImageFile(
          imageBytes: imageBytesList[0],
          fileName: '${baseFileName}_0_$timestamp.jpg',
          title: baseFileName,
        );
        
        if (documentId == null) {
          throw Exception('Failed to save first image to Document table');
        }
        
        // Get document data for first image paths
        final document = await dbHelper.getDocument(documentId);
        if (document == null) {
          throw Exception('Document not found after creation');
        }
        
        savedPath = document['Image_path']?.toString();
        
        // Save all images (including first) to DocumentDetail table
        final baseTimestamp = DateTime.now();
        final imagesDir = await fileStorageService.getImagesDirectory();
        
        for (int i = 0; i < imageBytesList.length; i++) {
          String savedFilePath;
          String? savedThumbnailPath;
          
          if (i == 0) {
            // Use paths from Document table for first image
            savedFilePath = document['Image_path']?.toString() ?? '';
            savedThumbnailPath = document['image_thumbnail']?.toString();
          } else {
            // Save other images
            final fileTimestamp = baseTimestamp.add(Duration(milliseconds: i));
            final fileTimestampMs = fileTimestamp.millisecondsSinceEpoch;
            savedFilePath = '${imagesDir.path}/img_${fileTimestampMs}_$i.jpg';
            
            final file = File(savedFilePath);
            await file.writeAsBytes(imageBytesList[i]);
            
            // Generate thumbnail
            final thumbnailBytes = await fileStorageService.generateImageThumbnail(imageBytesList[i]);
            if (thumbnailBytes != null) {
              savedThumbnailPath = '${imagesDir.path}/thumb_${fileTimestampMs}_$i.jpg';
              final thumbFile = File(savedThumbnailPath);
              await thumbFile.writeAsBytes(thumbnailBytes);
            }
          }
          
          // Create DocumentDetail entry
          final fileTimestamp = baseTimestamp.add(Duration(milliseconds: i));
          final documentDetailMap = {
            'document_id': documentId,
            'title': '${baseFileName}_$i',
            'type': 'image',
            'Image_path': savedFilePath,
            'image_thumbnail': savedThumbnailPath,
            'created_date': fileTimestamp.toIso8601String(),
            'updated_date': fileTimestamp.toIso8601String(),
            'favourite': 0,
            'is_deleted': 0,
          };
          
          await dbHelper.createDocumentDetail(documentDetailMap);
        }
      }
      
      // Refresh home screen documents
      if (mounted) {
        final provider = Provider.of<HomeProvider>(context, listen: false);
        await provider.loadDocuments();
      }

      // Final progress update (100%)
      setState(() {
        _savedPath = savedPath ?? '';
        _progress = 1.0;
        _percentageAnimation = Tween<double>(
          begin: _percentageAnimation.value,
          end: 100,
        ).animate(
          CurvedAnimation(
            parent: _percentageController,
            curve: Curves.easeOut,
          ),
        );
        _percentageController.forward(from: 0);
      });
    } catch (e) {
      _showError('Error saving images: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surface.withOpacity(0.2)
                          : colorScheme.surface.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                  onPressed: () => NavigationService.goBack(),
                ),
              ),

              const Spacer(),

              // Water Fill Circle Animation
              AnimatedBuilder(
                animation: Listenable.merge([
                  _percentageAnimation,
                  _waveAnimation,
                ]),
                builder: (context, child) {
                  final percentage = _percentageAnimation.value;
                  final fillLevel = percentage / 100.0; // 0.0 to 1.0
                  
                  return SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer circle border
                        Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 4,
                            ),
                          ),
                        ),
                        // Water fill with wave effect
                        ClipOval(
                          child: CustomPaint(
                            size: const Size(240, 240),
                            painter: WaterFillPainter(
                              fillLevel: fillLevel,
                              waveAnimation: _waveAnimation.value,
                            ),
                          ),
                        ),
                        // Percentage text overlay
                        Text(
                          '${percentage.toInt()}%',
                          style: TextStyle(
                            color: colorScheme.onBackground,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: AppConstants.spacingXL),

              // File Path
              if (_savedPath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                  ),
                  child: Text(
                    _savedPath!,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Text(
                  'Processing...',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),

              const Spacer(),

              // Open File Button
              if (_savedPath != null)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      NavigationService.toImageViewer(
                        imagePath: _savedPath!,
                        imageName: 'Doc_Scan',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Open File',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
}

// Custom painter for water fill effect with waves
class WaterFillPainter extends CustomPainter {
  final double fillLevel; // 0.0 to 1.0 (0 = empty, 1 = full)
  final double waveAnimation; // 0.0 to 1.0 for wave movement

  WaterFillPainter({
    required this.fillLevel,
    required this.waveAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillLevel <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Clip to circle first
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(circlePath);
    
    // Calculate water level from bottom (0 = bottom, 1 = top)
    // fillLevel 0 means empty (at bottom), fillLevel 1 means full (at top)
    final waterHeight = size.height * fillLevel;
    final waterTop = size.height - waterHeight; // Top of water from top of circle
    
    // If completely full (100%), fill entire circle
    if (fillLevel >= 1.0) {
      // Draw full circle with gradient
      final fullGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blue[400]!.withOpacity(0.9),
          Colors.blue[500]!,
          Colors.blue[600]!,
          Colors.blue[700]!,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      );
      
      final fullPaint = Paint()
        ..shader = fullGradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      
      canvas.drawOval(
        Rect.fromCircle(center: center, radius: radius),
        fullPaint,
      );
      
      // Add subtle wave effect even when full
      final wavePath = Path();
      final waveHeight = 3.0;
      final waveFrequency = 0.015;
      final waveSpeed = waveAnimation * 2 * math.pi;
      
      wavePath.moveTo(0, 0);
      for (double x = 0; x <= size.width; x += 0.5) {
        final wave1 = math.sin(waveSpeed + x * waveFrequency) * waveHeight;
        final y = wave1;
        wavePath.lineTo(x, y);
      }
      wavePath.lineTo(size.width, size.height);
      wavePath.lineTo(0, size.height);
      wavePath.close();
      
      final wavePaint = Paint()
        ..color = Colors.blue[300]!.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(wavePath, wavePaint);
      
      // White reflection line at top
      final reflectionPath = Path();
      bool isFirst = true;
      for (double x = 0; x <= size.width; x += 0.5) {
        final wave1 = math.sin(waveSpeed + x * waveFrequency) * 2;
        final y = wave1;
        if (isFirst) {
          reflectionPath.moveTo(x, y);
          isFirst = false;
        } else {
          reflectionPath.lineTo(x, y);
        }
      }
      
      final reflectionPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      
      canvas.drawPath(reflectionPath, reflectionPaint);
      return;
    }
    
    // Create gradient for water (darker at bottom, lighter at top)
    final waterGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.blue[400]!.withOpacity(0.9),
        Colors.blue[500]!,
        Colors.blue[600]!,
        Colors.blue[700]!,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );

    // Draw water fill with wave effect
    final waterPath = Path();
    
    // Start from bottom left
    waterPath.moveTo(0, size.height);
    
    // Draw smooth wave pattern at the top of water
    if (fillLevel > 0 && fillLevel < 1) {
      final waveHeight = 12.0;
      final waveFrequency = 0.015;
      final waveSpeed = waveAnimation * 2 * math.pi;
      
      for (double x = 0; x <= size.width; x += 0.5) {
        // Create smooth, continuous wave using multiple sine waves
        final wave1 = math.sin(waveSpeed + x * waveFrequency) * waveHeight;
        final wave2 = math.sin(waveSpeed * 1.3 + x * waveFrequency * 1.7) * (waveHeight * 0.6);
        final wave3 = math.sin(waveSpeed * 0.7 + x * waveFrequency * 2.3) * (waveHeight * 0.4);
        
        final y = waterTop + wave1 + wave2 + wave3;
        waterPath.lineTo(x, y);
      }
    } else {
      // If full, draw straight line at top
      waterPath.lineTo(size.width, waterTop);
    }
    
    // Complete the path
    waterPath.lineTo(size.width, size.height);
    waterPath.close();

    // Draw main water fill with gradient
    final waterPaint = Paint()
      ..shader = waterGradient.createShader(
        Rect.fromLTWH(0, waterTop, size.width, waterHeight),
      );
    
    canvas.drawPath(waterPath, waterPaint);
    
    // Add secondary highlight layer (lighter blue translucent layer above main wave)
    if (fillLevel > 0.1 && fillLevel < 1) {
      final highlightPath = Path();
      final highlightOffset = 4.0; // Offset above main wave
      final waveHeight = 8.0;
      final waveFrequency = 0.015;
      final waveSpeed = waveAnimation * 2 * math.pi;
      
      highlightPath.moveTo(0, waterTop + highlightOffset);
      
      for (double x = 0; x <= size.width; x += 0.5) {
        final wave1 = math.sin(waveSpeed * 1.2 + x * waveFrequency * 1.1) * waveHeight;
        final wave2 = math.sin(waveSpeed * 0.9 + x * waveFrequency * 1.8) * (waveHeight * 0.5);
        
        final y = waterTop + highlightOffset + wave1 + wave2;
        highlightPath.lineTo(x, y);
      }
      
      highlightPath.lineTo(size.width, size.height);
      highlightPath.close();
      
      final highlightPaint = Paint()
        ..color = Colors.blue[300]!.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(highlightPath, highlightPaint);
    }
    
    // Add white highlight/reflection line on top of water surface
    if (fillLevel > 0.1) {
      final reflectionPath = Path();
      final reflectionY = waterTop + 2;
      final waveHeight = 6.0;
      final waveFrequency = 0.015;
      final waveSpeed = waveAnimation * 2 * math.pi;
      
      bool isFirst = true;
      for (double x = 0; x <= size.width; x += 0.5) {
        final wave1 = math.sin(waveSpeed + x * waveFrequency) * waveHeight;
        final y = reflectionY + wave1;
        
        if (isFirst) {
          reflectionPath.moveTo(x, y);
          isFirst = false;
        } else {
          reflectionPath.lineTo(x, y);
        }
      }
      
      final reflectionPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      
      canvas.drawPath(reflectionPath, reflectionPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WaterFillPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel ||
        oldDelegate.waveAnimation != waveAnimation;
  }
}

