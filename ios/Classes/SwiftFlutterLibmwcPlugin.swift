import Flutter
import UIKit

public class SwiftFlutterLibmwcPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_libmwc", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterLibmwcPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }

// TODO whenever mwc is updated with new functions, they need to be dummy called here.
    public func dummyMethodToEnforceBundling() {
    mwc_wallet_init("const char *config",
                "const char *mnemonic",
                "const char *password",
                "const char *name");
    mwc_get_mnemonic();
    mwc_rust_open_wallet("const char *config",
                     "const char *password");
    mwc_rust_wallet_balances("const char *wallet", "const char *refresh", "const char *min_confirmations");
    mwc_rust_recover_from_mnemonic("const char *config",
                               "const char *password",
                               "const char *mnemonic",
                               "const char *name");

    mwc_rust_wallet_scan_outputs("const char *wallet",
                             "const char *start_height", "onst char *number_of_blocks");

    mwc_rust_create_tx("const char *wallet",
                   "const char *amount",
                   "const char *to_address",
                   "const char *secret_key_index", "const char *mwcmqs_config",
                   "const char *minimum_confirmations", "const char *note");
    mwc_rust_txs_get("const char *wallet",
                 "const char *refresh_from_node");
    mwc_rust_tx_cancel("const char *wallet", "const char *tx_id");

    mwc_rust_get_chain_height("const char *config");
    mwc_rust_delete_wallet("const char *wallet",
                       "const char *mwcmqs_config");
    mwc_rust_get_wallet_address("const char *wallet", "const char *index", "const char *mwcmqs_config");
    mwc_rust_validate_address("const char *address");
    mwc_rust_get_tx_fees("const char *wallet", "const char *c_amount", "const char *min_confirmations");

    mwc_rust_tx_send_http("const char *wallet", "const char *selection_strategy_is_use_all","const char *minimum_confirmations",
                      "const char *message",
                      "const char *amount",
                      "const char *address");

    mwc_rust_mwcmqs_listener_start("const char *wallet",
                                    "const char *mwcmqs_config");

    mwc_listener_cancel("const char *handler");
      // ...
      // This code will force the bundler to use these functions, but will never be called
    }
}
