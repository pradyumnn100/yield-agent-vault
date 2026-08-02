import { ethers } from "ethers";
import "dotenv/config";
import * as fs from "fs";
import * as path from "path";
import { VAULT_ABI, ADAPTER_ABI } from "./abi";

const MIN_APY_DELTA = 50n; // basis points
const POLL_INTERVAL_MS = Number(process.env.POLL_INTERVAL_MS ?? 60_000);
const LOG_PATH = path.join(__dirname, "..", "logs", "rebalance-log.jsonl");

interface CycleResult {
  timestamp: string;
  activeStrategy: string;
  aaveAPY: string;
  compoundAPY: string;
  decision: "REBALANCE" | "HOLD";
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
  compoundAdapterAddress: string
): Promise<CycleResult> {
  const timestamp = new Date().toISOString();

  try {
    const [activeStrategy, aaveAPY, compoundAPY] = await Promise.all([
      vault.activeStrategy!(),
      aaveAdapter.currentAPY!(),
      compoundAdapter.currentAPY!(),
    ]);

    console.log(`[${timestamp}] Active: ${activeStrategy} | Aave: ${aaveAPY} | Compound: ${compoundAPY}`);

    const isAaveActive = activeStrategy.toLowerCase() === aaveAdapterAddress.toLowerCase();
    const currentAPY = isAaveActive ? aaveAPY : compoundAPY;
    const candidateAddress = isAaveActive ? compoundAdapterAddress : aaveAdapterAddress;
    const candidateAPY = isAaveActive ? compoundAPY : aaveAPY;

    const result: CycleResult = {
      timestamp,
      activeStrategy,
      aaveAPY: aaveAPY.toString(),
      compoundAPY: compoundAPY.toString(),
      decision: "HOLD",
    };

    if (candidateAPY > currentAPY + MIN_APY_DELTA) {
      console.log(`[${timestamp}] Decision: REBALANCE -> ${candidateAddress}`);
      result.decision = "REBALANCE";

      const tx = await vault.rebalance!(candidateAddress);
      result.txHash = tx.hash;
      console.log(`[${timestamp}] Tx sent: ${tx.hash}`);

      const receipt = await tx.wait();
      result.txStatus = receipt?.status === 1 ? "SUCCESS" : "FAILED";
      console.log(`[${timestamp}] Confirmed: ${result.txStatus}`);
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

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const agentWallet = new ethers.Wallet(agentKey, provider);
  const vault = new ethers.Contract(vaultAddress, VAULT_ABI, agentWallet);
  const aaveAdapter = new ethers.Contract(aaveAdapterAddress, ADAPTER_ABI, provider);
  const compoundAdapter = new ethers.Contract(compoundAdapterAddress, ADAPTER_ABI, provider);

  console.log(`Agent wallet: ${agentWallet.address}`);
  console.log(`Polling every ${POLL_INTERVAL_MS / 1000}s. Logs: ${LOG_PATH}`);

  let running = false; // prevents overlapping cycles if one run takes longer than the interval

  const tick = async () => {
    if (running) {
      console.log("Previous cycle still in flight, skipping this tick.");
      return;
    }
    running = true;
    await runOnce(vault, aaveAdapter, compoundAdapter, aaveAdapterAddress, compoundAdapterAddress);
    running = false;
  };

  await tick(); // run immediately on startup, then on the interval
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