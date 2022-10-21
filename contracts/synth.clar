
;; synth
;; Synthetic asset token collateralized by STX and powered by RedStone oracles

;; (impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; constants
(define-constant ERR_CODE_INVALID_AMOUNT u1)
(define-constant ERR_CODE_STX_TRANSFER_FAILED_DURING_MINTING u2)
(define-constant ERR_CODE_CANNOT_REMOVE_MORE_COLLATERAL_THAN_HAVE u3)
(define-constant ERR_CODE_ACCOUNT_MUST_REMAIN_SOLVENT u4)
(define-constant ERR_INVALID_AMOUNT_PARAM (err "Invalid amount"))
(define-constant ERR_INTERNAL_ERROR (err "Internal error"))
(define-constant REDSTONE_MULTIPLIER u100000000)
(define-constant MIN_SOLVENCY_RATIO u1200) ;; 120%
(define-constant SUCCESS_MSG "Success")
(define-constant ctr-dplyr tx-sender)

;; data maps and vars
(define-fungible-token synth-ft)
(define-fungible-token locked-stx-ft)


;; private functions
(define-private (get-oracle-stx-price) (* u3 REDSTONE_MULTIPLIER))

;; (define-private (is-solvent (account principal)) (
;;   let
;;     (
;;       (synth-balance (ft-get-balance synth-ft account))
;;       (locked-stx-balance (ft-get-balance locked-stx-ft account))
;;       (stx-usd-price (get-oracle-stx-price))
;;       (ratio (/ (/ (* locked-stx-balance stx-usd-price) synth-balance) u1000000))
;;     )
;;     (> ratio MIN_SOLVENCY_RATIO)
;; ))

(define-private (is-solvent (account principal))
  (> (get-solvency-ratio account) MIN_SOLVENCY_RATIO)
)

;; public functions
(define-public (add-collateral (amount uint))
  (if (<= amount u0)
    (err ERR_CODE_INVALID_AMOUNT)
    (if (is-ok (stx-transfer? amount tx-sender ctr-dplyr))
      (ft-mint? locked-stx-ft amount tx-sender)
      (err ERR_CODE_STX_TRANSFER_FAILED_DURING_MINTING)
    )
  )
)

(define-public (remove-collateral (amount uint))
  (if (<= amount u0)
    (err ERR_CODE_INVALID_AMOUNT)
    (if (is-ok (ft-burn? locked-stx-ft amount tx-sender))
      (if (is-solvent tx-sender)
        (as-contract (stx-transfer? amount tx-sender ctr-dplyr))
        (err ERR_CODE_CANNOT_REMOVE_MORE_COLLATERAL_THAN_HAVE)
      )
      (err ERR_CODE_ACCOUNT_MUST_REMAIN_SOLVENT)
    )
  )
)

;; mint new synth-ft
(define-public (mint (amount uint)) 
  (if (<= amount u0)
    ERR_INVALID_AMOUNT_PARAM
    (begin
      (unwrap! (ft-mint? synth-ft amount tx-sender) (err "Synth minting failed"))
      (asserts! (is-solvent tx-sender) (err "Account must remain solvent"))
      (ok SUCCESS_MSG)
    )
  )
)

;; burn synth-fts
(define-public (burn (amount uint))
  (if (<= amount u0)
    ERR_INVALID_AMOUNT_PARAM
    (begin
      (unwrap! (ft-burn? synth-ft amount tx-sender) (err "Synth burning failed"))
      (ok SUCCESS_MSG)
    )
  )
)

;; TODO: implement
(define-public (liquidate (account-to-liquidate principal)) (ok 42))

;; read-only functions
(define-read-only (get-solvency-ratio (account principal)) (
  let
    (
      (synth-balance (ft-get-balance synth-ft account))
      (locked-stx-balance (ft-get-balance locked-stx-ft account))
      (stx-usd-price (get-oracle-stx-price))
      (ratio (/ (/ (* locked-stx-balance stx-usd-price) synth-balance) u1000000))
    )
    ratio
))

;; TODO: remove
;; (define-public (asserts-example (input bool))
;;   (if (or input true)
;;     (err "hmm")
;;     (begin
;;       (asserts! input (err "the assertion failed"))
;;       (asserts! (not input) (err "the assertion failed"))
;;       (asserts! true (err "the assertion failed"))
;;       (try! (if input (ok u42) (err "Hhaha")))
;;       (ok "end of the function")
;;     )
;;   ) 
;; )
