# Logo Image Setup

## Instructions

1. **Add the logo image file:**
   - Place your logo image file in this directory (`assets/images/`)
   - Name it: `logo.png`
   - Recommended size: 512x512 pixels or higher (for best quality)
   - Format: PNG with transparent background (preferred) or white background

2. **File location:**
   ```
   assets/images/logo.png
   ```

3. **After adding the image:**
   - Run `flutter pub get` to ensure assets are registered
   - The logo will automatically appear in:
     - Splash Screen
     - Home Screen App Bar
     - Onboarding Screen
     - Any other screens using the `AppLogo` widget

## Usage

The logo is implemented using the `AppLogo` widget located at:
```
lib/Widget/app_logo.dart
```

You can use it anywhere in your app:
```dart
import '../Widget/app_logo.dart';

// Basic usage
AppLogo(width: 40, height: 40)

// Custom size and border radius
AppLogo(
  width: 120,
  height: 120,
  borderRadius: 20,
)
```

## Fallback

If the logo image is not found, the widget will automatically show a fallback icon with gradient colors matching your app theme.

