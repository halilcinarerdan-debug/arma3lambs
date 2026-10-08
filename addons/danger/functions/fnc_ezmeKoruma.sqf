#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EZME KORUMASI (v8.144) — kullanici: "apc ler adamlari eziyor, onune gecemez misin?" (RPT ece75d6d: hizli nakil araclari yaya timlerin yanindan 52 km/s gecti).
 * Her makinede 0.5 sn'de bir: kendi makinemizde yerel, AI surucusu olan, hizi > 6 km/s kara araclari icin hiz yonunde (ileri bakis = 8 m + 1.6 x hiz m/s) 3.5 m seritte
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
            if (abs _hiz < 1.7 && {!_frenli}) then { continue };
            private _vel = velocity _v;
            private _yon = vectorNormalized [_vel select 0, _vel select 1, 0];
            if (_yon isEqualTo [0,0,0]) then { _yon = vectorDir _v; _yon set [2, 0]; _yon = vectorNormalized _yon };
            private _bak = 8 + ((abs _hiz) * 1.6);
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
                private _boyuna = _rel vectorDotProduct _yon;
                if (_boyuna < 0 || {_boyuna > _bak}) then { continue };
                private _yanal = vectorMagnitude (_rel vectorDiff (_yon vectorMultiply _boyuna));
                if (_yanal > 3.5) then { continue };
                _tehlike = true;
                if (_boyuna < _enYakin) then { _enYakin = _boyuna };
            } forEach (_merkez nearEntities [["CAManBase"], (_bak / 2) + 4]);
            if (_tehlike) then {
                _d forceSpeed 0;
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
                };
            };
        } forEach (vehicles select {_x isKindOf "LandVehicle" && {alive _x} && {(speed _x) > 6 || {_x getVariable [QGVAR(ezmeFren), false]}}});
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
