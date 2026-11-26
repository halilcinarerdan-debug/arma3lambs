#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DOST ATES HATTI (v8.825; kullanici: 'adamlar kendi askerlerinin oldugu yere supress atiyorlar, ozellikle squad icindeki MG atiyor ya da squadlar arasi'): bastirma atesinin HATTINDA ya da hedef noktasinin cevresinde DOST var mi.
 * NEDEN: fnc_atesHatiAcik duvar / bina / arazi hatti kontrol ediyor ama INSAN vurusunu sayilmiyor (v8.372: 'insan vurusu sayilmaz': hedef ya da yan asker hattan sayilmasin diye); dost kontrolu yalniz RPG / UGL (fnc_atisGuvenli) ve fnc_hedefSiper'deydi.
 *   MG / tufek bastirma atesi (atesHareket taban atesi, mgDestek, hqDestek, hucum hazirligi, pusu tepkisi, tank koru ...) hattaki dosta mermi yagdirabiliyordu.
 * KURAL: atici ile hedef noktasi arasindaki 2B hat boyunca, atici ONUNDEKI 6 m'den baslayip hedefin 25 m ARKASINA kadar (mermi hedefi gecer), hatta yanal mesafe < 3 + 0.012 x mesafe m (en cok 9 m) olan her DOST (ayni takim, canli; bilinc kaybi dahil; oyuncu dahil) hatti KAPATIR;
 *   ayrica hedef noktasinin 12 m yaricapinda dost varsa kapatir. Aticiya 6 m'den yakin yan asker sayilmaz (yan yana duran takim arkadasi). Tum gruplar (squad ici + squadlar arasi).
 * Arguments: 0: Atici <OBJECT> | 1: Hedef <OBJECT | ARRAY (AGL / ASL fark etmez 2B)>
 * Return Value: Hatta dost var mi (true = ATMA) <BOOL>
 * CBA: lambs_danger_dostHatti (varsayilan acik). Log: [DOST-HATTI] (ilk 20, sonra 30 sn'de bir) + sayac.
 * Public: No
*/
params [["_u", objNull, [objNull]], ["_hedef", objNull, [objNull, []]]];
if (isNull _u || {!(missionNamespace getVariable ["lambs_danger_dostHatti", true])}) exitWith {false};
private _b = if (_hedef isEqualType objNull) then { if (isNull _hedef) then { [] } else { getPosASL _hedef } } else { if ((count _hedef) < 2) then { [] } else { +_hedef } };
if (_b isEqualTo []) exitWith {false};
private _a = getPosASL _u;
private _d = _a distance2D _b;
if (_d < 8) exitWith {false};
private _dx = ((_b select 0) - (_a select 0)) / _d;
private _dy = ((_b select 1) - (_a select 1)) / _d;
private _taraf = side group _u;
private _bulan = objNull;
private _neden = "";
{
    if (alive _x && {_x isNotEqualTo _u} && {(_taraf getFriend (side group _x)) >= 0.6} && {(side group _x) isNotEqualTo civilian}) then {
        private _p = getPosASL _x;
        private _rx = (_p select 0) - (_a select 0);
        private _ry = (_p select 1) - (_a select 1);
        private _t = (_rx * _dx) + (_ry * _dy);
        private _yan = abs ((_rx * _dy) - (_ry * _dx));
        private _enGen = (3 + (0.012 * (_t min 500))) min 9;
        if (_t >= 6 && {_t <= (_d + 25)} && {_yan < _enGen}) exitWith { _bulan = _x; _neden = format ["hatta (%1 m ileride, yanal %2 m)", round _t, (_yan toFixed 1)]; };
        if ((_p distance2D _b) < 12) exitWith { _bulan = _x; _neden = format ["hedef noktasina %1 m", round (_p distance2D _b)]; };
    };
} forEach ((_a nearEntities ["CAManBase", _d + 40]) + (if (_hedef isEqualType objNull) then { [] } else { [] }));
if (isNull _bulan) exitWith {false};
private _s = missionNamespace getVariable ["lambs_danger_dostHattiSay", createHashMap];
missionNamespace setVariable ["lambs_danger_dostHattiSay", _s];
private _k = ["ayni grup", "baska grup"] select ((group _bulan) isNotEqualTo (group _u));
_s set [_k, (_s getOrDefault [_k, 0]) + 1];
if (["dostHatti", 20, 30] call FUNC(logIzin)) then {
    diag_log format ["[DOST-HATTI] %1 | %2 | atici %3 (%4) | hedefe %5 m | dost %6 (%7) %8 -> bastirma atesi ENGELLENDI", groupId (group _u), _k, name _u, [_u] call { params ["_x"]; getText (configFile >> "CfgVehicles" >> (typeOf _x) >> "displayName") }, round _d, name _bulan, groupId (group _bulan), _neden];
};
true
