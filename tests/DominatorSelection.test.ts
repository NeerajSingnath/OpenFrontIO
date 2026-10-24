import { describe, expect, it } from "vitest";
import {
  DOMINATOR_EXPERIMENT_ENABLED,
  DOMINATOR_TEST_NATION_INDEX,
  isDominatorNation,
} from "../packages/engine/src/execution/nation/DominatorPolicy";

describe("Dominator nation selection", () => {
  it("enables the experiment for local testing", () => {
    expect(DOMINATOR_EXPERIMENT_ENABLED).toBe(true);
    expect(DOMINATOR_TEST_NATION_INDEX).toBe(0);
  });

  it("selects the designated nation only", () => {
    expect(isDominatorNation("nation-alpha", "nation-alpha")).toBe(true);
    expect(isDominatorNation("nation-beta", "nation-alpha")).toBe(false);
  });

  it("does not activate without a configured nation", () => {
    expect(isDominatorNation("nation-alpha", undefined)).toBe(false);
  });

  it("can be disabled without changing the policy", () => {
    expect(isDominatorNation("nation-alpha", "nation-alpha", false)).toBe(false);
  });
});
