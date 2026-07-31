---
id: RL-example-checkout-total
area: checkout
created: 2026-01-01
last_touched: 2026-01-01
status: active
visual: recommended
commits: []
guard:
  type: unit
  render: real-widget
  ref: ledger:RL-example-checkout-total
supersedes: []
---

# Order total is always recomputed from line items, never trusted from the client

**Invariant (what must not break, and why):** the order total shown at checkout and charged
at payment is recomputed on the server from the current line items + applicable discounts +
tax, on every request. It is never read back from a client-supplied `total` field. Why: a
client-trusted total is both a correctness bug (stale total after a cart edit) and a security
hole (a tampered request under-charges). This is a worked EXAMPLE record — delete it once you
have real ones.

**Gotchas / traps:**
- A percentage discount must apply to the pre-tax subtotal, then tax applies to the
  discounted amount — order of operations changes the result by cents.
- Removing the last item must reset the total to 0, not leave the previous total sticky
  (a classic state-accumulation bug — see the "Defocused" tour in docs/heuristics.md).
- Rounding: half-up per currency's minor unit; never float-compare totals in the guard.

## Acceptance criteria (from requirements)

Source: example session, 2026-01-01.
> "The charged total must ALWAYS equal server-recomputed subtotal minus discount plus tax —
> for an empty cart, a single item, many items, and after a discount is applied or removed."

- [ ] **AC-1** For {empty cart, 1 item, N items} the recomputed total equals
  subtotal − discount + tax to the currency's minor unit. — guard: `checkout_total_test`
  `AC:RL-example-checkout-total/1`
- [ ] **AC-2** A tampered client `total` field is ignored; the charged amount matches the
  server recomputation. — guard: `checkout_total_test` `AC:RL-example-checkout-total/2`
- [ ] **AC-3** Removing the last line item yields total = 0 (no sticky previous total). —
  guard: `checkout_total_test` `AC:RL-example-checkout-total/3`

**Guard:** `tests/checkout/checkout_total_test::recomputes total across cart states` — contains
the tag `ledger:RL-example-checkout-total`. Renders/exercises the real checkout computation
(`guard.render: real-widget`), not a hand-built replica.

**Red-proof:** the test fails when the fix is reverted — replacing the server recomputation
with `return request.total` makes AC-2 go red (client total is trusted), and hard-coding a
non-zero base makes AC-3 go red (empty cart). Both go green with the recomputation in place.
