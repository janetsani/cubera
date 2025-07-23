# Cubera Dispute Resolution Smart Contract

This Clarity smart contract implements a decentralized dispute resolution system with economic incentives, juror specialization, appeals, and transparent voting. It is designed for use on the Stacks blockchain.

---

## Features

- **Dispute Filing:** Users can file disputes in four categories (General, Financial, Technical, Content) by staking STX.
- **Juror System:** Only authorized jurors with relevant specializations can vote on disputes and appeals.
- **Voting & Resolution:** Disputes and appeals are resolved by juror votes. Thresholds vary by category.
- **Appeals:** Resolved disputes can be appealed by staking additional STX.
- **Economic Incentives:** Jurors earn rewards for correct votes and build reputation.
- **Ownership & Access Control:** Contract owner can add/remove jurors and transfer ownership.
- **Transparency:** Anyone can query dispute, appeal, juror, and voting data.

---

## Data Structures

- **Disputes:** Stores complainant, defendant, description, category, stake, resolution status, ruling, timestamps, and appeal reference.
- **Appeals:** Stores original dispute ID, appellant, stake, resolution status, ruling, timestamps, and deadline.
- **Jurors:** Tracks authorized jurors, their specializations, voting history, and reputation.
- **Vote Tallies:** Maintains counts of yes/no votes for disputes and appeals.

---

## Main Functions

### Public Functions

- `file-dispute(defendant, desc, category, stake)`: File a new dispute.
- `vote(dispute-id, support)`: Vote on a dispute.
- `file-appeal(dispute-id)`: Appeal a resolved dispute.
- `vote-appeal(appeal-id, support)`: Vote on an appeal.
- `add-juror(new-juror, specializations)`: Add a juror (owner only).
- `remove-juror(juror)`: Remove a juror (owner only).
- `transfer-ownership(new-owner)`: Transfer contract ownership.

### Read-Only Functions

- `get-dispute(dispute-id)`: Get dispute details.
- `get-appeal(appeal-id)`: Get appeal details.
- `get-vote-tally(dispute-id)`: Get dispute vote tally.
- `get-appeal-tally(appeal-id)`: Get appeal vote tally.
- `is-juror(address)`: Check if address is an authorized juror.
- `get-juror-stats(juror)`: Get juror statistics.
- `get-juror-specializations(juror)`: Get juror specializations.
- `has-voted(dispute-id, juror)`: Check if juror voted on dispute.
- `has-voted-appeal(appeal-id, juror)`: Check if juror voted on appeal.
- `get-dispute-count()`: Get total disputes.
- `get-appeal-count()`: Get total appeals.
- `get-owner()`: Get contract owner.
- `get-reward-pool()`: Get total reward pool.
- `get-dispute-summary(dispute-id)`: Get dispute status summary.
- `get-appeal-summary(appeal-id)`: Get appeal status summary.
- `validate-principal(address)`: Validate principal address.

---

## Categories & Thresholds

| Category    | Constant              | Min Stake | Vote Threshold |
|-------------|-----------------------|-----------|---------------|
| General     | `CATEGORY_GENERAL`    | 1 STX     | 3             |
| Financial   | `CATEGORY_FINANCIAL`  | 5 STX     | 5             |
| Technical   | `CATEGORY_TECHNICAL`  | 3 STX     | 4             |
| Content     | `CATEGORY_CONTENT`    | 1 STX     | 3             |

---

## Juror Incentives

- **Rewards:** Jurors who vote correctly receive rewards from the stake pool.
- **Reputation:** Juror reputation is tracked and updated based on voting accuracy.
- **Specialization:** Jurors can only vote on disputes in categories they are specialized for.

---

## Error Codes

- `ERR_ALREADY_VOTED`
- `ERR_NOT_JUROR`
- `ERR_ALREADY_RESOLVED`
- `ERR_DISPUTE_NOT_FOUND`
- `ERR_INSUFFICIENT_STAKE`
- `ERR_UNAUTHORIZED`
- `ERR_SELF_DISPUTE`
- `ERR_INVALID_DESCRIPTION`
- `ERR_INVALID_PRINCIPAL`
- `ERR_INVALID_CATEGORY`
- `ERR_NOT_SPECIALIZED`
- `ERR_APPEAL_DEADLINE_PASSED`
- `ERR_APPEAL_NOT_FOUND`
- `ERR_ALREADY_APPEALED`
- `ERR_CANNOT_APPEAL_UNRESOLVED`

---

## Deployment & Initialization

- The contract owner is set to the deployer (`tx-sender`).
- The owner is initialized as an authorized juror with all specializations.

---

## Example Usage

1. **File a Dispute:**  
   User stakes STX and files a dispute against another principal.

2. **Juror Voting:**  
   Authorized jurors with the right specialization vote on the dispute.

3. **Resolution:**  
   When the vote threshold is met, the dispute is resolved and rewards are distributed.

4. **Appeal:**  
   Either party can appeal a resolved dispute by staking more STX.

5. **Appeal Voting:**  
   Jurors vote on the appeal; resolution follows similar logic.

---

## License

This contract is provided for educational and demonstration purposes.  
Please audit and test thoroughly before deploying in production.

---

## Contact

For questions or improvements, open an issue or pull request on the repository.

---

**Powered by Clarity & Stacks.**
