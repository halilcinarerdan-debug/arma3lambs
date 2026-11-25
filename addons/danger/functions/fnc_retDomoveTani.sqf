#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RETREAT DOMOVE TESTI (v8.809; kullanici: 'retreati incele'; RPT 67cf9809 v8.808: retreat kosucularinin %64'u duruyor, duranlarin 61'i komut ATTACK; ATTACK 20-40 sn 'son ates' artarken (ATES YOK) ve hareket yokken surer;
 *   TAKILI satirinda 'beklenen hedef' = askerin ESKI konumu (siper noktasi), 'moveToCompleted:true': retreat doMove'u motor tarafindan KABUL EDILMEMIS gorunuyor; v8.807 kosu patlamasi (TARGET + AUTOTARGET kapat) bunu cozmedi).
 * Bu fonksiyon retreat ezme isleyicisi bir askere doStop + doMove verdikten 0.7 sn sonra motorun emri KABUL edip etmedigini olcer ve nedenini arama icin AI durumunu yazar:
 *   komut (once -> sonra), expectedDestination (nokta + mod; WP'ye / eski konuma uzaklik), unitReady, hiz, birim ve grup combatMode, davranis, assignedTarget / getAttackTarget, AI bayraklari (TARGET / AUTOTARGET / FSM / PATH / MOVE / AUTOCOMBAT / COVER),
 *   silah elde mi, kosuPatlama / kosu modu / forceMove / taktikKilit / siperTut / zorla belirteçleri.
 * Log: [RET-DOMOVE-TEST] KABUL / YOK SAYILDI (ilk 20) + 60 sn [RET-DOMOVE-OZET] (kabul / yok sayildi). Karne: 'RETREAT KOSUSU' satirinda 'doMove kabul'.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Hedef WP (AGL) <ARRAY>
 * 2: doMove oncesi komut <STRING>
 *
 * Return Value: Yok (spawn ile cagrilir)
 * Public: No
*/

params [["_b", objNull, [objNull]], ["_wp", [], [[]]], ["_kmtOnce", "?", [""]]];
if (isNull _b || {_wp isEqualTo []}) exitWith {};
private _p0 = getPosATL _b;
sleep 0.7;
if (!alive _b) exitWith {};
private _ed = expectedDestination _b;
private _kabul = ((_ed select 0) distance2D _wp) < 8;
private _say = missionNamespace getVariable ["lambs_danger_retDomoveSay", createHashMap];
missionNamespace setVariable ["lambs_danger_retDomoveSay", _say];
private _k = ["yok_sayildi", "kabul"] select _kabul;
_say set [_k, (_say getOrDefault [_k, 0]) + 1];
private _n = missionNamespace getVariable ["lambs_danger_retDomoveLogN", 0];
if (_n < 20) then {
    missionNamespace setVariable ["lambs_danger_retDomoveLogN", _n + 1];
    private _g = group _b;
    private _hd = getAttackTarget _b;
    private _at = assignedTarget _b;
    diag_log format [
        "[RET-DOMOVE-TEST] %1 | %2 | %3 | komut %4 -> %5 | beklenen hedef WP'ye %6 m, eski konuma %7 m, mod %8 | ready %9 | hiz %10 km/sa | birimCM %11 grupCM %12 | davranis %13 | saldiri hedefi %14 | atanan hedef %15 | AI TARGET:%16 AUTOTARGET:%17 FSM:%18 PATH:%19 MOVE:%20 AUTOCOMBAT:%21 COVER:%22 | silah elde: %23 | kosuPatlama %24 kosuModu %25 forceMove %26 taktikKilit %27 siperTutBit %28 zorlaBitis %29",
        ["YOK SAYILDI", "KABUL"] select _kabul, groupId _g, name _b, _kmtOnce, currentCommand _b, round ((_ed select 0) distance2D _wp), round ((_ed select 0) distance2D _p0), _ed select 1, unitReady _b, round (speed _b),
        unitCombatMode _b, combatMode _g, behaviour _b, ["-", typeOf _hd] select (!isNull _hd), ["-", typeOf _at] select (!isNull _at),
        _b checkAIFeature "TARGET", _b checkAIFeature "AUTOTARGET", _b checkAIFeature "FSM", _b checkAIFeature "PATH", _b checkAIFeature "MOVE", _b checkAIFeature "AUTOCOMBAT", _b checkAIFeature "COVER",
        (currentWeapon _b) isNotEqualTo "",
        (_b getVariable [QGVAR(kosuPatlamaTok), 0]) > 0, _b getVariable [QGVAR(retKosuModu), false], _b getVariable [QGVAR(forceMove), false], ((_b getVariable [QGVAR(taktikKilit), 0]) - time) toFixed 1,
        ((_b getVariable [QGVAR(siperTutBit), 0]) - time) toFixed 1, ((_b getVariable [QGVAR(zorlaBitis), 0]) - time) toFixed 1
    ];
};
if (isNil "lambs_danger_retDomoveOzetT") then { lambs_danger_retDomoveOzetT = time + 60; };
if (time > lambs_danger_retDomoveOzetT) then {
    lambs_danger_retDomoveOzetT = time + 60;
    diag_log format ["[RET-DOMOVE-OZET] 60 sn: kabul=%1 yok_sayildi=%2", _say getOrDefault ["kabul", 0], _say getOrDefault ["yok_sayildi", 0]];
    _say = createHashMap;
    missionNamespace setVariable ["lambs_danger_retDomoveSay", _say];
};
