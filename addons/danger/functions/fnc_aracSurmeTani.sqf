#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC SURMEME TANISI (v8.213) — AI surucu emri alip aracı surmuyor (RHS Stryker / M113A3 / GM Milan; sebep bilinmiyor). Olasi nedenleri tek tek loglar:
 *  A) surucuda AI ozelligi kapali (PATH / MOVE / TEAMSWITCH...)  B) ELITE / LAMBS bayragi: doStop / disableAI / ozel degiskenler  C) hasar: tekerlek / palet / yakit / canMove
 *  D) grup / yerellik: sahip, grup sahibi farkli, lider baska aracta  E) yolcu / ek surucu catismasi: komutan koltugu, effectiveCommander, ikinci arac grubu emri  F) cevre: yakin arac / engel / yuzey / egim
 *  G) yol bulma: hedefe giden rota var mi (calculatePath sonucu) ve 60 m ileri yakin hedefe doMove SINAMASI: arac 6 sn'de >3 m giderse "yakin hedef calisiyor" (sorun uzak rota), gitmezse "AI hic surmuyor"
 * Log: [SURME-TANI-*]. Arac basina 90 sn'de bir.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Surucu <OBJECT>
 * 2: Etiket (log) <STRING>
 *
 * Return Value: Yok
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_d", objNull, [objNull]], ["_et", "?", [""]], ["_sinama", true, [true]]];
if (isNull _v || {isNull _d} || {(time - (_v getVariable [QGVAR(surmeTaniT), -999])) < 90}) exitWith {};
_v setVariable [QGVAR(surmeTaniT), time];

private _vg = group _d;
private _ozellik = ["PATH", "MOVE", "ANIM", "FSM", "TARGET", "AUTOTARGET", "TEAMSWITCH", "AUTOCOMBAT", "COVER", "SUPPRESSION"] apply { format ["%1=%2", _x, _d checkAIFeature _x] };
private _lambsDeg = (allVariables _d) select {(toLower _x) find "lambs" >= 0 || {(toLower _x) find "elite" >= 0}};
private _lambsDegV = (allVariables _v) select {(toLower _x) find "lambs" >= 0};
private _lambsDegG = (allVariables _vg) select {(toLower _x) find "lambs" >= 0};
private _hasar = (getAllHitPointsDamage _v);
private _hasarOzet = [];
if (count _hasar >= 3) then {
    private _hn = _hasar select 0; private _hd = _hasar select 2;
    { if ((_hd select _forEachIndex) > 0.3) then { _hasarOzet pushBack format ["%1=%2", _x, (_hd select _forEachIndex) toFixed 2]; }; } forEach _hn;
};

diag_log format ["[SURME-TANI-AI] %1 | surucu %2 | AI ozellik: %3 | simulasyon surucu %4 arac %5 | hayatta %6 yasam %7 | esir %8 | komut %9 | hedef %10 | hazir %11 | tamamlandi %12 | basarisiz %13",
    _et, name _d, _ozellik joinString " ", simulationEnabled _d, simulationEnabled _v, alive _d, lifeState _d, captive _d, currentCommand _d, expectedDestination _d, unitReady _d, moveToCompleted _d, moveToFailed _d];
diag_log format ["[SURME-TANI-DEGISKEN] %1 | surucu: %2 | arac: %3 | grup: %4", _et, _lambsDeg, _lambsDegV, _lambsDegG];
diag_log format ["[SURME-TANI-HASAR] %1 | canMove %2 | yakit %3 | hasar %4 | parca hasari >0.3: %5 | motor %6 | kilitli %7 | baglanmis %8 | hiz limiti %9",
    _et, canMove _v, fuel _v toFixed 2, damage _v toFixed 2, _hasarOzet, isEngineOn _v, locked _v, attachedTo _v, speedMode _vg];
