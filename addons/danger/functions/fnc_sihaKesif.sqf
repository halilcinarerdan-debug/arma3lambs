#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIHA / IHA KESIF SORTISI (v8.344; kullanici: 'bayraktar gibi siha iha sistemini ekleyelim, once etrafi gozetlesinler, yollari, dusman nereden geliyor cikarim yapabilsinler, patrol atsinlar, bunu objektifi yoneten sistem yapsin; ileride lazer isaretlemede kullanilabilsin').
 * Objektif plani (fnc_komutanPlan) kurulunca cagrilir (CBA 'sihaAktif'). Tarafin UCUYOR (ya da helikopter / VTOL) AI kesif IHA'si / SIHA'si varsa (silahli olsa da ATES ETMEZ: BLUE + AUTOTARGET kapali) alinir;
 * ucak tipi yerdeki dron kalkis yapamaz, o yuzden yalniz havada olanlar / helikopter-quad tipler secilir. Bulunmazsa [SIHA-KESIF] logu ile sessizce biter.
 *   FAZ 1 CEVRE: objektif cevresinde 1200 m halkada 8 nokta (45'er derece) gezi; her noktada gorus (fnc_ihaGozlem 'ihaGorulen', fnc_ihaGorus katsayili) kaydedilir.
 *   FAZ 2 YOLLAR: objektiften 1500-2500 m'de her 45 derece yonde en yakin YOL aranir (nearRoads); bulunan yollar uzaktan objektife dogru taranir (yaklasma yollari = dusmanin gelececi yollar).
 *   CIKARIM: her gorus 45 derecelik sektore yazilir (adam 1, arac 3, zirh 4; son gorulme agirligi); en yuksek sektor ikinciden >= 1.5 kat ve puan >= 4 ise TEHDIT YONU = o sektorun agirlikli ortalama yonu.
 *     Sonuc plana yazilir (plan['tehditB'], plan['sihaTehdit'] = [yon, puan, zaman]) ve 'lambs_danger_sihaTehdit_<taraf>'; savunma planinda yon biliniyorsa lider hakim noktasi (fnc_foHakim) bu yonu kullanir.
 *   FAZ 3 PATROL: ~25 dk'ya kadar tehdit ekseninde (1000-2500 m, +-20 derece) ve cevre halkasinda dönüşümlü gezi; 90 sn'de bir cikarim guncellenir. Plan biterse ya da dron olurse biter; sonra kalkis noktasina doner.
 * LAZER HOOK: fnc_sihaLazer (hedef isaretleme: LaserTarget nesnesi) ileride lazer güdümlü mermi / bomba icin; bu surumde otomatik cagrilmaz.
 * Mod uyumu: vanilla UAV (Darter, Falcon, Ababil...), RHS / CUP UAV'leri unitIsUAV + Air sinifi ile bulunur (sinif adi gerekmez). FPV / bomba tipleri (fnc_ihaTip) alinmaz.
 * Kapatma: CBA sihaAktif / lambs_danger_sihaOff = true. Log: [SIHA-KESIF].
 *
 * Arguments:
 * 0: Plan <HASHMAP>
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!canSuspend) exitWith { _this spawn FUNC(sihaKesif); true };

params [["_plan", createHashMap, [createHashMap]]];
if (!(missionNamespace getVariable ["lambs_danger_sihaAktif", true]) || {missionNamespace getVariable ["lambs_danger_sihaOff", false]} || {count _plan isEqualTo 0}) exitWith {false};
private _taraf = _plan get "taraf";
private _obj = _plan get "obj";
private _id = _plan getOrDefault ["id", "?"];
private _tarafNo = [east, west, independent, civilian] find _taraf;

