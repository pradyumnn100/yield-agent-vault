"use client";

import { useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { VAULT_ABI, DAI_ABI } from "../lib/vaultAbi";
import { VAULT_ADDRESS, DAI_ADDRESS } from "../lib/addresses";

export function VaultCard() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState("");

  const { data: totalAssets, refetch: refetchTotalAssets } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: "totalAssets",
  });

  const { data: activeStrategy } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: "activeStrategy",
  });

  const { data: userShares, refetch: refetchUserShares } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: daiBalance } = useReadContract({
    address: DAI_ADDRESS,
    abi: DAI_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { writeContract: approve, data: approveHash } = useWriteContract();
  const { writeContract: deposit, data: depositHash } = useWriteContract();
  const { writeContract: redeem, data: redeemHash } = useWriteContract();

  const { isLoading: approving } = useWaitForTransactionReceipt({ hash: approveHash });
  const { isLoading: depositing } = useWaitForTransactionReceipt({
    hash: depositHash,
    query: { enabled: !!depositHash },
  });
  const { isLoading: redeeming } = useWaitForTransactionReceipt({ hash: redeemHash });

  const handleApproveAndDeposit = () => {
    if (!address || !amount) return;
    const parsed = parseUnits(amount, 18);
    approve({
      address: DAI_ADDRESS,
      abi: DAI_ABI,
      functionName: "approve",
      args: [VAULT_ADDRESS, parsed],
    });
  };

  const handleDeposit = () => {
    if (!address || !amount) return;
    const parsed = parseUnits(amount, 18);
    deposit({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      functionName: "deposit",
      args: [parsed, address],
    });
  };

  const handleWithdrawAll = () => {
    if (!address || !userShares) return;
    redeem({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      functionName: "redeem",
      args: [userShares, address, address],
    });
  };

  if (!isConnected) {
    return <p>Connect your wallet to view the vault.</p>;
  }

  return (
    <div style={{ maxWidth: 480, margin: "0 auto", padding: 24, border: "1px solid #333", borderRadius: 12 }}>
      <h2>Yield Vault</h2>
      <p>Total assets in vault: {totalAssets ? formatUnits(totalAssets, 18) : "..."} DAI</p>
      <p>Active strategy: {activeStrategy ?? "..."}</p>
      <p>Your DAI balance: {daiBalance ? formatUnits(daiBalance, 18) : "..."}</p>
      <p>Your vault shares: {userShares ? formatUnits(userShares, 18) : "0"}</p>

      <input
        type="text"
        placeholder="Amount in DAI"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
        style={{ width: "100%", padding: 8, marginBottom: 8 }}
      />

      <div style={{ display: "flex", gap: 8 }}>
        <button onClick={handleApproveAndDeposit} disabled={approving}>
          {approving ? "Approving..." : "1. Approve"}
        </button>
        <button onClick={handleDeposit} disabled={depositing}>
          {depositing ? "Depositing..." : "2. Deposit"}
        </button>
        <button onClick={handleWithdrawAll} disabled={redeeming}>
          {redeeming ? "Withdrawing..." : "Withdraw All"}
        </button>
      </div>
    </div>
  );
}