diag_log format ["[SURME-TANI-GRUP] %1 | arac sahibi %2 grup sahibi %3 surucu sahibi %4 | grup lideri %5 (aracta %6) | grup boyu %7 | surucu grubu %8 | arac grubu uyeleri aracta %9 | efektif komutan %10 | koltuklar %11",
    _et, owner _v, groupOwner _vg, owner _d, name leader _vg, (vehicle leader _vg) isEqualTo _v, count units _vg, groupId _vg, {vehicle _x isEqualTo _v} count units _vg, name effectiveCommander _v, (fullCrew _v) apply {format ["%1:%2", _x select 1, name (_x select 0)]}];
private _komsu = (_v nearEntities ["LandVehicle", 25]) - [_v];
diag_log format ["[SURME-TANI-CEVRE] %1 | yakin araclar(25 m) %2 | yakin nesne(8 m) %3 | yuzey %4 | egim %5 | su %6 | yol %7 | yere deger %8",
    _et, _komsu apply {format ["%1@%2m", typeOf _x, round (_v distance _x)]}, ((nearestObjects [_v, [], 8]) select {_x isNotEqualTo _v && {!(_x isKindOf "CAManBase")}}) apply {typeOf _x}, surfaceType (getPosATL _v), (surfaceNormal (getPosATL _v)) apply {_x toFixed 2}, surfaceIsWater (getPosATL _v), isOnRoad _v, isTouchingGround _v];

// G) SINAMA: 60 m ileri yakin hedef — AI hic mi surmuyor, yoksa yalniz uzak rota mi sorunlu?
// I) SURUCU IZLEME: 14 sn boyunca 0.5 sn aralikla surucu aracta mi; cikarsa an, komut, atanmis arac, grup bayraklari, lider ve LAMBS degiskenleri loglanir (kim cikarttiysa onu bulmak icin)
[_v, _d, _et] spawn {
    params ["_v4", "_d4", "_et4"];
    private _icerdeEski = (vehicle _d4) isEqualTo _v4;
    for "_k" from 1 to 28 do {
        sleep 0.5;
        private _icerde = (vehicle _d4) isEqualTo _v4;
        if (_icerdeEski && {!_icerde}) then {
            diag_log format ["[SURME-TANI-CIKTI] %1 | surucu %2 ARACTAN CIKTI (t+%3 sn) | komut %4 | atanmis arac %5 rol %6 | lider %7 (surucu mu %8) | grup bayraklar: planAktif %9 tasimaMesgul(arac) %10 yolcuBirak(arac) %11 | birey degiskenler %12 | grup degiskenler %13 | hiz %14 km/s | SON DENEY ADIMI %15",
                _et4, name _d4, _k * 0.5, currentCommand _d4, assignedVehicle _d4, (assignedVehicleRole _d4) select 0, name leader group _d4, (leader group _d4) isEqualTo _d4, (group _d4) getVariable ["lambs_danger_planAktif", false], _v4 getVariable ["lambs_danger_tasimaMesgul", false], _v4 getVariable ["lambs_danger_yolcuBirak", false],
                (allVariables _d4) select {(toLower _x) find "lambs" >= 0}, (allVariables (group _d4)) select {(toLower _x) find "lambs" >= 0}, round speed _v4, _v4 getVariable ["lambs_danger_deneyAdim", "-"]];
        };
        _icerdeEski = _icerde;
    };
};

if (_sinama) then {[_v, _d, _et] spawn {
    params ["_v2", "_d2", "_et2"];
    private _p0 = getPosATL _v2;
    private _hedef = _v2 modelToWorld [0, 60, 0];
    _d2 enableAI "PATH"; _d2 enableAI "MOVE"; _d2 forceSpeed -1;
    _d2 doMove _hedef;
    sleep 6;
    private _git = (getPosATL _v2) distance2D _p0;
    diag_log format ["[SURME-TANI-SINAMA] %1 | 60 m ileri doMove: 6 sn'de %2 m gitti (%3) | komut %4 | hiz %5 km/s | hazir %6 basarisiz %7",
        _et2, round _git, ["AI HIC SURMUYOR (yakin hedef bile)", "yakin hedef CALISIYOR -> sorun uzak rota / yol bulma"] select (_git > 3), currentCommand _d2, round (speed _v2), unitReady _d2, moveToFailed _d2];
};};
