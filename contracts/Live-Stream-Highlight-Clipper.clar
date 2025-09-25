(define-constant BPS u10000)
(define-constant err-unauthorized u100)
(define-constant err-invalid-bps u101)
(define-constant err-invalid-threshold u102)
(define-constant err-clip-not-found u103)
(define-constant err-already-engaged u104)
(define-constant err-already-minted u105)
(define-constant err-threshold-not-met u106)

(define-data-var owner principal tx-sender)
(define-data-var next-id uint u1)

(define-non-fungible-token clip uint)

(define-map clips {id: uint} {creator: principal, uri: (string-ascii 256), threshold: uint, engagements: uint, minted: bool, creator-bps: uint, platform: principal})
(define-map engaged {id: uint, user: principal} {flag: bool})

(define-read-only (get-owner) (ok (var-get owner)))
(define-read-only (get-next-id) (ok (var-get next-id)))

(define-read-only (get-clip (id uint)) (map-get? clips {id: id}))
(define-read-only (get-engagements (id uint))
  (match (map-get? clips {id: id})
    c (ok (get engagements c))
    (ok u0)))

(define-read-only (can-engage (id uint) (user principal))
  (ok (and (is-some (map-get? clips {id: id})) (is-none (map-get? engaged {id: id, user: user})))))

(define-read-only (can-mint (id uint))
  (match (map-get? clips {id: id})
    c
    (ok (and (not (get minted c)) (>= (get engagements c) (get threshold c))))
    (ok false)))

(define-read-only (get-owner-of (id uint)) (nft-get-owner? clip id))

(define-public (set-owner (new-owner principal))
  (if (is-eq tx-sender (var-get owner))
      (begin (var-set owner new-owner) (ok true))
      (err err-unauthorized)))

(define-public (create-clip (uri (string-ascii 256)) (threshold uint) (creator principal) (creator-bps uint) (platform principal))
  (if (is-eq creator tx-sender)
      (if (>= threshold u1)
          (if (<= creator-bps BPS)
              (let ((id (var-get next-id)))
                (begin
                  (map-set clips {id: id} {creator: creator, uri: uri, threshold: threshold, engagements: u0, minted: false, creator-bps: creator-bps, platform: platform})
                  (var-set next-id (+ id u1))
                  (ok id)))
              (err err-invalid-bps))
          (err err-invalid-threshold))
      (err err-unauthorized)))

(define-public (engage-clip (id uint))
  (match (map-get? clips {id: id})
    c
    (if (not (get minted c))
        (if (is-none (map-get? engaged {id: id, user: tx-sender}))
            (begin
              (map-set engaged {id: id, user: tx-sender} {flag: true})
              (map-set clips {id: id} {creator: (get creator c), uri: (get uri c), threshold: (get threshold c), engagements: (+ u1 (get engagements c)), minted: (get minted c), creator-bps: (get creator-bps c), platform: (get platform c)})
              (ok (+ u1 (get engagements c))))
            (err err-already-engaged))
        (err err-already-minted))
    (err err-clip-not-found)))

(define-public (finalize-mint (id uint) (price uint))
  (match (map-get? clips {id: id})
    c
    (if (not (get minted c))
        (if (>= (get engagements c) (get threshold c))
            (let ((creator (get creator c))
                  (platform (get platform c))
                  (bps (get creator-bps c))
                  (creator-share (/ (* price bps) BPS))
                  (platform-share (- price (/ (* price bps) BPS))))
              (begin
                (if (> price u0)
                  (begin
                    (if (> creator-share u0) (try! (stx-transfer? creator-share tx-sender creator)) true)
                    (if (> platform-share u0) (try! (stx-transfer? platform-share tx-sender platform)) true))
                  true)
                (try! (nft-mint? clip id creator))
                (map-set clips {id: id} {creator: creator, uri: (get uri c), threshold: (get threshold c), engagements: (get engagements c), minted: true, creator-bps: bps, platform: platform})
                (ok id)))
            (err err-threshold-not-met))
        (err err-already-minted))
    (err err-clip-not-found)))

(define-public (transfer (id uint) (to principal))
  (let ((owner-opt (nft-get-owner? clip id)))
    (match owner-opt
      o
      (if (is-eq o tx-sender)
          (begin (try! (nft-transfer? clip id tx-sender to)) (ok true))
          (err err-unauthorized))
      (err err-clip-not-found))))

(define-read-only (get-clip-uri (id uint))
  (match (map-get? clips {id: id})
    c (ok (get uri c))
    (ok "")))

(define-read-only (get-clip-split (id uint))
  (match (map-get? clips {id: id})
    c (ok {creator: (get creator c), creator-bps: (get creator-bps c), platform: (get platform c)})
    (ok {creator: tx-sender, creator-bps: u0, platform: tx-sender})))

(define-read-only (get-threshold (id uint))
  (match (map-get? clips {id: id})
    c (ok (get threshold c))
    (ok u0)))

(define-public (update-split (id uint) (creator-bps uint) (platform principal))
  (match (map-get? clips {id: id})
    c
    (if (is-eq (get creator c) tx-sender)
        (if (<= creator-bps BPS)
            (begin
              (map-set clips {id: id} {creator: (get creator c), uri: (get uri c), threshold: (get threshold c), engagements: (get engagements c), minted: (get minted c), creator-bps: creator-bps, platform: platform})
              (ok true))
            (err err-invalid-bps))
        (err err-unauthorized))
    (err err-clip-not-found)))

(define-public (update-threshold (id uint) (threshold uint))
  (match (map-get? clips {id: id})
    c
    (if (is-eq (get creator c) tx-sender)
        (if (>= threshold u1)
            (begin
              (map-set clips {id: id} {creator: (get creator c), uri: (get uri c), threshold: threshold, engagements: (get engagements c), minted: (get minted c), creator-bps: (get creator-bps c), platform: (get platform c)})
              (ok true))
            (err err-invalid-threshold))
        (err err-unauthorized))
    (err err-clip-not-found)))

(define-read-only (get-total-created)
  (ok (- (var-get next-id) u1)))

(define-read-only (is-minted (id uint))
  (match (map-get? clips {id: id})
    c (ok (get minted c))
    (ok false)))

(define-read-only (get-creator (id uint))
  (match (map-get? clips {id: id})
    c (ok (some (get creator c)))
    (ok none)))

(define-read-only (get-platform (id uint))
  (match (map-get? clips {id: id})
    c (ok (some (get platform c)))
    (ok none)))
