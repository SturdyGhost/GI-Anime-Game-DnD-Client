# Generates data/Reputation_Events.json — the DEFAULT campaign-history seed.
# Expands every Campaign-category action in data/reputation/actions.json into
# individual trait-event records, one per party player per emission, stamped with
# an arc-appropriate Campaign_Day so older deeds have already decayed.
# Re-run after editing campaign actions:  pwsh tools/gen_default_reputation.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$actions = (Get-Content "$root\data\reputation\actions.json" -Raw | ConvertFrom-Json).actions
$campaign = $actions | Where-Object { $_.Category -eq 'Campaign' }

# The three player characters (companions excluded). Communal campaign deeds are
# attributed to all three — they adventured as a party — so each carries the
# shared history; future per-player actions create divergence from there.
$actors = @("Brian C.", "Brian F.", "Dylan")

# Arc -> starting Campaign_Day (current campaign clock is 835 / Year 3 Month 4).
$regionBase = @{ "Mondstadt" = 60; "Liyue" = 250; "Inazuma" = 480; "Khaenri'ah" = 680; "Sumeru" = 760 }
$regionIdx  = @{}

$records = New-Object System.Collections.ArrayList
$id = 1
foreach ($a in $campaign) {
  $region = if ($a.Region) { $a.Region } else { "Liyue" }
  if (-not $regionBase.ContainsKey($region)) { $regionBase[$region] = 300 }
  if (-not $regionIdx.ContainsKey($region))  { $regionIdx[$region] = 0 }
  # An action may pin its own Campaign_Day (same-session deeds all share a day);
  # otherwise it slots into the region's arc at 8-day intervals.
  if ($null -ne $a.Campaign_Day) {
    $day = [int]$a.Campaign_Day
  } else {
    $day = $regionBase[$region] + ($regionIdx[$region] * 8)
    $regionIdx[$region]++
  }
  # An action with its own Actor(s) was done by those members alone; otherwise the
  # whole party did it (attributed to all three) and forms the shared baseline.
  # `Actors` (array) covers deeds shared by some-but-not-all of the party.
  $actorList = if ($a.Actors) { @($a.Actors | ForEach-Object { [string]$_ }) }
               elseif ($a.Actor) { @([string]$a.Actor) }
               else { @("Party") }
  foreach ($actor in $actorList) {
    foreach ($e in $a.Emissions) {
      [void]$records.Add([ordered]@{
        id            = $id
        Actor         = $actor
        Region        = $region
        Trait         = $e.Trait
        Points        = $e.Points
        Severity      = $e.Severity
        Campaign_Day  = $day
        Source_Action = $a.Id
        created_at    = "2026-06-14T00:00:00"
      })
      $id++
    }
  }
}

