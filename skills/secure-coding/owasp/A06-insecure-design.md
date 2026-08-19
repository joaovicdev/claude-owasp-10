# A06:2025 — Insecure Design

**ID:** `A06:2025` · **2021:** A04:2021 (#4 → #6) · **Applies to:** any

## Rule

1. Before building a feature, name who the actors are, what each may do, and what
   an attacker gains by abusing it. A flaw in the design survives a perfect
   implementation.
2. Every operation that costs money, sends a message, or grants access has an
   explicit limit — per actor, per resource, per unit of time.
3. The server is the authority on state, price, quantity, entitlement, and
   sequence. Anything the client sends about those is a proposal.
4. Model the abuse case alongside the use case, and write the test that proves the
   limit exists.

## How it shows up in a backend API

- A multi-step flow (checkout, onboarding, approval) where each step is its own
  endpoint and nothing enforces the order, so step 3 is callable directly.
- A state machine implicit in `if` statements across services, so an entity
  reaches a combination nobody designed — refunded and shipped, cancelled and
  renewed.
- Invitations, coupons, referrals, and trials without a use count or an expiry:
  correct code, unbounded value.
- Any endpoint that sends email or SMS, generates a document, or calls a paid API
  with no per-actor limit — a denial-of-wallet channel that looks like a feature.
- Business identifiers that are sequential and enumerable, so scraping the whole
  dataset needs no vulnerability beyond a loop.
- Time-of-check to time-of-use: the balance is checked, then spent, with a window
  in between and no atomic guard, so concurrent requests spend it twice.
- Cross-tenant assumptions baked into the schema, making correct authorization
  expensive later — the design decision that costs the most to reverse.

## Anti-pattern

```
handler POST /checkout/confirm:                  # callable without /checkout/start
    order.status = "paid"                        # no state machine, no idempotency

handler POST /invites: create_invite(code)       # no expiry, no use count, no cap
handler POST /notify:  send_sms(body.to)         # no per-actor limit
```

## Correct

```
STATES = { draft -> pending -> paid -> shipped, pending -> cancelled }

handler POST /checkout/confirm:
    require transition_allowed(order.status, "paid")     # explicit machine
    with_lock(order.id):                                 # no TOCTOU window
        require order.total == recompute_total(order)    # server recomputes
        apply_idempotent(request.idempotency_key)

invite = { code: random_bytes(32), expires_at: now + 7d, max_uses: 1 }
handler POST /notify: quota(caller, 20 per hour); send_sms(...)
```

## Applies when

Any change that introduces a workflow, a state transition, a quota, money, an
invitation, a notification path, or a new resource identifier scheme. Pure
refactors and presentation changes do not need this file.

## Idiom by stack

| Stack | Notes |
|---|---|
| Any | make the state machine explicit and testable, not a scatter of `if` |
| Any | opaque, random resource ids (UUIDv4/ULID) rather than sequential integers |
| Any | one idempotency key per state-changing operation, honored on retry |
| Any | quotas enforced server-side at the sink, not at the caller |

This is the one category with no `→ stacks/` pointer, and the all-`Any` table is
why: a design flaw is not expressible as framework idiom. If a finding here can be
restated as "framework X should be configured differently", it probably belongs in
another file.

## Review questions

- **A06.Q1** — Who are the actors for this feature, and what does an attacker
  gain from abusing it?
- **A06.Q2** — Can steps of a multi-step flow be called out of order, skipped, or
  repeated?
- **A06.Q3** — Is the set of valid state transitions explicit and enforced in one
  place?
- **A06.Q4** — Does every costly action (email, SMS, document, paid API, compute)
  have a per-actor limit?
- **A06.Q5** — Do invitations, coupons, and tokens have an expiry and a use count?
- **A06.Q6** — Is any value the outcome depends on taken from the client rather
  than recomputed by the server? (see `A08.Q4`)
- **A06.Q7** — Are new resource identifiers unguessable, or does enumeration
  disclose the dataset?
- **A06.Q8** — Is there a check-then-act window that concurrent requests could
  exploit, and is it guarded atomically?
- **A06.Q9** — Is there a test that asserts the limit or the forbidden
  transition, not just the happy path?

## Grep signals

```bash
rg -ni 'status\s*=\s*["'"'"'](paid|approved|active|completed|admin)'
rg -ni 'idempotenc|lock|transaction|SELECT .* FOR UPDATE|serializable'
rg -ni 'sendMail|sendSms|notify|invoice|charge|refund|payout'
rg -ni 'expires|expiry|max_uses|maxUses|quota|limit'
rg -n 'autoincrement|AUTO_INCREMENT|SERIAL|@GeneratedValue'
```
