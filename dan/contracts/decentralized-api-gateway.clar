;; Decentralized API Network - On-Chain Service Marketplace
;; Distributed network for API services and data feeds

;; Constants
(define-constant network-owner tx-sender)
(define-constant err-owner-access-only (err u400))
(define-constant err-service-not-available (err u401))
(define-constant err-unauthorized-access (err u402))
(define-constant err-payment-insufficient (err u403))
(define-constant err-service-already-exists (err u404))
(define-constant err-invalid-input (err u405))

;; Data Variables
(define-data-var network-fee-percentage uint u150) ;; 1.5% network fee

;; Data Maps
(define-map api-services
  { service-key: (string-ascii 40) }
  {
    provider: principal,
    service-title: (string-utf8 120),
    service-info: (string-utf8 600),
    api-category: (string-ascii 28), ;; "data-feed", "compute", "storage", "oracle"
    per-call-price: uint,
    bulk-package-price: uint,
    total-calls: uint,
    service-revenue: uint,
    is-active: bool,
    endpoint-hash: (string-ascii 64) ;; IPFS reference to API docs/schema
  }
)

(define-map client-subscriptions
  { client: principal, service-key: (string-ascii 40) }
  {
    plan-type: (string-ascii 14), ;; "bulk-package" or "per-call"
    active-until: uint,
    calls-remaining: uint,
    total-spent: uint
  }
)

(define-map service-reviews
  { service-key: (string-ascii 40), client: principal }
  {
    quality-rating: uint, ;; 1-5 service quality
    review-text: (string-utf8 450),
    created-at: uint
  }
)

(define-map provider-earnings principal uint)

;; Read-only functions
(define-read-only (get-service (service-key (string-ascii 40)))
  (map-get? api-services { service-key: service-key })
)

(define-read-only (get-subscription (client principal) (service-key (string-ascii 40)))
  (map-get? client-subscriptions { client: client, service-key: service-key })
)

(define-read-only (get-service-review (service-key (string-ascii 40)) (client principal))
  (map-get? service-reviews { service-key: service-key, client: client })
)

(define-read-only (get-provider-earnings (provider principal))
  (default-to u0 (map-get? provider-earnings provider))
)

(define-read-only (can-access-service (client principal) (service-key (string-ascii 40)))
  (let (
    (subscription (get-subscription client service-key))
  )
    (match subscription
      sub-info
        (or 
          (> (get calls-remaining sub-info) u0)
          (> (get active-until sub-info) block-height)
        )
      false
    )
  )
)

;; Public functions

;; Deploy new API service
(define-public (deploy-service
    (service-key (string-ascii 40))
    (service-title (string-utf8 120))
    (service-info (string-utf8 600))
    (api-category (string-ascii 28))
    (per-call-price uint)
    (bulk-package-price uint)
    (endpoint-hash (string-ascii 64))
  )
  (let (
    (existing-service (get-service service-key))
  )
    (asserts! (is-none existing-service) err-service-already-exists)
    (ok (map-set api-services
      { service-key: service-key }
      {
        provider: tx-sender,
        service-title: service-title,
        service-info: service-info,
        api-category: api-category,
        per-call-price: per-call-price,
        bulk-package-price: bulk-package-price,
        total-calls: u0,
        service-revenue: u0,
        is-active: true,
        endpoint-hash: endpoint-hash
      }
    ))
  )
)

;; Purchase bulk package subscription
(define-public (purchase-bulk-package (service-key (string-ascii 40)))
  (let (
    (service (unwrap! (get-service service-key) err-service-not-available))
    (package-cost (get bulk-package-price service))
    (network-cut (/ (* package-cost (var-get network-fee-percentage)) u10000))
    (provider-share (- package-cost network-cut))
  )
    (asserts! (get is-active service) err-service-not-available)
    (try! (stx-transfer? package-cost tx-sender (as-contract tx-sender)))
    
    ;; Update service metrics
    (map-set api-services
      { service-key: service-key }
      (merge service {
        total-calls: (+ (get total-calls service) u1),
        service-revenue: (+ (get service-revenue service) package-cost)
      })
    )
    
    ;; Create subscription
    (map-set client-subscriptions
      { client: tx-sender, service-key: service-key }
      {
        plan-type: "bulk-package",
        active-until: (+ block-height u8640), ;; 60 days
        calls-remaining: u0,
        total-spent: package-cost
      }
    )
    
    ;; Credit provider
    (map-set provider-earnings
      (get provider service)
      (+ (get-provider-earnings (get provider service)) provider-share)
    )
    
    (ok true)
  )
)

