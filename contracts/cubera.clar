;; Data Variables
(define-data-var dispute-counter uint u0)
(define-data-var appeal-counter uint u0)
(define-data-var private-dispute-counter uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var reward-pool uint u0)

;; Dispute Categories
(define-constant CATEGORY_GENERAL u1)
(define-constant CATEGORY_FINANCIAL u2)
(define-constant CATEGORY_TECHNICAL u3)
(define-constant CATEGORY_CONTENT u4)

;; Privacy Constants
(define-constant PRIVACY_LEVEL_PUBLIC u0)
(define-constant PRIVACY_LEVEL_ENCRYPTED u1)
(define-constant PRIVACY_LEVEL_COMMITMENT u2)

;; Data Maps
(define-map disputes uint
  {
    complainant: principal,
    defendant: principal,
    description: (string-ascii 200),
    category: uint,
    stake: uint,
    resolved: bool,
    ruling: (optional bool), ;; true = for complainant, false = for defendant
    created-at: uint,
    resolved-at: (optional uint),
    appeal-id: (optional uint)
  })

;; Privacy-Preserving Disputes
(define-map private-disputes uint
  {
    complainant: principal,
    defendant: principal,
    commitment: (buff 32), ;; Hash of encrypted dispute details
    category: uint,
    stake: uint,
    resolved: bool,
    ruling: (optional bool),
    created-at: uint,
    resolved-at: (optional uint),
    appeal-id: (optional uint),
    privacy-level: uint,
    reveal-deadline: uint,
    revealed: bool
  })

;; Commitment-Reveal for Private Disputes
(define-map dispute-reveals uint
  {
    description: (string-ascii 200),
    evidence-hash: (optional (buff 32)),
    salt: (buff 32),
    revealed-by: principal,
    revealed-at: uint
  })

;; Encrypted Evidence Storage
(define-map encrypted-evidence uint
  {
    dispute-id: uint,
    evidence-hash: (buff 32),
    submitter: principal,
    encryption-key-hash: (buff 32),
    submitted-at: uint,
    evidence-type: uint ;; 1=document, 2=image, 3=transaction, 4=other
  })

(define-map appeals uint
  {
    original-dispute-id: uint,
    appellant: principal,
    appeal-stake: uint,
    resolved: bool,
    ruling: (optional bool),
    created-at: uint,
    resolved-at: (optional uint),
    deadline: uint
  })

(define-map juror-votes {dispute-id: uint, juror: principal} bool)
(define-map private-juror-votes {dispute-id: uint, juror: principal} bool)
(define-map appeal-votes {appeal-id: uint, juror: principal} bool)
(define-map vote-tallies uint {yes: uint, no: uint})
(define-map private-vote-tallies uint {yes: uint, no: uint})
(define-map appeal-tallies uint {yes: uint, no: uint})
(define-map authorized-jurors principal bool)

;; Enhanced voter tracking for reward distribution
(define-map dispute-voters uint (list 20 principal))
(define-map private-dispute-voters uint (list 20 principal))
(define-map appeal-voters uint (list 20 principal))

;; Individual vote tracking for reward calculation
(define-map individual-votes {dispute-id: uint, juror: principal} bool)
(define-map individual-private-votes {dispute-id: uint, juror: principal} bool)
(define-map individual-appeal-votes {appeal-id: uint, juror: principal} bool)

;; Economic Incentive System
(define-map juror-stats principal 
  {
    total-votes: uint,
    correct-votes: uint,
    reputation-score: uint,
    total-rewards: uint,
    total-penalties: uint
  })

(define-map juror-specializations principal (list 10 uint)) ;; Categories juror can handle

;; Category Configuration
(define-map category-config uint
  {
    min-stake: uint,
    required-jurors: uint,
    reward-multiplier: uint,
    specialization-required: bool
  })

