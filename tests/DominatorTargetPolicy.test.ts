import { describe, expect, it } from "vitest";
import {
  scoreDominatorTarget,
  type DominatorTargetObservation,
} from "../packages/engine/src/execution/nation/DominatorTargetPolicy";

const baseline: DominatorTargetObservation = {
  ownTroops: 100_000,
  enemyTroops: 20_000,
  enemyTiles: 120,
  enemyEconomicLevels: 1,
  enemyAttackingUs: false,
  incomingHostileTroops: 0,
  landBorder: true,
};

describe("Dominator target scoring", () => {
  it("rewards economically valuable targets", () => {
    const valuable = { ...baseline, enemyEconomicLevels: 4 };
    expect(scoreDominatorTarget(valuable)!).toBeGreaterThan(
      scoreDominatorTarget(baseline)!,
    );
  });

  it("rewards larger targets all else equal", () => {
    expect(scoreDominatorTarget({ ...baseline, enemyTiles: 2000 })!).toBeGreaterThan(
      scoreDominatorTarget(baseline)!,
    );
  });

  it("prefers land targets over overseas targets", () => {
    expect(scoreDominatorTarget(baseline)!).toBeGreaterThan(
      scoreDominatorTarget({ ...baseline, landBorder: false })!,
    );
  });

  it("rejects dangerous stronger targets", () => {
    expect(scoreDominatorTarget({ ...baseline, enemyTroops: 80_000 })).toBeNull();
  });

  it("avoids starting a second front under major attack", () => {
    expect(
      scoreDominatorTarget({ ...baseline, incomingHostileTroops: 30_000 }),
    ).toBeNull();
  });

  it("can consider a current attacker despite the second-front guard", () => {
    expect(
      scoreDominatorTarget({
        ...baseline,
        enemyTroops: 80_000,
        incomingHostileTroops: 30_000,
        enemyAttackingUs: true,
      }),
    ).not.toBeNull();
  });

  it("does not send attacks with no army", () => {
    expect(scoreDominatorTarget({ ...baseline, ownTroops: 0 })).toBeNull();
  });

  it("rejects invalid numeric values", () => {
    expect(() =>
      scoreDominatorTarget({ ...baseline, enemyTroops: -1 }),
    ).toThrow();
  });
});
