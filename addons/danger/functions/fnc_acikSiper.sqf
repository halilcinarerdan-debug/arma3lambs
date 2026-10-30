#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ACIKTA KALAN ASKERI NESNE ARKASINA / BINAYA SOK (v8.303 bina; v8.305 agac / kaya / duvar arkasi; kullanici: 'arkada ev var adam acikta kaliyor ama evi siper olarak kullanmiyor').
 * Cagiran: fnc_coverHug — temasta, duran, acikta (3 yukseklikte dusmandan sert yuzey yok ya da 6 m'den uzak) asker icin.
 *   1) 28 m icindeki girilebilir binalarin (buildingPos) noktalari taranir
 *   2) aday: dusmanin gozunden o noktaya hat bina tarafindan KESILIYOR (lineIntersects) + dusmana 8 m'den fazla yaklasmaz + baska askere ayrilmis degil (1.8 m, 30 sn)
 *   3) en yakin aday: doMove, FULL hiz, 15 sn taktik kilidi (diger hareket arbitrajlari ezmesin); asker basina 25 sn'de bir
 * ATLANIR: bounding / taktik yurutenler (hucumda ilerlemek bilincli), CBA kapatma: lambs_danger_acikSiperOff = true
 * v8.354: bina kolu ATIS POZISYONU tercih eder (dusmana pencere hatti acik, ust ortulu); pasif gizlenme yalniz son care. Log: [ACIK-SIPER]
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: En yakin bilinen dusman <OBJECT>
 *
 * Return Value: Yonlendirildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_en", objNull, [objNull]]];
if (isNull _u || {isNull _en} || {missionNamespace getVariable ["lambs_danger_acikSiperOff", false]}) exitWith {false};
if (captive _u || {_u getVariable [QGVAR(teslim), false]}) exitWith {false};   // v8.352: teslim olan / esir asker nesne arkasina gonderilmez (STOP -> MOVE salinimi)
if (time < (_u getVariable [QGVAR(acikSiperT), 0])) exitWith {false};
// v8.312: tekrar 25 -> 10 sn (CBA lambs_danger_siperHizli), nesne arama yaricapi CBA lambs_danger_siperYaricap (varsayilan 22 m; eskiden 14), bina _yar + 10 m (eskiden 28)
private _hizli = missionNamespace getVariable ["lambs_danger_siperHizli", true];
private _yar = missionNamespace getVariable ["lambs_danger_siperYaricap", 22];
_u setVariable [QGVAR(acikSiperT), time + ([25, 10] select _hizli)];
private _g = group _u;
if ((_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isRetreating), false]}) exitWith {false};

private _p = getPosATL _u;
private _eASL = eyePos _en;
private _ed = _u distance2D _en;
private _dolu = missionNamespace getVariable ["lambs_danger_acikSiperDolu", []];
_dolu = _dolu select {(time - (_x select 1)) < 30};

