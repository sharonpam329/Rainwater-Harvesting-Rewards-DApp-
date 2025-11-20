(define-fungible-token harvest-token)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_REGISTERED (err u101))
(define-constant ERR_ALREADY_REGISTERED (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_ALREADY_VERIFIED (err u105))
(define-constant ERR_NOT_FOUND (err u106))
(define-constant ERR_VERIFICATION_FAILED (err u107))
(define-constant ERR_GOVERNANCE_DISABLED (err u108))
(define-constant ERR_INVALID_PROPOSAL (err u109))
(define-constant ERR_VOTING_ENDED (err u110))
(define-constant ERR_ALREADY_VOTED (err u111))
(define-constant ERR_INSUFFICIENT_VOTING_POWER (err u112))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u113))
(define-constant ERR_EXECUTION_TIME_NOT_REACHED (err u114))
(define-constant ERR_INVALID_REFERRER (err u115))
(define-constant ERR_SELF_REFERRAL (err u116))
(define-constant MIN_HARVEST_AMOUNT u100)
(define-constant MAX_HARVEST_AMOUNT u100000)
(define-constant REWARD_MULTIPLIER u10)
(define-constant VERIFICATION_THRESHOLD u3)

(define-constant BADGE_FIRST_HARVEST u1)
(define-constant BADGE_CONSISTENT_HARVESTER u2)
(define-constant BADGE_VOLUME_CHAMPION u3)
(define-constant BADGE_COMMUNITY_VERIFIER u4)
(define-constant BADGE_VETERAN_HARVESTER u5)

(define-constant CONSISTENT_THRESHOLD u5)
(define-constant VOLUME_CHAMPION_THRESHOLD u50000)
(define-constant VERIFIER_THRESHOLD u10)
(define-constant VETERAN_THRESHOLD u20)

(define-constant PROPOSAL_ACTIVE u0)
(define-constant PROPOSAL_PASSED u1)
(define-constant PROPOSAL_FAILED u2)
(define-constant PROPOSAL_EXECUTED u3)

(define-constant PROPOSAL_REWARD_MULTIPLIER u0)
(define-constant PROPOSAL_VERIFICATION_THRESHOLD u1)
(define-constant PROPOSAL_HARVEST_LIMITS u2)

(define-constant VOTING_PERIOD u1440)
(define-constant MIN_VOTES_REQUIRED u100)
(define-constant EXECUTION_DELAY u720)

(define-constant REFERRAL_BONUS_PERCENTAGE u5)
(define-constant REFERRER_BONUS_PERCENTAGE u10)
(define-constant BADGE_REFERRAL_CHAMPION u6)
(define-constant REFERRAL_CHAMPION_THRESHOLD u5)

(define-data-var total-registered-households uint u0)
(define-data-var total-harvest-volume uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-pool-balance uint u1000000)
(define-data-var proposal-counter uint u0)
(define-data-var governance-active bool true)
(define-data-var total-referral-bonuses uint u0)

(define-map households
  principal
  {
    registered-at: uint,
    total-harvested: uint,
    total-rewards: uint,
    verification-score: uint,
    active: bool,
    referred-by: (optional principal),
    referral-count: uint,
    referral-bonuses-earned: uint
  }
)

(define-map harvest-records
  {household: principal, record-id: uint}
  {
    amount: uint,
    timestamp: uint,
    verified: bool,
    verifier-count: uint,
    reward-claimed: bool
  }
)

(define-map household-record-count principal uint)

(define-map verifiers principal bool)

(define-map verification-votes
  {record-household: principal, record-id: uint, verifier: principal}
  bool
)

(define-map household-badges
  {household: principal, badge-id: uint}
  {
    earned-at: uint,
    badge-type: uint
  }
)

(define-map verifier-stats principal uint)

(define-map proposals
  uint
  {
    proposer: principal,
    proposal-type: uint,
    title: (string-ascii 64),
    description: (string-ascii 256),
    new-value: uint,
    votes-for: uint,
    votes-against: uint,
    status: uint,
    created-at: uint,
    voting-ends-at: uint,
    execution-time: uint
  }
)

