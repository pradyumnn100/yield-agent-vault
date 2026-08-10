# -*- coding: utf-8 -*-
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
    ListFlowable, ListItem, HRFlowable
)
from reportlab.pdfgen import canvas as canvas_module

NAVY = colors.HexColor("#1a2332")
ACCENT = colors.HexColor("#2f6fed")
ACCENT_DARK = colors.HexColor("#1d4fb8")
CODE_BG = colors.HexColor("#f4f6f9")
CODE_BORDER = colors.HexColor("#dbe1ea")
TEXT_GRAY = colors.HexColor("#3c4453")
MUTED = colors.HexColor("#6b7280")
GOOD = colors.HexColor("#0f7a3d")
GOOD_BG = colors.HexColor("#eefaf1")
GOOD_BORDER = colors.HexColor("#bfe6cb")
WARN_BG = colors.HexColor("#fff4ed")
WARN_BORDER = colors.HexColor("#f3c9a8")

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="CoverTitle", fontName="Helvetica-Bold", fontSize=25, textColor=NAVY, leading=30, spaceAfter=10))
styles.add(ParagraphStyle(name="CoverSub", fontName="Helvetica", fontSize=13, textColor=TEXT_GRAY, leading=18))
styles.add(ParagraphStyle(name="H1", fontName="Helvetica-Bold", fontSize=17, textColor=NAVY, leading=21, spaceBefore=6, spaceAfter=10))
styles.add(ParagraphStyle(name="H2", fontName="Helvetica-Bold", fontSize=12.5, textColor=ACCENT_DARK, leading=16, spaceBefore=12, spaceAfter=6))
styles.add(ParagraphStyle(name="Body", fontName="Helvetica", fontSize=10, textColor=TEXT_GRAY, leading=14.5, spaceAfter=6))
styles.add(ParagraphStyle(name="BulletItem", parent=styles["Body"], leftIndent=0, spaceAfter=4))
styles.add(ParagraphStyle(name="CodeText", fontName="Courier", fontSize=7.8, textColor=NAVY, leading=10.8))
styles.add(ParagraphStyle(name="Footnote", fontName="Helvetica-Oblique", fontSize=8.5, textColor=MUTED, leading=12))
styles.add(ParagraphStyle(name="TableCell", fontName="Helvetica", fontSize=9, textColor=TEXT_GRAY, leading=12))
styles.add(ParagraphStyle(name="TableHead", fontName="Helvetica-Bold", fontSize=9, textColor=colors.white, leading=12))

class NumberedCanvas(canvas_module.Canvas):
    def __init__(self, *args, **kwargs):
        canvas_module.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []
    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()
    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_footer(num_pages)
            canvas_module.Canvas.showPage(self)
        canvas_module.Canvas.save(self)
    def draw_footer(self, page_count):
        self.setFont("Helvetica", 8)
        self.setFillColor(MUTED)
        self.drawString(0.75 * inch, 0.5 * inch, "Autonomous DeFi Yield Rebalancing Agent")
        self.drawRightString(letter[0] - 0.75 * inch, 0.5 * inch, f"Page {self._pageNumber} of {page_count}")

story = []

def code_block(text):
    p = Paragraph(text.replace("\n", "<br/>").replace(" ", "&nbsp;"), styles["CodeText"])
    t = Table([[p]], colWidths=[6.4 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), CODE_BG),
        ("BOX", (0, 0), (-1, -1), 0.75, CODE_BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 10), ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8), ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return t

def bullets(items):
    flow = [ListItem(Paragraph(it, styles["BulletItem"]), leftIndent=14) for it in items]
    return ListFlowable(flow, bulletType="bullet", start="circle", bulletFontSize=6, bulletColor=ACCENT, leftIndent=16, spaceAfter=8)

