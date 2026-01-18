# Token Metrics Multi-Strategy ERC-4626 Vault

This repository contains a production-style **ERC-4626** vault built with **Foundry** that routes deposits into multiple strategies, supports rebalancing, handles locked liquidity via a withdrawal queue, and is fully tested end-to-end.

---

## ✨ Features

* **ERC-4626 compliant vault** (OpenZeppelin v5)
* **Multi-strategy allocation** (e.g., Strategy A / Strategy B)
* **Target allocation in basis points (BPS)** with per-strategy safety caps
* **Rebalancing** to maintain target weights
* **Accurate `totalAssets()`** across vault + strategies
* **Withdrawal queue** when a strategy has lockup
* **Role-based access control** (manager/admin)
* **Pausable** emergency switch
* **Full integration test** covering deposit → rebalance → profit → withdraw

---

## 🏗 Architecture

```
src/
 ├── Vault.sol                 # ERC-4626 multi-strategy vault
 ├── MockUSDC.sol              # 6-decimal mock USDC
 ├── interfaces/
 │     └── IStrategy.sol       # Strategy interface
 └── strategies/
       ├── StrategyA.sol       # Instant liquidity, yield can increase
       └── StrategyB.sol       # Has lockup (withdraw blocked until unlocked)

test/
 └── Vault.t.sol               # End-to-end integration test
```

---

## 🔑 Core Design

### Vault

* Inherits **ERC4626**, **AccessControl**, **Pausable**
* Accepts an ERC20 asset (MockUSDC in tests)
* Holds a list of `Allocation { protocol, targetBps }`
* `rebalance()` moves funds between strategies to match target weights
* `totalAssets()` = vault balance + sum(strategy.totalAssets())

### Strategies

* Must implement `IStrategy`
* `StrategyA`: instant withdraw, can simulate profit
* `StrategyB`: has lockup; withdrawals revert until `unlock()`

### Withdrawal Queue

* If **any strategy has lockup**, user withdrawals are queued
* User calls `requestWithdraw(shares)` → gets a `requestId`
* Once liquidity is available, user calls `claimWithdraw(requestId)`

---

## 🧪 Testing (Foundry)

The main test (`test/Vault.t.sol`) covers:

1. User deposits **1000 USDC**
2. Vault is configured **60% / 40%**
3. Manager calls `rebalance()` → funds move into strategies
4. Strategy A gains **+10% profit** (simulated + real mint)
5. `totalAssets()` becomes **1060 USDC**
6. User requests withdraw while Strategy B is locked → goes to queue
7. Strategy B is unlocked
8. User claims withdraw → receives ~**1060 USDC**

### Run tests

```bash
forge build
forge test -vv
```

Expected output:

```
[PASS] testFullFlow()
```

---

## 🛡 Safety Considerations

* Per-strategy allocation cap enforced (`MAX_PER_PROTOCOL_BPS`)
* Total allocation must sum to **10000 BPS (100%)**
* `pause()` / `unpause()` for emergency
* Role-gated management functions

---

## 🧰 Foundry Commands (Quick Reference)

```bash
forge build        # Build
forge test -vv     # Run tests (verbose)
forge fmt          # Format
forge snapshot     # Gas snapshots
anvil              # Local node
```

---

## 👨‍💻 How to Explain This in an Interview

* “This is an ERC-4626 vault that allocates capital across multiple strategies using BPS weights.”
* “Rebalancing ensures funds match the desired allocation.”
* “`totalAssets()` aggregates on-vault liquidity and strategy TVL.”
* “If any strategy has lockup, withdrawals are queued and claimed later.”
* “I test the full lifecycle: deposit → rebalance → yield → withdraw.”

---

## 🏁 Conclusion

This project demonstrates:

* ERC-4626 mastery
* Multi-strategy vault architecture
* Correct DeFi accounting
* Realistic integration testing with Foundry

It is designed to be **production-style, not a toy example**.
