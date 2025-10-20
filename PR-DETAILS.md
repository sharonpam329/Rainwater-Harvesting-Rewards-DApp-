# Rainwater Harvesting Rewards Smart Contract

## Overview
This feature introduces a comprehensive smart contract system for incentivizing rainwater harvesting through a token-based rewards program. The contract enables participants to register, record their rainwater harvesting activities, and earn rewards based on the amount of water harvested.

## Technical Implementation

### Key Functions and Data Structures Added

**Core Data Structures:**
- `participants` map: Stores participant information including registration status, harvest totals, rewards earned, and reward multipliers
- `harvest-records` map: Records individual harvest events with verification status and reward calculations
- `reward-balances` map: Tracks pending rewards for each participant
- `seasonal-bonuses` map: Configurable seasonal multipliers for different harvesting periods

**Public Functions:**
- `register-participant()`: Allows new users to join the rewards program
- `record-harvest(amount, month, year)`: Records rainwater harvest with automatic reward calculation
- `claim-rewards()`: Enables participants to claim their accumulated rewards
- `verify-harvest(participant, month, year)`: Owner function to verify harvest records
- `set-seasonal-bonus()`: Owner function to configure seasonal reward multipliers

**Read-only Functions:**
- `get-participant-info()`: Retrieves participant details and statistics
- `get-harvest-record()`: Fetches specific harvest records
- `get-reward-balance()`: Returns pending rewards for a participant
- `calculate-reward()`: Computes reward amounts based on harvest volume and multipliers
- `get-total-participants()`: Returns total registered participants
- `get-total-rewards-distributed()`: Returns cumulative rewards distributed

**Administrative Functions:**
- `set-reward-rate()`: Adjusts the base reward rate per volume harvested
- `set-minimum-threshold()`: Sets minimum harvest volume for reward eligibility
- `update-reward-multiplier()`: Adjusts individual participant reward multipliers

## Testing & Validation
- ✅ Contract passes Clarity syntax validation
- ✅ Comprehensive test suite with 15+ test cases covering all major functionality
- ✅ CI/CD pipeline configured with GitHub Actions
- ✅ Clarity v3 compliant with proper error handling and data types
- ✅ Independent implementation with no cross-contract dependencies
- ✅ Line endings normalized (CRLF → LF)

## Key Features
1. **Participation Management**: Registration system with duplicate prevention
2. **Harvest Tracking**: Monthly harvest recording with timestamp and verification
3. **Reward Calculation**: Automatic reward computation based on configurable rates and multipliers
4. **Seasonal Bonuses**: Configurable multipliers for monsoon and dry seasons
5. **Admin Controls**: Owner-only functions for system configuration and harvest verification
6. **Analytics Support**: Read-only functions for participant ranking and system statistics

## Security Considerations
- Owner-only administrative functions with proper access control
- Input validation for harvest amounts and thresholds
- Error constants for consistent error handling
- Comprehensive assertions to prevent invalid state changes
