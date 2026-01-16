
import { createHash } from "crypto";
import { describe, expect, it } from "vitest";
import {
  Cl,
  ClarityType,
  SomeCV,
  serializeCVBytes,
} from "@stacks/transactions";

const contract = "cubera";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;
const wallet4 = accounts.get("wallet_4")!;
const wallet5 = accounts.get("wallet_5")!;

const CATEGORY_GENERAL = 1;
const CATEGORY_FINANCIAL = 2;
const CATEGORY_TECHNICAL = 3;
const CATEGORY_CONTENT = 4;
const MIN_STAKE_GENERAL = 1_000_000;
const PRIVACY_LEVEL_COMMITMENT = 2;

const ALL_CATEGORIES = [
  CATEGORY_GENERAL,
  CATEGORY_FINANCIAL,
  CATEGORY_TECHNICAL,
  CATEGORY_CONTENT,
];

function principal(address: string) {
  return Cl.standardPrincipal(address);
}

function categoryList(categories: number[] = ALL_CATEGORIES) {
  return Cl.list(categories.map((category) => Cl.uint(category)));
}

function unwrapSome(value: unknown) {
  expect(value).toHaveClarityType(ClarityType.OptionalSome);
  return (value as SomeCV).value;
}

function addJuror(address: string, categories: number[] = ALL_CATEGORIES) {
  const { result } = simnet.callPublicFn(
    contract,
    "add-juror",
    [principal(address), categoryList(categories)],
    deployer,
  );
  expect(result).toBeOk(Cl.bool(true));
}

function concatBytes(...parts: Uint8Array[]) {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const result = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    result.set(part, offset);
    offset += part.length;
  }
  return result;
}

function makeCommitment(description: string, salt: Uint8Array, sender: string) {
  const descriptionBytes = serializeCVBytes(Cl.stringAscii(description));
  const senderBytes = serializeCVBytes(principal(sender));
  const preimage = concatBytes(descriptionBytes, salt, senderBytes);
  const hash = createHash("sha256").update(preimage).digest();
  return new Uint8Array(hash);
}

