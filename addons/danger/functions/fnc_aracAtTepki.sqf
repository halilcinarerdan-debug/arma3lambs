#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC AT ATESINE TEPKI (v8.251, tank / arac "contact drill") — kullanici: "AT atesine tepki + duman" (RPT 4cceba48: tank/BTR'ler roket-fuze/isabet aldiginda tepkisiz kaldi).
 * Kitap: ATP 3-20.15 3-81..3-98 (temasta eylemler: karsi ates, bildir, duman, korunakli konuma yer degistir), 3-108/3-109 (dolayli ates drili), 3-136 (duman); sayilar TASARIM.
 * Tetik: (1) fnc_atAtisIzle — dusman AT roketi / fuzesi / tank topu merminin yolu araca 25 m + 3% mesafe icinden geciyor (ates anindan; sebep ROKET); (2) fnc_tankAtesKontrol — tank hasari >= 0.05 artti (sebep ISABET, atici bilinen en yakin dusman).
 * Drill (arac basina 25 sn bekleme; yerel, oyuncusuz AI suruculu kara araci; TOPCU haric):
 *   1) grup COMBAT + temas isareti 15 sn; atici biliniyorsa reveal 1.5, gozcu / nisanci tehdide doWatch (15 m hata), nisanci doTarget + doFire (karsi ates)
 *   2) 1.5 sn sonra DUMAN (fnc_aracDuman; once taret tehdide donsun) — atici >= 40 m ise
 *   3) YER DEGISTIRME (nakildeki arac haric): atici gozunden ENGELLI korunakli konuma 45 / 75 / 110 m (aticidan uzaga, +-90 derece); engel yoksa en uzak aday. planZirh 20 sn dokunmaz (tankManevraT)
 *   4) YAKIN PIYADE (fnc_tankKoru): tankin yakinindaki dost piyade gruplari tehdide ates eder
 * Kapatma: lambs_danger_aracAtTepkiOff = true.  Log: [ARAC-AT-TEPKI] (ilk 60).
 *
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Atici <OBJECT> (bilinmiyorsa objNull)
 * 2: Sebep <STRING> "ROKET" | "ISABET"
 * 3: Atici konumu <ARRAY> (bos olabilir)
 *
 * Return Value: Tepki verdi mi <BOOL>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_atici", objNull, [objNull]], ["_neden", "ROKET", [""]], ["_aPoz", [], [[]]]];
if (isNull _v || {!alive _v} || {!local _v}) exitWith {false};
if (missionNamespace getVariable ["lambs_danger_aracAtTepkiOff", false]) exitWith {false};
if (!(_v isKindOf "LandVehicle") || {_v isKindOf "StaticWeapon"}) exitWith {false};
if ((time - (_v getVariable [QGVAR(atTepkiT), -999])) < 25) exitWith {false};
private _d = driver _v;
if (isNull _d || {!alive _d} || {isPlayer _d} || {(crew _v) findIf {isPlayer _x} >= 0}) exitWith {false};
private _sn = [_v] call FUNC(aracSinif);
if ((_sn select 0) isEqualTo "TOPCU") exitWith {false};
private _g = group _d;
if (!isNull _atici && {!alive _atici}) then { _atici = objNull; };
private _poz = if (!isNull _atici) then { getPosATL _atici } else { _aPoz };
_v setVariable [QGVAR(atTepkiT), time];

// 1) COMBAT + temas + karsi ates
if ((behaviour (leader _g)) in ["SAFE", "CARELESS", "AWARE", "STEALTH"]) then { _g setBehaviour "COMBAT"; };
_g setVariable [QGVAR(contact), ((time + 15) max (_g getVariable [QGVAR(contact), 0]))];
if (!isNull _atici) then { _g reveal [_atici, 1.5]; };
private _gn = gunner _v;
private _kd = commander _v;
if (_poz isNotEqualTo []) then {
    private _bak = _poz getPos [random 15, random 360];
    { if (!isNull _x && {alive _x}) then { _x doWatch _bak; }; } forEach [_gn, _kd];
};
if (!isNull _gn && {alive _gn} && {!isNull _atici} && {[_atici] call FUNC(gercekHedef)}) then { _gn doTarget _atici; _gn doFire _atici; };

