import { ethers } from "ethers";
import "dotenv/config";

async function main() {
  const rpcUrl = process.env.SEPOLIA_RPC_URL;
  if (!rpcUrl) {
    throw new Error("SEPOLIA_RPC_URL is not set in .env");
  }

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const block = await provider.getBlockNumber();
  console.log("Current Sepolia block:", block);
}

main().catch((err) => {
  console.error("Agent failed:", err);
  process.exit(1);
});
