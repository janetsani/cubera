# Cubera Dispute Resolution Smart Contract

A decentralized dispute resolution system on Stacks blockchain with privacy features, economic incentives, and specialized juror voting.

## Core Features

### Dispute Management
- **Public Disputes**: Traditional dispute filing with transparent details
- **Private Disputes**: Privacy-preserving disputes using commitment-reveal scheme
- **Evidence Handling**: Support for encrypted evidence submission
- **Category System**: General, Financial, Technical, and Content categories

### Privacy Features
- **Privacy Levels**: Public, Encrypted, and Commitment-based disputes
- **Commitment-Reveal**: Secure mechanism for private dispute details
- **Encrypted Evidence**: Support for different evidence types with encryption
- **Access Control**: Restricted access to sensitive dispute information

### Voting & Resolution
- **Public Voting**: Standard voting for transparent disputes
- **Private Voting**: Special handling for private disputes after revelation
- **Appeal System**: Double-stake appeals with separate voting process
- **Threshold-based Resolution**: Category-specific voting thresholds

## Technical Implementation

### Data Structures
```clarity
;; Main dispute types
(define-map disputes uint {...})
(define-map private-disputes uint {...})
(define-map dispute-reveals uint {...})
(define-map encrypted-evidence uint {...})
```

### Core Functions

#### Dispute Filing
```clarity
(define-public (file-dispute (defendant principal) (desc (string-ascii 200)) (category uint) (stake uint)))
(define-public (file-private-dispute (defendant principal) (commitment (buff 32)) (category uint) (stake uint) (privacy-level uint)))
```

#### Evidence Management
```clarity
(define-public (submit-encrypted-evidence (dispute-id uint) (evidence-hash (buff 32)) (encryption-key-hash (buff 32)) (evidence-type uint)))
(define-public (reveal-private-dispute (dispute-id uint) (description (string-ascii 200)) (salt (buff 32)) (evidence-hash (optional (buff 32)))))
```

#### Voting System
```clarity
(define-public (vote (dispute-id uint) (support bool)))
(define-public (vote-private (dispute-id uint) (support bool)))
(define-public (vote-appeal (appeal-id uint) (support bool)))
```

## Economic Model

### Staking Requirements
| Category    | Minimum Stake | Appeal Multiplier |
|-------------|---------------|------------------|
| General     | 1 STX        | 2x              |
| Financial   | 5 STX        | 2x              |
| Technical   | 3 STX        | 2x              |
| Content     | 1 STX        | 2x              |

### Juror Incentives
- Reputation scoring based on voting accuracy
- Reward distribution from stake pool
- Specialization-based voting rights
- Penalties for incorrect votes

## Privacy Levels

1. **Public** (Level 0)
   - Fully transparent disputes
   - Open voting and evidence

2. **Encrypted** (Level 1)
   - Encrypted dispute details
   - Controlled access to evidence

3. **Commitment** (Level 2)
   - Hash-based commitment scheme
   - Time-locked revelations
   - Privacy-preserving voting

## Constants & Configuration

```clarity
(define-constant VOTE_THRESHOLD_GENERAL u3)
(define-constant VOTE_THRESHOLD_APPEAL u5)
(define-constant APPEAL_DEADLINE_BLOCKS u1440) ;; ~10 days
(define-constant REVEAL_DEADLINE_BLOCKS u720)  ;; ~5 days
(define-constant REPUTATION_THRESHOLD u80)     ;; 80% accuracy
```

## Usage Flow

1. **Filing a Dispute**
   - Choose privacy level
   - Submit details/commitment
   - Stake required STX

2. **Evidence Submission**
   - Submit encrypted evidence
   - Provide encryption keys
   - Meet revelation deadlines

3. **Voting Process**
   - Juror validation
   - Specialization checks
   - Vote recording
   - Threshold monitoring

4. **Resolution & Appeals**
   - Automatic resolution at threshold
   - Appeal window management
   - Higher stake requirements
   - Final resolution

## Development & Deployment

### Requirements
- Clarity smart contract support
- Stacks blockchain environment
- STX token for transactions

### Testing
- Unit tests for core functions
- Privacy mechanism validation
- Economic model simulation
- Voting system verification

## Security Considerations

- Commitment scheme integrity
- Encryption key management
- Access control enforcement
- Deadline management
- Stake handling security

## License

This contract is provided for educational and demonstration purposes.
Please audit and test thoroughly before production deployment.

## Contact

For questions, improvements, or issues:
- Open an issue in the repository
- Submit a pull request
- Contact the development team

---

**Built with Clarity on Stacks Blockchain**
