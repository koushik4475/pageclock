import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/features/app_update/apk_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/pageclock/apk_installer');
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pageclock-installer-test-');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('passes the verified APK path to Android and reports installer launch', () async {
    final apk = File('${tempDirectory.path}/verified-update.apk');
    await apk.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);
    MethodCall? receivedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return true;
    });

    final result = await AndroidApkInstallerChannel(channel: channel).install(apk);

    expect(result.success, isTrue);
    expect(receivedCall?.method, 'installApk');
    expect(receivedCall?.arguments, {'path': apk.absolute.path});
  });

  test('does not invoke Android when the verified APK is missing', () async {
    var invoked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invoked = true;
      return true;
    });

    final missingApk = File('${tempDirectory.path}/missing.apk');
    final result =
        await AndroidApkInstallerChannel(channel: channel).install(missingApk);

    expect(result.success, isFalse);
    expect(result.message, contains('no longer available'));
    expect(invoked, isFalse);
  });

  test('fails closed when Android does not confirm that the installer opened', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);

    final apk = File('${tempDirectory.path}/unconfirmed.apk');
    await apk.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);

    final result = await AndroidApkInstallerChannel(channel: channel).install(apk);

    expect(result.success, isFalse);
    expect(result.message, contains('did not confirm'));
  });

  test('surfaces native Package Installer errors without opening the share sheet', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'NO_PACKAGE_INSTALLER',
        message: 'Android Package Installer is unavailable.',
      );
    });

    final apk = File('${tempDirectory.path}/installer-error.apk');
    await apk.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);

    final result = await AndroidApkInstallerChannel(channel: channel).install(apk);

    expect(result.success, isFalse);
    expect(result.message, 'Android Package Installer is unavailable.');
  });
}
