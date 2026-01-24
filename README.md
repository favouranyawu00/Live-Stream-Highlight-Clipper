# Live Stream Highlight Clipper 🎥✨

Auto-mint highlight clips as NFTs when viewer engagement meets on-chain thresholds. Includes automated STX split between creator and platform.

## Contract

- File: contracts/Live-Stream-Highlight-Clipper.clar
- NFT: define-non-fungible-token clip with token-id = clip id
- Engagement-gated: viewers call engage-clip; once engagements >= threshold, anyone can finalize-mint
- Splits: finalize-mint(price) transfers STX from caller to creator and platform per creator-bps out of 10000

## Key Concepts

- Engagement threshold: minimum unique engagements before mint
- Creator split: creator-bps out of 10000 (e.g., 1000 = 10%)
- Platform recipient: principal receiving the remainder of price
- Token owner on mint: creator

## Functions

- create-clip(uri, threshold, creator, creator-bps, platform) -> id
- engage-clip(id) -> engagements
- can-mint(id) -> bool
- finalize-mint(id, price)
- transfer(id, to)
- get-clip(id) -> optional tuple
- get-engagements(id) -> uint
- get-clip-uri(id) -> string
- get-clip-split(id) -> tuple
- get-owner-of(id) -> optional principal
- update-split(id, creator-bps, platform)
- update-threshold(id, threshold)
- get-next-id(), get-owner(), set-owner(new-owner)

## Usage with Clarinet 🧪

1) Check

```
clarinet check
```

2) Open console

```
clarinet console
```

3) Create a clip (example; replace principals)

```
(contract-call? .Live-Stream-Highlight-Clipper create-clip "ipfs://QmClipMeta" u3 tx-sender u1500 'SP2C2PYZ7K6B2G3J5K9ZM8Q2F3MZP7V2N7H7X3X5K)
```

4) Engage from multiple unique principals until threshold is met

```
(contract-call? .Live-Stream-Highlight-Clipper engage-clip u1)
```

5) Check readiness

```
(contract-call? .Live-Stream-Highlight-Clipper can-mint u1)
```

6) Finalize mint and split a price among creator and platform

```
(contract-call? .Live-Stream-Highlight-Clipper finalize-mint u1 u1000000)
```

7) Confirm ownership

```
(contract-call? .Live-Stream-Highlight-Clipper get-owner-of u1)
```

## Notes 🧩

- creator-bps is out of 10000
- price is in microstacks (uSTX)
- Transfers in finalize-mint debit tx-sender; ensure sufficient balance
- stacks-block-height and get-stacks-block-info are supported if needed in future changes

## Git

- Commit message: chore: add engagement-gated clip NFT with automated splits
- PR title: Add Live Stream Highlight Clipper NFT with on-chain engagement gating and splits
- PR description: Implements an NFT that mints highlight clips once engagement thresholds are met. Includes automated STX revenue splits between creator and platform, plus helper read-only functions and admin setters.
