# Permissions & Configuration Guide

## ✅ All Permissions and Configurations Set

### Android Configuration (`android/app/src/main/AndroidManifest.xml`)

#### Permissions:
- ✅ **READ_MEDIA_IMAGES** - For Android 13+ (image access)
- ✅ **READ_MEDIA_VIDEO** - For Android 13+ (video access)
- ✅ **READ_EXTERNAL_STORAGE** - For Android 12 and below (file access)
- ✅ **WRITE_EXTERNAL_STORAGE** - For Android 12 and below (file saving)
- ✅ **CAMERA** - For QR scanning, image capture, and text extraction
- ✅ **Camera Hardware** - Required for camera features

#### Queries (Android 11+ Package Visibility):
- ✅ **PROCESS_TEXT** - For text processing
- ✅ **VIEW (https/http)** - For url_launcher browser selection
- ✅ **GET_CONTENT** - For file_picker document access
- ✅ **OPEN_DOCUMENT** - For file_picker document access
- ✅ **SEND** - For share_plus sharing functionality

#### Build Configuration:
- ✅ **minSdk = 23** - Required for mobile_scanner
- ✅ **ProGuard Rules** - Added for all packages

### iOS Configuration (`ios/Runner/Info.plist`)

#### Permissions:
- ✅ **NSPhotoLibraryUsageDescription** - Photo library access for image picking
- ✅ **NSPhotoLibraryAddUsageDescription** - Save images to photo library
- ✅ **NSCameraUsageDescription** - Camera access for QR scanning and photos
- ✅ **NSDocumentsFolderUsageDescription** - Document access for PDF files
- ✅ **NSMicrophoneUsageDescription** - Microphone access (for video features)

#### Build Configuration:
- ✅ **iOS 12.0+** - Required for mobile_scanner (set in Podfile)

### Package Requirements

#### All Packages Configured:
1. ✅ **file_picker** - Document and file selection
2. ✅ **image_picker** - Image and photo selection
3. ✅ **google_mlkit_text_recognition** - OCR text extraction
4. ✅ **share_plus** - Share functionality
5. ✅ **syncfusion_flutter_pdf** - PDF text extraction
6. ✅ **mobile_scanner** - QR/Barcode scanning
7. ✅ **url_launcher** - Open URLs and browser selection
8. ✅ **qr_flutter** - QR code generation
9. ✅ **path_provider** - File system access
10. ✅ **get** - State management and navigation
11. ✅ **get_storage** - Local storage
12. ✅ **provider** - State management
13. ✅ **sqflite** - Database
14. ✅ **signature** - Signature functionality
15. ✅ **image** - Image processing

### ProGuard Rules (`android/app/proguard-rules.pro`)

✅ All packages have ProGuard rules to prevent obfuscation issues in release builds:
- ML Kit classes
- Syncfusion classes
- QR Flutter classes
- Mobile Scanner classes
- File picker classes
- Image picker classes
- Share plus classes
- URL launcher classes
- And all other packages

### Testing Checklist

Before testing, ensure:
- [ ] Run `flutter pub get`
- [ ] For Android: Clean build (`cd android && ./gradlew clean && cd ..`)
- [ ] For iOS: Run `cd ios && pod install && cd ..`
- [ ] Rebuild the app (not just hot reload)
- [ ] Test on real device (camera doesn't work on emulators)
- [ ] Grant all permissions when prompted

### Common Issues & Solutions

1. **MissingPluginException**: 
   - Solution: Run `flutter clean` then rebuild

2. **Permission Denied**:
   - Solution: Grant permissions in device settings

3. **Camera Not Working**:
   - Solution: Test on real device, not emulator

4. **Browser Picker Not Showing**:
   - Solution: Ensure queries are in AndroidManifest.xml

5. **File Access Issues**:
   - Solution: Check storage permissions are granted

### Notes

- All permissions have user-friendly descriptions
- Android uses different permissions for API 33+ vs older versions
- iOS requires permission descriptions for all sensitive features
- ProGuard rules prevent release build issues
- Package visibility queries ensure Android 11+ compatibility

