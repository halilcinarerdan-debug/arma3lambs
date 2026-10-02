#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KUMANDA EMIR KANALI: kumanda modullerinin gruplara emir vermesinin TEK yolu (kayit + olay + yurutucu).
 *
 * EMIRLER:
 *   TAKVIYE  veri [hedef pozisyon, yardim isteyen grup adi]  -> LAMBS tacticsReinforce (kanattan yaklasma / CQB'de saldiri); LAMBS'in grup bayragi (enableGroupReinforce) EMIR SONRASI ESKI HALINE DONER
 *            (yoksa grup sonradan upstream telsiz olayiyla kumandayi atlayip kendi basina kosardi)
 *   KANAT    veri [kanat noktasi, istek sahibi grup adi]  -> ayni yurutucu (kanat noktasina hareket); varista kumanda SALDIRI verir
 *   SALDIRI  veri [dusman pozisyonu]  -> LAMBS tacticsAssault (kanattan hucum)
 *   ATES_KAYDIR veri [nokta]  -> grubun tum askerleri doSuppressiveFire nokta (doktrin: destek ateşi hazirlik sinyali ile kaydirilir / kesilir; hucum eden dost unsura ates gitmesin)
 *
 * Her emir: grup degiskeni lambs_danger_hqEmir = [ad, zaman, veri]; lambs_danger_hqGorevT = zaman; olay "HQEmir" (veri = ad); RPT [HQ-EMIR] (ilk 200 satir)
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Emir adi <STRING>
 * 2: Veri <ARRAY>
 *
 * Return Value: Uygulandi mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_ad", "", [""]], ["_veri", []]];
if (isNull _g || {_ad isEqualTo ""} || {!alive (leader _g)}) exitWith {false};

private _ok = false;

// TAKVIYE / KANAT: bir noktaya (kanat hedefi / yardim noktasi) hareket (LAMBS tacticsReinforce)
if (_ad in ["TAKVIYE", "KANAT"]) then {
    _veri params [["_hedef", [0, 0, 0], [[]]], ["_istekAd", "", [""]]];
    if (_hedef isNotEqualTo [0, 0, 0] && {!isNil "lambs_danger_fnc_tacticsReinforce"}) then {
        private _eskiF = _g getVariable ["lambs_danger_enableGroupReinforce", false];
        private _eskiT = _g getVariable ["lambs_danger_enableGroupReinforceTime", -1];
        [leader _g, _hedef, [], 120] call FUNC(tacticsReinforce);
        _g setVariable ["lambs_danger_enableGroupReinforce", _eskiF, true];
        _g setVariable ["lambs_danger_enableGroupReinforceTime", _eskiT, true];
        [{ params ["_grp"]; if (!isNull _grp) then { _grp enableAttack true; }; }, _g, 70] call CBA_fnc_waitAndExecute;
        _ok = true;
    };
};

// SALDIRI: kanat konumundan dusman noktasina hucum (LAMBS tacticsAssault)
if (_ad isEqualTo "SALDIRI") then {
    _veri params [["_hedef", [0, 0, 0], [[]]]];
    if (_hedef isNotEqualTo [0, 0, 0] && {!isNil "lambs_danger_fnc_tacticsAssault"}) then {
        [_g, _hedef] call FUNC(tacticsAssault);
        _ok = true;
    };
};

// ATES_KAYDIR: sabitleyen grup ateşini bir noktaya kaydirir (hucum eden dost unsurdan uzaga)
if (_ad isEqualTo "ATES_KAYDIR") then {
    _veri params [["_poz", [0, 0, 0], [[]]]];
    if (_poz isNotEqualTo [0, 0, 0]) then {
        { if (alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}) then { _x doSuppressiveFire _poz; }; } forEach (units _g);
        _ok = true;
    };
};

if (_ok) then {
    _g setVariable ["lambs_danger_hqEmir", [_ad, time, _veri]];
    _g setVariable ["lambs_danger_hqGorevT", time];
    [_g, "HQEmir", _ad] call FUNC(olayGonder);
    if (isNil "lambs_danger_hqEmirN") then { lambs_danger_hqEmirN = 0; };
    if (lambs_danger_hqEmirN < 200) then {
        lambs_danger_hqEmirN = lambs_danger_hqEmirN + 1;
        diag_log format ["[HQ-EMIR] %1 | %2 | %3", groupId _g, _ad, _veri];
    };
};
_ok