def note_box(text, kind="good"):
    bg, border, label, color = (GOOD_BG, GOOD_BORDER, "Verified", GOOD) if kind == "good" else (WARN_BG, WARN_BORDER, "Note", colors.HexColor("#9a3412"))
    p = Paragraph(f'<font color="{color.hexval() if hasattr(color,"hexval") else "#9a3412"}"><b>{label}:</b></font> {text}', styles["Body"])
    t = Table([[p]], colWidths=[6.4 * inch])
    t.setStyle(TableStyle([("BACKGROUND", (0,0),(-1,-1), bg), ("BOX",(0,0),(-1,-1),0.75,border),
                            ("LEFTPADDING",(0,0),(-1,-1),10),("RIGHTPADDING",(0,0),(-1,-1),10),
                            ("TOPPADDING",(0,0),(-1,-1),7),("BOTTOMPADDING",(0,0),(-1,-1),7)]))
    return t

def simple_table(headers, rows, col_widths):
    data = [[Paragraph(h, styles["TableHead"]) for h in headers]]
    for row in rows:
        data.append([Paragraph(c, styles["TableCell"]) for c in row])
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,0), NAVY),
        ("GRID", (0,0), (-1,-1), 0.5, CODE_BORDER),
        ("VALIGN", (0,0), (-1,-1), "TOP"),
        ("LEFTPADDING", (0,0), (-1,-1), 8), ("RIGHTPADDING", (0,0), (-1,-1), 8),
        ("TOPPADDING", (0,0), (-1,-1), 6), ("BOTTOMPADDING", (0,0), (-1,-1), 6),
        ("ROWBACKGROUNDS", (0,1), (-1,-1), [colors.white, colors.HexColor("#f7f8fa")]),
    ]))
    return t

# ============ COVER ============
story.append(Spacer(1, 1.5*inch))
story.append(Paragraph("Autonomous DeFi Yield<br/>Rebalancing Agent", styles["CoverTitle"]))
story.append(Paragraph("An ERC-4626 vault with an LLM-gated autonomous rebalancing agent", styles["CoverSub"]))
story.append(Spacer(1, 0.3*inch))
story.append(HRFlowable(width="30%", thickness=2, color=ACCENT, spaceAfter=14, hAlign="LEFT"))
story.append(Paragraph("Network: Ethereum Sepolia (chain ID 11155111) &mdash; testnet, unaudited. Not for use with real funds.", styles["Body"]))
story.append(Spacer(1, 2.4*inch))
story.append(Paragraph("This document doubles as the project README and a portfolio overview: it documents what is genuinely built and verified (with real transaction hashes and test runs), and is explicit about the gap between this and a production-ready system.", styles["Footnote"]))
story.append(PageBreak())

# ============ PROBLEM ============
story.append(Paragraph("The Problem", styles["H1"]))
story.append(Paragraph(
    "DeFi yield is fragmented across dozens of lending protocols, and rates move constantly &mdash; "
    "Aave might pay 3% today and Compound 5% next week. Capturing that spread means either:",
    styles["Body"]))
story.append(bullets([
    "<b>Watching rates manually and moving funds by hand</b> &mdash; realistic for maybe an hour a week for "
    "most people, meaning most opportunities are missed, and gas is paid every time action is taken.",
    "<b>Picking one protocol and never touching it again</b> &mdash; what almost everyone actually does, "
    "leaving yield on the table indefinitely.",
    "<b>Trusting an opaque \u201cauto-yield\u201d product</b> &mdash; existing aggregators exist, but their "
    "rebalancing logic is usually a black box: you can see that a decision happened, not why.",
]))
story.append(Paragraph(
    "There is also a sharper, newer version of this problem: as more DeFi automation moves toward AI-driven "
    "decision-making, \u201cchase the highest number\u201d agents are easy to build and easy to exploit &mdash; "
    "a temporary incentive spike or a bad data point can trick a naive bot into moving funds into something risky.",
    styles["Body"]))

story.append(Paragraph("Who This Helps", styles["H2"]))
story.append(Paragraph(
    "Anyone holding stablecoins or other yield-bearing assets who wants their capital working at close to the "
    "best available rate, without personally monitoring multiple protocols &mdash; while keeping a transparent, "
    "auditable trail of <i>why</i> each move was made, not just that it happened.",
    styles["Body"]))

story.append(Paragraph("The Proposed Solution", styles["H2"]))
story.append(Paragraph(
    "A vault that pools deposits and automatically redirects them to whichever approved lending protocol "
    "currently offers the best yield &mdash; gated by two independent layers before any capital moves:",
    styles["Body"]))
