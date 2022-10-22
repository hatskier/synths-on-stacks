;; synth
;; Synthetic asset token collateralized by STX and powered by RedStone oracles
;; Author: Alex Suvorov (alex@redstone.finance)

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CONSTANTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant err-invalid-amount-param (err u0))
(define-constant err-account-must-remain-solvent (err u1))
(define-constant err-cannot-remove-more-collateral-than-have (err u2))
(define-constant err-stx-transfer-failed (err u3))
(define-constant err-symbol-can-not-be-empty (err u4))
(define-constant err-invalid-data-feed-id (err u5))
(define-constant err-can-not-liquidate-solvent-account (err u6))
(define-constant err-already-initialized (err u7))
(define-constant err-synth-minting-failed (err u8))
(define-constant err-debt-saving-failed (err u9))
(define-constant err-synth-burning-failed (err u10))
(define-constant err-debt-decreasing-failed (err u11))
(define-constant err-not-initialized (err u12))
(define-constant err-token-uri-feat-not-implemented (err u13))
(define-constant err-oracle-data-update-failed (err u14))
(define-constant err-redstone-payload-cannot-be-empty (err u15))

(define-constant decimals u6)
(define-constant oracle-data-ttl-seconds u120)
(define-constant redstone-multiplier u100000000)
(define-constant min-solvency-ratio u12000) ;; 120%
(define-constant success-response (ok u0))
(define-constant pseudo-infinity u10000000000000000000)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STATE VARS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var initialized bool false)
(define-data-var name (string-ascii 32) "Synth Apple stock")
(define-data-var symbol (string-ascii 32) "SYNTH-AAPL")
(define-data-var stx-usd-data-feed-id (string-ascii 64) "STX")
(define-data-var data-feed-id-of-underlying-asset (string-ascii 64) "AAPL")
(define-data-var stx-price-from-oracle uint (* u3 redstone-multiplier))
(define-data-var underlying-asset-price-from-oracle uint (* u150 redstone-multiplier))
(define-data-var last-oracle-update-timestamp uint u0)
(define-fungible-token debt-ft)
(define-fungible-token synth-ft)
(define-fungible-token locked-stx-ft)

;; Define trusted RedStone signers
(define-map trusted-oracles (buff 33) bool)
(map-set trusted-oracles 0x035ca791fed34bf9e9d54c0ce4b9626e1382cf13daa46aa58b657389c24a751cc6 true)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; READ-ONLY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-stx-price-from-oracle)
  (var-get stx-price-from-oracle)
)

(define-read-only (get-price-of-underlying-asset-from-oracle)
  (var-get underlying-asset-price-from-oracle)
)

;; Returns collateral value in USD (multiplied by 10^8)
(define-read-only (get-collateral-usd-value (account principal))
  (let
    (
      (locked-stx-balance (ft-get-balance locked-stx-ft account))
      (stx-usd-price (get-stx-price-from-oracle))
    )
    (* stx-usd-price locked-stx-balance)
  )
)

;; Returns USD value of minted synths by a user (multiplied by 10^8)
(define-read-only (get-debt-usd-value (account principal))
  (let
    (
      (minted-synths (ft-get-balance debt-ft account))
      (underlying-asset-price (get-price-of-underlying-asset-from-oracle))
    )
    (* underlying-asset-price minted-synths)
  )
)

;; Returns ratio between collateral value and debt value
;; (in percentage points, e.g. 14575 means 145.75%)
(define-read-only (get-solvency-ratio (account principal))
  (let
    ((debt-usd-value (get-debt-usd-value account)))
    (if (is-eq debt-usd-value u0)
      pseudo-infinity
      (/ (* u10000 (get-collateral-usd-value account)) (get-debt-usd-value account))
    )
  )
)

(define-read-only (is-solvent (account principal))
  (> (get-solvency-ratio account) min-solvency-ratio)
)

(define-read-only (get-name)
  (if (var-get initialized) (ok (var-get name)) err-not-initialized)
)

(define-read-only (get-symbol)
  (if (var-get initialized)
    (ok (var-get symbol))
    err-not-initialized
  )
)

(define-read-only (get-decimals)
  (ok decimals)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance synth-ft account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply synth-ft))
)

(define-read-only (get-token-uri)
  err-token-uri-feat-not-implemented
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PRIVATE FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (get-block-timestamp)
  (default-to u0 (get-block-info? time block-height))
)

;; This function currently contains a mock implementation
;; It will be implemented correctly with the new version of redstone-stacks connector
;; It will verify data timestamp and signature in the redstone-payload buffer
;; Adn return the corresponding value
(define-private (verify-and-extract (data-feed-id (string-ascii 64)) (redstone-payload (buff 1024)))
  (if (is-eq data-feed-id "STX")
    (var-get stx-price-from-oracle)
    (var-get underlying-asset-price-from-oracle)
  )
)

