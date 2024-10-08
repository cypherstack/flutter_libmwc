#import "FlutterLibmwcPlugin.h"
#if __has_include(<flutter_libmwc/flutter_libmwc-Swift.h>)
#import <flutter_libmwc/flutter_libmwc-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_libmwc-Swift.h"
#endif

@implementation FlutterLibmwcPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterLibmwcPlugin registerWithRegistrar:registrar];
}
@end
