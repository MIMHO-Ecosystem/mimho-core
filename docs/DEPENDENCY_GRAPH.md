# MIMHO Technical Dependency Graph

## 1. Core Infrastructure (The Brain)
| Contract | Role | Key Dependencies |
| :--- | :--- | :--- |
| **MIMHO Registry** | Service Locator / ACL | None |
| **MIMHO Token** | ERC20 Utility Asset | Registry |
| **MIMHO Events Hub**| HUD Data Provider | Registry |

## 2. Liquidity & Launch (The Heart)
- **PreSale & Liquidity Bootstrapper:** Manages initial distribution and the creation of the DEX trading pair.
- **Inject Liquidity:** Receives trade fees and excess PreSale funds to permanently reinforce liquidity.

## 3. Burn & Scarcity Flow (The Engine)
Deflationary logic is governed by a "Supply Floor" rule:
1. **Burn Controller:** Centralizes burn orders from the ecosystem.
2. **Burn Governance Vault:** Allows the community to vote between Burning or Distributing deposited tokens.
3. **MIMHO Mart:** Called by the Burn Vault to mint `Burn Badges` (Proof-of-Burn NFTs) for participants.
4. **Supply Floor (500B):** If `totalSupply` reaches 500 Billion tokens, burn logic automatically redirects funds to **Staking** to preserve the floor.

## 4. Governance & Incentives (The Power)
- **DAO Governance:** Utilizes **Quadratic Voting** ($\sqrt{balance}$) and requires `registerHolding` (90-day minimum) for Sybil resistance.
- **Strategy Hub:** The internal bonus oracle. Queried by **Staking** and **Airdrop** to calculate reward multipliers based on specific NFT ownership.

## 5. User Engagement (The Academy)
- **Quiz Academy:** Allows users to validate ecosystem knowledge and claim rewards proportional to the cycle's reward pool.
- **Airdrop v1.1.0:** Uses Merkle Trees for high-efficiency claims and integrates on-chain bonuses via the Strategy Hub.
-
