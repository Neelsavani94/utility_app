# Mobile Scanner Setup Instructions

## ✅ Configuration Already Done:
- ✅ Android minSdk set to 23 in `android/app/build.gradle.kts`
- ✅ iOS platform set to 12.0 in `ios/Podfile`
- ✅ Camera permissions added to AndroidManifest.xml
- ✅ Camera permissions added to Info.plist
- ✅ Packages installed (`mobile_scanner` and `url_launcher`)

## 🔧 Required Steps to Fix MissingPluginException:

### **IMPORTANT: You MUST rebuild the app (not hot reload)**

### For Android:

1. **Stop the app completely** (close it from recent apps)

2. **Clean and rebuild:**
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

### For iOS:

1. **Stop the app completely**

2. **Clean and rebuild:**
```bash
flutter clean
cd ios
pod deintegrate
pod install
cd ..
flutter pub get
flutter run
```

### ⚠️ Common Issues:

1. **MissingPluginException**: This happens when the app wasn't rebuilt after adding the package
   - Solution: Run `flutter clean` then rebuild

2. **Camera not working on emulator**: 
   - Solution: Use a real device (camera doesn't work on Android emulator or iOS simulator)

3. **Permission denied**:
   - Solution: Grant camera permission when prompted, or go to device settings

### 📱 Testing:
- ✅ Test on a **real device** (not emulator/simulator)
- ✅ Grant camera permissions when prompted
- ✅ The scanner opens in full screen
- ✅ QR codes and barcodes are detected automatically

### 🔄 If Still Not Working:

1. **Completely uninstall the app** from your device
2. **Run these commands:**
```bash
flutter clean
flutter pub get
# For Android:
cd android && ./gradlew clean && cd ..
# For iOS:
cd ios && pod install && cd ..
```
3. **Rebuild and install fresh:**
```bash
flutter run
```

### ✅ Verification:
After rebuilding, the QR Reader should:
- Open full screen camera view
- Show scanning frame
- Detect QR codes and barcodes automatically
- Show popup with scanned text
- Search and Share buttons should work

