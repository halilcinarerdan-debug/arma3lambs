#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EZME KORUMASI (v8.144) — kullanici: "apc ler adamlari eziyor, onune gecemez misin?" (RPT ece75d6d: hizli nakil araclari yaya timlerin yanindan 52 km/s gecti).
 * Her makinede 0.5 sn'de bir: kendi makinemizde yerel, AI surucusu olan, hizi > 1.5 km/s kara araclari icin hiz yonunde (ileri bakis = 10 m + 1.6 x hiz m/s) 4 m seritte
 * DOST yaya (dost = surucunun tarafi ile getFriend >= 0.6; yatan / baygin dahil) varsa surucuye forceSpeed 0 (fren); mesafe < 5 m + hiz'a gore ise ek olarak hiz yariya indirilir.
 * Yol temizlenince 1.5 sn sonra forceSpeed -1 (yalniz bu fonksiyon dondurduysa). Dusman yaya icin fren YOK (savas, kasitli).
 * Sinirlama: sadece surucu AI; oyuncu surucuye dokunmaz. Kapatma: lambs_danger_ezmeOff = true. Log: [EZME] (frenleme baslangici, arac basina en fazla 8 sn'de bir).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_ezmeStarted") exitWith {false};
lambs_danger_ezmeStarted = true;

diag_log "[EZME] ezme korumasi watchdog'u baslatildi (v8.144)";

// v8.146 TANI: dost yaya BAYILIRSA (ACE unconscious) yakinda hizli giden arac var mi -> [EZME-BAYGIN] (ezilme mi baska sey mi kanitlansin)
if (!isNil "CBA_fnc_addEventHandler") then {
    ["ace_unconscious", {
        params ["_u", "_durum"];
        if (!_durum || {!isNull objectParent _u}) exitWith {};
        private _adaylar = (_u nearEntities [["LandVehicle"], 40]) select {(speed _x) > 3 || {(time - (_x getVariable [QGVAR(ezmeSonT), -999])) < 5}};
        if (_adaylar isEqualTo []) exitWith {};
        {
            private _d = driver _x;
            diag_log format ["[EZME-BAYGIN] %1 (%2) bayildi | arac %3 | surucu %4 | yerel %5 | hiz %6 km/s | mesafe %7 m | fren son %8 sn once", name _u, group _u, typeOf _x, if (isNull _d) then {"yok"} else {name _d}, local _x, round speed _x, round (_u distance2D _x), round (time - (_x getVariable [QGVAR(ezmeSonT), -999]))];
        } forEach _adaylar;
    }] call CBA_fnc_addEventHandler;
};

private _calis = {
    while {true} do {
        sleep 0.5;
        if (missionNamespace getVariable ["lambs_danger_ezmeOff", false]) then { continue };
        {
            private _v = _x;
            private _d = driver _v;
            private _frenli = _v getVariable [QGVAR(ezmeFren), false];
            if (!local _v || {isNull _d} || {!alive _d} || {isPlayer _d} || {!local _d}) then {
                if (_frenli && {!isNull _d} && {local _d}) then { _d forceSpeed -1; _v setVariable [QGVAR(ezmeFren), nil]; };
                continue
            };
            private _hiz = (speed _v) / 3.6;
            if (abs _hiz < 0.4 && {!_frenli}) then { continue };
            private _vel = velocity _v;
            private _yon = vectorNormalized [_vel select 0, _vel select 1, 0];
            if (_yon isEqualTo [0,0,0]) then { _yon = vectorDir _v; _yon set [2, 0]; _yon = vectorNormalized _yon };
            private _bak = 10 + ((abs _hiz) * 1.6);
            private _p = getPosASL _v;
            private _merkez = _p vectorAdd (_yon vectorMultiply (_bak / 2));
            private _taraf = side group _d;
            private _tehlike = false;
            private _enYakin = 1e6;
            {
                private _u = _x;
                if (!alive _u || {!isNull objectParent _u} || {_u == _d}) then { continue };
                if ((_taraf getFriend (side group _u)) < 0.6) then { continue };
                private _rel = (getPosASL _u) vectorDiff _p;
                _rel set [2, 0];
                // v8.146: arac govdesine 7 m icindeki dost yaya (donus / dar manevra / geri vites) yon farketmeksizin tehlike
                if ((vectorMagnitude _rel) < 7 && {abs _hiz > 0.4}) then {
                    _tehlike = true;
                    if ((vectorMagnitude _rel) < _enYakin) then { _enYakin = vectorMagnitude _rel };
                };
                private _boyuna = _rel vectorDotProduct _yon;
                if (_boyuna < 0 || {_boyuna > _bak}) then { continue };
                private _yanal = vectorMagnitude (_rel vectorDiff (_yon vectorMultiply _boyuna));
                if (_yanal > 4) then { continue };
                _tehlike = true;
                if (_boyuna < _enYakin) then { _enYakin = _boyuna };
            } forEach (_merkez nearEntities [["CAManBase"], (_bak / 2) + 4]);
            if (_tehlike) then {
                // 30 sn kesintisiz fren (yoldaki dost yaya kimildamiyor): 5 km/s siner (kilitlenme onlemi)
                if (!_frenli) then { _v setVariable [QGVAR(ezmeBaslaT), time]; };
                private _surekli = time - (_v getVariable [QGVAR(ezmeBaslaT), time]);
                _d forceSpeed ([0, 1.4] select (_surekli > 30));
                _v setVariable [QGVAR(ezmeFren), true];
                _v setVariable [QGVAR(ezmeSonT), time];
                if (_enYakin < (4 + (abs _hiz) * 0.6) && {abs _hiz > 3}) then {
                    _v setVelocity ((velocity _v) vectorMultiply 0.5);
                };
                if ((time - (_v getVariable [QGVAR(ezmeLogT), -999])) > 8) then {
                    _v setVariable [QGVAR(ezmeLogT), time];
                    diag_log format ["[EZME] %1 | surucu %2 | hiz %3 km/s | en yakin dost yaya %4 m onde -> FREN", typeOf _v, name _d, round speed _v, round _enYakin];
                };
            } else {
                if (_frenli && {(time - (_v getVariable [QGVAR(ezmeSonT), 0])) > 1.5}) then {
                    _d forceSpeed -1;
                    _v setVariable [QGVAR(ezmeFren), nil];
                    _v setVariable [QGVAR(ezmeBaslaT), nil];
                };
            };
        } forEach (vehicles select {_x isKindOf "LandVehicle" && {alive _x} && {(speed _x) > 1.5 || {_x getVariable [QGVAR(ezmeFren), false]}}});
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] ezmeKoruma betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
