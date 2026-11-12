#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * UGL ATIS POZISYONU (v8.508; kullanici: 'ugl kullanimini boostla, botlar siperden cok uzak duruyor, etraftaki engeller ozellikle ormanlik alanda ugl'leri felc ediyor').
 * UGL'li asker namlu onunde engel (dal / cali / agac / duvar) yuzunden atamayinca (fnc_atisGuvenli 'onunde cali/dal/engel') eskiden atis o tick'te bos gidiyordu; orman / sik arazide bu surekli tekrarlayip UGL'i felc ediyordu.
 * Bu fonksiyon askerin 10 m cevresinde, hedefe giden namlu seridi (2.5 m) TEMIZ bir atis noktasi arar; SIPER / engel kenari (3 m'de agac / duvar / kaya / bina) tercih edilir, kisa yurume tercih edilir.
 * Adaylar: hedef dogrultusuna dik +-3 / 6 / 9 m, hedefe 3 / 6 m ileri (hedefe >= 32 m kalmali), 4 m geri. Cagiran (fnc_tacticalUGL) askeri oraya gonderir, varinca atar.
 *
 * Arguments:
 * 0: Atici <OBJECT>
 * 1: Hedef <OBJECT>
 *
 * Return Value: Atis noktasi (AGL) ya da [] <ARRAY>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_t", objNull, [objNull]]];
if (isNull _u || {isNull _t}) exitWith {[]};
private _tPos = getPosATL _t;
private _uPos = getPosATL _u;
private _dir = _uPos getDir _tPos;
private _dT = _uPos distance2D _tPos;

private _adaylar = [];
{ _adaylar pushBack [_dir + 90, _x]; _adaylar pushBack [_dir - 90, _x]; } forEach [3, 6, 9];
{ _adaylar pushBack [_dir, _x]; } forEach [3, 6];
_adaylar pushBack [_dir + 180, 4];

private _en = [];
private _enP = -999;
{
    _x params ["_yon", "_mes"];
    private _p = _uPos getPos [_mes, _yon];
    _p set [2, 0];
    if (!surfaceIsWater _p && {(_p distance2D _tPos) >= 32} && {(_p distance2D _tPos) <= 340}) then {
        private _pASL = AGLToASL (_p vectorAdd [0, 0, 1.4]);
        private _hd = _p getDir _tPos;
        private _son = AGLToASL (_p getPos [2.5, _hd]);
        _son set [2, (_pASL select 2) + 0.4];
        // namlu seridi temiz mi (UGL icin atisGuvenli ile ayni test: 2.5 m, gogus yuksekligi)
        private _temiz = !(terrainIntersectASL [_pASL, _son]) && {(lineIntersectsSurfaces [_pASL, _son, _u, objNull, true, 1, "FIRE", "FIRE"]) isEqualTo []};
        // hedefe yaklasik gorus acisi (ust eger olsa da ilk 12 m acik olmali)
        private _son2 = AGLToASL (_p getPos [12, _hd]);
        _son2 set [2, (_pASL select 2) + 1.0];
        private _acik12 = !(terrainIntersectASL [_pASL, _son2]) && {(lineIntersectsSurfaces [_pASL, _son2, _u, objNull, true, 1, "FIRE", "FIRE"]) isEqualTo []};
        if (_temiz && {_acik12}) then {
            private _siper = ((nearestTerrainObjects [_p, ["TREE", "WALL", "ROCK", "BUILDING", "HOUSE", "FENCE", "BUSH"], 3, false, true]) isNotEqualTo []);
            private _puan = (10 * ([0, 1] select _siper)) - _mes;   // siper kenari tercih, kisa yurume tercih
            if (_puan > _enP) then { _enP = _puan; _en = _p; };
        };
    };
} forEach _adaylar;
_en
