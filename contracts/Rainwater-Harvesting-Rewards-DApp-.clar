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
(define-constant MIN_HARVEST_AMOUNT u100)
(define-constant MAX_HARVEST_AMOUNT u100000)
(define-constant REWARD_MULTIPLIER u10)
(define-constant VERIFICATION_THRESHOLD u3)

(define-data-var total-registered-households uint u0)
(define-data-var total-harvest-volume uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-pool-balance uint u1000000)

(define-map households
  principal
  {
    registered-at: uint,
    total-harvested: uint,
    total-rewards: uint,
    verification-score: uint,
    active: bool
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

(define-public (register-household)
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? households caller)) ERR_ALREADY_REGISTERED)
    (map-set households caller {
      registered-at: stacks-block-height,
      total-harvested: u0,
      total-rewards: u0,
      verification-score: u0,
      active: true
    })
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
      (map-set households caller (merge household-data {
        total-harvested: (+ (get total-harvested household-data) amount)
      }))
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
        (let ((new-verifier-count (+ (get verifier-count record-data) u1)))
          (map-set harvest-records record-key (merge record-data {
            verifier-count: new-verifier-count,
            verified: (>= new-verifier-count VERIFICATION_THRESHOLD)
          }))
          
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
            (map-set households household (merge household-data {
              total-rewards: (+ (get total-rewards household-data) reward-amount),
              verification-score: (+ (get verification-score household-data) u1)
            }))
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
            (map-set households caller (merge household-data {
              total-rewards: (+ (get total-rewards household-data) reward-amount),
              verification-score: (+ (get verification-score household-data) u1)
            }))
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

(define-read-only (get-token-balance (address principal))
  (ft-get-balance harvest-token address)
)
