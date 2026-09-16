import 'dart:io';

const applicationId = 'br.edu.ete.lixeirainteligente';
const displayName = 'Lixeira Inteligente';
const iosMinimum = '15.5';

void main() {
  _configureAndroid();
  _configureIos();
  stdout.writeln('Lixeira Inteligente: configuracoes Android/iOS aplicadas.');
}

void _configureAndroid() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    var text = manifest.readAsStringSync();
    text = text.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="$displayName"');

    if (!text.contains('android.permission.INTERNET')) {
      text = text.replaceFirst(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <uses-permission android:name="android.permission.INTERNET"/>',
      );
    }
    if (!text.contains('android.permission.CAMERA')) {
      text = text.replaceFirst(
        '<application',
        '    <uses-permission android:name="android.permission.CAMERA"/>\n'
            '    <uses-feature android:name="android.hardware.camera" android:required="false"/>\n'
            '    <application',
      );
    } else if (!text.contains('android.hardware.camera')) {
      text = text.replaceFirst(
        '<application',
        '    <uses-feature android:name="android.hardware.camera" android:required="false"/>\n'
            '    <application',
      );
    }
    manifest.writeAsStringSync(text);
  }

  _configureGradle(File('android/app/build.gradle'));
  _configureGradleKts(File('android/app/build.gradle.kts'));
  _configureMainActivity();
  _configureAndroidBranding();
}

void _configureGradle(File file) {
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  text = text.replaceAll(RegExp(r'namespace\s*=\s*"[^"]+"'), 'namespace = "$applicationId"');
  text = text.replaceAll(RegExp(r'applicationId\s*=\s*"[^"]+"'), 'applicationId = "$applicationId"');
  text = text.replaceAll(RegExp(r'minSdk\s*=\s*[^\r\n]+'), 'minSdk = 24');
  text = text.replaceAll(RegExp(r'minSdkVersion\s+[^\r\n]+'), 'minSdkVersion 24');
  text = text.replaceAll('JavaVersion.VERSION_11', 'JavaVersion.VERSION_17');
  file.writeAsStringSync(text);
}

void _configureGradleKts(File file) {
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  text = text.replaceAll(RegExp(r'namespace\s*=\s*"[^"]+"'), 'namespace = "$applicationId"');
  text = text.replaceAll(RegExp(r'applicationId\s*=\s*"[^"]+"'), 'applicationId = "$applicationId"');
  text = text.replaceAll(RegExp(r'minSdk\s*=\s*[^\r\n]+'), 'minSdk = 24');
  text = text.replaceAll('JavaVersion.VERSION_11', 'JavaVersion.VERSION_17');
  file.writeAsStringSync(text);
}

void _configureMainActivity() {
  final kotlinRoot = Directory('android/app/src/main/kotlin');
  final javaRoot = Directory('android/app/src/main/java');
  for (final root in [kotlinRoot, javaRoot]) {
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && (entity.path.endsWith('MainActivity.kt') || entity.path.endsWith('MainActivity.java'))) {
        entity.deleteSync();
      }
    }
  }

  final dir = Directory('android/app/src/main/kotlin/br/edu/ete/lixeirainteligente');
  dir.createSync(recursive: true);
  File('${dir.path}/MainActivity.kt').writeAsStringSync('''package $applicationId

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
''');
}


void _configureAndroidBranding() {
  for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
    final source = Directory('assets/branding/android/mipmap-$density');
    final target = Directory('android/app/src/main/res/mipmap-$density')..createSync(recursive: true);
    if (source.existsSync()) {
      for (final entity in source.listSync()) {
        if (entity is File) entity.copySync('${target.path}/${entity.uri.pathSegments.last}');
      }
    }
  }

  final drawable = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item><shape android:shape="rectangle"><solid android:color="#063E35"/></shape></item>
    <item><bitmap android:gravity="center" android:src="@mipmap/launch_image" /></item>
