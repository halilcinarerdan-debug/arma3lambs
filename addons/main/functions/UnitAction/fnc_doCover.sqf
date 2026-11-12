#include "script_component.hpp"
// v8.174: main/script_component.hpp'de tanimli degilse (RPT d0839622: 3600+ "Undefined variable ELITE_COVER_*" hatasi, siper bulma tamamen calismadi) varsayilanlar; tanimliysa o gecerli
#ifndef ELITE_COVER_RANGE
#define ELITE_COVER_RANGE 30
#endif
#ifndef ELITE_COVER_MAX_RESULTS
#define ELITE_COVER_MAX_RESULTS 3
#endif
#ifndef ELITE_COVER_MIN_DIST
#define ELITE_COVER_MIN_DIST 25
#endif
#ifndef ELITE_COVER_BUILDING_POS
#define ELITE_COVER_BUILDING_POS 4
#endif
#ifndef ELITE_COVER_CACHE_TIME
#define ELITE_COVER_CACHE_TIME 2
#endif
/*
 * Author: nkenny
 * moved the unit into cover
 *
 * Arguments:
 * 0: unit doing the flight <OBJECT>
 * 1: position of cover <ARRAY>
 *
 * Return Value:
 * bool
 *
 * Example:
 * [bob] call lambs_main_fnc_doCover;
 *
 * Public: No
*/

params ["_unit", ["_pos", [], [[]]], ["_enemy", objNull, [objNull, []]]];

// stance change (one step lower)
_unit setUnitPosWeak (["DOWN", "MIDDLE"] select ((stance _unit) isEqualTo "STAND"));

// check if stopped or inside a building
if (!(_unit checkAIFeature "PATH") || {(insideBuilding _unit) >= 0.5}) exitWith {false};

// 2026-10-01 FIX: dusman bilinmeden "siper" secilirdi (agacin hangi tarafinda oldugu
// dusmanla ilgisizdi, BUSH da siper sayiliyordu). Artik dusman varsa findCover'dan
// gercek (dusmana gore golgede kalan) pozisyon alinir.
private _dusman = if (_enemy isEqualType objNull) then {
    if (isNull _enemy) then {_unit findNearestEnemy _unit} else {_enemy}
} else {
    _enemy
};
private _dusmanVar = ((_dusman isEqualType []) && {(count _dusman) >= 2}) || {(_dusman isEqualType objNull) && {!isNull _dusman}};

// Zaten gercek siperdeyse (yakinda engel + hat kapali) yerinde kal:
// marjinal kazanc icin siperi terk edip acik araziye cikma.
private _zatenKorunakli = false;
if (_dusmanVar && {_pos isEqualTo []}) then {
    private _dusmanGoz = if (_dusman isEqualType objNull) then {
        eyePos _dusman
    } else {
        AGLToASL (_dusman vectorAdd [0, 0, 1.6])
    };
    private _benimASL = (getPosASL _unit) vectorAdd [0, 0, 0.75];
    private _hatYon = vectorNormalized (_dusmanGoz vectorDiff _benimASL);
    // v8.514 SIPER TANIMI SIKILASTI (kullanici: 'su anda siper olarak saydigi yer aciklik'): eskiden askerin 5 m onunde HERHANGI bir nesne + dusman hattinin herhangi bir yerde kesilmesi yetiyordu
    //   (ince agac govdesi / cit / direk / uzaktaki nesne 'siper' sayiliyor, asker acikta kaliyordu). Simdi: engel askere <= lambs_danger_siperYakinlik (3 m; eskiden 5-6) VE govde genisligi (+-0.25 m yan isinlar)
    //   dahil dusman gozunden ucu de kapali (FIRE LOD; elektrik teli / direk sayilmaz).
    private _esikK = missionNamespace getVariable ["lambs_danger_siperYakinlik", 3];
    private _perpK = (vectorNormalized (_benimASL vectorDiff _dusmanGoz)) vectorCrossProduct [0, 0, 1];
    private _kapaliSay = 0;
    {
        private _hh = lineIntersectsSurfaces [_dusmanGoz, _benimASL vectorAdd (_perpK vectorMultiply _x), objNull, _unit, true, 1, "FIRE", "NONE"];
        if (_hh isNotEqualTo []) then {
            private _ho = (_hh select 0) select 2;
            private _ad0 = toLower ([typeOf _ho, (getModelInfo _ho) select 0] select ((typeOf _ho) isEqualTo ""));
            private _sahte = (["wire", "powerline", "powerpole", "pole", "cable", "lamp", "antenna", "pylon"] findIf {(_ad0 find _x) >= 0}) >= 0;
            if (!_sahte && {(_benimASL distance ((_hh select 0) select 0)) <= _esikK}) then { _kapaliSay = _kapaliSay + 1; };
        } else {
            if (terrainIntersectASL [_dusmanGoz, _benimASL vectorAdd (_perpK vectorMultiply _x)]) then { _kapaliSay = _kapaliSay + 1; };
        };
    } forEach [0, -0.25, 0.25];
    _zatenKorunakli = _kapaliSay isEqualTo 3;

    if (_zatenKorunakli) then {
        // ayakta da gizliyse UP, degilse MIDDLE
        private _ayakta = (getPosASL _unit) vectorAdd [0, 0, 1.45];
        _unit setUnitPosWeak (["MIDDLE", "UP"] select (
            (lineIntersects [_dusmanGoz, _ayakta, _unit]) || {terrainIntersectASL [_dusmanGoz, _ayakta]}
        ));
    };
};
if (_zatenKorunakli) exitWith {false};

