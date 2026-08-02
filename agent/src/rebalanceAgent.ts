import { ethers } from "ethers";
import "dotenv/config";
import { VAULT_ABI, ADAPTER_ABI } from "./abi";

const MIN_APY_DELTA = 50n; // agent only rebalances if candidate APY beats current by at least this much (basis points)

async function main() {
  const rpcUrl = process.env.SEPOLIA_RPC_URL;
  const agentKey = process.env.AGENT_PRIVATE_KEY;
  const vaultAddress = process.env.VAULT_ADDRESS;
  const aaveAdapterAddress = process.env.AAVE_ADAPTER_ADDRESS;
  const compoundAdapterAddress = process.env.COMPOUND_ADAPTER_ADDRESS;

  if (!rpcUrl || !agentKey || !vaultAddress || !aaveAdapterAddress || !compoundAdapterAddress) {
    throw new Error("Missing required .env values — check SEPOLIA_RPC_URL, AGENT_PRIVATE_KEY, VAULT_ADDRESS, AAVE_ADAPTER_ADDRESS, COMPOUND_ADAPTER_ADDRESS");
  }

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const agentWallet = new ethers.Wallet(agentKey, provider);

  const vault = new ethers.Contract(vaultAddress, VAULT_ABI, agentWallet);
  const aaveAdapter = new ethers.Contract(aaveAdapterAddress, ADAPTER_ABI, provider);
  const compoundAdapter = new ethers.Contract(compoundAdapterAddress, ADAPTER_ABI, provider);

  console.log(`[${new Date().toISOString()}] Agent wallet: ${agentWallet.address}`);

  const [activeStrategy, aaveAPY, compoundAPY] = await Promise.all([
    vault.activeStrategy(),
    aaveAdapter.currentAPY(),
    compoundAdapter.currentAPY(),
  ]);

  console.log(`Active strategy: ${activeStrategy}`);
  console.log(`Aave APY:     ${aaveAPY}`);
  console.log(`Compound APY: ${compoundAPY}`);

  const isAaveActive = activeStrategy.toLowerCase() === aaveAdapterAddress.toLowerCase();
  const currentAPY = isAaveActive ? aaveAPY : compoundAPY;
  const candidateAddress = isAaveActive ? compoundAdapterAddress : aaveAdapterAddress;
  const candidateAPY = isAaveActive ? compoundAPY : aaveAPY;

  console.log(`Currently in: ${isAaveActive ? "Aave" : "Compound"} (APY: ${currentAPY})`);
  console.log(`Candidate:    ${isAaveActive ? "Compound" : "Aave"} (APY: ${candidateAPY})`);

  if (candidateAPY > currentAPY + MIN_APY_DELTA) {
    console.log(`Decision: REBALANCE — candidate APY exceeds current by more than ${MIN_APY_DELTA} bps`);
    const tx = await vault.rebalance(candidateAddress);
    console.log(`Tx sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Confirmed in block ${receipt?.blockNumber}. Status: ${receipt?.status === 1 ? "SUCCESS" : "FAILED"}`);
  } else {
    console.log("Decision: HOLD — no sufficiently better yield available");
  }
}

main().catch((err) => {
  console.error("Agent run failed:", err);
  process.exit(1);
});