# A04:2025 — Cryptographic Failures

**ID:** `A04:2025` · **2021:** A02:2021 (#2 → #4) · **Applies to:** any

## Rule

1. Never invent a scheme, and never use a primitive directly when a vetted
   construction exists. Prefer an authenticated mode (AEAD) over encrypt-then-hope.
2. Passwords use a memory-hard password hash (argon2id, scrypt, bcrypt) — never a
   general-purpose digest, salted or not. High-entropy tokens use SHA-256 plus a
   constant-time compare.
3. Anything used as a secret, token, id, or nonce comes from a cryptographically
   secure random source. A predictable identifier is an access control failure.
4. Keys come from validated configuration, are distinct per purpose, and are
   rotatable. Classify data first: what you do not store cannot leak.

## How it shows up in a backend API

- A general-purpose hash used for passwords because it was already imported.
  Fast hashes are the wrong tool regardless of salting.
- Reversible encryption chosen where a hash was required, so a single key
  compromise discloses every credential at once.
- A homemade "encrypt" that is a static IV, ECB mode, or no authentication tag —
  ciphertext an attacker can rearrange without detection.
- Tokens, reset links, and invitation ids built from a timestamp, a counter, or a
  non-cryptographic RNG, making them guessable in bulk.
- One key reused for sessions, webhooks, and field encryption, so rotating any of
  them means rotating all of them, so none of them rotate.
- Sensitive data collected because it was easy — full documents, card data,
  precise location — and retained indefinitely with no classification.
- Transport left to defaults: verification disabled somewhere internal, or
  plaintext between services because "it is a private network" (see A02).

## Anti-pattern

```
user.password = sha256(body.password + salt)      # fast digest
token         = base64(user.id + ":" + now())     # predictable
cipher        = aes_ecb(key: cfg.key, data)       # no IV, no authentication
if provided_token == stored_token: ...            # early-exit comparison
```

## Correct

```
user.password_hash = argon2id(body.password)                  # tuned, versioned
token              = random_bytes(32)                         # CSPRNG
store(hash: sha256(token))                                    # store the hash, show once
cipher             = aead_encrypt(key: keys.field_encryption, # distinct key per purpose
                                  nonce: random_bytes(12), plaintext: data, aad: tenant_id)
if constant_time_equals(sha256(provided), stored_hash): ...
```

Show a generated token once and store only its hash — the same reasoning as
passwords, applied to API keys, reset links, and invitations.

## Idiom by stack

| Stack | Notes |
|---|---|
| NestJS | `argon2`/`bcrypt`; `crypto.randomBytes`, `crypto.timingSafeEqual`; never `Math.random` |
| Laravel | `Hash::make`/`Hash::check`, `Crypt` (requires `APP_KEY`), `Str::random`, `hash_equals` |
| Spring Boot | `DelegatingPasswordEncoder`, `SecureRandom`, `MessageDigest.isEqual`, Jasypt/KMS for field encryption |
| Any | keys from a secret manager, distinct per purpose, versioned so rotation is possible |

→ `stacks/nestjs.md (NEST.5, NEST.6, NEST.13)` · `stacks/laravel.md (LAR.8)` ·
`stacks/spring-boot.md (SPR.8)`

## Applies when

Any change that stores or transports a credential, a token, personal data, or
payment data; that generates an identifier which must be unguessable; or that
touches TLS, hashing, encryption, or randomness. If none of those are in the
diff, this file does not apply.

## Review questions

- **A04.Q1** — Are passwords hashed with a memory-hard algorithm, with
  parameters recorded so they can be raised later?
- **A04.Q2** — Is anything reversibly encrypted that should be hashed?
- **A04.Q3** — Do all secrets, tokens, ids, and nonces come from a CSPRNG?
- **A04.Q4** — Are secret comparisons constant-time?
- **A04.Q5** — Is encryption authenticated (AEAD), with a unique nonce per
  message, and is the key distinct from other purposes and rotatable?
- **A04.Q6** — Are generated tokens stored hashed and displayed only once?
- **A04.Q7** — Is any newly stored field sensitive enough that it should be
  minimized, redacted, or not stored at all?
- **A04.Q8** — Is transport encrypted and verified end to end, including between
  internal services? (see `A02.Q7`)

## Grep signals

```bash
# fast digests reached for where a password hash belongs — SHA-256 over a
# high-entropy token is correct (rule 2), so read the call site before judging
rg -ni '\b(md5|sha1)\b|\b(sha-?256)\b.{0,40}\b(password|senha|passwd|pwd)\b'
rg -n '\bMath\.random\b|\brand\(\)|\bmt_rand\b|new Random\('
rg -ni '\b(ECB|createCipher\b|AES/ECB|NoPadding)\b'
rg -ni 'timingSafeEqual|hash_equals|isEqual|compare_digest'
rg -ni 'encrypt|decrypt|cipher|secret|private_key|passphrase'
```