;; Constants
(define-constant VOTE_THRESHOLD_GENERAL u3)
(define-constant VOTE_THRESHOLD_APPEAL u5)
(define-constant MIN_STAKE_GENERAL u1000000) ;; 1 STX
(define-constant MIN_STAKE_FINANCIAL u5000000) ;; 5 STX
(define-constant MIN_STAKE_TECHNICAL u3000000) ;; 3 STX
(define-constant MIN_STAKE_CONTENT u1000000) ;; 1 STX
(define-constant APPEAL_MULTIPLIER u2) ;; 2x original stake
(define-constant APPEAL_DEADLINE_BLOCKS u1440) ;; ~10 days
(define-constant REVEAL_DEADLINE_BLOCKS u720) ;; ~5 days for reveals
(define-constant MAX_DESCRIPTION_LENGTH u200)
(define-constant ZERO_ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant BASE_REWARD u100000) ;; 0.1 STX base reward
(define-constant REPUTATION_THRESHOLD u80) ;; 80% accuracy for good standing

;; Error Constants
(define-constant ERR_ALREADY_VOTED (err u301))
(define-constant ERR_NOT_JUROR (err u302))
(define-constant ERR_ALREADY_RESOLVED (err u303))
(define-constant ERR_DISPUTE_NOT_FOUND (err u304))
(define-constant ERR_INSUFFICIENT_STAKE (err u305))
(define-constant ERR_UNAUTHORIZED (err u306))
(define-constant ERR_SELF_DISPUTE (err u307))
(define-constant ERR_INVALID_DESCRIPTION (err u308))
(define-constant ERR_INVALID_PRINCIPAL (err u309))
(define-constant ERR_INVALID_CATEGORY (err u310))
(define-constant ERR_NOT_SPECIALIZED (err u311))
(define-constant ERR_APPEAL_DEADLINE_PASSED (err u312))
(define-constant ERR_APPEAL_NOT_FOUND (err u313))
(define-constant ERR_ALREADY_APPEALED (err u314))
(define-constant ERR_CANNOT_APPEAL_UNRESOLVED (err u315))
(define-constant ERR_INVALID_COMMITMENT (err u316))
(define-constant ERR_REVEAL_DEADLINE_PASSED (err u317))
(define-constant ERR_ALREADY_REVEALED (err u318))
(define-constant ERR_INVALID_REVEAL (err u319))
(define-constant ERR_NOT_REVEALED (err u320))
(define-constant ERR_REWARD_TRANSFER_FAILED (err u321))
(define-constant ERR_VOTER_LIST_FULL (err u322))

;; Helper Functions

;; Validate that a principal is not zero address
(define-private (is-valid-principal (address principal))
  (not (is-eq address ZERO_ADDRESS))
)

;; Validate commitment hash (must be non-zero)
(define-private (is-valid-commitment (commitment (buff 32)))
  (not (is-eq commitment 0x00000000000000000000000000000000000000000000000000000000000000))
)

;; Get category configuration
(define-private (get-category-min-stake (category uint))
  (if (is-eq category CATEGORY_FINANCIAL)
    MIN_STAKE_FINANCIAL
    (if (is-eq category CATEGORY_TECHNICAL)
      MIN_STAKE_TECHNICAL
      (if (is-eq category CATEGORY_CONTENT)
        MIN_STAKE_CONTENT
        MIN_STAKE_GENERAL
      )
    )
  )
)

(define-private (get-category-threshold (category uint))
  (if (is-eq category CATEGORY_FINANCIAL)
    u5
    (if (is-eq category CATEGORY_TECHNICAL)
      u4
      VOTE_THRESHOLD_GENERAL
    )
  )
)

;; Check if juror is specialized for category
(define-private (is-specialized-for-category (juror principal) (category uint))
  (let (
    (specializations (default-to (list) (map-get? juror-specializations juror)))
  )
    (or 
      (is-eq category CATEGORY_GENERAL)
      (is-some (index-of specializations category))
    )
  )
)

;; Calculate juror reputation
(define-private (calculate-reputation (total-votes uint) (correct-votes uint))
  (if (is-eq total-votes u0)
    u100 ;; New jurors start with 100% reputation
    (/ (* correct-votes u100) total-votes)
  )
)

;; Update juror stats after voting
(define-private (update-juror-stats (juror principal) (was-correct bool))
  (let (
    (current-stats (default-to 
      {total-votes: u0, correct-votes: u0, reputation-score: u100, total-rewards: u0, total-penalties: u0}
      (map-get? juror-stats juror)
    ))
    (new-total (+ (get total-votes current-stats) u1))
    (new-correct (if was-correct (+ (get correct-votes current-stats) u1) (get correct-votes current-stats)))
  )
    (map-set juror-stats juror (merge current-stats {
      total-votes: new-total,
      correct-votes: new-correct,
      reputation-score: (calculate-reputation new-total new-correct)
    }))
  )
)

