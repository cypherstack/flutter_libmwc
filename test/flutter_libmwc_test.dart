import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_limwc/flutter_limwc.dart';
import 'package:flutter_limwc/flutter_limwc_platform_interface.dart';
import 'package:flutter_limwc/flutter_limwc_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterLimwcPlatform
    with MockPlatformInterfaceMixin
    implements FlutterLimwcPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterLimwcPlatform initialPlatform = FlutterLimwcPlatform.instance;

  test('$MethodChannelFlutterLimwc is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterLimwc>());
  });

  test('getPlatformVersion', () async {
    FlutterLimwc flutterLimwcPlugin = FlutterLimwc();
    MockFlutterLimwcPlatform fakePlatform = MockFlutterLimwcPlatform();
    FlutterLimwcPlatform.instance = fakePlatform;

    expect(await flutterLimwcPlugin.getPlatformVersion(), '42');
  });
}
