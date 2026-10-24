# Dominator v0.2 — risk-adjusted target selection

This is a **local/offline OpenFront simulation experiment**, not a public-server
client bot. The patch is designed only for the v0.1 fork created in our prior
steps, which has `private effectiveReserveRatio()` in `AiAttackBehavior.ts`.

## Install (PowerShell, E:\OpenFrontIO)

1. Ensure the v0.1 work is committed and the tree is clean; create a new
   branch with `git switch -c feature/dominator-ai-v0.2`.
2. Extract the ZIP into the repo root, keeping the `packages`, `scripts`,
   and `tests` folder structure.
3. Apply patch:
   `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\apply-dominator-v0.2.ps1`
4. Run:

   ```powershell
   npx vitest run tests/DominatorPolicy.test.ts tests/DominatorSelection.test.ts tests/DominatorTargetPolicy.test.ts
   npm run typecheck
   git diff --check
   ```

5. Inspect `git diff` and run `npm run dev` for a local game. If validated:

   ```powershell
   git add packages/engine/src/execution/nation/DominatorTargetPolicy.ts
   git add packages/engine/src/execution/utils/AiAttackBehavior.ts
   git add tests/DominatorTargetPolicy.test.ts scripts/apply-dominator-v0.2.ps1 DOMINATOR_V02.md
   git commit -m "feat(ai): add risk-adjusted target selection experiment"
   git push -u origin feature/dominator-ai-v0.2
   ```

## What it does

- Only the selected first nation (`DOMINATOR_TEST_NATION_INDEX = 0`) uses this strategy.
- Uses existing engine eligibility checks and actual attack sending; it doesn't
  modify hit points, resources or troop balances.
- Scores reachable hostile nations by troop advantage, territory, economic
  structures, land adjacency and incoming attack pressure.
- Keeps existing bot-annexation and downstream Impossible strategies as fallback.
- No simulation state to save/restore. No machine learning in this milestone.

## Caveats

The scoring weights are **untuned hypotheses**, not known to improve win rate.
Do A/B trials with identical seeds and map settings before claiming success.
The script intentionally fails without writing anything when the local
`AiAttackBehavior.ts` doesn't match the older integration version.
To revert the v0.2 source integration before commit, review `git diff` and
restore just `AiAttackBehavior.ts` using `git restore`, then remove the new files.