;; Update juror rewards after receiving payment
(define-private (update-juror-rewards (juror principal) (reward-amount uint))
  (let (
    (current-stats (default-to 
      {total-votes: u0, correct-votes: u0, reputation-score: u100, total-rewards: u0, total-penalties: u0}
      (map-get? juror-stats juror)
    ))
  )
    (map-set juror-stats juror (merge current-stats {
      total-rewards: (+ (get total-rewards current-stats) reward-amount)
    }))
  )
)

;; Verify commitment-reveal scheme
(define-private (verify-commitment (commitment (buff 32)) (description (string-ascii 200)) (salt (buff 32)))
  (is-eq commitment (sha256 (concat (concat (unwrap-panic (to-consensus-buff? description)) salt) (unwrap-panic (to-consensus-buff? tx-sender)))))
)

;; Initialize contract
(map-set authorized-jurors tx-sender true)
(map-set juror-specializations tx-sender (list CATEGORY_GENERAL CATEGORY_FINANCIAL CATEGORY_TECHNICAL CATEGORY_CONTENT))

;; Public Functions

;; File a new dispute with category
(define-public (file-dispute (defendant principal) (desc (string-ascii 200)) (category uint) (stake uint))
  (let (
    (dispute-id (+ (var-get dispute-counter) u1))
    (current-block stacks-block-height)
    (min-stake (get-category-min-stake category))
  )
    (begin
      ;; Validation checks
      (asserts! (is-valid-principal defendant) ERR_INVALID_PRINCIPAL)
      (asserts! (not (is-eq tx-sender defendant)) ERR_SELF_DISPUTE)
      (asserts! (>= stake min-stake) ERR_INSUFFICIENT_STAKE)
      (asserts! (> (len desc) u0) ERR_INVALID_DESCRIPTION)
      (asserts! (<= (len desc) MAX_DESCRIPTION_LENGTH) ERR_INVALID_DESCRIPTION)
      (asserts! (and (>= category CATEGORY_GENERAL) (<= category CATEGORY_CONTENT)) ERR_INVALID_CATEGORY)
      
      ;; Burn the stake
      (try! (stx-burn? stake tx-sender))
      
      ;; Create dispute record
      (map-set disputes dispute-id {
        complainant: tx-sender,
        defendant: defendant,
        description: desc,
        category: category,
        stake: stake,
        resolved: false,
        ruling: none,
        created-at: current-block,
        resolved-at: none,
        appeal-id: none
      })
      
      ;; Initialize vote tally and voter list
      (map-set vote-tallies dispute-id {yes: u0, no: u0})
      (map-set dispute-voters dispute-id (list))
      
      ;; Update counter
      (var-set dispute-counter dispute-id)
      
      (ok dispute-id)
    )
  )
)

;; File a private dispute with commitment
(define-public (file-private-dispute (defendant principal) (commitment (buff 32)) (category uint) (stake uint) (privacy-level uint))
  (let (
    (dispute-id (+ (var-get private-dispute-counter) u1))
    (current-block stacks-block-height)
    (min-stake (get-category-min-stake category))
    (reveal-deadline (+ current-block REVEAL_DEADLINE_BLOCKS))
  )
    (begin
      ;; Validation checks
      (asserts! (is-valid-principal defendant) ERR_INVALID_PRINCIPAL)
      (asserts! (not (is-eq tx-sender defendant)) ERR_SELF_DISPUTE)
      (asserts! (>= stake min-stake) ERR_INSUFFICIENT_STAKE)
      (asserts! (is-valid-commitment commitment) ERR_INVALID_COMMITMENT)
      (asserts! (and (>= category CATEGORY_GENERAL) (<= category CATEGORY_CONTENT)) ERR_INVALID_CATEGORY)
      (asserts! (<= privacy-level PRIVACY_LEVEL_COMMITMENT) ERR_INVALID_CATEGORY)
      
      ;; Burn the stake
      (try! (stx-burn? stake tx-sender))
      
      ;; Create private dispute record
      (map-set private-disputes dispute-id {
        complainant: tx-sender,
        defendant: defendant,
        commitment: commitment,
        category: category,
        stake: stake,
        resolved: false,
        ruling: none,
        created-at: current-block,
        resolved-at: none,
        appeal-id: none,
        privacy-level: privacy-level,
        reveal-deadline: reveal-deadline,
        revealed: false
      })
      
      ;; Initialize vote tally and voter list
      (map-set private-vote-tallies dispute-id {yes: u0, no: u0})
      (map-set private-dispute-voters dispute-id (list))
      
      ;; Update counter
      (var-set private-dispute-counter dispute-id)
      
      (ok dispute-id)
    )
  )
)

