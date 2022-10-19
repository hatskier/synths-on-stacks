
;; sample-sip-010-token
;; A simplified version of a fungible token
;; created by alex@redstone.finance

;; constants
(define-constant decimals 6)

;; data maps and vars
(define-map balances
  { owner:  principal }
  { balance:  uint })
(define-data-var total-supply uint u0)

;; private functions
(define-private (get-balance (account principal))
  u10
  ;; (begin
    ;; (default-to u0
    ;;   (get balance
    ;;      (map-get? balances ((owner account)))))
)


;; public functions
(define-public (get-total-supply)
  (ok (var-get total-supply))
)

(define-public (balance-of (account principal))
  (begin
      (print account)
      ;; (ok (map-get? balances (owner)))
      (ok u10)
  )
)

(define-public (mint (amount uint))
  (if (< amount u0)
    (err false)
    (begin
      (var-set total-supply (+ (var-get total-supply) amount))
      ;; (ok amount)))
      (let ((balance (get-balance tx-sender)))
        ;; (map-set balances (addr) (+ balance amount))
        (ok amount)
      )))
)