story.append(bullets([
    "<b>A quantitative threshold</b> &mdash; a candidate has to beat the current position by a meaningful "
    "margin, not just marginally.",
    "<b>An LLM risk assessment</b> &mdash; given recent yield history, an LLM judges whether the signal looks "
    "like durable yield or a suspicious spike, and can veto the move even if the threshold is technically met.",
]))
story.append(Paragraph(
    "Every decision &mdash; hold, rebalance, or veto &mdash; is logged with its full reasoning, so the "
    "system's behavior is inspectable, not a black box.",
    styles["Body"]))
story.append(PageBreak())

# ============ TECH STACK ============
story.append(Paragraph("Tech Stack", styles["H1"]))
story.append(simple_table(
    ["Layer", "Technology"],
    [
        ["Smart contracts", "Solidity, Foundry, OpenZeppelin (ERC4626, AccessControl, ReentrancyGuard)"],
        ["Off-chain agent", "Node.js, TypeScript, ethers.js v6"],
        ["LLM risk layer", "Google Gemini (gemini-3.6-flash) via @google/genai"],
        ["Testing", "Foundry (unit, fork, invariant/fuzz tests), Slither static analysis"],
        ["Frontend (planned)", "Next.js, RainbowKit + wagmi + viem for wallet connection and vault interaction"],
        ["Deployment (planned)", "Vercel (frontend), Ethereum Sepolia / mainnet or L2 (contracts)"],
        ["Automation (planned)", "Chainlink Automation or Gelato, replacing the local polling loop"],
    ],
    [1.7*inch, 4.7*inch]
))
story.append(Spacer(1, 8))
story.append(note_box(
    "The frontend and decentralized-trigger rows are planned, not yet built. They're listed here to show the "
    "intended full-stack shape of the project, not to claim they exist today.",
    kind="warn"
))
story.append(PageBreak())

# ============ SYSTEM DESIGN ============
story.append(Paragraph("System Design", styles["H1"]))
story.append(code_block(
"""                         User deposits / withdraws
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
        +--------------------------------------+"""
))
story.append(Spacer(1, 10))

story.append(Paragraph("Security Model", styles["H2"]))
story.append(bullets([
    "<b>The trigger never holds custody.</b> The agent's wallet has AGENT_ROLE, which can only call "
    "rebalance() &mdash; and only toward addresses on the isApprovedStrategy whitelist, which only "
    "DEFAULT_ADMIN_ROLE controls. Even a fully compromised agent key cannot redirect funds anywhere the "
    "admin hasn't already vetted.",
    "<b>New strategies are timelocked.</b> proposeStrategy() starts a 1-hour clock; approveStrategy() only "
    "succeeds after it elapses &mdash; a visible reaction window even against a compromised admin key.",
    "<b>Reentrancy guarded.</b> rebalance() is nonReentrant, since it makes an external call "
    "(activeStrategy.withdraw) before updating strategy state.",
    "<b>The LLM is a gate, not a decision-maker.</b> It can only approve or veto a move the heuristic already "
    "flagged &mdash; it never chooses a destination or invents an action. An unparseable or failed LLM "
    "response defaults to <i>not</i> trusting the move (fail-safe, not fail-open).",
    "<b>Every deposit/withdraw/rebalance/fee event is on-chain and logged off-chain</b>, so behavior is "
    "auditable after the fact, not just in theory.",
]))
story.append(PageBreak())

