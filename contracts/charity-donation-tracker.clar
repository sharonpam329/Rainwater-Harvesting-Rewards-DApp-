;; Rainwater Harvesting Rewards Smart Contract
;; A comprehensive system for incentivizing rainwater harvesting through token rewards

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-already-registered (err u104))
(define-constant err-not-registered (err u105))
(define-constant err-invalid-threshold (err u106))
(define-constant err-reward-period-active (err u107))
(define-constant err-no-rewards-available (err u108))

;; Data Variables
(define-data-var total-participants uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-rate uint u10) ;; 10 tokens per 1000 liters
(define-data-var minimum-harvest-threshold uint u1000) ;; Minimum 1000 liters to earn rewards

;; Data Maps
(define-map participants principal {
    registered: bool,
    total-harvested: uint,
    total-rewards-earned: uint,
    last-claim-block: uint,
    monthly-harvest: uint,
    reward-multiplier: uint
})

(define-map harvest-records {participant: principal, month: uint, year: uint} {
    amount: uint,
    timestamp: uint,
    verified: bool,
    reward-amount: uint
})

(define-map reward-balances principal uint)

(define-map seasonal-bonuses uint {
    monsoon-multiplier: uint,
    dry-season-multiplier: uint,
    active: bool
})

;; Read-only functions
(define-read-only (get-participant-info (participant principal))
    (map-get? participants participant)
)

(define-read-only (get-harvest-record (participant principal) (month uint) (year uint))
    (map-get? harvest-records {participant: participant, month: month, year: year})
)

(define-read-only (get-reward-balance (participant principal))
    (default-to u0 (map-get? reward-balances participant))
)

(define-read-only (get-total-participants)
    (var-get total-participants)
)

(define-read-only (get-total-rewards-distributed)
    (var-get total-rewards-distributed)
)

(define-read-only (get-reward-rate)
    (var-get reward-rate)
)

(define-read-only (get-minimum-threshold)
    (var-get minimum-harvest-threshold)
)

(define-read-only (calculate-reward (harvest-amount uint) (multiplier uint))
    (let ((base-reward (/ (* harvest-amount (var-get reward-rate)) u1000)))
        (/ (* base-reward multiplier) u100)
    )
)

(define-read-only (get-seasonal-bonus (season uint))
    (map-get? seasonal-bonuses season)
)

;; Public functions
(define-public (register-participant)
    (let ((participant tx-sender))
        (asserts! (is-none (map-get? participants participant)) err-already-registered)
        (map-set participants participant {
            registered: true,
            total-harvested: u0,
            total-rewards-earned: u0,
            last-claim-block: block-height,
            monthly-harvest: u0,
            reward-multiplier: u100
        })
        (var-set total-participants (+ (var-get total-participants) u1))
        (ok true)
    )
)

(define-public (record-harvest (amount uint) (month uint) (year uint))
    (let (
        (participant tx-sender)
        (participant-info (unwrap! (map-get? participants participant) err-not-registered))
        (current-multiplier (get reward-multiplier participant-info))
        (reward-amount (calculate-reward amount current-multiplier))
    )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (>= amount (var-get minimum-harvest-threshold)) err-invalid-threshold)
        
        ;; Record the harvest
        (map-set harvest-records {participant: participant, month: month, year: year} {
            amount: amount,
            timestamp: block-height,
            verified: false,
            reward-amount: reward-amount
        })
        
        ;; Update participant info
        (map-set participants participant (merge participant-info {
            total-harvested: (+ (get total-harvested participant-info) amount),
            monthly-harvest: amount
        }))
        
        ;; Add to reward balance
        (map-set reward-balances participant 
            (+ (get-reward-balance participant) reward-amount))
        
        (print {
            event: "harvest-recorded",
            participant: participant,
            amount: amount,
            reward: reward-amount,
            month: month,
            year: year
        })
        
        (ok reward-amount)
    )
)

(define-public (claim-rewards)
    (let (
        (participant tx-sender)
        (participant-info (unwrap! (map-get? participants participant) err-not-registered))
        (reward-amount (get-reward-balance participant))
    )
        (asserts! (> reward-amount u0) err-no-rewards-available)
        
        ;; Update participant info
        (map-set participants participant (merge participant-info {
            total-rewards-earned: (+ (get total-rewards-earned participant-info) reward-amount),
            last-claim-block: block-height
        }))
        
        ;; Reset reward balance
        (map-set reward-balances participant u0)
        
        ;; Update total rewards distributed
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
        
        (print {
            event: "rewards-claimed",
            participant: participant,
            amount: reward-amount,
            block-height: block-height
        })
        
        (ok reward-amount)
    )
)

(define-public (verify-harvest (participant principal) (month uint) (year uint))
    (let ((record-key {participant: participant, month: month, year: year}))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? harvest-records record-key)
            record (begin
                (map-set harvest-records record-key (merge record {verified: true}))
                (print {
                    event: "harvest-verified",
                    participant: participant,
                    month: month,
                    year: year
                })
                (ok true)
            )
            err-not-found
        )
    )
)

(define-public (set-seasonal-bonus (season uint) (monsoon-mult uint) (dry-mult uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set seasonal-bonuses season {
            monsoon-multiplier: monsoon-mult,
            dry-season-multiplier: dry-mult,
            active: true
        })
        (ok true)
    )
)

(define-public (update-reward-multiplier (participant principal) (new-multiplier uint))
    (let ((participant-info (unwrap! (map-get? participants participant) err-not-registered)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set participants participant (merge participant-info {
            reward-multiplier: new-multiplier
        }))
        (ok true)
    )
)

;; Owner-only functions
(define-public (set-reward-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set reward-rate new-rate)
        (print {event: "reward-rate-updated", new-rate: new-rate})
        (ok true)
    )
)

(define-public (set-minimum-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set minimum-harvest-threshold new-threshold)
        (print {event: "threshold-updated", new-threshold: new-threshold})
        (ok true)
    )
)

;; Analytics functions
(define-read-only (get-monthly-harvest-total (month uint) (year uint))
    (fold + (list ) u0) ;; Simplified for this implementation
)

(define-read-only (get-participant-rank (participant principal))
    (let ((participant-info (unwrap! (map-get? participants participant) err-not-registered)))
        (ok (get total-harvested participant-info))
    )
)

;; Initialize seasonal bonuses
(map-set seasonal-bonuses u1 {monsoon-multiplier: u150, dry-season-multiplier: u80, active: true})
(map-set seasonal-bonuses u2 {monsoon-multiplier: u120, dry-season-multiplier: u90, active: true})
