use std::ffi::CString;
use std::os::raw::c_char;

/// Release the string returned by `mwc_rust_open_wallet`, including errors.
///
/// # Safety
/// `value` must be null or an unmodified pointer returned by that function.
/// A non-null pointer must be released exactly once and never used afterwards.
/// This frees the serialized string, not the wallet it describes.
#[no_mangle]
pub unsafe extern "C" fn mwc_string_free(value: *mut c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn releases_empty_unicode_and_large_strings() {
        for text in [String::new(), "wallet é 🔑".to_string(), "x".repeat(65536)] {
            let value = CString::new(text).unwrap().into_raw();
            unsafe { mwc_string_free(value) };
        }
    }

    #[test]
    fn accepts_null() {
        unsafe { mwc_string_free(std::ptr::null_mut()) };
    }
}
