import { ethers } from "ethers";
import "dotenv/config";
import * as fs from "fs";
import * as path from "path";
import { VAULT_ABI, ADAPTER_ABI } from "./abi";
import { assessRebalanceRisk, RiskAssessment } from "./riskAssessor";

const MIN_APY_DELTA = 50n;
const MIN_LLM_CONFIDENCE = 0.5;
const MAX_HISTORY = 10;
const POLL_INTERVAL_MS = Number(process.env.POLL_INTERVAL_MS ?? 60_000);
const LOG_PATH = path.join(__dirname, "..", "logs", "rebalance-log.jsonl");

interface APYSnapshot {
  timestamp: string;
  aaveAPY: string;
  compoundAPY: string;
}

interface CycleResult {
  timestamp: string;
  activeStrategy: string;
  aaveAPY: string;
  compoundAPY: string;
  decision: "REBALANCE" | "HOLD" | "VETOED_BY_LLM";
  llmAssessment?: RiskAssessment;
  txHash?: string;
  txStatus?: "SUCCESS" | "FAILED";
  error?: string;
}

function appendLog(entry: CycleResult) {
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.appendFileSync(LOG_PATH, JSON.stringify(entry) + "\n");
}

async function runOnce(
  vault: ethers.Contract,
  aaveAdapter: ethers.Contract,
  compoundAdapter: ethers.Contract,
  aaveAdapterAddress: string,
  compoundAdapterAddress: string,
  history: APYSnapshot[]
): Promise<CycleResult> {
  const timestamp = new Date().toISOString();

  try {
    const [activeStrategy, aaveAPY, compoundAPY] = await Promise.all([
      vault.activeStrategy!(),
      aaveAdapter.currentAPY!(),
      compoundAdapter.currentAPY!(),
    ]);

    console.log(`[${timestamp}] Active: ${activeStrategy} | Aave: ${aaveAPY} | Compound: ${compoundAPY}`);

    const priorHistory = [...history];
    history.push({ timestamp, aaveAPY: aaveAPY.toString(), compoundAPY: compoundAPY.toString() });
    if (history.length > MAX_HISTORY) history.shift();

    const isAaveActive = activeStrategy.toLowerCase() === aaveAdapterAddress.toLowerCase();
    const currentAPY = isAaveActive ? aaveAPY : compoundAPY;
    const candidateAddress = isAaveActive ? compoundAdapterAddress : aaveAdapterAddress;
    const candidateAPY = isAaveActive ? compoundAPY : aaveAPY;
    const candidateName = isAaveActive ? "Compound" : "Aave";
    const currentName = isAaveActive ? "Aave" : "Compound";

    const result: CycleResult = {
      timestamp,
      activeStrategy,
      aaveAPY: aaveAPY.toString(),
      compoundAPY: compoundAPY.toString(),
      decision: "HOLD",
    };

    if (candidateAPY > currentAPY + MIN_APY_DELTA) {
      console.log(`[${timestamp}] Heuristic: ${candidateName} beats ${currentName} by threshold. Consulting risk layer...`);

      const assessment = await assessRebalanceRisk(
        candidateName,
        candidateAPY.toString(),
        currentName,
        currentAPY.toString(),
        priorHistory
      );

      result.llmAssessment = assessment;
      console.log(`[${timestamp}] LLM: trust=${assessment.trust} confidence=${assessment.confidence} — ${assessment.reasoning}`);

      if (assessment.trust && assessment.confidence >= MIN_LLM_CONFIDENCE) {
        result.decision = "REBALANCE";
        const tx = await vault.rebalance!(candidateAddress);
        result.txHash = tx.hash;
        console.log(`[${timestamp}] Tx sent: ${tx.hash}`);
        const receipt = await tx.wait();
        result.txStatus = receipt?.status === 1 ? "SUCCESS" : "FAILED";
        console.log(`[${timestamp}] Confirmed: ${result.txStatus}`);
      } else {
        result.decision = "VETOED_BY_LLM";
        console.log(`[${timestamp}] Decision: HOLD — LLM vetoed the move`);
      }
    } else {
      console.log(`[${timestamp}] Decision: HOLD`);
    }

    appendLog(result);
    return result;
  } catch (err: any) {
    const errorResult: CycleResult = {
      timestamp,
      activeStrategy: "unknown",
      aaveAPY: "unknown",
      compoundAPY: "unknown",
      decision: "HOLD",
      error: err?.message ?? String(err),
    };
    console.error(`[${timestamp}] Cycle failed:`, err?.message ?? err);
    appendLog(errorResult);
    return errorResult;
  }
}

async function main() {
  const rpcUrl = process.env.SEPOLIA_RPC_URL;
  const agentKey = process.env.AGENT_PRIVATE_KEY;
  const vaultAddress = process.env.VAULT_ADDRESS;
  const aaveAdapterAddress = process.env.AAVE_ADAPTER_ADDRESS;
  const compoundAdapterAddress = process.env.COMPOUND_ADAPTER_ADDRESS;

  if (!rpcUrl || !agentKey || !vaultAddress || !aaveAdapterAddress || !compoundAdapterAddress) {
    throw new Error("Missing required .env values");
  }
  if (!process.env.GEMINI_API_KEY) {
    throw new Error("Missing GEMINI_API_KEY in .env");
  }

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const agentWallet = new ethers.Wallet(agentKey, provider);
  const vault = new ethers.Contract(vaultAddress, VAULT_ABI, agentWallet);
  const aaveAdapter = new ethers.Contract(aaveAdapterAddress, ADAPTER_ABI, provider);
  const compoundAdapter = new ethers.Contract(compoundAdapterAddress, ADAPTER_ABI, provider);

  console.log(`Agent wallet: ${agentWallet.address}`);
  console.log(`Polling every ${POLL_INTERVAL_MS / 1000}s. Logs: ${LOG_PATH}`);

  const history: APYSnapshot[] = [];
  let running = false;

  const tick = async () => {
    if (running) {
      console.log("Previous cycle still in flight, skipping this tick.");
      return;
    }
    running = true;
    await runOnce(vault, aaveAdapter, compoundAdapter, aaveAdapterAddress, compoundAdapterAddress, history);
    running = false;
  };

  await tick();
  const interval = setInterval(tick, POLL_INTERVAL_MS);

  process.on("SIGINT", () => {
    console.log("\nShutting down agent...");
    clearInterval(interval);
    process.exit(0);
  });
}

main().catch((err) => {
  console.error("Agent failed to start:", err);
  process.exit(1);
});