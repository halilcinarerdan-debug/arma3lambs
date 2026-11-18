#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DUSUNME HIZI (v8.601; kullanici: 'ai kodlarda kabaca yuzde 20 daha hizli dusunur, sicak temas kisimlarini; cqb boyle kalsin'): karar / algi izleyicilerinin dongu bekleme suresini SICAK TEMASTA kisaltir.
 * Sicak temas = yerel, oyuncusuz bir AI grubu temasta (QGVAR(contact) > time); bayrak 1 sn'de bir yenilenir (allGroups taramasi ucuz). Temas yokken sure DEGISMEZ (bosta ek yuk yok).
 * Carpan: CBA lambs_danger_dusunHizi (0.5-2, varsayilan 1.2 = %20 daha hizli; 1 = eski). Sure = bekleme / carpan.
 * Kullanan izleyiciler (CQB izleyicileri KULLANMAZ): atisUstunlugu, atesHareket, hedefSiper, reloadCover, gizliAlgi, leaderSync, ozguven, pusuTepki, sektorBakis, ufukAlgi, acikBekleme, haltKur, kacis, kamuflaj,
 *   sinsiGeri, pusu, patlayici, buddyBond, dispersion, fireSupport, gelisYonu, noktaEleman, tehlikeAlani, rearGuard, mermiDisiplin, combatGevset, moral + fnc_tactics komutan karar onbellegi.
 *
 * Arguments:
 * 0: Taban bekleme suresi (sn) <NUMBER>
 *
 * Return Value: Bekleme suresi (sn) <NUMBER>
 * Public: No
*/

params [["_s", 1, [0]]];
private _h = ((missionNamespace getVariable ["lambs_danger_dusunHizi", 1.2]) max 0.5) min 2;
if (_h isEqualTo 1) exitWith {_s};
if (time > (missionNamespace getVariable ["lambs_danger_sicakT", -1])) then {
    missionNamespace setVariable ["lambs_danger_sicakT", time + 1];
    missionNamespace setVariable ["lambs_danger_sicakTemas", (allGroups findIf { local _x && {(_x getVariable [QGVAR(contact), 0]) > time} && {((units _x) findIf {isPlayer _x}) < 0} }) >= 0];
};
if (missionNamespace getVariable ["lambs_danger_sicakTemas", false]) then { _s / _h } else { _s }
