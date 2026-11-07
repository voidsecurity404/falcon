//! The few primitives the proxy needs, from the system's libcrypto. No other library is used.
use std::ffi::{c_int, c_uint, c_void};
use std::ptr::{null, null_mut};

type Ptr = *mut c_void;
type Const = *const c_void;

#[link(name = "crypto")]
extern "C" {
    fn RAND_bytes(buf: *mut u8, num: c_int) -> c_int;
    fn EVP_sha256() -> Const;
    fn EVP_sha384() -> Const;
    fn EVP_sha512() -> Const;
    fn EVP_Digest(data: *const u8, count: usize, md: *mut u8, size: *mut c_uint, kind: Const, engine: Ptr) -> c_int;
    fn HMAC(evp: Const, key: *const u8, key_len: c_int, d: *const u8, n: usize, md: *mut u8, md_len: *mut c_uint) -> *mut u8;

    fn EVP_PKEY_new_raw_private_key(kind: c_int, engine: Ptr, key: *const u8, len: usize) -> Ptr;
    fn EVP_PKEY_new_raw_public_key(kind: c_int, engine: Ptr, key: *const u8, len: usize) -> Ptr;
    fn EVP_PKEY_get_raw_public_key(pkey: Ptr, out: *mut u8, len: *mut usize) -> c_int;
    fn EVP_PKEY_free(pkey: Ptr);
    fn EVP_PKEY_CTX_new(pkey: Ptr, engine: Ptr) -> Ptr;
    fn EVP_PKEY_CTX_free(ctx: Ptr);
    fn EVP_PKEY_derive_init(ctx: Ptr) -> c_int;
    fn EVP_PKEY_derive_set_peer(ctx: Ptr, peer: Ptr) -> c_int;
    fn EVP_PKEY_derive(ctx: Ptr, key: *mut u8, len: *mut usize) -> c_int;

    fn EVP_aes_128_gcm() -> Const;
    fn EVP_aes_256_gcm() -> Const;
    fn EVP_chacha20_poly1305() -> Const;
    fn EVP_CIPHER_CTX_new() -> Ptr;
    fn EVP_CIPHER_CTX_free(ctx: Ptr);
    fn EVP_CIPHER_CTX_ctrl(ctx: Ptr, kind: c_int, arg: c_int, ptr: *mut c_void) -> c_int;
    fn EVP_EncryptInit_ex(ctx: Ptr, cipher: Const, engine: Ptr, key: *const u8, iv: *const u8) -> c_int;
    fn EVP_EncryptUpdate(ctx: Ptr, out: *mut u8, out_len: *mut c_int, data: *const u8, len: c_int) -> c_int;
    fn EVP_EncryptFinal_ex(ctx: Ptr, out: *mut u8, out_len: *mut c_int) -> c_int;
    fn EVP_DecryptInit_ex(ctx: Ptr, cipher: Const, engine: Ptr, key: *const u8, iv: *const u8) -> c_int;
    fn EVP_DecryptUpdate(ctx: Ptr, out: *mut u8, out_len: *mut c_int, data: *const u8, len: c_int) -> c_int;
    fn EVP_DecryptFinal_ex(ctx: Ptr, out: *mut u8, out_len: *mut c_int) -> c_int;
}

const NID_X25519: c_int = 1034;
const CTRL_GET_TAG: c_int = 0x10;
const CTRL_SET_TAG: c_int = 0x11;
const TAG: usize = 16;

pub fn random(out: &mut [u8]) {
    let done = unsafe { RAND_bytes(out.as_mut_ptr(), out.len() as c_int) };
    assert_eq!(done, 1, "no random numbers");
}

#[derive(Clone, Copy, PartialEq)]
pub enum Hash {
    Sha256,
    Sha384,
    Sha512,
}

impl Hash {
    fn evp(self) -> Const {
        unsafe {
            match self {
                Hash::Sha256 => EVP_sha256(),
                Hash::Sha384 => EVP_sha384(),
                Hash::Sha512 => EVP_sha512(),
            }
        }
    }

    pub fn len(self) -> usize {
        match self {
            Hash::Sha256 => 32,
            Hash::Sha384 => 48,
            Hash::Sha512 => 64,
        }
    }

    pub fn digest(self, data: &[u8]) -> Vec<u8> {
        let mut out = vec![0; self.len()];
        let done = unsafe { EVP_Digest(data.as_ptr(), data.len(), out.as_mut_ptr(), null_mut(), self.evp(), null_mut()) };
        assert_eq!(done, 1, "digest failed");
        out
    }

    pub fn hmac(self, key: &[u8], data: &[u8]) -> Vec<u8> {
        let mut out = vec![0; self.len()];
        let done = unsafe { HMAC(self.evp(), key.as_ptr(), key.len() as c_int, data.as_ptr(), data.len(), out.as_mut_ptr(), null_mut()) };
        assert!(!done.is_null(), "hmac failed");
        out
    }

    /// One HKDF output of up to one hash length, which is all that TLS 1.3 and Reality ask for here.
    pub fn hkdf_expand(self, prk: &[u8], info: &[u8], len: usize) -> Vec<u8> {
        assert!(len <= self.len());
        let mut data = info.to_vec();
        data.push(1);
        let mut out = self.hmac(prk, &data);
        out.truncate(len);
        out
    }
}

/// X25519: the public key of a private key, and the secret shared with a peer.
pub struct X25519 {
    key: Ptr,
    pub public: [u8; 32],
}