;; Buy per-call credits
(define-public (buy-call-credits (service-key (string-ascii 40)) (call-count uint))
  (let (
    (service (unwrap! (get-service service-key) err-service-not-available))
    (total-cost (* (get per-call-price service) call-count))
    (network-cut (/ (* total-cost (var-get network-fee-percentage)) u10000))
    (provider-share (- total-cost network-cut))
  )
    (asserts! (get is-active service) err-service-not-available)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    ;; Update service metrics
    (map-set api-services
      { service-key: service-key }
      (merge service {
        total-calls: (+ (get total-calls service) u1),
        service-revenue: (+ (get service-revenue service) total-cost)
      })
    )
    
    ;; Update or create subscription
    (let (
      (existing-sub (get-subscription tx-sender service-key))
    )
      (match existing-sub
        sub-info
          (map-set client-subscriptions
            { client: tx-sender, service-key: service-key }
            (merge sub-info {
              calls-remaining: (+ (get calls-remaining sub-info) call-count),
              total-spent: (+ (get total-spent sub-info) total-cost)
            })
          )
        (map-set client-subscriptions
          { client: tx-sender, service-key: service-key }
          {
            plan-type: "per-call",
            active-until: u0,
            calls-remaining: call-count,
            total-spent: total-cost
          }
        )
      )
    )
    
    ;; Credit provider
    (map-set provider-earnings
      (get provider service)
      (+ (get-provider-earnings (get provider service)) provider-share)
    )
    
    (ok true)
  )
)

;; Make API call (consumes credit or checks subscription)
(define-public (make-api-call (service-key (string-ascii 40)))
  (let (
    (service (unwrap! (get-service service-key) err-service-not-available))
    (subscription (unwrap! (get-subscription tx-sender service-key) err-unauthorized-access))
  )
    (asserts! (get is-active service) err-service-not-available)
    
    ;; Validate and consume access
    (if (is-eq (get plan-type subscription) "per-call")
      (begin
        (asserts! (> (get calls-remaining subscription) u0) err-unauthorized-access)
        (map-set client-subscriptions
          { client: tx-sender, service-key: service-key }
          (merge subscription {
            calls-remaining: (- (get calls-remaining subscription) u1)
          })
        )
      )
      (asserts! (> (get active-until subscription) block-height) err-unauthorized-access)
    )
    
    (ok true)
  )
)

;; Review a service
(define-public (review-service
    (service-key (string-ascii 40))
    (quality-rating uint)
    (review-text (string-utf8 450))
  )
  (let (
    (service (unwrap! (get-service service-key) err-service-not-available))
  )
    (asserts! (and (>= quality-rating u1) (<= quality-rating u5)) err-invalid-input)
    (asserts! (can-access-service tx-sender service-key) err-unauthorized-access)
    
    (ok (map-set service-reviews
      { service-key: service-key, client: tx-sender }
      {
        quality-rating: quality-rating,
        review-text: review-text,
        created-at: block-height
      }
    ))
  )
)

;; Provider withdraws earnings
(define-public (withdraw-provider-earnings)
  (let (
    (earnings (get-provider-earnings tx-sender))
  )
    (asserts! (> earnings u0) err-service-not-available)
    (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
    (map-set provider-earnings tx-sender u0)
    (ok earnings)
  )
)

;; Update service configuration
(define-public (update-service-config
    (service-key (string-ascii 40))
    (service-title (string-utf8 120))
    (service-info (string-utf8 600))
    (per-call-price uint)
    (bulk-package-price uint)
    (endpoint-hash (string-ascii 64))
    (is-active bool)
  )
  (let (
    (service (unwrap! (get-service service-key) err-service-not-available))
  )
    (asserts! (is-eq (get provider service) tx-sender) err-unauthorized-access)
    
    (ok (map-set api-services
      { service-key: service-key }
      (merge service {
        service-title: service-title,
        service-info: service-info,
        per-call-price: per-call-price,
        bulk-package-price: bulk-package-price,
        endpoint-hash: endpoint-hash,
        is-active: is-active
      })
    ))
  )
)

;; Network admin function
(define-public (set-network-fee (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender network-owner) err-owner-access-only)
    (asserts! (<= new-fee-percentage u1000) err-invalid-input) ;; Max 10%
    (ok (var-set network-fee-percentage new-fee-percentage))
  )
)