(define-map proposal-votes
  {proposal-id: uint, voter: principal}
  {
    vote: bool,
    voting-power: uint,
    voted-at: uint
  }
)

(define-map referrals
  {referrer: principal, referee: principal}
  {
    registered-at: uint,
    bonus-paid: uint
  }
)

(define-public (register-household)
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? households caller)) ERR_ALREADY_REGISTERED)
    (map-set households caller {
      registered-at: stacks-block-height,
      total-harvested: u0,
      total-rewards: u0,
      verification-score: u0,
      active: true,
      referred-by: none,
      referral-count: u0,
      referral-bonuses-earned: u0
    })
    (var-set total-registered-households (+ (var-get total-registered-households) u1))
    (ok true)
  )
)

(define-public (register-household-with-referral (referrer principal))
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? households caller)) ERR_ALREADY_REGISTERED)
    (asserts! (not (is-eq caller referrer)) ERR_SELF_REFERRAL)
    (asserts! (is-some (map-get? households referrer)) ERR_INVALID_REFERRER)
    
    (map-set households caller {
      registered-at: stacks-block-height,
      total-harvested: u0,
      total-rewards: u0,
      verification-score: u0,
      active: true,
      referred-by: (some referrer),
      referral-count: u0,
      referral-bonuses-earned: u0
    })
    
    (match (map-get? households referrer)
      referrer-data
      (begin
        (map-set households referrer (merge referrer-data {
          referral-count: (+ (get referral-count referrer-data) u1)
        }))
        (map-set referrals {referrer: referrer, referee: caller} {
          registered-at: stacks-block-height,
          bonus-paid: u0
        })
        (unwrap-panic (check-and-award-referral-badge referrer))
      )
      false
    )
    
    (var-set total-registered-households (+ (var-get total-registered-households) u1))
    (ok true)
  )
)

(define-public (submit-harvest-data (amount uint))
  (let ((caller tx-sender)
        (current-count (default-to u0 (map-get? household-record-count caller))))
    (asserts! (is-some (map-get? households caller)) ERR_NOT_REGISTERED)
    (asserts! (>= amount MIN_HARVEST_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (<= amount MAX_HARVEST_AMOUNT) ERR_INVALID_AMOUNT)
    
    (map-set harvest-records
      {household: caller, record-id: current-count}
      {
        amount: amount,
        timestamp: stacks-block-height,
        verified: false,
        verifier-count: u0,
        reward-claimed: false
      }
    )
    
    (map-set household-record-count caller (+ current-count u1))
    
    (match (map-get? households caller)
      household-data
      (begin
        (map-set households caller (merge household-data {
          total-harvested: (+ (get total-harvested household-data) amount)
        }))
        (unwrap-panic (check-and-award-badges caller))
      )
      false
    )
    
    (var-set total-harvest-volume (+ (var-get total-harvest-volume) amount))
    (ok current-count)
  )
)

(define-public (become-verifier)
  (begin
    (map-set verifiers tx-sender true)
    (ok true)
  )
)

(define-public (verify-harvest-record (household principal) (record-id uint))
  (let ((caller tx-sender)
        (record-key {household: household, record-id: record-id})
        (vote-key {record-household: household, record-id: record-id, verifier: caller}))
    
    (asserts! (default-to false (map-get? verifiers caller)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? harvest-records record-key)) ERR_NOT_FOUND)
    (asserts! (is-none (map-get? verification-votes vote-key)) ERR_ALREADY_VERIFIED)
    
    (match (map-get? harvest-records record-key)
      record-data
      (begin
        (map-set verification-votes vote-key true)
        (map-set verifier-stats caller (+ (default-to u0 (map-get? verifier-stats caller)) u1))
        (let ((new-verifier-count (+ (get verifier-count record-data) u1)))
          (map-set harvest-records record-key (merge record-data {
            verifier-count: new-verifier-count,
            verified: (>= new-verifier-count VERIFICATION_THRESHOLD)
          }))
          (unwrap-panic (check-and-award-verifier-badge caller))
          
          (if (>= new-verifier-count VERIFICATION_THRESHOLD)
            (begin
              (unwrap! (auto-claim-reward household record-id) ERR_VERIFICATION_FAILED)
              (ok true)
            )
            (ok true)
          )
        )
      )
      ERR_NOT_FOUND
    )
  )
)

