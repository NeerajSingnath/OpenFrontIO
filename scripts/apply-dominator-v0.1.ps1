# OpenFront Dominator v0.1: reversible source integration.
# Run from E:\OpenFrontIO using the instructions in the README.
$ErrorActionPreference = 'Stop'
$repo = (Get-Location).Path
$policyPath = Join-Path $repo 'packages\engine\src\execution\nation\DominatorPolicy.ts'
$attackPath = Join-Path $repo 'packages\engine\src\execution\utils\AiAttackBehavior.ts'

if (-not (Test-Path $policyPath)) { throw 'Missing DominatorPolicy.ts: first extract the starter ZIP.' }
if (-not (Test-Path $attackPath)) { throw 'Missing AiAttackBehavior.ts: run from the OpenFrontIO repo root.' }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$policy = [IO.File]::ReadAllText($policyPath)
$attack = [IO.File]::ReadAllText($attackPath)
if ($attack.Contains('private effectiveReserveRatio()')) { throw 'Integration already applied; nothing changed.' }
if ($policy.Contains('DOMINATOR_EXPERIMENT_ENABLED')) { throw 'Feature flags already exist; nothing changed.' }

function Replace-Once([string]$text, [string]$old, [string]$replacement) {
    $i = $text.IndexOf($old, [StringComparison]::Ordinal)
    if ($i -lt 0) { throw "Missing expected source anchor: $old" }
    if ($text.IndexOf($old, $i + $old.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Ambiguous source anchor appears more than once: $old"
    }
    return $text.Substring(0, $i) + $replacement + $text.Substring($i + $old.Length)
}

$eol = if ($attack.Contains("`r`n")) { "`r`n" } else { "`n" }
$importAnchor = 'import { planBotAttacks, walledInBots } from "../nation/BotAnnexation";'
$importBlock = @'
import {
  DOMINATOR_TEST_NATION_INDEX,
  dominatorReserveRatio,
  isDominatorNation,
} from "../nation/DominatorPolicy";
'@
$importBlock = $importBlock.TrimEnd()
$attack = Replace-Once $attack $importAnchor ($importAnchor + $eol + $importBlock.Replace("`n", $eol))

$methodAnchor = '  private hasReserveRatioTroops(): boolean {'
$method = @'
  /** Experimental reserve for exactly one nation; others use the upstream AI unchanged. */
  private effectiveReserveRatio(): number {
    const selectedNation = this.game.nations()[DOMINATOR_TEST_NATION_INDEX];
    if (!isDominatorNation(this.player.id(), selectedNation?.playerInfo.id)) {
      return this.reserveRatio;
    }

    const neighbors = this.player.nearby();
    let strongestHostileNeighborTroops = 0;
    for (const neighbor of neighbors) {
      if (neighbor.isPlayer() && !this.player.isFriendly(neighbor)) {
        strongestHostileNeighborTroops = Math.max(
          strongestHostileNeighborTroops,
          neighbor.troops(),
        );
      }
    }

    let incomingHostileTroops = 0;
    for (const attack of this.player.incomingAttacks()) {
      if (!this.player.isFriendly(attack.attacker())) {
        incomingHostileTroops += attack.troops();
      }
    }

    return dominatorReserveRatio({
      currentTroops: this.player.troops(),
      maxTroops: this.game.config().maxTroops(this.player),
      strongestHostileNeighborTroops,
      incomingHostileTroops,
      hasUnclaimedLand: neighbors.some((neighbor) => !neighbor.isPlayer()),
    });
  }

'@
$method = $method.Replace("`n", $eol)
$attack = Replace-Once $attack $methodAnchor ($method + $methodAnchor)

$replacements = @(
    @('return ratio >= this.reserveRatio;', 'return ratio >= this.effectiveReserveRatio();'),
    @('const aboveReserve = troops - maxTroops * this.reserveRatio;', 'const aboveReserve = troops - maxTroops * this.effectiveReserveRatio();'),
    @('this.player.troops() - maxTroops * this.reserveRatio,', 'this.player.troops() - maxTroops * this.effectiveReserveRatio(),'),
    @('const reserveRatio = useReserve ? this.reserveRatio : this.expandRatio;', 'const reserveRatio = useReserve ? this.effectiveReserveRatio() : this.expandRatio;'),
    @('const troopsToKeep = maxTroops * this.reserveRatio;', 'const troopsToKeep = maxTroops * this.effectiveReserveRatio();')
)
foreach ($pair in $replacements) {
    $attack = Replace-Once $attack $pair[0] $pair[1]
}

$policyAppend = @'

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
'@
$policyEol = if ($policy.Contains("`r`n")) { "`r`n" } else { "`n" }
$policyNew = $policy.TrimEnd([char[]]@("`r", "`n")) + $policyAppend.Replace("`n", $policyEol) + $policyEol

# Nothing gets modified until all expected anchors have been validated.
[IO.File]::WriteAllText($attackPath, $attack, $utf8)
[IO.File]::WriteAllText($policyPath, $policyNew, $utf8)
Write-Host 'Dominator integration applied. Run tests and typecheck before committing.' -ForegroundColor Green
