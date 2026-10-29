import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_colors.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';

/// Platform configuration no Dart test would otherwise notice: app id, minimum Android version, the name and icon on
/// the launcher, the native splash screens (light only, ready for the Flutter LaunchSplash to take over), the push
/// icon, network permission, and the bundled font. Run from the package root, as `flutter test` does.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'expected $path (run `flutter test` from the package root)');
    return file.readAsStringSync();
  }

  /// XML text with `&#x200C;`-style character references resolved.
  String decodeXml(String text) => text.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
  );

  String withoutComments(String xml) => xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  Color hex(String value) => Color(int.parse('FF${value.substring(1)}', radix: 16));

  // The brand's source (branding/mark.json, one folder up), which every raster is rendered from.
  final brand = jsonDecode(File('../branding/mark.json').readAsStringSync()) as Map<String, dynamic>;
  final tile = brand['tile'] as Map<String, dynamic>;

  group('Android', () {
    const res = 'android/app/src/main/res';
    const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
    late String gradle;
    late String manifest;
    late Map<String, Color> colors;

    String resource(String path) => withoutComments(read('$res/$path'));

    /// The value of `<item name="[name]">` in the `<style name="[style]">` of a styles file.
    String? item(String styles, String style, String name) {
      final body = RegExp('<style name="$style"[^>]*>(.*?)</style>', dotAll: true).firstMatch(styles)?.group(1);
      return body == null ? null : RegExp('<item name="$name">([^<]*)</item>').firstMatch(body)?.group(1)?.trim();
    }

    String? parentOf(String styles, String style) =>
        RegExp('<style name="$style" parent="([^"]+)"').firstMatch(styles)?.group(1);

    String? metaData(String name) => RegExp(
      '<meta-data\\s+android:name="${RegExp.escape(name)}"\\s+android:resource="([^"]+)"',
    ).firstMatch(manifest)?.group(1);

    void expectEveryDensity(String folder, String file) {
      for (final density in densities) {
        expect(File('$res/$folder-$density/$file').existsSync(), isTrue, reason: '$folder-$density/$file');
      }
    }

    setUpAll(() {
      gradle = read('android/app/build.gradle.kts');
      manifest = withoutComments(read('android/app/src/main/AndroidManifest.xml'));
      colors = {
        for (final m in RegExp(
          r'<color name="([^"]+)">(#[0-9A-Fa-f]{6})</color>',
        ).allMatches(resource('values/colors.xml')))
          m.group(1)!: hex(m.group(2)!),
      };
    });

    test('the application id is ir.rallyto.app', () {
      expect(gradle, contains('applicationId = "ir.rallyto.app"'));
    });

    test('the minimum SDK is 23 or higher', () {
      final minSdk = int.parse(RegExp(r'minSdk = (\d+)').firstMatch(gradle)!.group(1)!);
      expect(minSdk, greaterThanOrEqualTo(23));
    });

    test('the launcher label is the app name «رالیتو»', () {
      final label = RegExp(r'android:label="([^"]*)"').firstMatch(manifest)!.group(1)!;
      expect(decodeXml(label), AppStrings.appName);
    });

    test('release builds may use the network', () {
      expect(manifest, contains('android.permission.INTERNET'));
    });

    test('the launcher icon is adaptive: the mark on the tile gradient, and the mark alone for themed icons', () {
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      final icon = resource('mipmap-anydpi-v26/ic_launcher.xml');
      String layer(String name) => RegExp('<$name android:drawable="([^"]+)"').firstMatch(icon)!.group(1)!;
      expect(layer('background'), '@drawable/ic_launcher_background');
      expect(layer('foreground'), '@mipmap/ic_launcher_foreground');
      expect(layer('monochrome'), '@mipmap/ic_launcher_monochrome');

      final background = resource('drawable/ic_launcher_background.xml');
      String attribute(String name) => RegExp('android:$name="([^"]+)"').firstMatch(background)!.group(1)!;
      expect(hex(attribute('startColor')), hex(tile['gradientFrom'] as String), reason: 'mark.json › tile');
      expect(hex(attribute('endColor')), hex(tile['gradientTo'] as String), reason: 'mark.json › tile');
      expect(attribute('angle'), '315', reason: 'top-left to bottom-right');

      expectEveryDensity('mipmap', 'ic_launcher.png');
      expectEveryDensity('mipmap', 'ic_launcher_foreground.png');
      expectEveryDensity('mipmap', 'ic_launcher_monochrome.png');
    });

    test('the launch screen is the canvas with the 96dp tile centred, as the LaunchSplash starts', () {
      expect(colors['splash_background'], AppColors.canvas);
      for (final file in ['drawable/launch_background.xml', 'drawable-v21/launch_background.xml']) {
        final layers = resource(file);
        expect(layers, contains('<item android:drawable="@color/splash_background" />'), reason: file);
        final bitmap = RegExp(r'<bitmap([^>]*)/>').firstMatch(layers)?.group(1) ?? '';
        expect(bitmap, contains('android:gravity="center"'), reason: file);
        expect(bitmap, contains('android:src="@drawable/launch_mark"'), reason: file);
      }
      expectEveryDensity('drawable', 'launch_mark.png');
    });

    test('Android 12+ splash: the same canvas and tile, in dark mode too', () {
      for (final file in ['values-v31/styles.xml', 'values-night-v31/styles.xml']) {
        final styles = resource(file);
        expect(parentOf(styles, 'LaunchTheme'), '@android:style/Theme.Light.NoTitleBar', reason: file);
        expect(item(styles, 'LaunchTheme', 'android:windowSplashScreenBackground'), '@color/splash_background');
        expect(item(styles, 'LaunchTheme', 'android:windowSplashScreenAnimatedIcon'), '@drawable/splash_icon');
        expect(item(styles, 'LaunchTheme', 'android:windowBackground'), '@drawable/launch_background');
      }
      expectEveryDensity('drawable', 'splash_icon.png');
    });

    test('the app is light only: with Dark Mode on, the window keeps the light themes', () {
      for (final file in ['values/styles.xml', 'values-night/styles.xml']) {
        final styles = resource(file);
        expect(parentOf(styles, 'LaunchTheme'), '@android:style/Theme.Light.NoTitleBar', reason: file);
        expect(parentOf(styles, 'NormalTheme'), '@android:style/Theme.Light.NoTitleBar', reason: file);
        expect(item(styles, 'LaunchTheme', 'android:windowBackground'), '@drawable/launch_background');
      }
      final themes = Directory(res).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.xml'));
      for (final file in themes) {
        expect(withoutComments(file.readAsStringSync()), isNot(contains('Theme.Black')), reason: file.path);
      }
    });

    test('pushes the system shows carry the mark silhouette, tinted court green', () {
      expect(metaData('com.google.firebase.messaging.default_notification_icon'), '@drawable/ic_notification');
      expect(metaData('com.google.firebase.messaging.default_notification_color'), '@color/notification');
      expect(colors['notification'], AppColors.primary);
      expectEveryDensity('drawable', 'ic_notification.png');
    });

    test('the push channel the server posts to is created by the app and is the default', () {
      final server = read('../src/Contexts/Notifications/Rallyto.Notifications.Infrastructure/Push/FirebasePushGateway.cs');
      final channelId = RegExp(r'ChannelId = "([^"]+)"').firstMatch(server)!.group(1)!;
      final activity = read('android/app/src/main/kotlin/ir/rallyto/app/MainActivity.kt');
      expect(activity, contains('const val PUSH_CHANNEL_ID = "$channelId"'));
      expect(activity, contains('createNotificationChannel'));
      expect(
        RegExp(r'default_notification_channel_id"\s+android:value="([^"]+)"').firstMatch(manifest)?.group(1),
        channelId,
      );
    });
  });

  group('iOS', () {
    test('the display name is «رالیتو» and the bundle id ir.rallyto.app', () {
      final plist = read('ios/Runner/Info.plist');
      final name = RegExp(r'<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>').firstMatch(plist)!.group(1)!;
      expect(decodeXml(name), AppStrings.appName);
      expect(plist, contains('<string>fa</string>'), reason: 'CFBundleLocalizations declares Persian');
      expect(read('ios/Runner.xcodeproj/project.pbxproj'), contains('PRODUCT_BUNDLE_IDENTIFIER = ir.rallyto.app;'));
    });

    test('the launch screen is the canvas with the 96pt tile centred, as the LaunchSplash starts', () {
      final storyboard = read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      final background = RegExp(
        r'<color key="backgroundColor" red="([\d.]+)" green="([\d.]+)" blue="([\d.]+)" alpha="1" '
        r'colorSpace="custom" customColorSpace="sRGB"/>',
      ).firstMatch(storyboard)!;
      int channel(int group) => (double.parse(background.group(group)!) * 255).round();
      expect(Color.fromARGB(255, channel(1), channel(2), channel(3)), AppColors.canvas);

      expect(storyboard, contains('<image name="LaunchImage" width="96" height="96"/>'));
      expect(storyboard, contains('contentMode="center" image="LaunchImage"'));
      expect(storyboard, contains('firstAttribute="centerX"'));
      expect(storyboard, contains('firstAttribute="centerY"'));
      for (final suffix in ['', '@2x', '@3x']) {
        final png = 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png';
        expect(File(png).existsSync(), isTrue, reason: png);
      }
    });
  });

  test('the Vazir font is declared and bundled', () {
    final pubspec = read('pubspec.yaml');
    expect(pubspec, contains('family: Vazir'));
    for (final asset in RegExp(r'asset: (assets/fonts/vazir/\S+\.ttf)').allMatches(pubspec).map((m) => m.group(1)!)) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });
}