(define-private (auto-claim-reward (household principal) (record-id uint))
  (let ((record-key {household: household, record-id: record-id}))
    (match (map-get? harvest-records record-key)
      record-data
      (if (and (get verified record-data) (not (get reward-claimed record-data)))
        (let ((reward-amount (* (get amount record-data) REWARD_MULTIPLIER)))
          (asserts! (>= (var-get reward-pool-balance) reward-amount) ERR_INSUFFICIENT_BALANCE)
          
          (try! (ft-mint? harvest-token reward-amount household))
          (var-set reward-pool-balance (- (var-get reward-pool-balance) reward-amount))
          (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
          
          (map-set harvest-records record-key (merge record-data {
            reward-claimed: true
          }))
          
          (match (map-get? households household)
            household-data
            (begin
              (map-set households household (merge household-data {
                total-rewards: (+ (get total-rewards household-data) reward-amount),
                verification-score: (+ (get verification-score household-data) u1)
              }))
              (unwrap-panic (check-and-award-badges household))
              (unwrap-panic (distribute-referral-bonuses household reward-amount))
            )
            false
          )
          
          (ok reward-amount)
        )
        (ok u0)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (claim-reward (record-id uint))
  (let ((caller tx-sender)
        (record-key {household: caller, record-id: record-id}))
    (match (map-get? harvest-records record-key)
      record-data
      (if (and (get verified record-data) (not (get reward-claimed record-data)))
        (let ((reward-amount (* (get amount record-data) REWARD_MULTIPLIER)))
          (asserts! (>= (var-get reward-pool-balance) reward-amount) ERR_INSUFFICIENT_BALANCE)
          
          (try! (ft-mint? harvest-token reward-amount caller))
          (var-set reward-pool-balance (- (var-get reward-pool-balance) reward-amount))
          (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
          
          (map-set harvest-records record-key (merge record-data {
            reward-claimed: true
          }))
          
          (match (map-get? households caller)
            household-data
            (begin
              (map-set households caller (merge household-data {
                total-rewards: (+ (get total-rewards household-data) reward-amount),
                verification-score: (+ (get verification-score household-data) u1)
              }))
              (unwrap-panic (check-and-award-badges caller))
              (unwrap-panic (distribute-referral-bonuses caller reward-amount))
            )
            false
          )
          
          (ok reward-amount)
        )
        ERR_VERIFICATION_FAILED
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (deactivate-household (household principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? households household)
      household-data
      (map-set households household (merge household-data {active: false}))
      false
    )
    (ok true)
  )
)

(define-public (add-to-reward-pool (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set reward-pool-balance (+ (var-get reward-pool-balance) amount))
    (ok true)
  )
)

(define-read-only (get-household-info (household principal))
  (map-get? households household)
)

(define-read-only (get-harvest-record (household principal) (record-id uint))
  (map-get? harvest-records {household: household, record-id: record-id})
)

(define-read-only (get-household-record-count (household principal))
  (default-to u0 (map-get? household-record-count household))
)

(define-read-only (is-verifier (address principal))
  (default-to false (map-get? verifiers address))
)

(define-read-only (get-verification-vote (household principal) (record-id uint) (verifier principal))
  (default-to false (map-get? verification-votes {record-household: household, record-id: record-id, verifier: verifier}))
)

(define-read-only (get-total-registered-households)
  (var-get total-registered-households)
)

(define-read-only (get-total-harvest-volume)
  (var-get total-harvest-volume)
)

(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed)
)

(define-read-only (get-reward-pool-balance)
  (var-get reward-pool-balance)
)

(define-read-only (get-contract-stats)
  {
    total-households: (var-get total-registered-households),
    total-harvest-volume: (var-get total-harvest-volume),
    total-rewards-distributed: (var-get total-rewards-distributed),
    reward-pool-balance: (var-get reward-pool-balance)
  }
)

(define-read-only (calculate-potential-reward (amount uint))
  (* amount REWARD_MULTIPLIER)
)

(define-private (check-and-award-badges (household principal))
  (match (map-get? households household)
    household-data
    (let ((total-harvested (get total-harvested household-data))
          (record-count (get-household-record-count household))
          (verification-score (get verification-score household-data)))
      
      (if (and (>= record-count u1) (is-none (map-get? household-badges {household: household, badge-id: BADGE_FIRST_HARVEST})))
        (map-set household-badges {household: household, badge-id: BADGE_FIRST_HARVEST} {earned-at: stacks-block-height, badge-type: BADGE_FIRST_HARVEST})
        false
      )
      
      (if (and (>= record-count CONSISTENT_THRESHOLD) (is-none (map-get? household-badges {household: household, badge-id: BADGE_CONSISTENT_HARVESTER})))
        (map-set household-badges {household: household, badge-id: BADGE_CONSISTENT_HARVESTER} {earned-at: stacks-block-height, badge-type: BADGE_CONSISTENT_HARVESTER})
        false
      )
      
      (if (and (>= total-harvested VOLUME_CHAMPION_THRESHOLD) (is-none (map-get? household-badges {household: household, badge-id: BADGE_VOLUME_CHAMPION})))
        (map-set household-badges {household: household, badge-id: BADGE_VOLUME_CHAMPION} {earned-at: stacks-block-height, badge-type: BADGE_VOLUME_CHAMPION})
        false
      )
      
      (if (and (>= verification-score VETERAN_THRESHOLD) (is-none (map-get? household-badges {household: household, badge-id: BADGE_VETERAN_HARVESTER})))
        (map-set household-badges {household: household, badge-id: BADGE_VETERAN_HARVESTER} {earned-at: stacks-block-height, badge-type: BADGE_VETERAN_HARVESTER})
        false
      )
      
      (ok true)
    )
    (ok false)
  )
)

(define-private (check-and-award-verifier-badge (verifier principal))
  (let ((verification-count (default-to u0 (map-get? verifier-stats verifier))))
    (if (and (>= verification-count VERIFIER_THRESHOLD) (is-none (map-get? household-badges {household: verifier, badge-id: BADGE_COMMUNITY_VERIFIER})))
      (map-set household-badges {household: verifier, badge-id: BADGE_COMMUNITY_VERIFIER} {earned-at: stacks-block-height, badge-type: BADGE_COMMUNITY_VERIFIER})
      false
    )
    (ok true)
  )
)

(define-private (check-and-award-referral-badge (referrer principal))
  (match (map-get? households referrer)
    referrer-data
    (let ((referral-count (get referral-count referrer-data)))
      (if (and (>= referral-count REFERRAL_CHAMPION_THRESHOLD) (is-none (map-get? household-badges {household: referrer, badge-id: BADGE_REFERRAL_CHAMPION})))
        (map-set household-badges {household: referrer, badge-id: BADGE_REFERRAL_CHAMPION} {earned-at: stacks-block-height, badge-type: BADGE_REFERRAL_CHAMPION})
        false
      )
      (ok true)
    )
    (ok false)
  )
)

(define-private (distribute-referral-bonuses (household principal) (base-reward uint))
  (match (map-get? households household)
    household-data
    (match (get referred-by household-data)
      referrer
      (let ((referee-bonus (/ (* base-reward REFERRAL_BONUS_PERCENTAGE) u100))
            (referrer-bonus (/ (* base-reward REFERRER_BONUS_PERCENTAGE) u100)))
        (if (and (> referee-bonus u0) (>= (var-get reward-pool-balance) (+ referee-bonus referrer-bonus)))
          (begin
            (unwrap-panic (ft-mint? harvest-token referee-bonus household))
            (unwrap-panic (ft-mint? harvest-token referrer-bonus referrer))
            (var-set reward-pool-balance (- (var-get reward-pool-balance) (+ referee-bonus referrer-bonus)))
            (var-set total-referral-bonuses (+ (var-get total-referral-bonuses) (+ referee-bonus referrer-bonus)))
            (match (map-get? households referrer)
              referrer-data
              (map-set households referrer (merge referrer-data {
                referral-bonuses-earned: (+ (get referral-bonuses-earned referrer-data) referrer-bonus)
              }))
              false
            )
            (match (map-get? households household)
              updated-household-data
              (map-set households household (merge updated-household-data {
                referral-bonuses-earned: (+ (get referral-bonuses-earned updated-household-data) referee-bonus)
              }))
              false
            )
            (match (map-get? referrals {referrer: referrer, referee: household})
              referral-data
              (map-set referrals {referrer: referrer, referee: household} (merge referral-data {
                bonus-paid: (+ (get bonus-paid referral-data) (+ referee-bonus referrer-bonus))
              }))
              false
            )
            (ok true)
          )
          (ok false)
        )
      )
      (ok false)
    )
    (ok false)
  )
)

(define-read-only (get-household-badge (household principal) (badge-id uint))
  (map-get? household-badges {household: household, badge-id: badge-id})
)

(define-read-only (get-household-badges (household principal))
  (list
    (map-get? household-badges {household: household, badge-id: BADGE_FIRST_HARVEST})
    (map-get? household-badges {household: household, badge-id: BADGE_CONSISTENT_HARVESTER})
    (map-get? household-badges {household: household, badge-id: BADGE_VOLUME_CHAMPION})
    (map-get? household-badges {household: household, badge-id: BADGE_COMMUNITY_VERIFIER})
    (map-get? household-badges {household: household, badge-id: BADGE_VETERAN_HARVESTER})
    (map-get? household-badges {household: household, badge-id: BADGE_REFERRAL_CHAMPION})
  )
)

(define-read-only (get-verifier-stats (verifier principal))
  (default-to u0 (map-get? verifier-stats verifier))
)

(define-read-only (get-badge-info (badge-id uint))
  (if (is-eq badge-id BADGE_FIRST_HARVEST)
    (some {name: "First Harvest", description: "Submitted first harvest record", criteria: u1})
    (if (is-eq badge-id BADGE_CONSISTENT_HARVESTER)
      (some {name: "Consistent Harvester", description: "Submitted 5+ harvest records", criteria: CONSISTENT_THRESHOLD})
      (if (is-eq badge-id BADGE_VOLUME_CHAMPION)
        (some {name: "Volume Champion", description: "Harvested 50,000+ units total", criteria: VOLUME_CHAMPION_THRESHOLD})
        (if (is-eq badge-id BADGE_COMMUNITY_VERIFIER)
          (some {name: "Community Verifier", description: "Verified 10+ harvest records", criteria: VERIFIER_THRESHOLD})
          (if (is-eq badge-id BADGE_VETERAN_HARVESTER)
            (some {name: "Veteran Harvester", description: "Achieved 20+ verification score", criteria: VETERAN_THRESHOLD})
            (if (is-eq badge-id BADGE_REFERRAL_CHAMPION)
              (some {name: "Referral Champion", description: "Referred 5+ new households", criteria: REFERRAL_CHAMPION_THRESHOLD})
              none
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-token-balance (address principal))
  (ft-get-balance harvest-token address)
)

(define-public (create-proposal (proposal-type uint) (title (string-ascii 64)) (description (string-ascii 256)) (new-value uint))
  (let ((caller tx-sender)
        (proposal-id (var-get proposal-counter))
        (voting-power (ft-get-balance harvest-token caller)))
    
    (asserts! (var-get governance-active) ERR_GOVERNANCE_DISABLED)
    (asserts! (>= voting-power u1000) ERR_INSUFFICIENT_VOTING_POWER)
    (asserts! (<= proposal-type PROPOSAL_HARVEST_LIMITS) ERR_INVALID_PROPOSAL)
    
    (map-set proposals proposal-id {
      proposer: caller,
      proposal-type: proposal-type,
      title: title,
      description: description,
      new-value: new-value,
      votes-for: u0,
      votes-against: u0,
      status: PROPOSAL_ACTIVE,
      created-at: stacks-block-height,
      voting-ends-at: (+ stacks-block-height VOTING_PERIOD),
      execution-time: u0
    })
    
    (var-set proposal-counter (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let ((caller tx-sender)
        (voting-power (ft-get-balance harvest-token caller))
        (vote-key {proposal-id: proposal-id, voter: caller}))
    
    (asserts! (var-get governance-active) ERR_GOVERNANCE_DISABLED)
    (asserts! (> voting-power u0) ERR_INSUFFICIENT_VOTING_POWER)
    (asserts! (is-none (map-get? proposal-votes vote-key)) ERR_ALREADY_VOTED)
    
    (match (map-get? proposals proposal-id)
      proposal-data
      (begin
        (asserts! (is-eq (get status proposal-data) PROPOSAL_ACTIVE) ERR_INVALID_PROPOSAL)
        (asserts! (<= stacks-block-height (get voting-ends-at proposal-data)) ERR_VOTING_ENDED)
        
        (map-set proposal-votes vote-key {
          vote: vote-for,
          voting-power: voting-power,
          voted-at: stacks-block-height
        })
        
        (let ((new-votes-for (if vote-for (+ (get votes-for proposal-data) voting-power) (get votes-for proposal-data)))
              (new-votes-against (if vote-for (get votes-against proposal-data) (+ (get votes-against proposal-data) voting-power))))
          
          (map-set proposals proposal-id (merge proposal-data {
            votes-for: new-votes-for,
            votes-against: new-votes-against
          }))
          
          (ok true)
        )
      )
      ERR_INVALID_PROPOSAL
    )
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal-data
    (begin
      (asserts! (var-get governance-active) ERR_GOVERNANCE_DISABLED)
      (asserts! (is-eq (get status proposal-data) PROPOSAL_ACTIVE) ERR_INVALID_PROPOSAL)
      (asserts! (> stacks-block-height (get voting-ends-at proposal-data)) ERR_VOTING_ENDED)
      
      (let ((total-votes (+ (get votes-for proposal-data) (get votes-against proposal-data)))
            (votes-for (get votes-for proposal-data))
            (proposal-passed (and (>= total-votes MIN_VOTES_REQUIRED) (> votes-for (get votes-against proposal-data)))))
        
        (if proposal-passed
          (map-set proposals proposal-id (merge proposal-data {
            status: PROPOSAL_PASSED,
            execution-time: (+ stacks-block-height EXECUTION_DELAY)
          }))
          (map-set proposals proposal-id (merge proposal-data {
            status: PROPOSAL_FAILED
          }))
        )
        
        (ok proposal-passed)
      )
    )
    ERR_INVALID_PROPOSAL
  )
)

(define-public (execute-proposal (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal-data
    (begin
      (asserts! (var-get governance-active) ERR_GOVERNANCE_DISABLED)
      (asserts! (is-eq (get status proposal-data) PROPOSAL_PASSED) ERR_PROPOSAL_NOT_PASSED)
      (asserts! (>= stacks-block-height (get execution-time proposal-data)) ERR_EXECUTION_TIME_NOT_REACHED)
      
      (let ((proposal-type (get proposal-type proposal-data))
            (new-value (get new-value proposal-data)))
        
        (if (is-eq proposal-type PROPOSAL_REWARD_MULTIPLIER)
          (var-set reward-pool-balance new-value)
          (if (is-eq proposal-type PROPOSAL_VERIFICATION_THRESHOLD)
            true
            (if (is-eq proposal-type PROPOSAL_HARVEST_LIMITS)
              true
              false
            )
          )
        )
      )
      
      (map-set proposals proposal-id (merge proposal-data {
        status: PROPOSAL_EXECUTED
      }))
      
      (ok true)
    )
    ERR_INVALID_PROPOSAL
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-proposal-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-voting-power (address principal))
  (ft-get-balance harvest-token address)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (is-governance-active)
  (var-get governance-active)
)

(define-read-only (get-referral-info (referrer principal) (referee principal))
  (map-get? referrals {referrer: referrer, referee: referee})
)

(define-read-only (get-household-referrer (household principal))
  (match (map-get? households household)
    household-data
    (get referred-by household-data)
    none
  )
)

(define-read-only (get-referral-stats (household principal))
  (match (map-get? households household)
    household-data
    (some {
      referral-count: (get referral-count household-data),
      referral-bonuses-earned: (get referral-bonuses-earned household-data),
      referred-by: (get referred-by household-data)
    })
    none
  )
)

(define-read-only (get-total-referral-bonuses)
  (var-get total-referral-bonuses)
)
