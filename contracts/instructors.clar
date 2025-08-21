;; Meditation Instructors Management Contract
;; Handles instructor registration, qualifications, and ratings

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSTRUCTOR-EXISTS (err u101))
(define-constant ERR-INSTRUCTOR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-RATING (err u103))
(define-constant ERR-INVALID-EXPERIENCE (err u104))

;; Data Variables
(define-data-var next-instructor-id uint u1)

;; Data Maps
(define-map instructors
  { instructor-id: uint }
  {
    principal: principal,
    name: (string-ascii 100),
    bio: (string-ascii 500),
    experience-years: uint,
    specializations: (string-ascii 200),
    certifications: (string-ascii 300),
    hourly-rate-microstx: uint,
    total-sessions: uint,
    average-rating: uint,
    total-ratings: uint,
    is-verified: bool,
    registered-at: uint
  }
)

(define-map instructor-by-principal
  { principal: principal }
  { instructor-id: uint }
)

;; Public Functions

;; Register a new instructor
(define-public (register-instructor
  (name (string-ascii 100))
  (bio (string-ascii 500))
  (experience-years uint)
  (specializations (string-ascii 200))
  (certifications (string-ascii 300))
  (hourly-rate-microstx uint))
  (let
    (
      (instructor-id (var-get next-instructor-id))
      (caller tx-sender)
    )
    ;; Validate inputs
    (asserts! (<= experience-years u50) ERR-INVALID-EXPERIENCE)
    (asserts! (is-none (map-get? instructor-by-principal { principal: caller })) ERR-INSTRUCTOR-EXISTS)

    ;; Store instructor data
    (map-set instructors
      { instructor-id: instructor-id }
      {
        principal: caller,
        name: name,
        bio: bio,
        experience-years: experience-years,
        specializations: specializations,
        certifications: certifications,
        hourly-rate-microstx: hourly-rate-microstx,
        total-sessions: u0,
        average-rating: u0,
        total-ratings: u0,
        is-verified: false,
        registered-at: block-height
      }
    )

    ;; Create reverse lookup
    (map-set instructor-by-principal
      { principal: caller }
      { instructor-id: instructor-id }
    )

    ;; Increment next ID
    (var-set next-instructor-id (+ instructor-id u1))

    (ok instructor-id)
  )
)

;; Verify instructor (only contract owner)
(define-public (verify-instructor (instructor-id uint))
  (let
    (
      (instructor-data (map-get? instructors { instructor-id: instructor-id }))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some instructor-data) ERR-INSTRUCTOR-NOT-FOUND)

    (let
      (
        (current-instructor (unwrap-panic instructor-data))
      )
      (map-set instructors
        { instructor-id: instructor-id }
        (merge current-instructor { is-verified: true })
      )
      (ok true)
    )
  )
)

;; Rate instructor
(define-public (rate-instructor (instructor-id uint) (rating uint))
  (let
    (
      (instructor-data (map-get? instructors { instructor-id: instructor-id }))
    )
    (asserts! (is-some instructor-data) ERR-INSTRUCTOR-NOT-FOUND)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)

    (let
      (
        (current-instructor (unwrap-panic instructor-data))
        (current-total (get total-ratings current-instructor))
        (current-avg (get average-rating current-instructor))
        (new-total (+ current-total u1))
        (new-avg (/ (+ (* current-avg current-total) rating) new-total))
      )
      (map-set instructors
        { instructor-id: instructor-id }
        (merge current-instructor {
          average-rating: new-avg,
          total-ratings: new-total
        })
      )
      (ok true)
    )
  )
)

;; Read-only Functions

;; Get instructor by ID
(define-read-only (get-instructor (instructor-id uint))
  (map-get? instructors { instructor-id: instructor-id })
)

;; Get instructor ID by principal
(define-read-only (get-instructor-id-by-principal (principal principal))
  (map-get? instructor-by-principal { principal: principal })
)

;; Get next instructor ID
(define-read-only (get-next-instructor-id)
  (var-get next-instructor-id)
)
