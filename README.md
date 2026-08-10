# Autonomous DeFi Yield Rebalancing Agent

An ERC-4626 vault that autonomously moves pooled funds between lending protocols
to capture the best available yield — with an LLM acting as a risk gate before
any capital actually moves.

**Network:** Ethereum Sepolia (chain ID `11155111`) — testnet, not audited, do not use with real funds. See [Path to Production](#path-to-production).

---

## The problem

DeFi yield is fragmented across dozens of lending protocols, and rates move
constantly — Aave might pay 3% today and Compound 5% next week. Capturing that
spread means either:

- **Watching rates manually and moving funds by hand** — realistic for maybe
  an hour a week for most people, which means missing most of the actual
  opportunities, and paying gas every time you do act.
- **Picking one protocol and never touching it again** — what almost everyone
  actually does, which leaves yield on the table indefinitely.
- **Trusting an opaque "auto-yield" product** — existing yield aggregators
  exist, but their rebalancing logic is usually a black box: you can't see
  *why* a decision was made, only that it happened.

There's also a sharper, newer version of this problem: as more DeFi automation
moves toward AI-driven decision-making, "chase the highest number" agents are
easy to build and easy to exploit — a temporary incentive spike or bad data
can trick a naive bot into moving funds into something risky.

## Who this helps

Anyone holding stablecoins or other yield-bearing assets who wants their
capital working at close to the best available rate, without personally
monitoring multiple protocols — while keeping a transparent, auditable trail
of *why* each move was made, not just that it happened.

## The proposed solution

A vault that pools deposits and automatically redirects them to whichever
approved lending protocol currently offers the best yield — gated by two
independent layers before any capital moves:

1. **A quantitative threshold** — a candidate has to beat the current position
   by a meaningful margin, not just marginally.
2. **An LLM risk assessment** — given recent yield history, an LLM judges
   whether the signal looks like durable yield or a suspicious spike (e.g. an
   incentive program about to end, or anomalous data), and can veto the move
   even if the threshold is technically met.

Every decision — hold, rebalance, or veto — is logged with its full reasoning,
so the system's behavior is inspectable, not a black box.

---

## Tech stack

| Layer | Technology |
|---|---|
| Smart contracts | Solidity, Foundry, OpenZeppelin (ERC4626, AccessControl, ReentrancyGuard) |
| Off-chain agent | Node.js, TypeScript, ethers.js v6 |
| LLM risk layer | Google Gemini (`gemini-3.6-flash`) via `@google/genai` |
| Testing | Foundry (unit, fork, invariant/fuzz tests), Slither static analysis |
| Frontend *(planned)* | Next.js, RainbowKit + wagmi + viem for wallet connection and vault interaction |
| Deployment *(planned)* | Vercel (frontend), Sepolia/mainnet/L2 (contracts) |
| Automation *(planned)* | Chainlink Automation or Gelato, replacing the local polling loop |

> Frontend and decentralized-trigger rows are planned, not yet built — listed to show the intended full-stack shape of the project.

---

## System design
User deposits / withdraws
                                |
                                v
                +---------------------------------+
                |     Vault.sol (ERC-4626)         |
                |  AccessControl, ReentrancyGuard  |
                |  Strategy whitelist + timelock   |
                +---------------------------------+
                      |                    |
                      v                    v
          +--------------------+  +----------------------+
          |   AaveAdapter      |  |   CompoundAdapter     |
          | IStrategyAdapter   |  |  IStrategyAdapter     |
          +--------------------+  +----------------------+
                      |                    |
                      v                    v
                Aave Pool             Compound Comet
             (or mock pool)          (or mock pool)

                 ^ rebalance() -- gated by AGENT_ROLE
                 |    (whitelist-only destinations)
                 |
    +--------------------------------------+
    |     Off-chain agent (Node.js/TS)      |
    |  1. Poll currentAPY() on both adapters|
    |  2. Threshold check                   |
    |  3. If flagged -> ask Gemini:          |
    |     "does this spike look real?"      |
    |  4. Only execute if both layers agree |
    |  5. Log full reasoning to disk         |
    +--------------------------------------+

    +--------------------------------------+
    |   Frontend (planned)                  |
    |   Next.js + RainbowKit + wagmi         |
    |   Deployed on Vercel                   |
    |   Reads Vault state, submits deposit/  |
    |   withdraw transactions via wallet      |
    +--------------------------------------+


### Security model

- **The trigger never holds custody.** The agent's wallet has `AGENT_ROLE`,
  which can only call `rebalance()` — and only toward addresses on the
  `isApprovedStrategy` whitelist, which only `DEFAULT_ADMIN_ROLE` controls.
  Even a fully compromised agent key cannot redirect funds anywhere the
  admin hasn't already vetted.
- **New strategies are timelocked.** `proposeStrategy()` starts a 1-hour
  clock; `approveStrategy()` only succeeds after it elapses — a visible
  reaction window even against a compromised admin key.
- **Reentrancy guarded.** `rebalance()` is `nonReentrant`, since it makes an
  external call (`activeStrategy.withdraw`) before updating strategy state.
- **The LLM is a gate, not a decision-maker.** It can only approve or veto a
  move the heuristic already flagged — it never chooses a destination or
  invents an action. An unparseable or failed LLM response defaults to
  **not** trusting the move (fail-safe, not fail-open).
- **Every deposit/withdraw/rebalance/fee event is on-chain and logged
  off-chain**, so behavior is auditable after the fact, not just in theory.

---

## Repo structure
yield-agent-vault/
├── contracts/
│ ├── src/
│ │ ├── Vault.sol ERC-4626 vault, AccessControl, fees, timelock
│ │ ├── AaveAdapter.sol IStrategyAdapter impl for Aave V3
│ │ ├── CompoundAdapter.sol IStrategyAdapter impl for Compound III
│ │ ├── IStrategyAdapter.sol Shared interface -- keeps Vault protocol-agnostic
│ │ ├── IPool.sol / IComet.sol Minimal local interfaces (no external dep tree)
│ ├── test/
│ │ ├── VaultAaveMock.t.sol Deposit/yield/withdraw against a mock Aave pool
│ │ ├── VaultRebalance.t.sol Manual rebalance + timelock enforcement
│ │ ├── VaultFee.t.sol Withdrawal fee split correctness
│ │ ├── VaultInvariant.t.sol Fuzzed invariants (128k+ randomized calls)
│ │ ├── VaultAaveFork.t.sol Fork test against live Sepolia Aave
│ │ └── mocks/ MockAavePool, MockCompoundPool
│ └── script/
│ └── DeployPhase3.s.sol Full deployment script
├── agent/
│ ├── src/
│ │ ├── rebalanceAgent.ts Polling loop: read APY -> threshold -> LLM -> execute
│ │ ├── riskAssessor.ts Gemini-based risk judgment
│ │ └── abi.ts Minimal ABI fragments
│ └── logs/ Structured JSONL decision log (gitignored)
└── frontend/ (planned)
├── Next.js app
├── RainbowKit + wagmi wallet connection
├── Deposit / withdraw / vault-state UI
└── Deployed on Vercel


---

## Deployed contracts (Sepolia)

| Contract | Address |
|---|---|
| Vault | `0xE3E4de3aE11e930beF66185a62879574FF9Bc224` |
| AaveAdapter | `0xddE75e4e424f10A8a1812D3D5575A56fcec75364` |
| CompoundAdapter | `0xcC72b49CC5a26296d266dD68D273eDE63F5e298a` |
| Mock DAI | `0x0ffb3A169dBB6a3DC1E9d819c838D2a2A3235191` |

> The live deployment predates the timelock/reentrancy-guard hardening pass. Current `Vault.sol` source includes those changes; the deployed contract does not yet — redeploying to sync them is a known follow-up.

## Verified, working end to end

- [x] Deposit → yield accrual → withdraw, against a mock Aave pool
- [x] Manual rebalance moves funds between Aave and Compound adapters, share value unaffected
- [x] Off-chain agent autonomously detected an APY change and executed a real on-chain rebalance (`tx 0xe77ee86b...`)
- [x] LLM correctly **approved** a gradual, credible yield increase (950→1000 bps, confidence 0.9)
- [x] LLM correctly **vetoed** an extreme, suspicious spike (900→5000 bps, confidence 0.9) — heuristic threshold was met, LLM still blocked execution
- [x] Withdrawal fee splits exactly (`feeCollected + userReceived == assets`)
- [x] Invariant fuzzing: 128,000+ randomized deposit/withdraw calls, share value never collapsed
- [x] Slither pass reviewed; real findings fixed; library/style findings documented as intentionally unchanged

## Running it

### Contracts
```bash
cd contracts
forge install
forge build
forge test -vv
```
`contracts/.env`:
SEPOLIA_RPC_URL=your_sepolia_rpc_url
DEPLOYER_PRIVATE_KEY=your_deployer_wallet_private_key
AGENT_ADDRESS=address_of_the_off-chain_agent_wallet


### Off-chain agent
```bash
cd agent
npm install
npx tsx src/rebalanceAgent.ts
```
`agent/.env`:
SEPOLIA_RPC_URL=your_sepolia_rpc_url
AGENT_PRIVATE_KEY=agent_wallet_private_key
GEMINI_API_KEY=your_gemini_api_key
VAULT_ADDRESS=0xE3E4de3aE11e930beF66185a62879574FF9Bc224
AAVE_ADAPTER_ADDRESS=0xddE75e4e424f10A8a1812D3D5575A56fcec75364
COMPOUND_ADAPTER_ADDRESS=0xcC72b49CC5a26296d266dD68D273eDE63F5e298a
DAI_ADDRESS=0x0ffb3A169dBB6a3DC1E9d819c838D2a2A3235191
POLL_INTERVAL_MS=60000


### Frontend (planned)
A Next.js app using RainbowKit and wagmi for wallet connection, letting users deposit/withdraw directly and view live vault state without a terminal. Deployment target: Vercel.

---

## Path to production

| Area | Current state | What production needs |
|---|---|---|
| Yield data | `currentAPY()` is a manually-settable mock | Real on-chain interest rate reads |
| Audit | Slither + manual review only | A paid third-party audit |
| Trigger | Local Node.js process | Chainlink Automation or Gelato |
| Frontend | None yet | Next.js + RainbowKit + wagmi on Vercel |
| Deployment | Sepolia testnet, mock pools | Mainnet/L2, real Aave/Compound |
| Fee model | Flat withdrawal fee only | Performance fee (high-water mark) |
| Circuit breakers | None yet | Pause, max-slippage, max-rebalance-size limits |
| Key management | Plain private keys in `.env` | HSM or secrets manager |

## Known limitations

- Testnet only, unaudited — **do not deposit real funds**
- Yield data is simulated, not read from live protocol state
- Agent stops running when its process exits (no decentralized keeper yet)
- Fee is flat-rate only, no performance-fee logic
- No frontend yet — all interaction via Foundry scripts, `cast`, and the agent CLI

## License
MIT

