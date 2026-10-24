# Apply v0.2 to the v0.1 integration's AiAttackBehavior.ts ONLY.
# Preflight checks avoid accidentally changing other upstream versions.
$ErrorActionPreference = 'Stop'
$repo = (Get-Location).Path
$path = Join-Path $repo 'packages\engine\src\execution\utils\AiAttackBehavior.ts'
$policy = Join-Path $repo 'packages\engine\src\execution\nation\DominatorTargetPolicy.ts'
if (-not (Test-Path $path)) { throw 'Cannot find AiAttackBehavior.ts. Run this from the OpenFrontIO root.' }
if (-not (Test-Path $policy)) { throw 'Cannot find DominatorTargetPolicy.ts. Extract the v0.2 ZIP first.' }
$original = [IO.File]::ReadAllText($path)
if ($original.Contains('const dominatorStrategy = (): boolean =>')) {
  throw 'Dominator v0.2 is already installed. No changes made.'
}
if (-not $original.Contains('private effectiveReserveRatio()')) {
  throw 'v0.1 experimental reserve integration missing. No changes made.'
}
if (-not $original.Contains('isDominatorNation')) {
  throw 'v0.1 nation selection missing. No changes made.'
}

function Replace-Once([string]$text, [string]$old, [string]$replacement) {
    $i = $text.IndexOf($old, [StringComparison]::Ordinal)
    if ($i -lt 0) { throw "Missing expected code anchor: $old. No changes made." }
    if ($text.IndexOf($old, $i + $old.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Ambiguous repeated code anchor: $old. No changes made."
    }
    return $text.Substring(0, $i) + $replacement + $text.Substring($i + $old.Length)
}

$eol = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
$updated = $original
$importAnchor = 'import { planBotAttacks, walledInBots } from "../nation/BotAnnexation";'
$updated = Replace-Once $updated $importAnchor (
  $importAnchor + $eol + 'import { scoreDominatorTarget } from "../nation/DominatorTargetPolicy";'
)

$strategyAnchor = '    const bots = (): boolean => this.attackBots();'
$strategyCode = @'
    // v0.2: additive experiment; return false to preserve all default strategies.
    const dominatorStrategy = (): boolean => {
      const selected = this.game.nations()[DOMINATOR_TEST_NATION_INDEX];
      if (!isDominatorNation(this.player.id(), selected?.playerInfo.id)) {
        return false;
      }

      const hostileAttacks = this.player.incomingAttacks().filter(
        (attack) => !this.player.isFriendly(attack.attacker()),
      );
      const incomingHostileTroops = hostileAttacks.reduce(
        (total, attack) => total + attack.troops(),
        0,
      );

      const target = pick((enemies) => {
        let highestScore = -Infinity;
        let best: Player | null = null;
        for (const enemy of enemies) {
          // Bot annexation has a dedicated planner; don't override it.
          if (enemy.type() === PlayerType.Bot || this.player.isFriendly(enemy)) {
            continue;
          }
          const economicLevels = enemy.units().reduce((total, unit) => {
            const type = unit.type();
            return type === UnitType.City || type === UnitType.Port || type === UnitType.Factory
              ? total + unit.level()
              : total;
          }, 0);
          const score = scoreDominatorTarget({
            ownTroops: this.player.troops(),
            enemyTroops: enemy.troops(),
            enemyTiles: enemy.numTilesOwned(),
            enemyEconomicLevels: economicLevels,
            enemyAttackingUs: hostileAttacks.some((a) => a.attacker() === enemy),
            incomingHostileTroops,
            landBorder: this.bordersByLand(enemy),
          });
          if (score !== null && score > highestScore) {
            highestScore = score;
            best = enemy;
          }
        }
        return best;
      });
      return target !== null ? this.sendAttack(target) : false;
    };
'@
$strategyCode = $strategyCode.Replace("`n", $eol)
$updated = Replace-Once $updated $strategyAnchor ($strategyAnchor + $eol + $eol + $strategyCode.TrimEnd([char[]]@("`r", "`n")))

$oldOrder = 'return [bots, veryWeak, betray, assist, victim, crown, traitor, juicy, afk, nuked, hated, weakest, island, donate];'
$newOrder = 'return [bots, dominatorStrategy, veryWeak, betray, assist, victim, crown, traitor, juicy, afk, nuked, hated, weakest, island, donate];'
$updated = Replace-Once $updated $oldOrder $newOrder

# Write only after EVERY expected anchor has been found.
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($path, $updated, $utf8)
Write-Host 'Dominator v0.2 strategy installed. Run tests and typecheck.' -ForegroundColor Green