# --- Standing events: authored grudges/favors that trait-alignment can't capture
# (e.g. "you got our leader killed"). Faction scope = party-wide; Individual scope
# = a specific NPC's personal feeling. Negative = grudge, positive = favor.
$standing = @(
  @{ Scope_Type="Faction";    Scope="Signora's Retinue"; Standing=-200; Severity=0.95; Campaign_Day=580; Note="Party caused La Signora's death (death-duel -> the Raiden executed La Signora)" },
  @{ Scope_Type="Faction";    Scope="Fatui";             Standing=-110; Severity=0.80; Campaign_Day=540; Note="Killed Fatui personnel across the Liyue lab and Inazuma delusion factory" },
  @{ Scope_Type="Faction";    Scope="Fatui Skirmishers"; Standing=-80;  Severity=0.65; Campaign_Day=540; Note="Killed rank-and-file skirmishers at those sites" },
  @{ Scope_Type="Faction";    Scope="The Akademiya";     Standing=-100; Severity=0.70; Campaign_Day=805; Note="Broke the dream-harvest loop and foiled Grand Sage Azar's scheme" },
  @{ Scope_Type="Faction";    Scope="The Shogunate";     Standing=-30;  Severity=0.60; Campaign_Day=600; Note="Openly defied the Vision Hunt Decree (later partly reconciled with the Raiden)" },
  @{ Scope_Type="Individual"; Scope="Alhaitham";         Standing=90;   Severity=0.60; Campaign_Day=770; Note="The party helped Alhaitham at Port Ormos; Alhaitham respects the party, but is aloof rather than effusive" },
  @{ Scope_Type="Individual"; Scope="Nahida";            Standing=120;  Severity=0.70; Campaign_Day=810; Note="Nahida went through the entire dream-loop ordeal with the party, and the party saved all of Sumeru's dreamers - Nahida is deeply fond of the party" },
  @{ Scope_Type="Individual"; Scope="Scaramouche";       Standing=-65;  Severity=0.80; Campaign_Day=580; Note="Upset the party got Scaramouche's fellow Harbinger and then-ally Signora killed" },
  @{ Scope_Type="Individual"; Scope="Mona";              Standing=-55;  Severity=0.55; Campaign_Day=75;  Note="The party accidentally attacked Mona, then tried to 'buy' Mona with a couple of coins - a valuation of 2 gold" },
  @{ Scope_Type="Faction";    Scope="HexenZirkel";       Standing=-15;  Severity=0.50; Campaign_Day=75;  Note="Ripple: their member Mona was assaulted and demeaned" },
  @{ Scope_Type="Faction";    Scope="Yashiro Commission"; Standing=140; Severity=0.80; Campaign_Day=660; Note="Dylan married into the Kamisato clan (who lead the Yashiro Commission) - they are family now" },
  @{ Scope_Type="Individual"; Scope="Kamisato Ayato";    Standing=95;   Severity=0.70; Campaign_Day=660; Note="Ayato is now Dylan's brother-in-law through Dylan's marriage to Ayato's sister Ayaka" },
  @{ Scope_Type="Region";     Scope="Sumeru";            Standing=-55;  Severity=0.60; Campaign_Day=810; Note="The Akademiya - who currently govern Sumeru - turned cold after the party foiled their dream-harvest scheme, souring the region's official reception. The populace is no warmer: Sumerans do not regard Lesser Lord Kusanali favourably, so standing as Kusanali's champions wins the party little here" },
  @{ Scope_Type="Region";     Scope="Inazuma";           Standing=22;   Severity=0.80; Campaign_Day=660; Actor="Dylan"; Note="Dylan married into the prominent Kamisato clan, lifting Dylan's own standing across Inazuma above the party's rebel reputation - reduced since Ayaka's death, as Dylan is now a widower rather than a newly-made son of the clan, though Dylan remains Ayato's brother-in-law" },
  # Per-member personal reputations (so no two members read identically):
  @{ Scope_Type="Region";     Scope="Sumeru";            Standing=30;   Severity=0.55; Campaign_Day=800; Actor="Brian F."; Note="Brian F. is personally respected by Sumeru's intellectuals as a fellow scholar" },
  @{ Scope_Type="Region";     Scope="Liyue";             Standing=12;   Severity=0.45; Campaign_Day=300; Actor="Brian F."; Note="Brian F. is well regarded in Liyue as a scholar and a capable talker" },
  @{ Scope_Type="Region";     Scope="Liyue";             Standing=-28;  Severity=0.50; Campaign_Day=300; Actor="Brian F."; Note="Brian F. is also on a list among Liyue's librarians - unpaid late fees, plus a name for pursuing them too persistently" },
  @{ Scope_Type="Region";     Scope="Mondstadt";         Standing=-22;  Severity=0.55; Campaign_Day=110; Actor="Brian F."; Note="Brian F. is the one who talked the Dragonspine predator into walking free, and toward work around children" },
  @{ Scope_Type="Region";     Scope="Sumeru";            Standing=-32;  Severity=0.50; Campaign_Day=805; Actor="Brian C."; Note="Brian C.'s persistent unwanted advances toward Dehya gave Brian C. an unsavory personal reputation in Sumeru" },
  @{ Scope_Type="Region";     Scope="Liyue";             Standing=-22;  Severity=0.45; Campaign_Day=300; Actor="Brian C."; Note="Brian C. is known around Liyue for heavy gambling and habitual substance use" },
  @{ Scope_Type="Region";     Scope="Mondstadt";         Standing=-16;  Severity=0.40; Campaign_Day=110; Actor="Brian C."; Note="Brian C. left a boorish personal impression in Mondstadt" },
  @{ Scope_Type="Region";     Scope="Mondstadt";         Standing=14;   Severity=0.45; Campaign_Day=110; Actor="Dylan";    Note="Vivienne is Dylan's daughter, and Dylan's devotion to Vivienne reads as wholesome to Mondstadters" },
  # --- DAY 20: "The Day of Spanking" (Suristana, Ayaka's death, the desert) ---
  # Ayaka's death: Dylan is commended, the Brians are blamed. Region records carry
  # the headline number; the matching trait actions (brians_let_ayaka_fall,
  # dylan_pyrrhic_hero_of_ayakas_death) are what actually move Inazuman factions
  # and NPCs, since normalized faction/npc standing ignores Region nudges.
  @{ Scope_Type="Region";     Scope="Inazuma";           Standing=10;   Severity=0.85; Campaign_Day=835; Actor="Dylan";    Note="Full commendation for how Dylan bore Ayaka's death - a pyrrhic hero across Inazuma, personally" },
  @{ Scope_Type="Region";     Scope="Inazuma";           Standing=-34;  Severity=0.70; Campaign_Day=835; Actor="Brian C."; Note="Blamed nation-wide for letting Kamisato Ayaka die to Dottore" },
  @{ Scope_Type="Region";     Scope="Inazuma";           Standing=-34;  Severity=0.70; Campaign_Day=835; Actor="Brian F."; Note="Blamed nation-wide for letting Kamisato Ayaka die to Dottore - and it was Brian F.'s arrow that Dottore used" },
  @{ Scope_Type="Faction";    Scope="Yashiro Commission"; Standing=-90; Severity=0.80; Campaign_Day=835; Actors=@("Brian C.","Brian F."); Note="The Kamisato clan lost a daughter on {Actor}'s watch; offsets the party-wide marriage favour for {Actor} alone" },
  @{ Scope_Type="Individual"; Scope="Kamisato Ayato";    Standing=-70;  Severity=0.80; Campaign_Day=835; Actor="Brian C."; Note="Ayato's sister is dead; Dylan is still family, Brian C. is not" },
  @{ Scope_Type="Individual"; Scope="Kamisato Ayato";    Standing=-70;  Severity=0.80; Campaign_Day=835; Actor="Brian F."; Note="Ayato's sister is dead, and it was Brian F.'s arrow that Dottore used" },
  # Sumeru under Dottore: outlaws by decree of a mind-controlled populace.
  # TEMPORARY - low Severity, and delete outright once Dottore is dealt with.
  @{ Scope_Type="Region";     Scope="Sumeru";            Standing=-15;  Severity=0.20; Campaign_Day=835; Note="TEMPORARY: branded outlaws across Sumeru while Dottore holds the population through the Acacia terminals. Delete with the branded_outlaws_of_sumeru action once Dottore is dealt with" },
  @{ Scope_Type="Individual"; Scope="Dottore";           Standing=-180; Severity=0.95; Campaign_Day=835; Note="Refused to kill the crowd Dottore controlled, refused to murder Nahida at Dottore's demand, and shot at Dottore - who answered by killing Ayaka" },
  @{ Scope_Type="Faction";    Scope="Dottore's Researchers"; Standing=-120; Severity=0.85; Campaign_Day=835; Note="Openly defied the Doctor at Suristana and broke Dottore's terminal grip on the crowd" },
  @{ Scope_Type="Individual"; Scope="Nahida";            Standing=60;   Severity=0.90; Campaign_Day=835; Note="The party obeyed Nahida's plea to harm no one and refused Dottore's demand to kill Nahida, even at the cost of Ayaka; Nahida stayed behind holding the warp so the party could escape" },
  @{ Scope_Type="Faction";    Scope="Followers of Lesser Lord Kusanali"; Standing=55; Severity=0.45; Campaign_Day=835; Note="Split (1/2): the party refused Dottore's demand to murder Kusanali even with a Harbinger's blade at their throats" },
  @{ Scope_Type="Faction";    Scope="Followers of Lesser Lord Kusanali"; Standing=-45; Severity=0.45; Campaign_Day=835; Note="Split (2/2): their god is captive and the party is not - a quiet, growing resentment. Net barely positive; expect infighting" },
  # The desert. Bargain struck, relic not yet delivered.
  @{ Scope_Type="Faction";    Scope="Desert Tribes";     Standing=45;   Severity=0.50; Campaign_Day=835; Note="Allied against the city; the King Deshret relic bargain is agreed but NOT yet fulfilled - the party killed the Ruin Guardian and have not returned to the tribes" },
  @{ Scope_Type="Faction";    Scope="Desert Tribes";     Standing=85;   Severity=0.55; Campaign_Day=835; Actor="Dylan";    Note="Dylan personally won them where Brian F.'s peaceful appeal failed - 'blood spill causes rivers to flow'" },
  @{ Scope_Type="Faction";    Scope="Deseret's Relics";  Standing=-250; Severity=0.90; Campaign_Day=816; Note="Day 19: the party wiped the band out to the last raider" },
  @{ Scope_Type="Individual"; Scope="Dehya";             Standing=50;   Severity=0.55; Campaign_Day=835; Note="Dehya fled Suristana with the party and vouched for the party to the tribes" },
  @{ Scope_Type="Individual"; Scope="Dehya";             Standing=-45;  Severity=0.50; Campaign_Day=835; Actor="Brian C."; Note="Brian C.'s persistent unwanted advances - Dehya travels with the party in spite of Brian C., not because of Brian C." }
)
# A standing record carries exactly ONE Actor - ReputationManager._standing_total
# matches it exactly - so a penalty shared by two members must become two records.
# `Actors` lets that be authored once instead of copy-pasted, and "{Actor}" in the
# Note is substituted per member so the expanded records read unambiguously.
foreach ($s in $standing) {
  $sActors = if ($s.Actors) { @($s.Actors | ForEach-Object { [string]$_ }) }
             elseif ($s.Actor) { @([string]$s.Actor) }
             else { @("Party") }
  foreach ($sActor in $sActors) {
    [void]$records.Add([ordered]@{
      id            = $id
      Actor         = $sActor
      Scope_Type    = $s.Scope_Type
      Scope         = $s.Scope
      Standing      = $s.Standing
      Severity      = $s.Severity
      Campaign_Day  = $s.Campaign_Day
      Note          = $s.Note.Replace("{Actor}", $sActor)
      created_at    = "2026-06-14T00:00:00"
    })
    $id++
  }
}

$json = $records | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText("$root\data\Reputation_Events.json", $json, (New-Object System.Text.UTF8Encoding $false))
"Wrote $($records.Count) seed records from $($campaign.Count) campaign actions across $($actors.Count) actors."