</layer-list>
''';
  for (final path in [
    'android/app/src/main/res/drawable/launch_background.xml',
    'android/app/src/main/res/drawable-v21/launch_background.xml',
  ]) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(drawable);
  }

  final v31 = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#063E35</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher</item>
        <item name="android:windowSplashScreenIconBackgroundColor">#063E35</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">#063E35</item>
    </style>
</resources>
''';
  for (final path in [
    'android/app/src/main/res/values-v31/styles.xml',
    'android/app/src/main/res/values-night-v31/styles.xml',
  ]) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(v31);
  }
}

void _configureIosBranding() {
  final mappings = <String, String>{
    'assets/branding/ios/AppIcon.appiconset': 'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    'assets/branding/ios/LaunchImage.imageset': 'ios/Runner/Assets.xcassets/LaunchImage.imageset',
  };
  for (final entry in mappings.entries) {
    final source = Directory(entry.key);
    final target = Directory(entry.value)..createSync(recursive: true);
    if (!source.existsSync()) continue;
    for (final entity in source.listSync()) {
      if (entity is File) entity.copySync('${target.path}/${entity.uri.pathSegments.last}');
    }
  }
  final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard');
  if (storyboard.existsSync()) {
    var text = storyboard.readAsStringSync();
    text = text.replaceAll(
      RegExp(r'<color key="backgroundColor"[^>]*/>'),
      '<color key="backgroundColor" red="0.0235" green="0.2431" blue="0.2078" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
    );
    storyboard.writeAsStringSync(text);
  }
}

void _configureIos() {
  final plist = File('ios/Runner/Info.plist');
  if (plist.existsSync()) {
    var text = plist.readAsStringSync();
    text = _replacePlistString(text, 'CFBundleDisplayName', displayName);
    text = _replacePlistString(text, 'CFBundleName', displayName);
    if (!text.contains('NSCameraUsageDescription')) {
      text = text.replaceFirst(
        '</dict>',
        '''\t<key>NSCameraUsageDescription</key>\n\t<string>A camera e usada para identificar materiais reciclaveis.</string>\n</dict>''',
      );
    }
    plist.writeAsStringSync(text);
  }

  final podfile = File('ios/Podfile');
  if (podfile.existsSync()) {
    var text = podfile.readAsStringSync();
    final platformPattern = RegExp(r"^#?\s*platform :ios, '[^']+'", multiLine: true);
    if (platformPattern.hasMatch(text)) {
      text = text.replaceFirst(platformPattern, "platform :ios, '$iosMinimum'");
    } else {
      text = "platform :ios, '$iosMinimum'\n\n$text";
    }
    podfile.writeAsStringSync(text);
  }

  final frameworkInfo = File('ios/Flutter/AppFrameworkInfo.plist');
  if (frameworkInfo.existsSync()) {
    var text = frameworkInfo.readAsStringSync();
    text = text.replaceAllMapped(
      RegExp(r'(<key>MinimumOSVersion</key>\s*<string>)[^<]+(</string>)'),
      (match) => '${match.group(1)}$iosMinimum${match.group(2)}',
    );
    frameworkInfo.writeAsStringSync(text);
  }

  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  _configureIosBranding();

  if (project.existsSync()) {
    var text = project.readAsStringSync();
    text = text.replaceAllMapped(
      RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);'),
      (match) {
        final current = match.group(1) ?? '';
        final suffix = current.contains('RunnerTests') ? '.RunnerTests' : '';
        return 'PRODUCT_BUNDLE_IDENTIFIER = $applicationId$suffix;';
      },
    );
    text = text.replaceAll(RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = [^;]+;'), 'IPHONEOS_DEPLOYMENT_TARGET = $iosMinimum;');
    project.writeAsStringSync(text);
  }
}

String _replacePlistString(String text, String key, String value) {
  final pattern = RegExp('<key>${RegExp.escape(key)}</key>\\s*<string>[^<]*</string>');
  final replacement = '<key>$key</key>\n\t<string>$value</string>';
  if (pattern.hasMatch(text)) return text.replaceFirst(pattern, replacement);
  return text;
}