describe("cubera disputes", () => {
  it("files a dispute and initializes state", () => {
    const description = "late delivery";
    const { result } = simnet.callPublicFn(
      contract,
      "file-dispute",
      [
        principal(wallet2),
        Cl.stringAscii(description),
        Cl.uint(CATEGORY_GENERAL),
        Cl.uint(MIN_STAKE_GENERAL),
      ],
      wallet1,
    );
    expect(result).toBeOk(Cl.uint(1));

    const disputeCounter = simnet.getDataVar(contract, "dispute-counter");
    expect(disputeCounter).toBeUint(1);

    const disputeEntry = simnet.getMapEntry(contract, "disputes", Cl.uint(1));
    const dispute = unwrapSome(disputeEntry);
    expect(dispute).toBeTuple({
      complainant: principal(wallet1),
      defendant: principal(wallet2),
      description: Cl.stringAscii(description),
      category: Cl.uint(CATEGORY_GENERAL),
      stake: Cl.uint(MIN_STAKE_GENERAL),
      resolved: Cl.bool(false),
      ruling: Cl.none(),
      "created-at": expect.anything(),
      "resolved-at": Cl.none(),
      "appeal-id": Cl.none(),
    });
    expect((dispute as any).value["created-at"]).toHaveClarityType(ClarityType.UInt);

    const tallyEntry = simnet.getMapEntry(contract, "vote-tallies", Cl.uint(1));
    const tally = unwrapSome(tallyEntry);
    expect(tally).toBeTuple({ yes: Cl.uint(0), no: Cl.uint(0) });

    const votersEntry = simnet.getMapEntry(contract, "dispute-voters", Cl.uint(1));
    const voters = unwrapSome(votersEntry);
    expect(voters).toBeList([]);

    const rewardPool = simnet.getDataVar(contract, "reward-pool");
    expect(rewardPool).toBeUint(0);
  });

  it("resolves after threshold votes and updates reward pool", () => {
    addJuror(wallet2);
    addJuror(wallet3);

    const description = "service dispute";
    const { result: fileResult } = simnet.callPublicFn(
      contract,
      "file-dispute",
      [
        principal(wallet4),
        Cl.stringAscii(description),
        Cl.uint(CATEGORY_GENERAL),
        Cl.uint(MIN_STAKE_GENERAL),
      ],
      wallet1,
    );
    expect(fileResult).toBeOk(Cl.uint(1));

    const firstVote = simnet.callPublicFn(
      contract,
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      deployer,
    );
    expect(firstVote.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const duplicateVote = simnet.callPublicFn(
      contract,
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      deployer,
    );
    expect(duplicateVote.result).toBeErr(Cl.uint(301));

    const secondVote = simnet.callPublicFn(
      contract,
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      wallet2,
    );
    expect(secondVote.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const thirdVote = simnet.callPublicFn(
      contract,
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      wallet3,
    );
    expect(thirdVote.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(true), ruling: Cl.bool(true) }),
    );

    const disputeEntry = simnet.getMapEntry(contract, "disputes", Cl.uint(1));
    const dispute = unwrapSome(disputeEntry);
    expect(dispute).toBeTuple({
      complainant: principal(wallet1),
      defendant: principal(wallet4),
      description: Cl.stringAscii(description),
      category: Cl.uint(CATEGORY_GENERAL),
      stake: Cl.uint(MIN_STAKE_GENERAL),
      resolved: Cl.bool(true),
      ruling: Cl.some(Cl.bool(true)),
      "created-at": expect.anything(),
      "resolved-at": expect.anything(),
      "appeal-id": Cl.none(),
    });

    const rewardPool = simnet.getDataVar(contract, "reward-pool");
    expect(rewardPool).toBeUint(MIN_STAKE_GENERAL);
  });
});

describe("cubera private disputes", () => {
  it("requires reveal before voting and resolves after reveal", () => {
    addJuror(wallet2);
    addJuror(wallet3);

    const description = "private contract terms";
    const salt = new Uint8Array(32).fill(7);
    const commitment = makeCommitment(description, salt, wallet1);

    const { result: fileResult } = simnet.callPublicFn(
      contract,
      "file-private-dispute",
      [
        principal(wallet4),
        Cl.buffer(commitment),
        Cl.uint(CATEGORY_GENERAL),
        Cl.uint(MIN_STAKE_GENERAL),
        Cl.uint(PRIVACY_LEVEL_COMMITMENT),
      ],
      wallet1,
    );
    expect(fileResult).toBeOk(Cl.uint(1));

    const preVote = simnet.callPublicFn(
      contract,
      "vote-private",
      [Cl.uint(1), Cl.bool(true)],
      deployer,
    );
    expect(preVote.result).toBeErr(Cl.uint(320));

    const reveal = simnet.callPublicFn(
      contract,
      "reveal-private-dispute",
      [Cl.uint(1), Cl.stringAscii(description), Cl.buffer(salt), Cl.none()],
      wallet1,
    );
    expect(reveal.result).toBeOk(Cl.bool(true));

    const firstVote = simnet.callPublicFn(
      contract,
      "vote-private",
      [Cl.uint(1), Cl.bool(true)],
      deployer,
    );
    expect(firstVote.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const secondVote = simnet.callPublicFn(
      contract,
      "vote-private",
      [Cl.uint(1), Cl.bool(true)],
      wallet2,
    );
    expect(secondVote.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const thirdVote = simnet.callPublicFn(
      contract,
      "vote-private",
      [Cl.uint(1), Cl.bool(true)],
      wallet3,
    );
    expect(thirdVote.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(true), ruling: Cl.bool(true) }),
    );

    const disputeEntry = simnet.getMapEntry(contract, "private-disputes", Cl.uint(1));
    const dispute = unwrapSome(disputeEntry);
    expect(dispute).toBeTuple({
      complainant: principal(wallet1),
      defendant: principal(wallet4),
      commitment: Cl.buffer(commitment),
      category: Cl.uint(CATEGORY_GENERAL),
      stake: Cl.uint(MIN_STAKE_GENERAL),
      resolved: Cl.bool(true),
      ruling: Cl.some(Cl.bool(true)),
      "created-at": expect.anything(),
      "resolved-at": expect.anything(),
      "appeal-id": Cl.none(),
      "privacy-level": Cl.uint(PRIVACY_LEVEL_COMMITMENT),
      "reveal-deadline": expect.anything(),
      revealed: Cl.bool(true),
    });

    const rewardPool = simnet.getDataVar(contract, "reward-pool");
    expect(rewardPool).toBeUint(MIN_STAKE_GENERAL);
  });
});

