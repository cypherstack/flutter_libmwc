use std::sync::Arc;
use mwc_util::Mutex;
use mwc_wallet_impls::{DefaultLCProvider, HTTPNodeClient};
use mwc_wallet_libwallet::{Error, WalletInst, Slate, SlateVersion, SlatePurpose};
use mwc_wallet_libwallet::slatepack::Slatepacker;
use mwc_keychain::ExtKeychain;
use ed25519_dalek::{PublicKey as DalekPublicKey, SecretKey as DalekSecretKey};
use mwc_util::secp::Secp256k1;

/// Wallet type (same as in wallet.rs).
pub type Wallet = Arc<
    Mutex<
        Box<
            dyn WalletInst<
                'static,
                DefaultLCProvider<'static, HTTPNodeClient, ExtKeychain>,
                HTTPNodeClient,
                ExtKeychain,
            >,
        >,
    >,
>;

/// Encode a slate into slatepack format with optional encryption.
/// 
/// # Arguments
/// * `slate_json` - JSON representation of the slate
/// * `recipient_address` - Optional recipient address for encryption (None for unencrypted).
/// * `sender_secret` - Optional sender secret key for encryption.
/// 
/// # Returns
/// * Result containing the armored slatepack string or error.
pub fn encode_slatepack(
    slate_json: &str,
    recipient_address: Option<&str>,
) -> Result<String, Error> {
    encode_slatepack_with_keys(slate_json, recipient_address, None)
}

/// Encode a slate into slatepack format with optional encryption and custom keys.
/// 
/// # Arguments
/// * `slate_json` - JSON representation of the slate
/// * `recipient_address` - Optional recipient address for encryption (None for unencrypted).
/// * `sender_secret` - Optional sender secret key for encryption.
/// 
/// # Returns
/// * Result containing the armored slatepack string or error.
/// 
/// # Note
/// For production use, always provide sender_secret derived from wallet.
/// Using None for sender_secret in encrypted mode will return an error.
pub fn encode_slatepack_with_keys(
    slate_json: &str,
    recipient_address: Option<&str>,
    sender_secret: Option<&DalekSecretKey>,
) -> Result<String, Error> {
    // Deserialize the slate to validate it.
    let slate = Slate::deserialize_upgrade_plain(slate_json)?;
    
    // Create secp context.
    let secp = Secp256k1::new();
    
    let (sender_key, sender_secret_key, recipient_key) = if let Some(recipient_addr) = recipient_address {
        // For encrypted slatepacks, we require a real sender secret key from wallet.
        let sender_secret_key_ref = sender_secret
            .ok_or_else(|| Error::GenericError(
                "Sender secret key is required for encrypted slatepacks. Please provide wallet context.".to_string()
            ))?;

        // Create a new secret key from the bytes (since DalekSecretKey doesn't implement Clone).
        let sender_secret_key = DalekSecretKey::from_bytes(&sender_secret_key_ref.to_bytes())
            .map_err(|e| Error::GenericError(format!("Failed to create sender secret key: {:?}", e)))?;

        let sender_public = DalekPublicKey::from(&sender_secret_key);

        // Accept either a raw hex ed25519 public key (64 hex chars), or an MWCMQS-style
        // address where the left part before '@' encodes the public key as hex.
        let recipient_public = parse_recipient_public_key(recipient_addr)?;

        (sender_public, sender_secret_key, Some(recipient_public))
    } else {
        // For unencrypted slatepacks, use dummy keys (this is acceptable for unencrypted).
        let dummy_secret = DalekSecretKey::from_bytes(&[1u8; 32])
            .map_err(|e| Error::GenericError(format!("Failed to create dummy key: {:?}", e)))?;
        let dummy_sender = DalekPublicKey::from(&dummy_secret);
        
        (dummy_sender, dummy_secret, None)
    };
    
    // Choose appropriate SlatePurpose based on the slate state, aligning with mwc713 behavior.
    let purpose = infer_slate_purpose(&slate);

    let armored = Slatepacker::encrypt_to_send(
        slate,
        SlateVersion::SP,
        purpose,
        sender_key,
        recipient_key,
        &sender_secret_key,
        false, // use_test_rng = false.
        &secp,
    )?;
    
    Ok(armored)
}

/// Infer the best SlatePurpose for encoding based on the slate's current state.
/// This mirrors mwc713's approach of preserving content/purpose for the current step.
fn infer_slate_purpose(slate: &Slate) -> SlatePurpose {
    // Infer stage from how many participant partial signatures are present.
    // Two-party flow heuristics:
    // - 0 partial signatures -> SendInitial (S1)
    // - 1 partial signature  -> SendResponse (S2)
    // - >=2 partial signatures -> FullSlate (final/other)
    if slate.num_participants == 2 && !slate.participant_data.is_empty() {
        let sig_count = slate
            .participant_data
            .iter()
            .filter(|p| p.part_sig.is_some())
            .count();
        return match sig_count {
            0 => SlatePurpose::SendInitial,
            1 => SlatePurpose::SendResponse,
            _ => SlatePurpose::FullSlate,
        };
    }

    // Fallback for other flows (invoice, multi-party, etc.)
    SlatePurpose::FullSlate
}

