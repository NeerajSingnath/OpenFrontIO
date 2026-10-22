import { describe, expect, it } from "vitest";
import {
  dominatorAttackBudget,
  dominatorReserveRatio,
  type DominatorObservation,
} from "../packages/engine/src/execution/nation/DominatorPolicy";

const neutral: DominatorObservation = {
  currentTroops: 500,
  maxTroops: 1000,
  strongestHostileNeighborTroops: 0,
  incomingHostileTroops: 0,
  hasUnclaimedLand: false,
};

describe("Dominator reserve policy", () => {
  it("keeps a basic reserve in quiet conditions", () => {
    expect(dominatorReserveRatio(neutral)).toBeCloseTo(0.3);
    expect(dominatorAttackBudget(neutral)).toBe(200);
  });

  it("expands more aggressively when the frontier is safe", () => {
    const safe = { ...neutral, hasUnclaimedLand: true };
    expect(dominatorReserveRatio(safe)).toBeCloseTo(0.24);
    expect(dominatorAttackBudget(safe)).toBe(260);
  });

  it("keeps more troops when threatened", () => {
    const threatened = {
      ...neutral,
      strongestHostileNeighborTroops: 500,
      incomingHostileTroops: 200,
    };
    expect(dominatorReserveRatio(threatened)).toBeGreaterThan(
      dominatorReserveRatio(neutral),
    );
    expect(dominatorAttackBudget(threatened)).toBe(0);
  });

  it("caps the reserve even against overwhelming pressure", () => {
    expect(
      dominatorReserveRatio({
        ...neutral,
        strongestHostileNeighborTroops: 5000,
        incomingHostileTroops: 5000,
      }),
    ).toBe(0.8);
  });

  it("never returns a negative attack budget", () => {
    expect(dominatorAttackBudget({ ...neutral, currentTroops: 0 })).toBe(0);
  });

  it("rejects invalid inputs", () => {
    expect(() =>
      dominatorReserveRatio({ ...neutral, maxTroops: -1 }),
    ).toThrow();
  });
});
