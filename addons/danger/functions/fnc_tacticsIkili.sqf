#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IKILI SICRAMA (KUCUK EKIP / BUDDY BOUNDING; v8.817; kullanici: 'hepsini yapalim'; yol haritasi Asama 15 / 4): komutan beyni ve bounding >= 4 kisilik gruplar icin; 2-3 kisilik gruplar (ates timi / kalan manga) temas kesme tetigi
 * (tek kalan / kayip >= %50 / baski >= 0.7) yoksa 'LAMBS'in duz akisi'na (catismaya devam) dusuyordu. Doktrin ilkesi (ATP 3-21.8 / MCWP 3-11.2: ates timi ikili sicrama; biri gozetler digeri siperden siperye ilerler; ayrintili sayilar kaynakta YOK = TASARIM):
 *   TETIK: 2-3 saglam piyade, oyuncusuz, temas var, bilinen dusman 60-350 m ve en cok (kendi sayimiz) kadar GORULEN dusman, kayip < %50, ortalama baski < 0.5, retreat / evade / temas kes / taktik YOK, bina disi.
 *   SIRA: her sicramada baska asker (sira artar); diger(ler)i gozetler (taktik kilidi, kendi AI'lari acik = karsilik verir). Sicrama noktasi: findCover 'ADVANCE' (35 m) adaylarindan 8-35 m uzakta, dusmana >= 45 m ve MEVCUT mesafeden >= 5 m yakin
 *   (ileri), yol taramasi (fnc_yolTara) erisilebilir. Kosucu forceMove + AUTOCOMBAT / COVER kapali; vardiginda ya da 12 sn sonra bayraklar geri, siper durusu, dusmana bakis. Sonraki sicrama 6-9 sn sonra (gozetleme suresi).
 *   Aday yoksa false doner (eski akis). CBA lambs_danger_ikiliSicrama (varsayilan acik). Log: [IKILI-SICRAMA] (ilk 20, sonra 30 sn'de bir).
 * Arguments: 0: Grup <GROUP|OBJECT> | 1: Hedef <OBJECT|ARRAY>
 * Return Value: Kontrol bu fonksiyonda mi (sicrama baslatildi ya da gozetleme suresi) <BOOL>
 * Public: No
*/

params [["_group", grpNull, [grpNull, objNull]], ["_target", objNull, [objNull, []]]];
if (_group isEqualType objNull) then { _group = group _group; };
if (isNull _group || {!(missionNamespace getVariable ["lambs_danger_ikiliSicrama", true])}) exitWith {false};
private _us = (units _group) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable ["ACE_isUnconscious", false])}};
private _n = count _us;
if (_n < 2 || {_n > 3}) exitWith {false};
if (((units _group) findIf { isPlayer _x }) >= 0) exitWith {false};
if ((_group getVariable [QGVAR(isRetreating), false]) || {_group getVariable [QGVAR(isEvading), false]} || {_group getVariable [QGVAR(isBreakingContact), false]} || {_group getVariable [QGVAR(isATEngage), false]}
    || {_group getVariable [QGVAR(isExecutingTactic), false]} || {_group getVariable [QGVAR(isSweeping), false]} || {_group getVariable [QGVAR(isAmbushing), false]} || {_group getVariable [QGVAR(isBounding), false]}) exitWith {false};
private _l = leader _group;
if (isNull _l || {!alive _l} || {(insideBuilding _l) > 0.5}) exitWith {false};
private _tp = if (_target isEqualType objNull) then { if (isNull _target) then { [] } else { getPosATL _target } } else { _target };
if ((count _tp) < 2) exitWith {false};
private _d = _l distance2D _tp;
if (_d < 60 || {_d > 350}) exitWith {false};
private _ilk = _group getVariable [QGVAR(cmdInitialCount), -1];
if !(_ilk isEqualType 0) then { _ilk = -1; };
if (_ilk > 0 && {((_ilk - _n) / _ilk) >= 0.5}) exitWith {false};
private _bsk = 0;
{ _bsk = _bsk + (getSuppression _x); } forEach _us;
if ((_bsk / _n) >= 0.5) exitWith {false};
private _gor = (_l targets [true, 400, [], 30]) select { alive _x && {((side _group) getFriend (side group _x)) < 0.6} && {(side group _x) isNotEqualTo civilian} };
if ((count _gor) > _n) exitWith {false};   // kendi sayimizdan fazla gorulen dusman: temas kesme / LAMBS akisi
if (time < (_group getVariable [QGVAR(ikiliT), 0])) exitWith {true};   // gozetleme suresi: kontrol bizde (LAMBS tacticsAssess calismaz)