// find cover
if (_pos isEqualTo []) then {
    if (_dusmanVar) then {
        // 2 sn onbellek: FSM her tick'te cagirir, her seferinde tarama yapma
        // (bos sonuc da onbelleklenir: siper yokken her FSM tick'inde tam tarama yapilmaz;
        //  onbellekte siper stance'i de tutulur ve tekrar uygulanir)
        private _onbellek = _unit getVariable [QGVAR(coverCache), [-10, [], "MIDDLE"]];
        if ((time - (_onbellek select 0)) < ELITE_COVER_CACHE_TIME) then {
            _pos = _onbellek select 1;
            if (_pos isNotEqualTo []) then { _unit setUnitPosWeak (_onbellek param [2, "MIDDLE"]); };
        } else {
            private _cStance = "MIDDLE";
            private _cover = [_unit, _dusman, 25, "ASCEND", 1] call FUNC(findCover);
            if (_cover isNotEqualTo []) then {
                _pos = (_cover select 0) select 0;
                _cStance = (_cover select 0) select 1;
                _unit setUnitPosWeak _cStance;
            };
            _unit setVariable [QGVAR(coverCache), [time, _pos, _cStance]];
        };
    };
};

// yedek: yakin agac / HIDE objesi (BUSH cikarildi - mermi durdurmaz)
if (_pos isEqualTo []) then {
    private _objeler = nearestTerrainObjects [_unit, ["TREE", "HIDE"], 6, true, true];
    _pos = if (_objeler isEqualTo []) then {
        getPosASL _unit
    } else {
        private _obj = _objeler select 0;
        if (_dusmanVar) then {
            // dusmana gore objenin ARKASI
            _obj getPos [1.2, (_dusman call CBA_fnc_getPos) getDir _obj]
        } else {
            _obj getPos [-1.2, _unit getDir _obj]
        }
    };
};

// v8.510 SIPERE ZORLA (kullanici: 'botlar ates etmekten cover alamiyor, FSM cover istediginde sipere forceleyecek sistem, raycast destegiyle'): catisma halindeki (COMBAT / baski) asker icin
//   hedef secimi 3.5 sn kapali kisa siper atilisi (raycast: siper dusmandan gizli + yol acik; dusman <= 8 m'de uygulanmaz). Uygulanamazsa asagidaki eski yuruyus davranisi.
private _zorlaYap = false;
if (_dusmanVar && {_dusman isEqualType objNull} && {((behaviour _unit) isEqualTo "COMBAT") || {(getSuppression _unit) >= 0.1}}) then {
    _zorlaYap = [_unit, _pos, _dusman, (_unit getVariable [QGVAR(coverCache), [-10, [], "MIDDLE"]]) param [2, "MIDDLE"]] call (missionNamespace getVariable ["lambs_danger_fnc_siperZorla", {false}]);
};
if (_zorlaYap) exitWith {true};

// force anim
if (_unit distance2D _pos < 0.6) exitWith {false};
private _direction = _unit getRelDir _pos;
private _anim = call {
    if (_direction > 315) exitWith {["WalkF", "WalkLF"]};
    if (_direction > 225) exitWith {["WalkL", "WalkLF"]};
    if (_direction > 135) exitWith {["WalkB"]};
    if (_direction > 45) exitWith {["WalkR", "WalkRF"]};
    ["WalkF", "WalkRF"]
};

// prevent run in place
_unit moveTo _pos;
_unit setDestination [_pos, "FORMATION PLANNED", true];

// do anim
[_unit, _anim, false] call FUNC(doGesture);       // gesture is not forced to allow cover movement to appear smoother - nkenny

// end
true