# ============ REPO STRUCTURE ============
story.append(Paragraph("Repo Structure", styles["H1"]))
story.append(code_block(
"""yield-agent-vault/
|-- contracts/
|   |-- src/
|   |   |-- Vault.sol              ERC-4626 vault, AccessControl, fees, timelock
|   |   |-- AaveAdapter.sol        IStrategyAdapter impl for Aave V3
|   |   |-- CompoundAdapter.sol    IStrategyAdapter impl for Compound III
|   |   |-- IStrategyAdapter.sol   Shared interface -- keeps Vault protocol-agnostic
|   |   |-- IPool.sol / IComet.sol Minimal local interfaces (no external dep tree)
|   |-- test/
|   |   |-- VaultAaveMock.t.sol    Deposit/yield/withdraw against a mock Aave pool
|   |   |-- VaultRebalance.t.sol   Manual rebalance + timelock enforcement
|   |   |-- VaultFee.t.sol         Withdrawal fee split correctness
|   |   |-- VaultInvariant.t.sol   Fuzzed invariants (128k+ randomized calls)
|   |   |-- VaultAaveFork.t.sol    Fork test against live Sepolia Aave
|   |   |-- mocks/                 MockAavePool, MockCompoundPool
|   |-- script/
|       |-- DeployPhase3.s.sol     Full deployment script
|-- agent/
|   |-- src/
|   |   |-- rebalanceAgent.ts      Polling loop: read APY -> threshold -> LLM -> execute
|   |   |-- riskAssessor.ts        Gemini-based risk judgment
|   |   |-- abi.ts                 Minimal ABI fragments
|   |-- logs/                      Structured JSONL decision log (gitignored)
|-- frontend/ (planned)
    |-- Next.js app
    |-- RainbowKit + wagmi wallet connection
    |-- Deposit / withdraw / vault-state UI
    |-- Deployed on Vercel"""
))
story.append(PageBreak())

# ============ DEPLOYED CONTRACTS ============
story.append(Paragraph("Deployed Contracts (Sepolia)", styles["H1"]))
story.append(simple_table(
    ["Contract", "Address"],
    [
        ["Vault", "0xE3E4de3aE11e930beF66185a62879574FF9Bc224"],
        ["AaveAdapter", "0xddE75e4e424f10A8a1812D3D5575A56fcec75364"],
        ["CompoundAdapter", "0xcC72b49CC5a26296d266dD68D273eDE63F5e298a"],
        ["Mock DAI", "0x0ffb3A169dBB6a3DC1E9d819c838D2a2A3235191"],
    ],
    [1.7*inch, 4.7*inch]
))
story.append(Spacer(1, 8))
story.append(note_box(
    "The live deployment predates the timelock/reentrancy-guard hardening pass. The current Vault.sol source "
    "includes those changes; the deployed contract does not yet. Redeploying to sync them is a known follow-up.",
    kind="warn"
))
story.append(Spacer(1, 14))

story.append(Paragraph("Verified, Working End to End", styles["H2"]))
story.append(Paragraph("Not just \u201ccompiles\u201d &mdash; each item below was confirmed with a real transaction hash or test run.", styles["Body"]))
story.append(bullets([
    "Deposit -> yield accrual -> withdraw, against a mock Aave pool",
    "Manual rebalance moves funds between Aave and Compound adapters, share value unaffected",
    "Off-chain agent autonomously detected an APY change and executed a real on-chain rebalance "
    "(tx 0xe77ee86b75628839a63c245be4a3139b5536c1d6b84eebe89fc8e04b1ae6779c)",
    "LLM correctly <b>approved</b> a gradual, credible yield increase (950 -> 1000 bps, confidence 0.9)",
    "LLM correctly <b>vetoed</b> an extreme, suspicious spike (900 -> 5000 bps, confidence 0.9) &mdash; the "
    "heuristic threshold was met, and the LLM still blocked execution",
    "Withdrawal fee splits exactly (feeCollected + userReceived == assets, no value lost or created)",
    "Invariant fuzzing: 128,000+ randomized deposit/withdraw calls, share value never collapsed",
    "Slither pass reviewed; real findings (missing zero-checks, reentrancy) fixed; library/style findings "
    "documented as intentionally unchanged",
]))
story.append(PageBreak())

# ============ RUNNING IT ============
story.append(Paragraph("Running It", styles["H1"]))
story.append(Paragraph("Contracts", styles["H2"]))
story.append(code_block(
"""cd contracts
forge install
forge build
forge test -vv"""
))
story.append(Paragraph("Requires contracts/.env:", styles["Body"]))
story.append(code_block(
"""SEPOLIA_RPC_URL=your_sepolia_rpc_url
DEPLOYER_PRIVATE_KEY=your_deployer_wallet_private_key
AGENT_ADDRESS=address_of_the_off-chain_agent_wallet"""
))

