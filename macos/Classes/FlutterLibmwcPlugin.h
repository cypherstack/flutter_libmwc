#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

const char *mwc_wallet_init(const char *config,
                            const char *mnemonic,
                            const char *password,
                            const char *name);

const char *mwc_get_mnemonic(void);

const char *mwc_rust_open_wallet(const char *config, const char *password);

const char *mwc_rust_wallet_balances(const char *wallet,
                                     const char *refresh,
                                     const char *min_confirmations);

const char *mwc_rust_recover_from_mnemonic(const char *config,
                                           const char *password,
                                           const char *mnemonic,
                                           const char *name);

const char *mwc_rust_wallet_scan_outputs(const char *wallet,
                                         const char *start_height,
                                         const char *number_of_blocks);

const char *mwc_rust_create_tx(const char *wallet,
                               const char *amount,
                               const char *to_address,
                               const char *secret_key_index,
                               const char *mwcmqs_config,
                               const char *confirmations,
                               const char *note);

const char *mwc_rust_txs_get(const char *wallet, const char *refresh_from_node);

const char *mwc_rust_tx_cancel(const char *wallet, const char *tx_id);

const char *mwc_rust_get_chain_height(const char *config);

const char *mwc_rust_delete_wallet(const char *_wallet, const char *config);

const char *mwc_rust_tx_send_http(const char *wallet,
                                  const char *selection_strategy_is_use_all,
                                  const char *minimum_confirmations,
                                  const char *message,
                                  const char *amount,
                                  const char *address);

const char *mwc_rust_get_wallet_address(const char *wallet,
                                        const char *index,
                                        const char *mwcmqs_config);

const char *mwc_rust_validate_address(const char *address);

const char *mwc_rust_get_tx_fees(const char *wallet,
                                 const char *c_amount,
                                 const char *min_confirmations);

const char *mwc_rust_init_logs(const char *config);

const char *mwc_rust_encode_slatepack(const char *slate_json, const char *recipient_address);

const char *mwc_rust_encode_slatepack_enhanced(const char *wallet,
                                               const char *slate_json,
                                               const char *recipient_address);

const char *mwc_rust_decode_slatepack(const char *slatepack_str);

const char *mwc_rust_decode_slatepack_enhanced(const char *wallet, const char *slatepack_str);

const char *mwc_rust_tx_receive(const char *wallet, const char *slate_json);

const char *mwc_rust_tx_finalize(const char *wallet, const char *slate_json);

const char *mwc_rust_tx_init(const char *wallet,
                             const char *selection_strategy_is_use_all,
                             const char *minimum_confirmations,
                             const char *message,
                             const char *amount);

void *mwc_rust_mwcmqs_listener_start(const char *wallet, const char *mwcmqs_config);

const char *mwc_listener_cancel(void *handler);