;; Reveal private dispute details
(define-public (reveal-private-dispute (dispute-id uint) (description (string-ascii 200)) (salt (buff 32)) (evidence-hash (optional (buff 32))))
  (let (
    (dispute (unwrap! (map-get? private-disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
    (current-block stacks-block-height)
  )
    (begin
      ;; Validation checks
      (asserts! (or (is-eq tx-sender (get complainant dispute)) (is-eq tx-sender (get defendant dispute))) ERR_UNAUTHORIZED)
      (asserts! (<= current-block (get reveal-deadline dispute)) ERR_REVEAL_DEADLINE_PASSED)
      (asserts! (not (get revealed dispute)) ERR_ALREADY_REVEALED)
      (asserts! (verify-commitment (get commitment dispute) description salt) ERR_INVALID_REVEAL)
      (asserts! (> (len description) u0) ERR_INVALID_DESCRIPTION)
      (asserts! (<= (len description) MAX_DESCRIPTION_LENGTH) ERR_INVALID_DESCRIPTION)
      
      ;; Store reveal details
      (map-set dispute-reveals dispute-id {
        description: description,
        evidence-hash: evidence-hash,
        salt: salt,
        revealed-by: tx-sender,
        revealed-at: current-block
      })
      
      ;; Mark as revealed
      (map-set private-disputes dispute-id (merge dispute {revealed: true}))
      
      (ok true)
    )
  )
)

;; Submit encrypted evidence for private disputes
(define-public (submit-encrypted-evidence (dispute-id uint) (evidence-hash (buff 32)) (encryption-key-hash (buff 32)) (evidence-type uint))
  (let (
    (dispute (unwrap! (map-get? private-disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
    (current-block stacks-block-height)
    (evidence-id (+ dispute-id (* u1000000 current-block))) ;; Simple ID generation
  )
    (begin
      ;; Validation checks
      (asserts! (or (is-eq tx-sender (get complainant dispute)) (is-eq tx-sender (get defendant dispute))) ERR_UNAUTHORIZED)
      (asserts! (not (get resolved dispute)) ERR_ALREADY_RESOLVED)
      (asserts! (and (>= evidence-type u1) (<= evidence-type u4)) ERR_INVALID_CATEGORY)
      
      ;; Store encrypted evidence
      (map-set encrypted-evidence evidence-id {
        dispute-id: dispute-id,
        evidence-hash: evidence-hash,
        submitter: tx-sender,
        encryption-key-hash: encryption-key-hash,
        submitted-at: current-block,
        evidence-type: evidence-type
      })
      
      (ok evidence-id)
    )
  )
)

;; Enhanced vote function with completely inlined reward distribution
(define-public (vote (dispute-id uint) (support bool))
  (let (
    (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
    (current-tally (unwrap! (map-get? vote-tallies dispute-id) ERR_DISPUTE_NOT_FOUND))
    (vote-key {dispute-id: dispute-id, juror: tx-sender})
    (threshold (get-category-threshold (get category dispute)))
    (current-voters (default-to (list) (map-get? dispute-voters dispute-id)))
  )
    (begin
      ;; Validation checks
      (asserts! (default-to false (map-get? authorized-jurors tx-sender)) ERR_NOT_JUROR)
      (asserts! (not (get resolved dispute)) ERR_ALREADY_RESOLVED)
      (asserts! (is-none (map-get? juror-votes vote-key)) ERR_ALREADY_VOTED)
      (asserts! (is-specialized-for-category tx-sender (get category dispute)) ERR_NOT_SPECIALIZED)
      
      ;; Record the vote and voter
      (map-set juror-votes vote-key true)
      (map-set individual-votes vote-key support)
      
      ;; Add voter to the list - FIXED: Handle the match expression properly
      (let (
        (new-voters-result (as-max-len? (append current-voters tx-sender) u20))
      )
        (match new-voters-result
          new-voters (begin
            (map-set dispute-voters dispute-id new-voters)
            true
          )
          false
        )
        
        ;; Check if we couldn't add the voter (list full)
        (asserts! (is-some new-voters-result) ERR_VOTER_LIST_FULL)
      )
      
      ;; Update vote tally
      (let (
        (new-tally (if support
          {yes: (+ (get yes current-tally) u1), no: (get no current-tally)}
          {yes: (get yes current-tally), no: (+ (get no current-tally) u1)}
        ))
      )
        (begin
          (map-set vote-tallies dispute-id new-tally)
          
          ;; Check if threshold is met for resolution
          (if (>= (+ (get yes new-tally) (get no new-tally)) threshold)
            (let (
              (ruling (> (get yes new-tally) (get no new-tally)))
              (current-block stacks-block-height)
              (total-stake (get stake dispute))
              (reward-per-voter (/ total-stake threshold))
            )
              (begin
                ;; Resolve the dispute
                (map-set disputes dispute-id (merge dispute {
                  resolved: true,
                  ruling: (some ruling),
                  resolved-at: (some current-block)
                }))
                
                ;; Add stake to reward pool
                (var-set reward-pool (+ (var-get reward-pool) total-stake))
                
                ;; Update current voter's stats
                (update-juror-stats tx-sender (is-eq support ruling))
                
                (ok {resolved: true, ruling: ruling})
              )
            )
            (ok {resolved: false, ruling: false})
          )
        )
      )
    )
  )
)

;; Enhanced vote function for private disputes with completely inlined reward distribution
(define-public (vote-private (dispute-id uint) (support bool))
  (let (
    (dispute (unwrap! (map-get? private-disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
    (current-tally (unwrap! (map-get? private-vote-tallies dispute-id) ERR_DISPUTE_NOT_FOUND))
    (vote-key {dispute-id: dispute-id, juror: tx-sender})
    (threshold (get-category-threshold (get category dispute)))
    (current-voters (default-to (list) (map-get? private-dispute-voters dispute-id)))
  )
    (begin
      ;; Validation checks
      (asserts! (default-to false (map-get? authorized-jurors tx-sender)) ERR_NOT_JUROR)
      (asserts! (not (get resolved dispute)) ERR_ALREADY_RESOLVED)
      (asserts! (get revealed dispute) ERR_NOT_REVEALED) ;; Must be revealed to vote
      (asserts! (is-none (map-get? private-juror-votes vote-key)) ERR_ALREADY_VOTED)
      (asserts! (is-specialized-for-category tx-sender (get category dispute)) ERR_NOT_SPECIALIZED)
      
      ;; Record the vote and voter
      (map-set private-juror-votes vote-key true)
      (map-set individual-private-votes vote-key support)
      
      ;; Add voter to the list - FIXED: Handle the match expression properly
      (let (
        (new-voters-result (as-max-len? (append current-voters tx-sender) u20))
      )
        (match new-voters-result
          new-voters (begin
            (map-set private-dispute-voters dispute-id new-voters)
            true
          )
          false
        )
        
        ;; Check if we couldn't add the voter (list full)
        (asserts! (is-some new-voters-result) ERR_VOTER_LIST_FULL)
      )
      
      ;; Update vote tally
      (let (
        (new-tally (if support
          {yes: (+ (get yes current-tally) u1), no: (get no current-tally)}
          {yes: (get yes current-tally), no: (+ (get no current-tally) u1)}
        ))
      )
        (begin
          (map-set private-vote-tallies dispute-id new-tally)
          
          ;; Check if threshold is met for resolution
          (if (>= (+ (get yes new-tally) (get no new-tally)) threshold)
            (let (
              (ruling (> (get yes new-tally) (get no new-tally)))
              (current-block stacks-block-height)
              (total-stake (get stake dispute))
              (reward-per-voter (/ total-stake threshold))
            )
              (begin
                ;; Resolve the dispute
                (map-set private-disputes dispute-id (merge dispute {
                  resolved: true,
                  ruling: (some ruling),
                  resolved-at: (some current-block)
                }))
                
                ;; Add stake to reward pool
                (var-set reward-pool (+ (var-get reward-pool) total-stake))
                
                ;; Update current voter's stats
                (update-juror-stats tx-sender (is-eq support ruling))
                
                (ok {resolved: true, ruling: ruling})
              )
            )
            (ok {resolved: false, ruling: false})
          )
        )
      )
    )
  )
)

;; File an appeal
(define-public (file-appeal (dispute-id uint))
  (let (
    (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
    (appeal-id (+ (var-get appeal-counter) u1))
    (current-block stacks-block-height)
    (appeal-stake (* (get stake dispute) APPEAL_MULTIPLIER))
    (deadline (+ current-block APPEAL_DEADLINE_BLOCKS))
  )
    (begin
      ;; Validation checks
      (asserts! (get resolved dispute) ERR_CANNOT_APPEAL_UNRESOLVED)
      (asserts! (is-none (get appeal-id dispute)) ERR_ALREADY_APPEALED)
      (asserts! (or (is-eq tx-sender (get complainant dispute)) (is-eq tx-sender (get defendant dispute))) ERR_UNAUTHORIZED)
      
      ;; Burn the appeal stake
      (try! (stx-burn? appeal-stake tx-sender))
      
      ;; Create appeal record
      (map-set appeals appeal-id {
        original-dispute-id: dispute-id,
        appellant: tx-sender,
        appeal-stake: appeal-stake,
        resolved: false,
        ruling: none,
        created-at: current-block,
        resolved-at: none,
        deadline: deadline
      })
      
      ;; Update dispute with appeal reference
      (map-set disputes dispute-id (merge dispute {appeal-id: (some appeal-id)}))
      
      ;; Initialize appeal vote tally and voter list
      (map-set appeal-tallies appeal-id {yes: u0, no: u0})
      (map-set appeal-voters appeal-id (list))
      
      ;; Update counter
      (var-set appeal-counter appeal-id)
      
      (ok appeal-id)
    )
  )
)

;; Enhanced vote function for appeals with completely inlined reward distribution
(define-public (vote-appeal (appeal-id uint) (support bool))
  (let (
    (appeal (unwrap! (map-get? appeals appeal-id) ERR_APPEAL_NOT_FOUND))
    (current-tally (unwrap! (map-get? appeal-tallies appeal-id) ERR_APPEAL_NOT_FOUND))
    (vote-key {appeal-id: appeal-id, juror: tx-sender})
    (current-block stacks-block-height)
    (current-voters (default-to (list) (map-get? appeal-voters appeal-id)))
  )
    (begin
      ;; Validation checks
      (asserts! (default-to false (map-get? authorized-jurors tx-sender)) ERR_NOT_JUROR)
      (asserts! (not (get resolved appeal)) ERR_ALREADY_RESOLVED)
      (asserts! (is-none (map-get? appeal-votes vote-key)) ERR_ALREADY_VOTED)
      (asserts! (<= current-block (get deadline appeal)) ERR_APPEAL_DEADLINE_PASSED)
      
      ;; Record the vote and voter
      (map-set appeal-votes vote-key true)
      (map-set individual-appeal-votes vote-key support)
      
      ;; Add voter to the list - FIXED: Handle the match expression properly
      (let (
        (new-voters-result (as-max-len? (append current-voters tx-sender) u20))
      )
        (match new-voters-result
          new-voters (begin
            (map-set appeal-voters appeal-id new-voters)
            true
          )
          false
        )
        
        ;; Check if we couldn't add the voter (list full)
        (asserts! (is-some new-voters-result) ERR_VOTER_LIST_FULL)
      )
      
      ;; Update vote tally
      (let (
        (new-tally (if support
          {yes: (+ (get yes current-tally) u1), no: (get no current-tally)}
          {yes: (get yes current-tally), no: (+ (get no current-tally) u1)}
        ))
      )
        (begin
          (map-set appeal-tallies appeal-id new-tally)
          
          ;; Check if threshold is met for resolution
          (if (>= (+ (get yes new-tally) (get no new-tally)) VOTE_THRESHOLD_APPEAL)
            (let (
              (ruling (> (get yes new-tally) (get no new-tally)))
              (total-stake (get appeal-stake appeal))
              (reward-per-voter (/ total-stake VOTE_THRESHOLD_APPEAL))
            )
              (begin
                ;; Resolve the appeal
                (map-set appeals appeal-id (merge appeal {
                  resolved: true,
                  ruling: (some ruling),
                  resolved-at: (some current-block)
                }))
                
                ;; Add stake to reward pool
                (var-set reward-pool (+ (var-get reward-pool) total-stake))
                
                ;; Update current voter's stats
                (update-juror-stats tx-sender (is-eq support ruling))
                
                (ok {resolved: true, ruling: ruling})
              )
            )
            (ok {resolved: false, ruling: false})
          )
        )
      )
    )
  )
)

;; Add juror with specializations
(define-public (add-juror (new-juror principal) (specializations (list 10 uint)))
  (begin
    ;; Validation checks
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal new-juror) ERR_INVALID_PRINCIPAL)
    
    ;; Add the juror
    (map-set authorized-jurors new-juror true)
    (map-set juror-specializations new-juror specializations)
    (ok true)
  )
)

;; Remove a juror (only contract owner)
(define-public (remove-juror (juror principal))
  (begin
    ;; Validation checks
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal juror) ERR_INVALID_PRINCIPAL)
    (asserts! (not (is-eq juror (var-get contract-owner))) ERR_UNAUTHORIZED)
    
    ;; Remove the juror
    (map-delete authorized-jurors juror)
    (map-delete juror-specializations juror)
    (ok true)
  )
)

;; Transfer ownership (only current owner)
(define-public (transfer-ownership (new-owner principal))
  (begin
    ;; Validation checks
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal new-owner) ERR_INVALID_PRINCIPAL)
    
    ;; Transfer ownership
    (var-set contract-owner new-owner)
    (map-set authorized-jurors new-owner true)
    (ok true)
  )
)

;; Read-only Functions

;; Get dispute details
(define-read-only (get-dispute (dispute-id uint))
  (ok (map-get? disputes dispute-id))
)

;; Get private dispute details (only parties can see full details)
(define-read-only (get-private-dispute (dispute-id uint))
  (match (map-get? private-disputes dispute-id)
    dispute (if (or (is-eq tx-sender (get complainant dispute)) 
                    (is-eq tx-sender (get defendant dispute))
                    (default-to false (map-get? authorized-jurors tx-sender)))
              (ok (some dispute))
              (ok (some {
                complainant: (get complainant dispute),
                defendant: (get defendant dispute),
                commitment: (get commitment dispute),
                category: (get category dispute),
                stake: (get stake dispute),
                resolved: (get resolved dispute),
                ruling: (get ruling dispute),
                created-at: (get created-at dispute),
                resolved-at: (get resolved-at dispute),
                appeal-id: (get appeal-id dispute),
                privacy-level: (get privacy-level dispute),
                reveal-deadline: (get reveal-deadline dispute),
                revealed: (get revealed dispute)
              })))
    (ok none)
  )
)

;; Get dispute reveal (only after revealed)
(define-read-only (get-dispute-reveal (dispute-id uint))
  (match (map-get? private-disputes dispute-id)
    dispute (if (get revealed dispute)
              (ok (map-get? dispute-reveals dispute-id))
              (ok none))
    (ok none)
  )
)

;; Get encrypted evidence
(define-read-only (get-encrypted-evidence (evidence-id uint))
  (ok (map-get? encrypted-evidence evidence-id))
)

;; Get appeal details
(define-read-only (get-appeal (appeal-id uint))
  (ok (map-get? appeals appeal-id))
)

;; Get vote tally for a dispute
(define-read-only (get-vote-tally (dispute-id uint))
  (ok (map-get? vote-tallies dispute-id))
)

;; Get private vote tally
(define-read-only (get-private-vote-tally (dispute-id uint))
  (ok (map-get? private-vote-tallies dispute-id))
)

;; Get appeal vote tally
(define-read-only (get-appeal-tally (appeal-id uint))
  (ok (map-get? appeal-tallies appeal-id))
)

;; Get dispute voters list
(define-read-only (get-dispute-voters (dispute-id uint))
  (ok (map-get? dispute-voters dispute-id))
)

;; Get private dispute voters list
(define-read-only (get-private-dispute-voters (dispute-id uint))
  (ok (map-get? private-dispute-voters dispute-id))
)

;; Get appeal voters list
(define-read-only (get-appeal-voters (appeal-id uint))
  (ok (map-get? appeal-voters appeal-id))
)

;; Check if address is authorized juror
(define-read-only (is-juror (address principal))
  (if (is-valid-principal address)
    (ok (default-to false (map-get? authorized-jurors address)))
    (ok false)
  )
)

;; Get juror statistics
(define-read-only (get-juror-stats (juror principal))
  (ok (map-get? juror-stats juror))
)

;; Get juror specializations
(define-read-only (get-juror-specializations (juror principal))
  (ok (map-get? juror-specializations juror))
)

;; Check if juror has voted on dispute
(define-read-only (has-voted (dispute-id uint) (juror principal))
  (if (is-valid-principal juror)
    (ok (is-some (map-get? juror-votes {dispute-id: dispute-id, juror: juror})))
    (ok false)
  )
)

;; Check if juror has voted on private dispute
(define-read-only (has-voted-private (dispute-id uint) (juror principal))
  (if (is-valid-principal juror)
    (ok (is-some (map-get? private-juror-votes {dispute-id: dispute-id, juror: juror})))
    (ok false)
  )
)

;; Check if juror has voted on appeal
(define-read-only (has-voted-appeal (appeal-id uint) (juror principal))
  (if (is-valid-principal juror)
    (ok (is-some (map-get? appeal-votes {appeal-id: appeal-id, juror: juror})))
    (ok false)
  )
)

;; Get current dispute counter
(define-read-only (get-dispute-count)
  (ok (var-get dispute-counter))
)

;; Get current private dispute counter
(define-read-only (get-private-dispute-count)
  (ok (var-get private-dispute-counter))
)

;; Get current appeal counter
(define-read-only (get-appeal-count)
  (ok (var-get appeal-counter))
)

;; Get contract owner
(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

;; Get reward pool
(define-read-only (get-reward-pool)
  (ok (var-get reward-pool))
)

;; Get dispute status summary with category info
(define-read-only (get-dispute-summary (dispute-id uint))
  (match (map-get? disputes dispute-id)
    dispute (let (
      (tally (default-to {yes: u0, no: u0} (map-get? vote-tallies dispute-id)))
      (threshold (get-category-threshold (get category dispute)))
    )
      (ok {
        dispute: dispute,
        votes: tally,
        total-votes: (+ (get yes tally) (get no tally)),
        needs-votes: (if (get resolved dispute) u0 (- threshold (+ (get yes tally) (get no tally)))),
        category: (get category dispute),
        threshold: threshold
      })
    )
    (err ERR_DISPUTE_NOT_FOUND)
  )
)

;; Get private dispute summary
(define-read-only (get-private-dispute-summary (dispute-id uint))
  (match (map-get? private-disputes dispute-id)
    dispute (let (
      (tally (default-to {yes: u0, no: u0} (map-get? private-vote-tallies dispute-id)))
      (threshold (get-category-threshold (get category dispute)))
    )
      (ok {
        dispute: dispute,
        votes: tally,
        total-votes: (+ (get yes tally) (get no tally)),
        category: (get category dispute),
        threshold: threshold,
        revealed: (get revealed dispute)
      })
    )
    (err ERR_DISPUTE_NOT_FOUND)
  )
)

;; Get appeal summary
(define-read-only (get-appeal-summary (appeal-id uint))
  (match (map-get? appeals appeal-id)
    appeal (let (
      (tally (default-to {yes: u0, no: u0} (map-get? appeal-tallies appeal-id)))
    )
      (ok {
        appeal: appeal,
        votes: tally,
        total-votes: (+ (get yes tally) (get no tally)),
        needs-votes: (if (get resolved appeal) u0 (- VOTE_THRESHOLD_APPEAL (+ (get yes tally) (get no tally))))
      })
    )
    (err ERR_APPEAL_NOT_FOUND)
  )
)

;; Validate principal address (read-only helper)
(define-read-only (validate-principal (address principal))
  (ok (is-valid-principal address))
)
