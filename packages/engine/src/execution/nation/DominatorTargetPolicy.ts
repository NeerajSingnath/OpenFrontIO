/**
 * Experimental attack-target scoring for one locally simulated OpenFront nation.
 * No game-state mutation, nondeterministic inputs, or network interactions.
 */
export interface DominatorTargetObservation {
  ownTroops: number;
  enemyTroops: number;
  enemyTiles: number;
  enemyEconomicLevels: number;
  enemyAttackingUs: boolean;
  incomingHostileTroops: number;
  landBorder: boolean;
}

/**
 * Returns null when starting a new attack appears too risky.
 * Higher numbers indicate more valuable/risk-adjusted targets.
 * These coefficients are hypotheses to benchmark, not proven game-optimal values.
 */
export function scoreDominatorTarget(
  target: DominatorTargetObservation,
): number | null {
  const numbers = [
    target.ownTroops,
    target.enemyTroops,
    target.enemyTiles,
    target.enemyEconomicLevels,
    target.incomingHostileTroops,
  ];
  if (numbers.some((n) => !Number.isFinite(n) || n < 0)) {
    throw new Error("Target observations must be finite and nonnegative");
  }
  if (target.ownTroops < 1) return null;

  // Existing attack logic still checks eligibility and budgets. This filter
  // only keeps the experimental strategy from choosing reckless first strikes.
  const enemyStrength = target.enemyTroops / target.ownTroops;
  if (enemyStrength > (target.enemyAttackingUs ? 0.95 : 0.70)) {
    return null;
  }

  // Let the existing retaliation strategy deal with a major attack; don't
  // open a second front while the army is already under pressure.
  if (
    !target.enemyAttackingUs &&
    target.incomingHostileTroops > target.ownTroops * 0.25
  ) {
    return null;
  }

  const territorialValue =
    15 * Math.log2(1 + Math.min(target.enemyTiles, 20000) / 80);
  const economicValue = 22 * Math.min(target.enemyEconomicLevels, 12);
  const militaryAdvantage = 75 * (1 - enemyStrength);
  const frontierValue = target.landBorder ? 15 : -8;
  const retaliationValue = target.enemyAttackingUs ? 18 : 0;

  return (
    territorialValue +
    economicValue +
    militaryAdvantage +
    frontierValue +
    retaliationValue
  );
}
