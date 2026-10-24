/**
 * Experimental, deterministic policy for a future OpenFront Dominator nation.
 * Pure functions only: no wall-clock time, randomness, browser APIs, or side effects.
 * This module is NOT yet wired into NationExecution.
 */
export interface DominatorObservation {
  currentTroops: number;
  maxTroops: number;
  strongestHostileNeighborTroops: number;
  incomingHostileTroops: number;
  hasUnclaimedLand: boolean;
}

const clamp = (value: number, minimum: number, maximum: number) =>
  Math.max(minimum, Math.min(maximum, value));

function validate(observation: DominatorObservation): void {
  for (const value of [
    observation.currentTroops,
    observation.maxTroops,
    observation.strongestHostileNeighborTroops,
    observation.incomingHostileTroops,
  ]) {
    if (!Number.isFinite(value) || value < 0) {
      throw new Error("Dominator observations must be finite and nonnegative");
    }
  }
}

/**
 * Reserve is a fraction of the game's troop capacity.
 * Higher hostile pressure -> conserve troops.
 * Quiet, unclaimed frontier -> expand more aggressively.
 *
 * All coefficients are hypotheses; benchmark them before claiming improvement.
 */
export function dominatorReserveRatio(
  observation: DominatorObservation,
): number {
  validate(observation);

  const army = Math.max(1, observation.currentTroops);
  const borderPressure = clamp(
    observation.strongestHostileNeighborTroops / army,
    0,
    2,
  );
  const incomingPressure = clamp(
    observation.incomingHostileTroops / army,
    0,
    2,
  );
  const safeExpansion =
    observation.hasUnclaimedLand &&
    borderPressure < 0.35 &&
    incomingPressure === 0;

  return clamp(
    0.30 +
      0.18 * borderPressure +
      0.22 * incomingPressure -
      (safeExpansion ? 0.06 : 0),
    0.24,
    0.8,
  );
}

/** Maximum troops that could be committed without breaching the reserve. */
export function dominatorAttackBudget(
  observation: DominatorObservation,
): number {
  const reserve = Math.ceil(
    observation.maxTroops * dominatorReserveRatio(observation),
  );
  return Math.max(0, Math.floor(observation.currentTroops - reserve));
}
/** Local experiment: applies only to the nation at the configured roster index. */
export const DOMINATOR_EXPERIMENT_ENABLED = true;
export const DOMINATOR_TEST_NATION_INDEX = 0;

/** This function has no simulation state, so it is safe across save/restore. */
export function isDominatorNation(
  playerId: string,
  selectedNationId: string | undefined,
  enabled: boolean = DOMINATOR_EXPERIMENT_ENABLED,
): boolean {
  return enabled && selectedNationId !== undefined && playerId === selectedNationId;
}