story.append(Paragraph("Off-chain agent", styles["H2"]))
story.append(code_block(
"""cd agent
npm install
npx tsx src/rebalanceAgent.ts"""
))
story.append(Paragraph("Requires agent/.env:", styles["Body"]))
story.append(code_block(
"""SEPOLIA_RPC_URL=your_sepolia_rpc_url
AGENT_PRIVATE_KEY=agent_wallet_private_key
GEMINI_API_KEY=your_gemini_api_key
VAULT_ADDRESS=0xE3E4de3aE11e930beF66185a62879574FF9Bc224
AAVE_ADAPTER_ADDRESS=0xddE75e4e424f10A8a1812D3D5575A56fcec75364
COMPOUND_ADAPTER_ADDRESS=0xcC72b49CC5a26296d266dD68D273eDE63F5e298a
DAI_ADDRESS=0x0ffb3A169dBB6a3DC1E9d819c838D2a2A3235191
POLL_INTERVAL_MS=60000"""
))

story.append(Paragraph("Frontend (planned)", styles["H2"]))
story.append(Paragraph(
    "A Next.js app using RainbowKit and wagmi for wallet connection, letting users deposit into and withdraw "
    "from the vault directly, and view live vault state (total assets, active strategy, recent rebalances) "
    "without touching a terminal. Deployment target is Vercel, given its native Next.js support and simple "
    "environment-variable configuration for the RPC URL and contract addresses.",
    styles["Body"]
))
story.append(PageBreak())

# ============ PATH TO PRODUCTION ============
story.append(Paragraph("Path to Production", styles["H1"]))
story.append(Paragraph(
    "This is a working, tested system &mdash; but there is a real, specific gap between \u201cworks on testnet "
    "with mock data\u201d and \u201csafe to hold real user funds.\u201d Being explicit about that gap is the "
    "point of this section.",
    styles["Body"]
))
story.append(simple_table(
    ["Area", "Current State", "What Production Needs"],
    [
        ["Yield data", "currentAPY() is a manually-settable mock value", "Real on-chain interest rate reads (Aave's getReserveNormalizedIncome, Compound's utilization curve)"],
        ["Audit", "Slither + manual review only", "A paid third-party audit before any real funds are accepted"],
        ["Trigger", "Runs from a local Node.js process", "Decentralized keeper (Chainlink Automation or Gelato) so it survives a laptop closing"],
        ["Frontend", "None yet", "Next.js + RainbowKit + wagmi, deployed on Vercel"],
        ["Deployment", "Sepolia testnet, mock pools", "Mainnet or a real L2, against genuine Aave/Compound deployments"],
        ["Fee model", "Flat withdrawal fee only", "Performance fee (high-water mark) for sustainable economics"],
        ["Circuit breakers", "None yet", "Pause function, max-slippage checks, max-single-rebalance-size limits"],
        ["Key management", "Plain private keys in .env", "Hardware security module or secrets manager for the agent's signing key"],
    ],
    [1.3*inch, 2.3*inch, 2.8*inch]
))
story.append(Spacer(1, 14))

story.append(Paragraph("Known Limitations", styles["H2"]))
story.append(bullets([
    "Testnet only, unaudited &mdash; do not deposit real funds",
    "Yield data is simulated (setMockAPY), not read from live protocol state",
    "The off-chain agent stops running when its process exits (no decentralized keeper yet)",
    "Fee is flat-rate only, no performance-fee/high-water-mark logic",
    "No frontend yet &mdash; all interaction is via Foundry scripts, cast, and the agent's CLI",
]))
story.append(Spacer(1, 16))
story.append(Paragraph("License: MIT", styles["Footnote"]))

doc = SimpleDocTemplate(
    "/home/claude/Yield_Agent_Vault_README.pdf",
    pagesize=letter,
    topMargin=0.75*inch, bottomMargin=0.75*inch, leftMargin=0.75*inch, rightMargin=0.75*inch,
    title="Autonomous DeFi Yield Rebalancing Agent - README",
    author="Claude"
)
doc.build(story, canvasmaker=NumberedCanvas)
print("PDF built.")