;; This function updates the oracle value "lazily"
;; It doesn't update the value if it was recently updated
(define-private (lazy-oracle-refresh (redstone-payload (buff 1024)))
  (if
    (>
      (- (get-block-timestamp) (var-get last-oracle-update-timestamp))
      oracle-data-ttl-seconds
    )
    (let
      (
        (new-stx-price
          (verify-and-extract (var-get stx-usd-data-feed-id) redstone-payload)
        )
        (new-underlying-asset-price
          (verify-and-extract (var-get data-feed-id-of-underlying-asset) redstone-payload)
        )
      )
      (asserts! (> (len redstone-payload) u0) err-redstone-payload-cannot-be-empty)
      (var-set last-oracle-update-timestamp (get-block-timestamp))
      (var-set stx-price-from-oracle new-stx-price)
      (var-set underlying-asset-price-from-oracle new-underlying-asset-price)
      success-response
    )
    success-response
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PUBLIC FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public
  (initialize
    (initial-data-feed-id-of-underlying-asset (string-ascii 64))
    (initial-symbol (string-ascii 32))
  )
  (begin
    (asserts! (not (var-get initialized)) err-already-initialized)
    (asserts!
      (not (is-eq initial-data-feed-id-of-underlying-asset ""))
      err-invalid-data-feed-id
    )
    (asserts!
      (not (is-eq initial-symbol ""))
      err-symbol-can-not-be-empty
    )
    (var-set data-feed-id-of-underlying-asset initial-data-feed-id-of-underlying-asset)
    (var-set symbol initial-symbol)
    (var-set initialized true)
    success-response
  )
)


(define-public (add-collateral (stx-amount uint))
  (begin
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (> stx-amount u0) err-invalid-amount-param)
    (unwrap!
      (stx-transfer? stx-amount tx-sender (as-contract tx-sender))
      err-stx-transfer-failed
    )
    (unwrap-panic (ft-mint? locked-stx-ft stx-amount tx-sender))
    success-response
  )
)

(define-public (remove-collateral (stx-amount uint) (redstone-payload (buff 1024)))
  (let ((recipient tx-sender))
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (> stx-amount u0) err-invalid-amount-param)
    (unwrap! (lazy-oracle-refresh redstone-payload) err-oracle-data-update-failed)
    (unwrap!
      (ft-burn? locked-stx-ft stx-amount tx-sender)
      err-cannot-remove-more-collateral-than-have
    )
    (asserts! (is-solvent tx-sender) err-account-must-remain-solvent)
    (unwrap!
      (as-contract (stx-transfer? stx-amount tx-sender recipient))
      err-stx-transfer-failed
    )
    success-response
  )
)

(define-public (mint (synth-amount uint) (redstone-payload (buff 1024)))
  (begin
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (> synth-amount u0) err-invalid-amount-param)
    (unwrap! (lazy-oracle-refresh redstone-payload) err-oracle-data-update-failed)
    (unwrap! (ft-mint? synth-ft synth-amount tx-sender) err-synth-minting-failed)
    (unwrap! (ft-mint? debt-ft synth-amount tx-sender) err-debt-saving-failed)
    (asserts! (is-solvent tx-sender) err-account-must-remain-solvent)
    success-response
  )
)

(define-public
  (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (> amount u0) err-invalid-amount-param)
    (asserts! (is-eq sender tx-sender) (err u1))
    (asserts! (not (is-eq recipient tx-sender)) (err u2))
    (ft-transfer? synth-ft amount sender recipient)
  )
)

(define-public (burn (synth-amount uint))
  (begin
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (> synth-amount u0) err-invalid-amount-param)
    (unwrap! (ft-burn? synth-ft synth-amount tx-sender) err-synth-burning-failed)
    (unwrap! (ft-burn? debt-ft synth-amount tx-sender) err-debt-decreasing-failed)
    success-response
  )
)

(define-public (liquidate (liquidatable principal) (redstone-payload (buff 1024)))
  (let
    (
      (debt-amount (ft-get-balance synth-ft liquidatable))
      (liquidation-stx-reward (ft-get-balance locked-stx-ft liquidatable))
      (liquidator tx-sender)
    )
    (asserts! (var-get initialized) err-not-initialized)
    (unwrap! (lazy-oracle-refresh redstone-payload) err-oracle-data-update-failed)

    ;; Checking if the account is not solvent
    (asserts!
      (not (is-solvent liquidatable))
      err-can-not-liquidate-solvent-account
    )

    ;; Burning synth tokens owned by liquidator
    (unwrap! (ft-burn? synth-ft debt-amount tx-sender) err-synth-burning-failed)

    ;; Transfering locked STX of the liqudated account to the liquidator
    (unwrap!
      (as-contract (stx-transfer? liquidation-stx-reward tx-sender liquidator))
      err-stx-transfer-failed
    )

    ;; Decrease the debt of the liquided account
    (unwrap-panic
      (ft-burn? debt-ft debt-amount liquidatable)
    )

    success-response
  )
)
