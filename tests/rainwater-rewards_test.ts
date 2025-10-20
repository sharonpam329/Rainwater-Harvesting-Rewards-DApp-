import { describe, expect, it, beforeEach } from 'vitest';

const accounts = simnet.getAccounts();
const deployer = accounts.get('deployer')!;
const alice = accounts.get('wallet_1')!;
const bob = accounts.get('wallet_2')!;

const contractName = 'rainwater-rewards';

describe('Rainwater Harvesting Rewards Contract', () => {
  beforeEach(() => {
    // Reset to a clean state before each test
  });

  describe('Participant Registration', () => {
    it('allows new participants to register', () => {
      const registerResult = simnet.callPublicFn(
        contractName,
        'register-participant',
        [],
        alice
      );
      
      expect(registerResult.result).toBeOk(Cl.bool(true));
      
      // Check participant info was created
      const participantInfo = simnet.callReadOnlyFn(
        contractName,
        'get-participant-info',
        [Cl.principal(alice)],
        deployer
      );
      
      expect(participantInfo.result).toBeSome();
    });

    it('prevents duplicate registration', () => {
      // First registration should succeed
      simnet.callPublicFn(contractName, 'register-participant', [], alice);
      
      // Second registration should fail
      const secondRegister = simnet.callPublicFn(
        contractName,
        'register-participant',
        [],
        alice
      );
      
      expect(secondRegister.result).toBeErr(Cl.uint(104)); // err-already-registered
    });

    it('increments total participants counter', () => {
      const initialCount = simnet.callReadOnlyFn(
        contractName,
        'get-total-participants',
        [],
        deployer
      );
      expect(initialCount.result).toBe(Cl.uint(0));
      
      simnet.callPublicFn(contractName, 'register-participant', [], alice);
      
      const newCount = simnet.callReadOnlyFn(
        contractName,
        'get-total-participants',
        [],
        deployer
      );
      expect(newCount.result).toBe(Cl.uint(1));
    });
  });

  describe('Harvest Recording', () => {
    beforeEach(() => {
      // Register alice for harvest tests
      simnet.callPublicFn(contractName, 'register-participant', [], alice);
    });

    it('records valid harvest above minimum threshold', () => {
      const harvestAmount = 2000; // Above minimum threshold of 1000
      const month = 6;
      const year = 2024;
      
      const recordResult = simnet.callPublicFn(
        contractName,
        'record-harvest',
        [Cl.uint(harvestAmount), Cl.uint(month), Cl.uint(year)],
        alice
      );
      
      expect(recordResult.result).toBeOk();
      
      // Check harvest record was created
      const harvestRecord = simnet.callReadOnlyFn(
        contractName,
        'get-harvest-record',
        [Cl.principal(alice), Cl.uint(month), Cl.uint(year)],
        deployer
      );
      
      expect(harvestRecord.result).toBeSome();
    });

    it('rejects harvest below minimum threshold', () => {
      const harvestAmount = 500; // Below minimum threshold of 1000
      const month = 6;
      const year = 2024;
      
      const recordResult = simnet.callPublicFn(
        contractName,
        'record-harvest',
        [Cl.uint(harvestAmount), Cl.uint(month), Cl.uint(year)],
        alice
      );
      
      expect(recordResult.result).toBeErr(Cl.uint(106)); // err-invalid-threshold
    });

    it('calculates rewards correctly', () => {
      const harvestAmount = 3000; // 3000 liters
      const month = 6;
      const year = 2024;
      
      const recordResult = simnet.callPublicFn(
        contractName,
        'record-harvest',
        [Cl.uint(harvestAmount), Cl.uint(month), Cl.uint(year)],
        alice
      );
      
      // Expected reward: (3000 * 10) / 1000 * 100 / 100 = 30 tokens
      expect(recordResult.result).toBeOk(Cl.uint(30));
      
      // Check reward balance
      const rewardBalance = simnet.callReadOnlyFn(
        contractName,
        'get-reward-balance',
        [Cl.principal(alice)],
        deployer
      );
      
      expect(rewardBalance.result).toBe(Cl.uint(30));
    });

    it('prevents unregistered users from recording harvest', () => {
      const harvestAmount = 2000;
      const month = 6;
      const year = 2024;
      
      const recordResult = simnet.callPublicFn(
        contractName,
        'record-harvest',
        [Cl.uint(harvestAmount), Cl.uint(month), Cl.uint(year)],
        bob // Bob is not registered
      );
      
      expect(recordResult.result).toBeErr(Cl.uint(105)); // err-not-registered
    });
  });

  describe('Reward Claiming', () => {
    beforeEach(() => {
      // Setup: Register alice and record a harvest
      simnet.callPublicFn(contractName, 'register-participant', [], alice);
      simnet.callPublicFn(
        contractName,
        'record-harvest',
        [Cl.uint(2000), Cl.uint(6), Cl.uint(2024)],
        alice
      );
    });

    it('allows participants to claim available rewards', () => {
      const claimResult = simnet.callPublicFn(
        contractName,
        'claim-rewards',
        [],
        alice
      );
      
      expect(claimResult.result).toBeOk(Cl.uint(20)); // Expected reward for 2000 liters
      
      // Check reward balance is reset to 0
      const rewardBalance = simnet.callReadOnlyFn(
        contractName,
        'get-reward-balance',
        [Cl.principal(alice)],
        deployer
      );
      
      expect(rewardBalance.result).toBe(Cl.uint(0));
    });

    it('prevents claiming when no rewards available', () => {
      // First claim should succeed
      simnet.callPublicFn(contractName, 'claim-rewards', [], alice);
      
      // Second claim should fail
      const secondClaim = simnet.callPublicFn(
        contractName,
        'claim-rewards',
        [],
        alice
      );
      
      expect(secondClaim.result).toBeErr(Cl.uint(108)); // err-no-rewards-available
    });

    it('updates total rewards distributed', () => {
      const initialTotal = simnet.callReadOnlyFn(
        contractName,
        'get-total-rewards-distributed',
        [],
        deployer
      );
      expect(initialTotal.result).toBe(Cl.uint(0));
      
      simnet.callPublicFn(contractName, 'claim-rewards', [], alice);
      
      const newTotal = simnet.callReadOnlyFn(
        contractName,
        'get-total-rewards-distributed',
        [],
        deployer
      );
      expect(newTotal.result).toBe(Cl.uint(20));
    });
  });

  describe('Owner Functions', () => {
    it('allows owner to verify harvests', () => {
      // Setup
      simnet.callPublicFn(contractName, 'register-participant', [], alice);
      simnet.callPublicFn(
        contractName,
        'record-harvest',
        [Cl.uint(2000), Cl.uint(6), Cl.uint(2024)],
        alice
      );
      
      const verifyResult = simnet.callPublicFn(
        contractName,
        'verify-harvest',
        [Cl.principal(alice), Cl.uint(6), Cl.uint(2024)],
        deployer
      );
      
      expect(verifyResult.result).toBeOk(Cl.bool(true));
    });

    it('prevents non-owners from verifying harvests', () => {
      // Setup
      simnet.callPublicFn(contractName, 'register-participant', [], alice);
      simnet.callPublicFn(
        contractName,
        'record-harvest',
        [Cl.uint(2000), Cl.uint(6), Cl.uint(2024)],
        alice
      );
      
      const verifyResult = simnet.callPublicFn(
        contractName,
        'verify-harvest',
        [Cl.principal(alice), Cl.uint(6), Cl.uint(2024)],
        bob // Non-owner trying to verify
      );
      
      expect(verifyResult.result).toBeErr(Cl.uint(100)); // err-owner-only
    });

    it('allows owner to set reward rate', () => {
      const newRate = 15;
      
      const setRateResult = simnet.callPublicFn(
        contractName,
        'set-reward-rate',
        [Cl.uint(newRate)],
        deployer
      );
      
      expect(setRateResult.result).toBeOk(Cl.bool(true));
      
      // Verify rate was updated
      const currentRate = simnet.callReadOnlyFn(
        contractName,
        'get-reward-rate',
        [],
        deployer
      );
      
      expect(currentRate.result).toBe(Cl.uint(newRate));
    });

    it('allows owner to set seasonal bonuses', () => {
      const season = 3;
      const monsoonMult = 140;
      const dryMult = 85;
      
      const setBonusResult = simnet.callPublicFn(
        contractName,
        'set-seasonal-bonus',
        [Cl.uint(season), Cl.uint(monsoonMult), Cl.uint(dryMult)],
        deployer
      );
      
      expect(setBonusResult.result).toBeOk(Cl.bool(true));
      
      // Verify bonus was set
      const seasonalBonus = simnet.callReadOnlyFn(
        contractName,
        'get-seasonal-bonus',
        [Cl.uint(season)],
        deployer
      );
      
      expect(seasonalBonus.result).toBeSome();
    });
  });

  describe('Read-only Functions', () => {
    beforeEach(() => {
      // Setup test data
      simnet.callPublicFn(contractName, 'register-participant', [], alice);
      simnet.callPublicFn(contractName, 'register-participant', [], bob);
      simnet.callPublicFn(
        contractName,
        'record-harvest',
        [Cl.uint(3000), Cl.uint(7), Cl.uint(2024)],
        alice
      );
    });

    it('returns correct participant information', () => {
      const participantInfo = simnet.callReadOnlyFn(
        contractName,
        'get-participant-info',
        [Cl.principal(alice)],
        deployer
      );
      
      expect(participantInfo.result).toBeSome();
    });

    it('calculates reward correctly for different amounts', () => {
      const reward1 = simnet.callReadOnlyFn(
        contractName,
        'calculate-reward',
        [Cl.uint(1000), Cl.uint(100)],
        deployer
      );
      expect(reward1.result).toBe(Cl.uint(10));
      
      const reward2 = simnet.callReadOnlyFn(
        contractName,
        'calculate-reward',
        [Cl.uint(5000), Cl.uint(150)],
        deployer
      );
      expect(reward2.result).toBe(Cl.uint(75));
    });

    it('returns correct minimum threshold', () => {
      const threshold = simnet.callReadOnlyFn(
        contractName,
        'get-minimum-threshold',
        [],
        deployer
      );
      
      expect(threshold.result).toBe(Cl.uint(1000));
    });
  });
});
