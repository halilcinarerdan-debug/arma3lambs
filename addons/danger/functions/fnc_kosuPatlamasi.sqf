#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOSU PATLAMASI (v8.807; kullanici: 'retreati incele, cok aciktta durmasinlar, siperi guclendir'; RPT d03615e7 v8.806: retreat kosucu orneklerinin %67'si duruyor ve duranlarin 14 / 16'si komut ATTACK; tek retreat'te lider 25 sn boyunca
 *   ATTACK -> yeniden MOVE (3 sn'de bir, hedefe 68 m) dongusunde aciktta kaldi; siper varis gozcusunde 18 basarisizligin 8'i komut ATTACK / Suppress).
 * NEDEN: motorun hedefe nisan alma alt durumu (AUTOTARGET / TARGET acikken gorulen dusmana dur + ates et) MOVE emrini askıya alir; geri cekilme kosucusunun ezme isleyicisi hedef almayi hep yeniden aciyordu (v8.386: 'kosarken karsilik
 *   versin') -> dongu. Teknik (referans modun 'move inhibitor' fikrinden ilhamla, kod kopyalanmadi): kosucu kisa sureligine (sure sn) TARGET + AUTOTARGET kapatilir, mevcut hedef birakilir (doTarget / doWatch objNull); tufek INDIRILMEZ
 *   (davranis degismez: COMBAT / tufek yukarda), sure sonunda hedef alma geri verilir (baska katman koşu modunu kalici tuttuysa -retKosuModu- dokunulmaz).
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Sure (sn) <NUMBER>
 * 2: Kaynak <STRING> (retreat / varis)
 *
 * Return Value: Uygulandi mi <BOOL> (CBA kosuPatlama kapaliysa false: cagiran eski davranisa doner)
 * CBA: lambs_danger_kosuPatlama (acik / kapali), lambs_danger_kosuPatlamaS (varsayilan sure). Log: [KOSU-PATLAMA] (ilk 20) + 60 sn [KOSU-PATLAMA-OZET]
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_sure", 0, [0]], ["_kaynak", "?", [""]]];
if (isNull _u || {!alive _u} || {isPlayer _u} || {!local _u}) exitWith {false};
if !(missionNamespace getVariable ["lambs_danger_kosuPatlama", true]) exitWith {false};
if (_sure <= 0) then { _sure = missionNamespace getVariable ["lambs_danger_kosuPatlamaS", 6]; };
_sure = (_sure max 2) min 15;
private _tok = time + (random 0.001);
_u setVariable [QGVAR(kosuPatlamaTok), _tok];
_u disableAI "TARGET";
_u disableAI "AUTOTARGET";
_u doTarget objNull;
_u doWatch objNull;

private _say = missionNamespace getVariable ["lambs_danger_kosuPatSay", createHashMap];
missionNamespace setVariable ["lambs_danger_kosuPatSay", _say];
_say set [_kaynak, (_say getOrDefault [_kaynak, 0]) + 1];
private _n = missionNamespace getVariable ["lambs_danger_kosuPatLogN", 0];
if (_n < 20) then {
    missionNamespace setVariable ["lambs_danger_kosuPatLogN", _n + 1];
    diag_log format ["[KOSU-PATLAMA] %1 | %2 | %3%4 | komut %5 | hiz %6 km/sa | %7 sn hedef alma kapali (tufek yukarda)", _kaynak, groupId (group _u), name _u, ["", " (K)"] select (_u isEqualTo (leader _u)), currentCommand _u, round (speed _u), _sure toFixed 0];
};
if (isNil "lambs_danger_kosuPatOzetT") then { lambs_danger_kosuPatOzetT = time + 60; };
if (time > lambs_danger_kosuPatOzetT) then {
    lambs_danger_kosuPatOzetT = time + 60;
    diag_log format ["[KOSU-PATLAMA-OZET] 60 sn: %1", (_say toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }];
    _say = createHashMap;
    missionNamespace setVariable ["lambs_danger_kosuPatSay", _say];
};
[{
    params ["_uu", "_tk"];
    if (alive _uu && {(_uu getVariable [QGVAR(kosuPatlamaTok), 0]) isEqualTo _tk}) then {
        _uu setVariable [QGVAR(kosuPatlamaTok), 0];
        if (!(_uu getVariable [QGVAR(retKosuModu), false])) then {
            _uu enableAI "TARGET";
            _uu enableAI "AUTOTARGET";
        };
    };
}, [_u, _tok], _sure] call CBA_fnc_waitAndExecute;
true
