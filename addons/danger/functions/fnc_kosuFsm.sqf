#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOSU FSM KAPAMA (v8.811; kullanici: 'retreat coz'; RPT'ler 8 adet v8.804-v8.810: retreat kosucularinin %60-67'si MOVE komutu + hiz 0 + bosta animasyon ile DURUYOR; hedef kabul edilmis (beklenen hedef WP'ye yakin) ama asker yurumuyor;
 *   TARGET / AUTOTARGET kapatma (v8.807), doStop + doMove (v8.743), kalici KOSU-MODU (AWARE + hedef alma kapali, v8.671) bunu cozmedi; ayni ortamda canli bombaci (fnc_eypKos: FSM + SUPPRESSION + AUTOCOMBAT + COVER KAPALI,
 *   MOVE / PATH / ANIM ACIK, CARELESS) kesintisiz kosuyor).
 * HIPOTEZ: motorun davranis FSM'i (tehdit / hedef / siper alt durumlari) MOVE emrini askiya aliyor; FSM kapaliyken AI yalniz emri uygular (referans modun 'move inhibitor' fikriyle ayni yon; kod kopyalanmadi).
 * KURAL: geri cekilme kosucusunun (lider HARIC: grup FSM'i liderde calisir) FSM'i kosu suresince (sure sn, varsayilan 14) kapatilir; sicrama sonunda / varista / geri cekilme bitince / sure dolunca (token) yeniden acilir.
 *   Davranis COMBAT + tufek yukarda kalir (v8.386 istegi). CBA lambs_danger_retKosuFsm kapaliysa hicbir sey yapmaz.
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Sure (sn) <NUMBER> (varsayilan 14)
 *
 * Return Value: Uygulandi mi <BOOL>
 * Log: [KOSU-FSM] (ilk 15) + 60 sn [KOSU-FSM-OZET]
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_sure", 14, [0]]];
if (isNull _u || {!alive _u} || {isPlayer _u} || {!local _u} || {!isNull objectParent _u}) exitWith {false};
if !(missionNamespace getVariable ["lambs_danger_retKosuFsm", true]) exitWith {false};
if (_u isEqualTo (leader group _u)) exitWith {false};
_sure = (_sure max 4) min 25;
private _tok = time + (random 0.001);
_u setVariable [QGVAR(kosuFsmTok), _tok];
_u disableAI "FSM";
private _say = missionNamespace getVariable ["lambs_danger_kosuFsmSay", createHashMap];
missionNamespace setVariable ["lambs_danger_kosuFsmSay", _say];
_say set ["uygulandi", (_say getOrDefault ["uygulandi", 0]) + 1];
private _n = missionNamespace getVariable ["lambs_danger_kosuFsmLogN", 0];
if (_n < 15) then {
    missionNamespace setVariable ["lambs_danger_kosuFsmLogN", _n + 1];
    diag_log format ["[KOSU-FSM] %1 | %2 | komut %3 | hiz %4 km/sa | FSM %5 sn kapali (lider haric; COMBAT + tufek yukarda)", groupId (group _u), name _u, currentCommand _u, round (speed _u), _sure toFixed 0];
};
if (isNil "lambs_danger_kosuFsmOzetT") then { lambs_danger_kosuFsmOzetT = time + 60; };
if (time > lambs_danger_kosuFsmOzetT) then {
    lambs_danger_kosuFsmOzetT = time + 60;
    diag_log format ["[KOSU-FSM-OZET] 60 sn: uygulandi=%1 erken_birakildi=%2", _say getOrDefault ["uygulandi", 0], _say getOrDefault ["birakildi", 0]];
    _say = createHashMap;
    missionNamespace setVariable ["lambs_danger_kosuFsmSay", _say];
};
[{
    params ["_uu", "_tk"];
    if (alive _uu && {(_uu getVariable [QGVAR(kosuFsmTok), 0]) isEqualTo _tk}) then {
        _uu setVariable [QGVAR(kosuFsmTok), 0];
        _uu enableAI "FSM";
    };
}, [_u, _tok], _sure] call CBA_fnc_waitAndExecute;
true