sleep 8;
private _adaylar = vehicles select {
    unitIsUAV _x && {alive _x} && {_x isKindOf "Air"} && {(([_x] call FUNC(ihaTip)) isEqualTo "GOZLEM") || {(_x getVariable [QGVAR(ihaGorevTur), ""]) isEqualTo "GOZLEM"}}
    && {private _tk = _x getVariable [QGVAR(ihaTok), -1]; _tk < 0 || {(diag_tickTime - _tk) > 1800}}
    && {((getPosATL _x) select 2) > 30 || {_x isKindOf "Helicopter"}}
    && {(_x distance2D _obj) < 9000}
    && {
        private _mur = (crew _x) select {alive _x};
        if (_mur isEqualTo []) then { (getNumber (configOf _x >> "side")) isEqualTo _tarafNo } else { (side (group (_mur select 0))) isEqualTo _taraf }
    }
};
if (_adaylar isEqualTo []) exitWith {
    diag_log format ["[SIHA-KESIF] %1 | %2 | kesif IHA / SIHA bulunamadi (ucuyor / helikopter tipi, GOZLEM turu, 9 km icinde, serbest) - sortie yok", _id, _taraf];
    false
};
private _uav = ([_adaylar, [], {_x distance2D _obj}, "ASCEND"] call BIS_fnc_sortBy) select 0;
if (!local _uav) then { _uav setOwner 2; private _w = time + 6; waitUntil { sleep 0.2; local _uav || {time > _w} }; };
if (!local _uav) exitWith { diag_log format ["[SIHA-KESIF] %1 | %2 sunucuda yerel degil", _id, typeOf _uav]; false };

private _tok = diag_tickTime;
_uav setVariable [QGVAR(ihaTok), _tok];
_uav setVariable [QGVAR(ihaGorevTur), "GOZLEM"];
if (isNull (driver _uav)) then { createVehicleCrew _uav; };
private _d = driver _uav;
if (isNull _d) exitWith { diag_log format ["[SIHA-KESIF] %1 | %2 murettebat olusmadi", _id, typeOf _uav]; false };
(group _d) setBehaviour "CARELESS";
(group _d) setCombatMode "BLUE";
(group _d) setSpeedMode "NORMAL";
{ _d disableAI _x; } forEach ["AUTOTARGET", "TARGET"];
{ _x disableAI "AUTOTARGET"; _x disableAI "TARGET"; } forEach ((crew _uav) select {alive _x});
private _yuks = [300, 150] select (_uav isKindOf "Helicopter");
_uav flyInHeight _yuks;
private _bas = getPosATL _uav;
private _t0 = time;
diag_log format ["[SIHA-KESIF] %1 | %2 | %3 (%4) kesif sortisine alindi | objektif %5 (%6 m) | irtifa %7 m", _id, _taraf, typeOf _uav, getText (configOf _uav >> "displayName"), mapGridPosition _obj, round (_uav distance2D _obj), _yuks];

private _aktif = {
    alive _uav && {alive _d} && {(_uav getVariable [QGVAR(ihaTok), -1]) isEqualTo _tok} && {(time - _t0) < 1500}
    && {!((_plan getOrDefault ["faz", ""]) in ["BITTI", "IPTAL", "DONUS", "CEKILME"])}
};

// ---- gorus kaydi: sektor puanlari (8 x 45 derece) ----
private _sek = [0, 0, 0, 0, 0, 0, 0, 0];
private _bSin = [0, 0, 0, 0, 0, 0, 0, 0];
private _bCos = [0, 0, 0, 0, 0, 0, 0, 0];
private _gorulen = [];   // [netId] daha once sayilan nesneler (yeniden sayim 90 sn)
private _kaydet = {
    private _gk = _uav getVariable ["lambs_danger_ihaGorulen", [-99, []]];
    if ((time - (_gk select 0)) < 12) then {
        {
            private _o = _x;
            if (alive _o && {(_o distance2D _obj) > 150}) then {
                private _kayit = _gorulen findIf {(_x select 0) isEqualTo _o && {(time - (_x select 1)) < 90}};
                if (_kayit < 0) then {
                    _gorulen = _gorulen select {(time - (_x select 1)) < 600};
                    _gorulen pushBack [_o, time];
                    private _w = if (_o isKindOf "CAManBase") then {1} else { if (_o isKindOf "Tank") then {4} else {3} };
                    private _b = _obj getDir _o;
                    private _i = (round (_b / 45)) mod 8;
                    _sek set [_i, (_sek select _i) + _w];
                    _bSin set [_i, (_bSin select _i) + (sin _b) * _w];
                    _bCos set [_i, (_bCos select _i) + (cos _b) * _w];
                };
            };
        } forEach (_gk select 1);
    };
};
private _cikarim = {
    private _en = 0; private _ens = -1; private _ik = 0;
    { if (_x > _ens) then { _ik = _ens max 0; _ens = _x; _en = _forEachIndex; } else { if (_x > _ik) then { _ik = _x; }; }; } forEach _sek;
    if (_ens >= 4 && {_ens >= (1.5 * (_ik max 1))}) then {
        private _brg = ((_bSin select _en) atan2 (_bCos select _en));
        if (_brg < 0) then { _brg = _brg + 360; };
        private _eskiB = _plan getOrDefault ["sihaTehdit", [-1]];
        _plan set ["sihaTehdit", [_brg, _ens, time]];
        missionNamespace setVariable [format ["lambs_danger_sihaTehdit_%1", _taraf], [_brg, _ens, time]];
        if ((_eskiB select 0) < 0 || {abs ((((_eskiB select 0) - _brg) + 540) mod 360 - 180) > 25}) then {
            // plan tehdit yonu bilinmiyorsa (veya >25 derece farkliysa) cikarimla guncellenir
            private _eskiPlan = _plan getOrDefault ["tehditB", -1];
            if (_eskiPlan < 0 || {abs ((((_eskiPlan) - _brg) + 540) mod 360 - 180) > 40}) then { _plan set ["tehditB", round _brg]; };
            diag_log format ["[SIHA-KESIF] %1 | %2 | CIKARIM: dusman %3 derece yonunden geliyor (sektor puani %4; tum sektorler %5) | plan tehdit yonu %6 -> %7", _id, _taraf, round _brg, _ens, _sek, _eskiPlan, _plan getOrDefault ["tehditB", -1]];
        };
        true
    } else { false }
};
private _git = {
    params ["_nokta", "_sureM"];
    _d doMove _nokta;
    private _bit = time + _sureM;
    waitUntil { sleep 3; call _kaydet; !(call _aktif) || {(_uav distance2D _nokta) < 250} || {time > _bit} };
};

