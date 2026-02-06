# MIMHO Registry Map (Standard v1.0)

This map defines the canonical `bytes32` keys used by the MIMHO Registry to resolve addresses. 
**Absolute Rule:** Never use hardcoded addresses; always resolve via these keys.

## 1. Core Infrastructure Keys
| Key Constant | bytes32 Hash (keccak256) | Target Module |
| :--- | :--- | :--- |
| `KEY_MIMHO_TOKEN` | `0x...` | The official MIMHO ERC20 Token. |
| `KEY_MIMHO_EVENTS_HUB`| `0x...` | Centralized Event Broadcaster (HUD). |
| `KEY_MIMHO_DAO` | `0x...` | Main Governance Controller. |

## 2. Economic & Distribution Keys
| Key Constant | Target Module | Purpose |
| :--- | :--- | :--- |
| `KEY_MIMHO_DAO_WALLET`| DAO Treasury Safe | Receives protocol fees and failsafe funds. |
| `KEY_MARKETING_WALLET`| Marketing Gnosis Safe| Funds Airdrops and receives Marketplace fees. |
| `KEY_MIMHO_STAKING` | Staking Rewards | Handles APR distribution and NFT bonuses. |

## 3. Utility & Apps Keys
| Key Constant | Target Module | Integration |
| :--- | :--- | :--- |
| `KEY_MIMHO_MART` | NFT Hub (MIMHO Mart) | Used by Marketplace to verify official NFTs. |
| `KEY_MIMHO_CERTIFY` | Certification Engine | Registers Quiz badges and Burn proofs. |
| `KEY_MIMHO_STRATEGY` | Strategy Hub | Internal oracle for NFT bonus multipliers. |