/// Parse an MWCMQS address to extract the public key for encryption.
/// 
/// # Arguments
/// * `address` - The MWCMQS address string (e.g., "gTesT...@mwcmqs.mwc.mw:443").
/// 
/// # Returns
/// * Result containing the DalekPublicKey or error.
fn parse_recipient_public_key(input: &str) -> Result<DalekPublicKey, Error> {
    // Case 1: raw hex pubkey
    let try_hex = |s: &str| -> Result<DalekPublicKey, Error> {
        let bytes = mwc_util::from_hex(s).map_err(|e| Error::GenericError(format!(
            "Failed to decode recipient public key hex: {}", e
        )))?;
        if bytes.len() != 32 {
            return Err(Error::GenericError(format!(
                "Invalid recipient public key length: expected 32 bytes, got {}",
                bytes.len()
            )));
        }
        DalekPublicKey::from_bytes(&bytes)
            .map_err(|e| Error::GenericError(format!("Invalid recipient public key: {:?}", e)))
    };

    if !input.contains('@') {
        // Treat as raw hex ed25519 public key (as returned by decode for sender/recipient)
        return try_hex(input);
    }

    // Case 2: address with '@' — take left side as hex public key
    let parts: Vec<&str> = input.split('@').collect();
    if parts.is_empty() || parts[0].is_empty() {
        return Err(Error::GenericError("Invalid recipient address (missing public key)".to_string()));
    }
    try_hex(parts[0])
}

/// Decode a slatepack into slate JSON.
/// 
/// # Arguments
/// * `slatepack_str` - The slatepack string to decode.
/// 
/// # Returns
/// * Result containing tuple of (slate_json, sender_info, recipient_info) or error.
pub fn decode_slatepack(
    slatepack_str: &str,
) -> Result<(String, Option<String>, Option<String>), Error> {
    decode_slatepack_with_wallet(slatepack_str, None)
}

/// Decode a slatepack into slate JSON with wallet context for encrypted slatepacks.
/// 
/// # Arguments
/// * `slatepack_str` - The slatepack string to decode.
/// * `wallet` - Optional wallet for encrypted slatepack decryption.
/// 
/// # Returns
/// * Result containing tuple of (slate_json, sender_info, recipient_info) or error.
pub fn decode_slatepack_with_wallet(
    slatepack_str: &str,
    wallet: Option<&Wallet>,
) -> Result<(String, Option<String>, Option<String>), Error> {
    // Create secp context.
    let secp = Secp256k1::new();
    
    // Try to determine if this is an encrypted slatepack by attempting to decode it.
    let slatepacker = if let Some(wallet_inst) = wallet {
        // For encrypted slatepacks, get the wallet's secret key.
        let secret_key = get_wallet_secret_key(wallet_inst)?;
        
        Slatepacker::decrypt_slatepack(
            slatepack_str.as_bytes(),
            &secret_key,
            0, // height - use 0 for testing.  
            &secp,
        )?
    } else {
        // Try with dummy key first (for unencrypted slatepacks).
        let dummy_secret = DalekSecretKey::from_bytes(&[1u8; 32])
            .map_err(|e| Error::GenericError(format!("Failed to create dummy key: {:?}", e)))?;
        
        match Slatepacker::decrypt_slatepack(
            slatepack_str.as_bytes(),
            &dummy_secret,
            0,
            &secp,
        ) {
            Ok(sp) => sp,
            Err(_) => {
                // If dummy key failed, this might be encrypted. Return error suggesting wallet is needed.
                return Err(Error::GenericError(
                    "Failed to decode slatepack. It may be encrypted and require wallet access.".to_string()
                ));
            }
        }
    };
    
    // Extract sender and recipient info before consuming slatepacker.
    let sender_info = slatepacker.get_sender()
        .map(|key| mwc_util::to_hex(key.as_bytes())); // Convert public key to hex string.
    let recipient_info = slatepacker.get_recipient()
        .map(|key| mwc_util::to_hex(key.as_bytes())); // Convert public key to hex string.
    
    // Extract the slate and convert to JSON.
    let slate = slatepacker.to_result_slate();
    let slate_json = serde_json::to_string(&slate)
        .map_err(|e| Error::GenericError(format!("Failed to serialize slate to JSON: {}", e)))?;
    
    Ok((slate_json, sender_info, recipient_info))
}

/// Get the wallet's secret key for slatepack decryption.
/// 
/// # Arguments
/// * `wallet` - The wallet instance.
/// 
/// # Returns
/// * Result containing the DalekSecretKey or error.
fn get_wallet_secret_key(wallet: &Wallet) -> Result<DalekSecretKey, Error> {
    use crate::get_wallet_secret_key_pair;
    
    // Get the wallet's secret key for MWCMQS/slatepack operations.
    // Use index 0 as the default derivation index.
    let (dalek_secret, _dalek_public) = get_wallet_secret_key_pair(wallet, None, 0)?;
    
    Ok(dalek_secret)
}

/// Enhanced encode function that can get sender key from wallet.
pub fn encode_slatepack_with_wallet(
    slate_json: &str,
    recipient_address: Option<&str>,
    wallet: Option<&Wallet>,
) -> Result<String, Error> {
    let sender_secret = if let Some(wallet_inst) = wallet {
        Some(get_wallet_secret_key(wallet_inst)?)
    } else {
        None
    };
    
    encode_slatepack_with_keys(slate_json, recipient_address, sender_secret.as_ref())
}