describe("cubera appeals", () => {
  it("files and resolves an appeal", () => {
    addJuror(wallet2);
    addJuror(wallet3);
    addJuror(wallet4);
    addJuror(wallet5);

    const description = "project disagreement";
    const { result: fileResult } = simnet.callPublicFn(
      contract,
      "file-dispute",
      [
        principal(wallet2),
        Cl.stringAscii(description),
        Cl.uint(CATEGORY_GENERAL),
        Cl.uint(MIN_STAKE_GENERAL),
      ],
      wallet1,
    );
    expect(fileResult).toBeOk(Cl.uint(1));

    const voteOne = simnet.callPublicFn(
      contract,
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      deployer,
    );
    expect(voteOne.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const voteTwo = simnet.callPublicFn(
      contract,
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      wallet3,
    );
    expect(voteTwo.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const voteThree = simnet.callPublicFn(
      contract,
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      wallet4,
    );
    expect(voteThree.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(true), ruling: Cl.bool(true) }),
    );

    const appealFile = simnet.callPublicFn(
      contract,
      "file-appeal",
      [Cl.uint(1)],
      wallet1,
    );
    expect(appealFile.result).toBeOk(Cl.uint(1));

    const appealEntry = simnet.getMapEntry(contract, "appeals", Cl.uint(1));
    const appeal = unwrapSome(appealEntry);
    expect(appeal).toBeTuple({
      "original-dispute-id": Cl.uint(1),
      appellant: principal(wallet1),
      "appeal-stake": Cl.uint(MIN_STAKE_GENERAL * 2),
      resolved: Cl.bool(false),
      ruling: Cl.none(),
      "created-at": expect.anything(),
      "resolved-at": Cl.none(),
      deadline: expect.anything(),
    });

    const appealVoteOne = simnet.callPublicFn(
      contract,
      "vote-appeal",
      [Cl.uint(1), Cl.bool(true)],
      deployer,
    );
    expect(appealVoteOne.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const appealVoteTwo = simnet.callPublicFn(
      contract,
      "vote-appeal",
      [Cl.uint(1), Cl.bool(true)],
      wallet2,
    );
    expect(appealVoteTwo.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const appealVoteThree = simnet.callPublicFn(
      contract,
      "vote-appeal",
      [Cl.uint(1), Cl.bool(true)],
      wallet3,
    );
    expect(appealVoteThree.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const appealVoteFour = simnet.callPublicFn(
      contract,
      "vote-appeal",
      [Cl.uint(1), Cl.bool(true)],
      wallet4,
    );
    expect(appealVoteFour.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(false), ruling: Cl.bool(false) }),
    );

    const appealVoteFive = simnet.callPublicFn(
      contract,
      "vote-appeal",
      [Cl.uint(1), Cl.bool(true)],
      wallet5,
    );
    expect(appealVoteFive.result).toBeOk(
      Cl.tuple({ resolved: Cl.bool(true), ruling: Cl.bool(true) }),
    );

    const rewardPool = simnet.getDataVar(contract, "reward-pool");
    expect(rewardPool).toBeUint(MIN_STAKE_GENERAL * 3);
  });
});
