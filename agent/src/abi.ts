export const VAULT_ABI = [
  "function activeStrategy() view returns (address)",
  "function rebalance(address newStrategy) external",
];

export const ADAPTER_ABI = [
  "function currentAPY() view returns (uint256)",
];