impl X25519 {
    pub fn generate() -> X25519 {
        let mut private = [0u8; 32];
        random(&mut private);
        let mut public = [0u8; 32];
        let mut len = 32usize;
        unsafe {
            let key = EVP_PKEY_new_raw_private_key(NID_X25519, null_mut(), private.as_ptr(), 32);
            assert!(!key.is_null(), "no X25519");
            assert_eq!(EVP_PKEY_get_raw_public_key(key, public.as_mut_ptr(), &mut len), 1);
            X25519 { key, public }
        }
    }

    pub fn shared(&self, peer: &[u8]) -> Option<Vec<u8>> {
        let mut out = vec![0u8; 32];
        let mut len = 32usize;
        unsafe {
            let other = EVP_PKEY_new_raw_public_key(NID_X25519, null_mut(), peer.as_ptr(), peer.len());
            if other.is_null() {
                return None;
            }
            let ctx = EVP_PKEY_CTX_new(self.key, null_mut());
            let done = EVP_PKEY_derive_init(ctx) == 1
                && EVP_PKEY_derive_set_peer(ctx, other) == 1
                && EVP_PKEY_derive(ctx, out.as_mut_ptr(), &mut len) == 1;
            EVP_PKEY_CTX_free(ctx);
            EVP_PKEY_free(other);
            done.then_some(out)
        }
    }
}

impl Drop for X25519 {
    fn drop(&mut self) {
        unsafe { EVP_PKEY_free(self.key) }
    }
}

#[derive(Clone, Copy)]
pub enum Cipher {
    Aes128Gcm,
    Aes256Gcm,
    Chacha20,
}

impl Cipher {
    fn evp(self) -> Const {
        unsafe {
            match self {
                Cipher::Aes128Gcm => EVP_aes_128_gcm(),
                Cipher::Aes256Gcm => EVP_aes_256_gcm(),
                Cipher::Chacha20 => EVP_chacha20_poly1305(),
            }
        }
    }

    pub fn key_len(self) -> usize {
        match self {
            Cipher::Aes128Gcm => 16,
            _ => 32,
        }
    }
}

/// An AEAD key, for one direction only.
pub struct Aead {
    ctx: Ptr,
    sealing: bool,
}

// Each one is used by a single thread at a time.
unsafe impl Send for Aead {}

impl Aead {
    pub fn new(cipher: Cipher, key: &[u8], sealing: bool) -> Aead {
        assert_eq!(key.len(), cipher.key_len());
        unsafe {
            let ctx = EVP_CIPHER_CTX_new();
            let done = if sealing {
                EVP_EncryptInit_ex(ctx, cipher.evp(), null_mut(), key.as_ptr(), null())
            } else {
                EVP_DecryptInit_ex(ctx, cipher.evp(), null_mut(), key.as_ptr(), null())
            };
            assert_eq!(done, 1, "cipher failed");
            Aead { ctx, sealing }
        }
    }

    pub fn seal(&mut self, nonce: &[u8; 12], aad: &[u8], plain: &[u8]) -> Vec<u8> {
        assert!(self.sealing);
        let mut out = vec![0u8; plain.len() + TAG];
        let (mut len, mut last) = (0, 0);
        unsafe {
            let done = EVP_EncryptInit_ex(self.ctx, null(), null_mut(), null(), nonce.as_ptr()) == 1
                && EVP_EncryptUpdate(self.ctx, null_mut(), &mut len, aad.as_ptr(), aad.len() as c_int) == 1
                && EVP_EncryptUpdate(self.ctx, out.as_mut_ptr(), &mut len, plain.as_ptr(), plain.len() as c_int) == 1
                && EVP_EncryptFinal_ex(self.ctx, out.as_mut_ptr().add(len as usize), &mut last) == 1
                && EVP_CIPHER_CTX_ctrl(self.ctx, CTRL_GET_TAG, TAG as c_int, out.as_mut_ptr().add(plain.len()).cast()) == 1;
            assert!(done, "sealing failed");
        }
        out
    }

    pub fn open(&mut self, nonce: &[u8; 12], aad: &[u8], sealed: &[u8]) -> Option<Vec<u8>> {
        assert!(!self.sealing);
        let body = sealed.len().checked_sub(TAG)?;
        let mut tag = [0u8; TAG];
        tag.copy_from_slice(&sealed[body..]);
        let mut out = vec![0u8; body];
        let (mut len, mut last) = (0, 0);
        let mut spare = [0u8; 32];
        unsafe {
            let done = EVP_DecryptInit_ex(self.ctx, null(), null_mut(), null(), nonce.as_ptr()) == 1
                && EVP_DecryptUpdate(self.ctx, null_mut(), &mut len, aad.as_ptr(), aad.len() as c_int) == 1
                && EVP_DecryptUpdate(self.ctx, out.as_mut_ptr(), &mut len, sealed.as_ptr(), body as c_int) == 1
                && EVP_CIPHER_CTX_ctrl(self.ctx, CTRL_SET_TAG, TAG as c_int, tag.as_mut_ptr().cast()) == 1
                && EVP_DecryptFinal_ex(self.ctx, spare.as_mut_ptr(), &mut last) == 1;
            done.then_some(out)
        }
    }
}

impl Drop for Aead {
    fn drop(&mut self) {
        unsafe { EVP_CIPHER_CTX_free(self.ctx) }
    }
}