private _sira = _group getVariable [QGVAR(ikiliSira), 0];
private _mover = _us select (_sira mod _n);
if ((_mover getVariable [QGVAR(forceMove), false]) isEqualTo true || {time < (_mover getVariable [QGVAR(tcccBusy), 0])}) exitWith {false};
private _kv = [_mover, _tp, 35, "ASCEND", 4, "ADVANCE"] call EFUNC(main,findCover);
private _hedef = [];
private _durus = "MIDDLE";
{
    private _cp = _x select 0;
    if (_cp isEqualType [] && {(count _cp) >= 2}) then {
        private _dm = _mover distance2D _cp;
        private _de = _cp distance2D _tp;
        if (_dm >= 8 && {_dm <= 35} && {_de >= 45} && {_de <= (_d - 5)} && {!(surfaceIsWater _cp)} && {([_mover, _cp, 0] call FUNC(yolTara)) select 0}) exitWith {
            _hedef = _cp;
            _durus = _x select 1;
        };
    };
} forEach _kv;
private _say = missionNamespace getVariable ["lambs_danger_ikiliSay", createHashMap];
missionNamespace setVariable ["lambs_danger_ikiliSay", _say];
if (_hedef isEqualTo []) exitWith {
    _say set ["aday_yok", (_say getOrDefault ["aday_yok", 0]) + 1];
    _group setVariable [QGVAR(ikiliT), time + 5];
    false
};
_group setVariable [QGVAR(ikiliSira), _sira + 1];
_group setVariable [QGVAR(ikiliT), time + 14 + (random 3)];   // sicrama suresi (<= 12 sn) + gozetleme
_mover setVariable [QGVAR(forceMove), true];
_mover setVariable [QGVAR(taktikKilit), time + 12];
{ _x setVariable [QGVAR(taktikKilit), time + 8]; _x doWatch (_tp vectorAdd [0, 0, 1.2]); } forEach (_us select { _x isNotEqualTo _mover });
_mover disableAI "AUTOCOMBAT";
_mover disableAI "COVER";
_mover enableAI "PATH";
_mover enableAI "MOVE";
_mover setUnitPosWeak "UP";
_mover forceSpeed -1;
_mover setSpeedMode "FULL";
_mover doMove _hedef;
private _bit = {
    params ["_m", "_p", "_st", "_et"];
    if (alive _m) then {
        _m setVariable [QGVAR(forceMove), nil];
        _m enableAI "AUTOCOMBAT";
        _m enableAI "COVER";
        _m setUnitPosWeak _st;
        _m doWatch (_et vectorAdd [0, 0, 1.2]);
    };
};
[{ params ["_m", "_p"]; !alive _m || {(_m distance2D _p) < 3.5} }, _bit, [_mover, _hedef, _durus, _tp], 12, _bit] call CBA_fnc_waitUntilAndExecute;
_say set ["sicrama", (_say getOrDefault ["sicrama", 0]) + 1];
if (["ikiliSicrama", 20, 30] call FUNC(logIzin)) then {
    diag_log format ["[IKILI-SICRAMA] %1 | %2 kisi | sicrama: %3 (sira %4) %5 m ileri, dusmana %6 m -> %7 m | gozetleyen %8 | gorulen dusman %9 | durus %10", groupId _group, _n, name _mover, _sira, round (_mover distance2D _hedef), round _d, round (_hedef distance2D _tp), (_us select { _x isNotEqualTo _mover }) apply { name _x }, count _gor, _durus];
};
true
