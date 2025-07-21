# 💧 Rainwater Harvesting Rewards DApp

A Stacks blockchain smart contract that incentivizes sustainable rainwater harvesting through tokenized rewards.

## 🌍 Overview

This DApp encourages households to implement rainwater harvesting systems by providing token-based rewards for verified water collection data. The system promotes environmental sustainability while creating economic incentives for water conservation.

## ✨ Features

- 🏠 **Household Registration**: Register rainwater harvesting setups on-chain
- 📊 **Data Submission**: Submit periodic water collection data
- 🎯 **Verification System**: Community-based verification through registered verifiers
- 🪙 **Token Rewards**: Earn HARVEST tokens based on collection volume
- 📈 **Statistics Tracking**: Monitor community-wide harvesting impact
- 🔒 **Governance Controls**: Admin functions for pool management

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- Stacks wallet (Hiro Wallet recommended)

### Installation
```bash
git clone https://github.com/your-username/rainwater-harvesting-rewards-dapp
cd rainwater-harvesting-rewards-dapp
clarinet check
```

## 📝 Contract Functions

### Public Functions

#### `register-household()`
Register a new household for the rewards program.
- **Requirements**: Must not be already registered
- **Returns**: `(ok true)` on success

#### `submit-harvest-data(amount: uint)`
Submit rainwater collection data for verification.
- **Parameters**: `amount` - Volume of water collected (100-100,000 units)
- **Requirements**: Must be registered household
- **Returns**: Record ID for tracking

#### `become-verifier()`
Register as a community verifier to validate harvest records.
- **Returns**: `(ok true)` on success

#### `verify-harvest-record(household: principal, record-id: uint)`
Verify a household's harvest record (verifiers only).
- **Requirements**: Must be registered verifier
- **Returns**: Auto-claims reward when threshold reached

#### `claim-reward(record-id: uint)`
Manually claim rewards for verified harvest records.
- **Requirements**: Record must be verified and not claimed
- **Returns**: Amount of tokens minted

### Read-Only Functions

#### `get-household-info(household: principal)`
Get complete household information and statistics.

#### `get-harvest-record(household: principal, record-id: uint)`
Retrieve specific harvest record details.

#### `get-contract-stats()`
Get overall contract statistics including total households, volume, and rewards.

#### `calculate-potential-reward(amount: uint)`
Calculate potential reward for a given harvest amount.

## 🎮 Usage Examples

### 1. Register Your Household
```clarity
(contract-call? .rainwater-harvesting register-household)
```

### 2. Submit Harvest Data
```clarity
(contract-call? .rainwater-harvesting submit-harvest-data u2500)
```

### 3. Become a Verifier
```clarity
(contract-call? .rainwater-harvesting become-verifier)
```

### 4. Verify Records (Verifiers)
```clarity
(contract-call? .rainwater-harvesting verify-harvest-record 'ST1HOUSEHOLD... u0)
```

## 💰 Tokenomics

- **Token Name**: HARVEST
- **Reward Formula**: `harvest_amount × 10`
- **Verification Threshold**: 3 verifiers required
- **Minimum Harvest**: 100 units
- **Maximum Harvest**: 100,000 units per submission

## 🔐 Security Features

- ✅ Owner-only administrative functions
- ✅ Input validation for all parameters
- ✅ Duplicate submission prevention
- ✅ Verification requirement for rewards
- ✅ Balance checks before minting

## 📊 Contract Statistics

Monitor the environmental impact:
- Total registered households
- Cumulative harvest volume
- Total rewards distributed
- Remaining reward pool balance

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Households    │    │   Verifiers     │    │  Reward Pool    │
│                 │    │                 │    │                 │
│ • Register      │    │ • Verify data   │    │ • Token minting │
│ • Submit data   │────▶│ • Vote on      │────▶│ • Balance mgmt  │
│ • Claim rewards │    │   validity      │    │ • Distribution  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🌱 Environmental Impact

This system promotes:
- 🌧️ Rainwater conservation
- 🏙️ Reduced municipal water demand
- 🌍 Community environmental awareness
- 📊 Data-driven sustainability metrics

## 🛠️ Development

### Testing
```bash
npm install
npm test
```

### Deployment
```bash
clarinet deploy --network testnet
```

## 📄 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co)
- [Clarinet Documentation](https://docs.hiro.so/clarinet)
- [Clarity Language Reference](https://docs.stacks.co/clarity)

---

**Built with 💚 for a sustainable future** 🌱
