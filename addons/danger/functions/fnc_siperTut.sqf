#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIPERDE TUT (v8.521; kullanici: 'botlar git gel atiyorlar, bir one gidiyor sonra bir arkaya gidiyor, aciklta duruyorlar').
 * Neden: fnc_acikSiper / fnc_siperZorla askeri siper noktasina yollar ama VARINCA birakir; 15 sn'lik taktik kilidi dolunca AI formasyon slotuna (FORMATION PLANNED; RPT 14:32 [ANOMALI] BOSTA-HAREKET:
 * 'lider duruyor, askerler FORMATION PLANNED ile liderin yanina yuruyor') geri doner -> siperden cikip acikta yuruyor, tekrar temas / acikta tespiti -> yeniden siper = GIT-GEL.
 * Bu fonksiyon siper noktasina varinca (cagiran, varis callback'inde) askeri DURDURUR (doStop: ates etmeye devam eder), taktik kilidini uzatir (diger ELITE katmanlari tasimaz) ve
 *   temas bitince (8 sn) / 45 sn sonra / kosucu (forceMove) olunca ya da emir verilince serbest birakir (doFollow). Bounding yeni sicrama verirse (moveTo / doMove) bu bekleme dogal olarak ezilir.
 * Kapatma: lambs_danger_siperTutOff = true.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 *
 * Return Value: Beklemeye alindi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]]];
if (isNull _u || {!alive _u} || {isPlayer _u} || {!local _u} || {missionNamespace getVariable ["lambs_danger_siperTutOff", false]}) exitWith {false};
if ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true || {captive _u} || {_u getVariable [QGVAR(teslim), false]} || {!isNull objectParent _u}) exitWith {false};
if ([group _u, "siperTut", true] call FUNC(senaryoKapi)) exitWith {false};   // LAMBS gorevi / kal-bekle waypoint'li grupta dokunma
if ((group _u) getVariable [QGVAR(isRetreating), false]) exitWith {false};

private _bit = time + 45;
_u setVariable [QGVAR(siperTutBit), _bit];
_u setVariable [QGVAR(taktikKilit), _bit];
doStop _u;
[{
    params ["_uu", "_b"];
    !alive _uu || {(_uu getVariable [QGVAR(siperTutBit), 0]) isNotEqualTo _b} || {time >= _b}
        || {((group _uu) getVariable [QGVAR(contact), 0]) < (time - 8)} || {(_uu getVariable [QGVAR(forceMove), false]) isEqualTo true}
}, {
    params ["_uu", "_b"];
    if (alive _uu && {(_uu getVariable [QGVAR(siperTutBit), 0]) isEqualTo _b}) then {
        _uu setVariable [QGVAR(siperTutBit), 0];
        _uu setVariable [QGVAR(taktikKilit), 0];
        if (!(_uu getVariable [QGVAR(forceMove), false]) && {_uu isNotEqualTo (leader _uu)}) then { _uu doFollow (leader _uu); };
    };
}, [_u, _bit], 46, {
    params ["_uu", "_b"];
    if (alive _uu && {(_uu getVariable [QGVAR(siperTutBit), 0]) isEqualTo _b}) then { _uu setVariable [QGVAR(siperTutBit), 0]; _uu setVariable [QGVAR(taktikKilit), 0]; };
}] call CBA_fnc_waitUntilAndExecute;
if ((missionNamespace getVariable ["lambs_danger_siperTutLogN", 0]) < 30) then {
    missionNamespace setVariable ["lambs_danger_siperTutLogN", (missionNamespace getVariable ["lambs_danger_siperTutLogN", 0]) + 1];
    diag_log format ["[SIPER-TUT] %1 | %2 | siperde bekliyor (doStop; temas bitince / 45 sn serbest)", groupId (group _u), name _u];
};
true