// 2) duman (taret donsun diye 1.5 sn gec)
private _dumanMi = _poz isNotEqualTo [] && {(_v distance2D _poz) >= 40};
if (_dumanMi) then {
    [{ params ["_vv"]; if (!isNull _vv && {alive _vv}) then { [_vv] call FUNC(aracDuman); }; }, [_v], 1.5] call CBA_fnc_waitAndExecute;
};

// 3) yer degistirme
private _yer = [];
private _engelli = false;
if (_poz isNotEqualTo [] && {!(_v getVariable [QGVAR(tasimaMesgul), false])}) then {
    private _vp = getPosATL _v;
    private _uzak = _poz getDir _vp;
    private _aEye = if (!isNull _atici) then { eyePos _atici } else { (AGLToASL _poz) vectorAdd [0, 0, 1.8] };
    private _enS = -1e9;
    // v8.257 CAPA (RPT e31bd8bd: her AT tepkisi planZirhPoz'u yeni yer yapinca tank zincirleme 45-110 m kayip mevziden ~200 m uzaklasti): plan tankinin ilk yer degistirmedeki mevzisi capa olur, yeni yer capaya <= 150 m olmali
    private _capa = _g getVariable ["lambs_danger_planZirhCapa", []];
    if (_capa isEqualTo [] && {_g getVariable ["lambs_danger_planZirh", false]}) then {
        _capa = _g getVariable ["lambs_danger_planZirhPoz", []];
        if (_capa isNotEqualTo []) then { _g setVariable ["lambs_danger_planZirhCapa", _capa]; };
    };
    {
        private _b = _uzak + _x;
        {
            private _cand = _vp getPos [_x, _b];
            if (!surfaceIsWater _cand && {(nearestObjects [_cand, ["House"], 8]) isEqualTo []} && {_capa isEqualTo [] || {(_cand distance2D _capa) <= 150}}) then {
                private _engel = (lineIntersectsSurfaces [_aEye, (AGLToASL _cand) vectorAdd [0, 0, 1.8], _atici, _v, true, 1, "VIEW", "FIRE"]) isNotEqualTo [];
                private _s = (if (_engel) then {100} else {0}) - (_x / 6) - ((abs (_b - _uzak)) / 4) + (((_cand distance2D _poz) - (_vp distance2D _poz)) / 8);
                if (_s > _enS) then { _enS = _s; _yer = _cand; _engelli = _engel; };
            };
        } forEach [45, 75, 110];
    } forEach [0, 30, -30, 60, -60, 90, -90];
    if (_yer isNotEqualTo []) then {
        _v setVariable [QGVAR(tankManevraT), time];
        _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
        _d doMove _yer;
        // plan zirh destek tanki: yeni konum yeni ates pozisyonu olur (eskisi yedek); planZirh varisi kendisi izler, eski (acik) konuma geri gonderme olmaz
        if (_g getVariable ["lambs_danger_planZirh", false]) then {
            _g setVariable ["lambs_danger_planZirhAlt", _g getVariable ["lambs_danger_planZirhPoz", []]];
            _g setVariable ["lambs_danger_planZirhPoz", _yer];
            _g setVariable ["lambs_danger_planZirhVardi", nil];
            _g setVariable ["lambs_danger_planZirhT", time];
            _g setVariable ["lambs_danger_planZirhMax", 90];
        };
    };
};

// 4) yakin piyade
private _koru = [_v, _poz, _atici] call FUNC(tankKoru);

if (isNil "lambs_danger_atTepkiLogN") then { lambs_danger_atTepkiLogN = 0; };
if (lambs_danger_atTepkiLogN < 60) then {
    lambs_danger_atTepkiLogN = lambs_danger_atTepkiLogN + 1;
    diag_log format ["[ARAC-AT-TEPKI] %1 (%2, sinif %3) | sebep %4 | atici %5 (%6 m) | duman %7 | yer degistirme %8 (engelli %9) | hasar %10 | koruyan piyade grubu %11",
        getText (configOf _v >> "displayName"), groupId _g, _sn select 0, _neden, if (isNull _atici) then {"bilinmiyor"} else {typeOf _atici},
        if (_poz isEqualTo []) then {"?"} else {round (_v distance2D _poz)}, _dumanMi,
        if (_yer isEqualTo []) then {"yok"} else {format ["%1 m -> %2", round (_v distance2D _yer), mapGridPosition _yer]}, _engelli, (damage _v) toFixed 2, _koru];
};
true