// v8.305 NESNENIN ARKASINA GEC (kullanici: 'siper cok guzel seciyor ama sadece yaklasiyor, siperin yanindaysa guvende saniyor, agac varsa sadece agacin yanindan gecip gidiyor'):
//   14 m icindeki sert nesneler (agac / kaya / duvar, yukseklik >= 0.7 m): dusmandan nesneye dogru yonde nesnenin 0.55 m ARKASI hesaplanir; dusmanin gozunden o noktaya (1.5 / 1.0 / 0.4 m) hat nesne
//   tarafindan kesiliyorsa aday (en yuksek korunan durus: UP > MIDDLE > DOWN); skor = mesafe + durus cezasi (0 / 2 / 5); dusmana 10 m'den fazla yaklasmaz.
private _obj = [];
private _objS = 1e9;
private _objDurus = "";
private _objAd = "";
{
    private _o = _x;
    private _op = getPosATL _o;
    private _bb = boundingBoxReal _o;
    private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
    if (_yk >= 0.7 && {(_u distance2D _op) <= _yar}) then {
        private _r = (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2.5;
        private _pos = _op getPos [_r + 0.55, _en getDir _o];
        if (!surfaceIsWater _pos && {(_pos distance2D _en) >= (_ed - 10)} && {(_dolu findIf {((_x select 0) distance2D _pos) < 1.5}) < 0}) then {
            private _gASL = ATLToASL [_pos select 0, _pos select 1, 0];
            private _bl = [1.5, 1.0, 0.4] apply { (lineIntersectsSurfaces [_eASL, _gASL vectorAdd [0, 0, _x], _en, _u, true, 1, "FIRE", "NONE"]) isNotEqualTo [] };
            private _ds = if (_bl select 0) then {["UP", 0]} else { if (_bl select 1) then {["MIDDLE", 2]} else { if (_bl select 2) then {["DOWN", 5]} else {["", 99]} } };
            if ((_ds select 0) isNotEqualTo "") then {
                private _sk = (_u distance2D _pos) + (_ds select 1);
                if (_sk < _objS) then { _objS = _sk; _obj = _pos; _objDurus = _ds select 0; _objAd = typeOf _o; if (_objAd isEqualTo "") then { _objAd = (getModelInfo _o) select 0; }; };
            };
        };
    };
} forEach (nearestTerrainObjects [_p, ["TREE", "SMALL TREE", "ROCK", "ROCKS", "WALL", "HIDE"], _yar, false, true]);

if (_obj isNotEqualTo []) exitWith {
    _dolu pushBack [_obj, time];
    missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
    _u setVariable [QGVAR(taktikKilit), time + 15];
    _u forceSpeed -1;
    _u setSpeedMode "FULL";
    _u doMove _obj;
    _u setUnitPos "UP";
    [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.5} }, { params ["_uu", "_hp", "_ds"]; if (alive _uu) then { _uu setUnitPos _ds; }; }, [_u, _obj, _objDurus], 12, { params ["_uu", "_hp", "_ds"]; if (alive _uu) then { _uu setUnitPos _ds; }; }] call CBA_fnc_waitUntilAndExecute;
    [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; }; }, [_u], 25] call CBA_fnc_waitAndExecute;
    if ((missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) < 40) then {
        missionNamespace setVariable ["lambs_danger_acikSiperLogN", (missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) + 1];
        diag_log format ["[ACIK-SIPER] %1 | %2 | dusman %3 m acikta -> NESNE ARKASI %4 (%5 m, durus %6, dusmandan gizli)", groupId _g, name _u, round _ed, _objAd, round (_u distance2D _obj), _objDurus];
    };
    true
};

