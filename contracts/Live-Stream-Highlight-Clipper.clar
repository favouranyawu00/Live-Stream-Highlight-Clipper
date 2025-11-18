(define-constant BPS u10000)
(define-constant err-unauthorized u100)
(define-constant err-invalid-bps u101)
(define-constant err-invalid-threshold u102)
(define-constant err-clip-not-found u103)
(define-constant err-already-engaged u104)
(define-constant err-already-minted u105)
(define-constant err-threshold-not-met u106)
(define-constant err-invalid-rating u107)
(define-constant err-already-rated u108)
(define-constant err-cannot-rate-own-clip u109)
(define-constant err-clip-not-minted u110)
(define-constant err-invalid-amount u111)

(define-data-var owner principal tx-sender)
(define-data-var next-id uint u1)

(define-non-fungible-token clip uint)

(define-map clips {id: uint} {creator: principal, uri: (string-ascii 256), threshold: uint, engagements: uint, minted: bool, creator-bps: uint, platform: principal})
(define-map engaged {id: uint, user: principal} {flag: bool})
(define-map clip-ratings {id: uint, user: principal} {rating: uint})
(define-map clip-rating-stats {id: uint} {total-ratings: uint, rating-sum: uint, average-rating: uint})
(define-map creator-reputation {creator: principal} {total-clips: uint, total-rating-sum: uint, total-ratings: uint, reputation-score: uint})
(define-map clip-tips {id: uint} {total-tips: uint, total-tips-count: uint})

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

(define-public (rate-clip (id uint) (rating uint))
  (let ((clip-data (map-get? clips {id: id})))
    (match clip-data
      c
      (if (get minted c)
          (if (not (is-eq (get creator c) tx-sender))
              (if (and (>= rating u1) (<= rating u5))
                  (if (is-none (map-get? clip-ratings {id: id, user: tx-sender}))
                      (let ((current-stats (default-to {total-ratings: u0, rating-sum: u0, average-rating: u0} (map-get? clip-rating-stats {id: id})))
                            (new-total-ratings (+ (get total-ratings current-stats) u1))
                            (new-rating-sum (+ (get rating-sum current-stats) rating))
                            (new-average (/ new-rating-sum new-total-ratings))
                            (creator (get creator c))
                            (current-rep (default-to {total-clips: u0, total-rating-sum: u0, total-ratings: u0, reputation-score: u0} (map-get? creator-reputation {creator: creator})))
                            (new-creator-ratings (+ (get total-ratings current-rep) u1))
                            (new-creator-sum (+ (get total-rating-sum current-rep) rating))
                            (new-creator-score (/ new-creator-sum new-creator-ratings)))
                        (begin
                          (map-set clip-ratings {id: id, user: tx-sender} {rating: rating})
                          (map-set clip-rating-stats {id: id} {total-ratings: new-total-ratings, rating-sum: new-rating-sum, average-rating: new-average})
                          (map-set creator-reputation {creator: creator} {total-clips: (get total-clips current-rep), total-rating-sum: new-creator-sum, total-ratings: new-creator-ratings, reputation-score: new-creator-score})
                          (ok new-average)))
                      (err err-already-rated))
                  (err err-invalid-rating))
              (err err-cannot-rate-own-clip))
          (err err-clip-not-minted))
      (err err-clip-not-found))))

(define-read-only (get-clip-rating (id uint))
  (match (map-get? clip-rating-stats {id: id})
    stats (ok {total-ratings: (get total-ratings stats), average-rating: (get average-rating stats)})
    (ok {total-ratings: u0, average-rating: u0})))

(define-read-only (get-user-rating (id uint) (user principal))
  (match (map-get? clip-ratings {id: id, user: user})
    rating-data (ok (some (get rating rating-data)))
    (ok none)))

(define-read-only (get-creator-reputation-score (creator principal))
  (match (map-get? creator-reputation {creator: creator})
    rep (ok (get reputation-score rep))
    (ok u0)))

(define-read-only (get-creator-stats (creator principal))
  (match (map-get? creator-reputation {creator: creator})
    rep (ok {total-clips: (get total-clips rep), total-ratings: (get total-ratings rep), reputation-score: (get reputation-score rep)})
    (ok {total-clips: u0, total-ratings: u0, reputation-score: u0})))

(define-public (tip-creator (id uint) (amount uint))
  (match (map-get? clips {id: id})
    c
    (if (> amount u0)
        (let ((creator (get creator c))
              (tips (default-to {total-tips: u0, total-tips-count: u0} (map-get? clip-tips {id: id})))
              (new-total (+ (get total-tips tips) amount))
              (new-count (+ (get total-tips-count tips) u1)))
          (begin
            (try! (stx-transfer? amount tx-sender creator))
            (map-set clip-tips {id: id} {total-tips: new-total, total-tips-count: new-count})
            (ok {total-tips: new-total, total-tips-count: new-count})))
        (err err-invalid-amount))
    (err err-clip-not-found)))

(define-read-only (get-clip-tips (id uint))
  (ok (default-to {total-tips: u0, total-tips-count: u0} (map-get? clip-tips {id: id}))))

(define-read-only (can-rate-clip (id uint) (user principal))
  (match (map-get? clips {id: id})
    c (ok (and (get minted c) (not (is-eq (get creator c) user)) (is-none (map-get? clip-ratings {id: id, user: user}))))
    (ok false)))