// ---- FAZ 1: cevre ----
diag_log format ["[SIHA-KESIF] %1 | FAZ 1 CEVRE: objektif cevresinde 1200 m halka, 8 nokta", _id];
for "_i" from 0 to 7 do {
    if !(call _aktif) exitWith {};
    [(_obj getPos [1200, _i * 45]) vectorAdd [0, 0, 0], 75] call _git;
};
call _cikarim;

// ---- FAZ 2: yollar ----
private _yollar = [];
for "_i" from 0 to 7 do {
    private _p = _obj getPos [2000, _i * 45];
    private _yl = _p nearRoads 400;
    if (_yl isNotEqualTo []) then { _yollar pushBack [_i, getPosATL (([_yl, [], {_x distance2D _p}, "ASCEND"] call BIS_fnc_sortBy) select 0)]; };
};
diag_log format ["[SIHA-KESIF] %1 | FAZ 2 YOLLAR: %2 yaklasma yolu bulundu (yonlar: %3)", _id, count _yollar, _yollar apply {(_x select 0) * 45}];
{
    if !(call _aktif) exitWith {};
    private _yp = _x select 1;
    [_yp, 70] call _git;
    [_obj getPos [900, _obj getDir _yp], 50] call _git;   // yolu disaridan objektife dogru tara
} forEach _yollar;
call _cikarim;

// ---- FAZ 3: patrol ----
diag_log format ["[SIHA-KESIF] %1 | FAZ 3 PATROL: tehdit ekseni + cevre halkasi", _id];
private _tur = 0;
private _cT = time;
while {call _aktif} do {
    private _st = _plan getOrDefault ["sihaTehdit", [-1]];
    private _nokta = if ((_st select 0) >= 0 && {(_tur mod 2) isEqualTo 0}) then {
        _obj getPos [1000 + random 1500, (_st select 0) + (random 40) - 20]
    } else {
        _obj getPos [1200 + random 600, random 360]
    };
    [_nokta, 70] call _git;
    _tur = _tur + 1;
    if ((time - _cT) > 90) then { _cT = time; call _cikarim; };
};

// ---- bitis ----
if (alive _uav && {alive _d}) then {
    _d doMove _bas;
    if (_uav isKindOf "Helicopter") then { _uav land "LAND"; };
    _uav setVariable [QGVAR(ihaTok), -1];
};
diag_log format ["[SIHA-KESIF] %1 | %2 | sortie bitti (%3 sn) | sektor puanlari %4 | son tehdit cikarimi %5", _id, _taraf, round (time - _t0), _sek, _plan getOrDefault ["sihaTehdit", "yok"]];
true