private _en_iyi = [];
private _enS = 1e9;
private _binaAd = "";
private _atisVar = false;
private _durusB = "AUTO";
// v8.354 BINAYI AKTIF KULLAN (kullanici: 'binalari aktif kullansinlar'; RPT 30-10: ACIK-SIPER bina kolu yalniz dusmandan GIZLI nokta seciyor -> asker binaya girip dusmani goremeyen, ates edemeyen 'pasif' noktada bekliyordu):
//   ATIS POZISYONU = dusman gozunden askerin ayakta (1.5 m) ya da comelmis (1.0 m) goz hizasina hat ACIK (pencere / kapi) ama ust ortulu (ic mekan); 5 yanal ornekten (+-0.8 m) hepsi aciksa (tamamen acik yapi) +8 ceza;
//   ust ortu yoksa +15; AT +12 (geri tepme: bina ici); keskin nisanci ust katta -6; kat farki x1.5; dusmani goremeyen gizli nokta yalniz SON CARE (+30). Kat sinirli: |dz| < 4 m (ulasilamaz ust kat yok).
//   Kapatma: lambs_danger_cqbV2 = false (eski: yalniz gizli nokta, en yakin).
private _cqbV2 = missionNamespace getVariable ["lambs_danger_cqbV2", true];
private _rolB = if (_cqbV2) then { [_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}]) } else { "RIFLE" };
private _uZ = (getPosATL _u) select 2;
private _edir = _p getDir _en;
{
    private _b = _x;
    {
        private _bp = _x;
        private _d = _u distance2D _bp;
        if (_d <= (_yar + 10) && {(_bp distance2D _en) >= (_ed - 8)} && {(_dolu findIf {((_x select 0) distance2D _bp) < 1.8}) < 0}) then {
            private _bA = AGLToASL _bp;
            if (!_cqbV2) then {
                if (_d < _enS && {lineIntersects [_eASL, _bA vectorAdd [0, 0, 1.3], _en, _u]}) then { _enS = _d; _en_iyi = _bp; _binaAd = typeOf _b; _atisVar = false; };
            } else {
                if ((abs ((_bp select 2) - _uZ)) < 4) then {
                    private _gUp = (lineIntersects [_eASL, _bA vectorAdd [0, 0, 1.5], _en, _u]) || {terrainIntersectASL [_eASL, _bA vectorAdd [0, 0, 1.5]]};
                    private _gMid = (lineIntersects [_eASL, _bA vectorAdd [0, 0, 1.0], _en, _u]) || {terrainIntersectASL [_eASL, _bA vectorAdd [0, 0, 1.0]]};
                    private _atis = !_gUp || {!_gMid};
                    private _sk = _d;
                    private _durus = "AUTO";
                    if (_atis) then {
                        _durus = ["MIDDLE", "UP"] select (!_gUp);
                        private _perp = [cos _edir, -(sin _edir), 0];
                        private _acik = 0;
                        {
                            private _yp = (_bA vectorAdd [0, 0, 1.4]) vectorAdd (_perp vectorMultiply _x);
                            if (!((lineIntersects [_eASL, _yp, _en, _u]) || {terrainIntersectASL [_eASL, _yp]})) then { _acik = _acik + 1; };
                        } forEach [-0.8, -0.4, 0, 0.4, 0.8];
                        if (_acik >= 5) then { _sk = _sk + 8; };
                    } else {
                        _sk = _sk + 30;
                    };
                    if !(lineIntersects [_bA vectorAdd [0, 0, 1.6], _bA vectorAdd [0, 0, 25], _u]) then { _sk = _sk + 15; };
                    switch (_rolB) do {
                        case "AT": { _sk = _sk + 12; };
                        case "MARKSMAN": { if (((_bp select 2) - _uZ) > 2.2) then { _sk = _sk - 6; }; };
                        default {};
                    };
                    _sk = _sk + ((abs ((_bp select 2) - _uZ)) * 1.5);
                    if (_sk < _enS) then { _enS = _sk; _en_iyi = _bp; _binaAd = typeOf _b; _atisVar = _atis; _durusB = _durus; };
                };
            };
        };
    } forEach (_b buildingPos -1);
} forEach ((nearestObjects [_p, ["House"], _yar + 12]) select {(count (_x buildingPos -1)) > 0});

if (_en_iyi isEqualTo []) exitWith {false};

_dolu pushBack [_en_iyi, time];
missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
_u setVariable [QGVAR(taktikKilit), time + 15];
_u forceSpeed -1;
_u setSpeedMode "FULL";
_u setUnitPos "AUTO";
_u doMove _en_iyi;
// v8.354: atis pozisyonuna varinca durus + dusmana bak (pasif beklemesin); 45 sn sonra serbest
if (_atisVar) then {
    [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.5} }, { params ["_uu", "_hp", "_ds", "_e"]; if (alive _uu) then { _uu setUnitPos _ds; if (!isNull _e && {alive _e}) then { _uu doWatch _e; }; }; }, [_u, _en_iyi, _durusB, _en], 14, {}] call CBA_fnc_waitUntilAndExecute;
    [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; _uu doWatch objNull; }; }, [_u], 45] call CBA_fnc_waitAndExecute;
};
if ((missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) < 40) then {
    missionNamespace setVariable ["lambs_danger_acikSiperLogN", (missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) + 1];
    diag_log format ["[ACIK-SIPER] %1 | %2 | dusman %3 m acikta -> bina %4 (%5 m, %6, skor %7)", groupId _g, name _u, round _ed, _binaAd, round (_u distance2D _en_iyi), if (_atisVar) then {format ["ATIS POZISYONU: dusman gorunuyor, durus %1", _durusB]} else {"pasif gizlenme (atis pozisyonu yok)"}, round _enS];
};
true
