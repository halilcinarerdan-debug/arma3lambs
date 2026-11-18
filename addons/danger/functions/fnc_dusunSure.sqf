#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DUSUNME HIZI (v8.601; kullanici: 'ai kodlarda kabaca yuzde 20 daha hizli dusunur, sicak temas kisimlarini; cqb boyle kalsin'): karar / algi izleyicilerinin dongu bekleme suresini SICAK TEMASTA kisaltir.
 * Sicak temas = yerel, oyuncusuz bir AI grubu temasta (QGVAR(contact) > time); bayrak 1 sn'de bir yenilenir (allGroups taramasi ucuz). Temas yokken sure DEGISMEZ (bosta ek yuk yok).
 * Carpan: CBA lambs_danger_dusunHizi (0.5-2, varsayilan 1.25 = %25 daha hizli; 1 = eski); ONEMLI izleyiciler (ikinci parametre true: ates ustunlugu, ates-hareket, pusu tepkisi, patlayici, kacis, hedef siper, ufuk / sektor / gizli algi,
 *   yeniden doldurma siperi, lider senkronu, komutan karar onbellegi) CBA lambs_danger_dusunHiziOnemli (varsayilan 1.30 = %30). Sure = bekleme / carpan.
 * Kullanan izleyiciler (CQB izleyicileri KULLANMAZ): atisUstunlugu, atesHareket, hedefSiper, reloadCover, gizliAlgi, leaderSync, ozguven, pusuTepki, sektorBakis, ufukAlgi, acikBekleme, haltKur, kacis, kamuflaj,
 *   sinsiGeri, pusu, patlayici, buddyBond, dispersion, fireSupport, gelisYonu, noktaEleman, tehlikeAlani, rearGuard, mermiDisiplin, combatGevset, moral + fnc_tactics komutan karar onbellegi.
 *
 * Arguments:
 * 0: Taban bekleme suresi (sn) <NUMBER>
 * 1: Onemli izleyici mi (%30 carpani) <BOOL> (varsayilan false)
 * 2: CQB izleyicisi mi (v8.603: CBA lambs_danger_dusunHiziCqb, varsayilan 1.10 = %10; kullanici: 'cqbde islemci yuku artsin yuzde 10 daha hizli dusunsunler') <BOOL> (varsayilan false)
 *
 * Return Value: Bekleme suresi (sn) <NUMBER>
 * Public: No
*/

params [["_s", 1, [0]], ["_onemli", false, [false]], ["_cqb", false, [false]]];
private _h = ((missionNamespace getVariable [if (_cqb) then {"lambs_danger_dusunHiziCqb"} else {["lambs_danger_dusunHizi", "lambs_danger_dusunHiziOnemli"] select _onemli}, if (_cqb) then {1.1} else {[1.25, 1.3] select _onemli}]) max 0.5) min 2;
if (_h isEqualTo 1) exitWith {_s};
if (time > (missionNamespace getVariable ["lambs_danger_sicakT", -1])) then {
    missionNamespace setVariable ["lambs_danger_sicakT", time + 1];
    missionNamespace setVariable ["lambs_danger_sicakTemas", (allGroups findIf { local _x && {(_x getVariable [QGVAR(contact), 0]) > time} && {((units _x) findIf {isPlayer _x}) < 0} }) >= 0];
};
if (missionNamespace getVariable ["lambs_danger_sicakTemas", false]) then { _s / _h } else { _s }
