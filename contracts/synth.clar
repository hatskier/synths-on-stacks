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

(define-constant decimals u6)
(define-constant redstone-multiplier u100000000)
(define-constant min-solvency-ratio u12000) ;; 120%
(define-constant success-response (ok u0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STATE VARS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-data-var initialized bool false)
(define-data-var name (string-ascii 32) "Synth Apple stock")
(define-data-var symbol (string-ascii 32) "SYNTH-AAPL")
(define-data-var data-feed-id-of-underlying-asset (string-ascii 64) "AAPL")
(define-fungible-token debt-ft)
(define-fungible-token synth-ft)
(define-fungible-token locked-stx-ft)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; READ-ONLY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; In the current version, oracle values are hardcoded
(define-read-only (get-stx-price-from-oracle) (* u3 redstone-multiplier))
(define-read-only (get-price-of-underlying-asset-from-oracle) (* u150 redstone-multiplier))

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
  (/ (* u10000 (get-collateral-usd-value account)) (get-debt-usd-value account))
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
;; PUBLIC FUNCTIONS (WITH STATE MODIFICATIONS)
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

(define-public (remove-collateral (stx-amount uint))
  (let ((recipient tx-sender))
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (> stx-amount u0) err-invalid-amount-param)
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

(define-public (mint (synth-amount uint))
  (begin
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (> synth-amount u0) err-invalid-amount-param)
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

(define-public (liquidate (liquidatable principal))
  (let
    (
      (debt-amount (ft-get-balance synth-ft liquidatable))
      (liquidation-stx-reward (ft-get-balance locked-stx-ft liquidatable))
      (liquidator tx-sender)
    )

    (asserts! (var-get initialized) err-not-initialized)

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
