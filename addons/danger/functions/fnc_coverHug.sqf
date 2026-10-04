#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIPERE YAPISMA — secilen siper "iyi" ama asker siperin yarim metre uzaginda / ayakta durup govdesi gorunuyordu.
 *
 * DOKTRIN (siperden ates, FM 3-21.8 "fighting position / use of cover"):
 *   - siperin ARKASINDA, yuzeye 30-50 cm kala dur (tam dayanma YOK: parca / sekme / yuzey vurusu bunu cezalandirir)
 *   - gorunur profili minimuma indir: dusmandan GIZLI olan EN YUKSEK durus (omuz + bas gizli); baski altindaysa
 *     bir kademe alcal
 *   - dusmana dogru bak (doWatch); siperin arkasindan sag/sol kenardan ates (LAMBS FSM zaten gerektiginde acar)
 *
 * Calisma: catisma halindeki yerel AI gruplarinda, duran (speed < 0.6), binada olmayan, aractan inmis askerlerde
 * 1.5 sn'de bir (en fazla 5 asker / tik):
 *   1) en yakin bilinen dusmanin gozunden askere ray -> hattaki ILK sert (FIRE geometri) yuzey bulunur
 *   2) yuzey 3.5 m icindeyse: hedef nokta = yuzeyin 0.45 m ARKASI (dusman -> asker yonunde); en fazla 2.2 m kayar
 *      (0.3 sn'lik yumusak kayma, isinlanma yok)
 *   3) durus: bas + iki omuz noktasi dusmandan gizliyse o stance (UP > MIDDLE > DOWN); hicbiri degilse DOWN
 *   - ayni noktada 20 sn tekrar etmez; ayni noktada kalan askere dokunmaz
 *
 * ATLANIR: oyuncu, arac, bina ici, hareket (speed >= 0.6 / forceMove), retreat / evade / temas kes, dusman < 6 m
 * KAPATMA ANAHTARI: lambs_danger_coverHugOff = true
 *
 * RPG degil, RPT: [SIPER-YAPIS] (ayrintili log: lambs_danger_coverHugLog = true)
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_coverHugStarted") exitWith {false};
lambs_danger_coverHugStarted = true;

diag_log "[SIPER-YAPIS] sipere yapisma (hull-down / yuzeyin 45 cm arkasi) watchdog baslatildi";

[] spawn {
    private _sayac = createHashMapFromArray [["ayarlandi", 0], ["acikta", 0], ["reddedildi", 0], ["kaymaTop", 0], ["UP", 0], ["MIDDLE", 0], ["DOWN", 0]];
    private _sonOzet = time;
    while {true} do {
        sleep 1.5;
        if ((time - _sonOzet) >= 60) then {
            _sonOzet = time;
            private _a = _sayac get "ayarlandi";
            diag_log format ["[SIPER-YAPIS-OZET] 60 sn: ayarlandi:%1 (ort kayma %2 m) | acikta:%3 reddedildi:%4 | durus UP:%5 MIDDLE:%6 DOWN:%7", _a, ((_sayac get "kaymaTop") / (_a max 1)) toFixed 2, _sayac get "acikta", _sayac get "reddedildi", _sayac get "UP", _sayac get "MIDDLE", _sayac get "DOWN"];
            { _sayac set [_x, 0]; } forEach (keys _sayac);
        };
        if (missionNamespace getVariable ["lambs_danger_coverHugOff", false]) then { continue };
        private _butce = 8;   // v8.19: 5 -> 8 asker / tik

        {
            private _g = _x;
            if (_butce <= 0) exitWith {};
            if (isNull _g || {!local _g}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false])
                || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isSweeping), false]}
            ) then { continue };

            {
                private _u = _x;
                if (_butce <= 0) exitWith {};
                if (
                    !alive _u || {!local _u} || {isPlayer _u} || {!isNull objectParent _u}
                    || {(speed _u) >= 0.6} || {(insideBuilding _u) > 0.5}
                    || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time}
                    || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                    || {time < (_u getVariable [QGVAR(hugT), 0])}
                ) then { continue };

                // ayni noktada tekrar etme
                private _eskiPos = _u getVariable [QGVAR(hugPos), []];
                if (_eskiPos isNotEqualTo [] && {(_u distance2D _eskiPos) < 1.2} && {time < ((_u getVariable [QGVAR(hugAt), -999]) + 20)}) then { continue };

                private _en = _u findNearestEnemy _u;
                if (isNull _en || {!alive _en}) then { continue };
                private _ed = _u distance2D _en;
                if (_ed < 6 || {_ed > 400}) then { continue };

                _u setVariable [QGVAR(hugT), time + 3];
                _butce = _butce - 1;

                private _eASL = eyePos _en;
                private _pASL = getPosASL _u;
                // v8.19: 3 yukseklikte (alcak duvar 0.4 / govde 1.1 / omuz 1.5) en YAKIN sert yuzey; mesafe 6 m'ye kadar
                private _uASL = _pASL vectorAdd [0, 0, 1.1];
                private _hP = [];
                private _d = 99;
                {
                    private _uH = _pASL vectorAdd [0, 0, _x];
                    private _hh = lineIntersectsSurfaces [_eASL, _uH, _en, _u, true, 1, "FIRE", "NONE"];
                    if (_hh isNotEqualTo []) then {
                        private _hp = (_hh select 0) select 0;
                        private _dd = _uH distance _hp;
                        if (_dd < _d && {_dd > 0.01}) then { _d = _dd; _hP = _hp; _uASL = _uH; };
                    };
                } forEach [1.1, 0.4, 1.5];
                if (_hP isEqualTo [] || {_d > 6}) then {
                    _sayac set ["acikta", (_sayac get "acikta") + 1];
                    if (isNil "lambs_danger_hugAcikLogN") then { lambs_danger_hugAcikLogN = 0; };
                    if (lambs_danger_hugAcikLogN < 25) then {
                        lambs_danger_hugAcikLogN = lambs_danger_hugAcikLogN + 1;
                        diag_log format ["[SIPER-YAPIS-TANI] %1 | %2 | dusman %3 m | yuzey: %4 | en yakin yuzey %5 m (esik 6) | stance:%6", groupId _g, name _u, round _ed, ["var ama uzak", "YOK (3 yukseklikte isin kesisimi yok)"] select (_hP isEqualTo []), if (_hP isEqualTo []) then {"-"} else {_d toFixed 1}, stance _u];
                    };
                    continue
                };

                private _dir = vectorNormalized (_uASL vectorDiff _eASL);
                private _tASL = _hP vectorAdd (_dir vectorMultiply (missionNamespace getVariable ["lambs_danger_coverHugMesafe", 0.35]));   // 45 -> 35 cm (kullanici: daha yapisik)
                _tASL set [2, _pASL select 2];
                private _t = ASLToATL _tASL;
                _t set [2, (getPosATL _u) select 2];

                private _kayma = (getPosATL _u) distance2D _t;
                private _yapisik = _kayma < 0.15;

                // yeni nokta gecerli mi: su yok, 2.5 m icinde dost yok (v8.39: 0.9 -> 2.5, siperde yigilma yok), kayma <= 2.2 m, yon dusmana dogru
                if (!_yapisik) then {
                    if (_kayma > 4 || {surfaceIsWater _t}) then { _sayac set ["reddedildi", (_sayac get "reddedildi") + 1]; continue };
                    if (((_u nearEntities ["CAManBase", 5]) findIf {_x isNotEqualTo _u && {(_x distance2D _t) < 2.5}}) > -1) then { _sayac set ["reddedildi", (_sayac get "reddedildi") + 1]; continue };
                };

                // durus: bas + iki omuz dusmandan gizli en yuksek stance
                private _perp = [-(_dir select 1), _dir select 0, 0];
                private _zeminASL = _pASL select 2;
                // v8.19 YANAL INCE AYAR: 5 yanal sapma (0, +-0.3, +-0.6 m) icin en yuksek gizli stance; en iyi nokta (esitlikte en kucuk sapma) secilir
                private _enIyiOfs = 0;
                private _enIyiSk = -1;
                {
                    private _ofs = _x;
                    private _tO = _tASL vectorAdd (_perp vectorMultiply _ofs);
                    private _sk = 0;
                    {
                        _x params ["_ad", "_h", "_puan"];
                        private _bas = [_tO select 0, _tO select 1, (_pASL select 2) + _h];
                        private _gz = true;
                        {
                            private _nokta = _bas vectorAdd (_perp vectorMultiply _x);
                            if (!((lineIntersects [_nokta, _eASL, _u, _en]) || {terrainIntersectASL [_nokta, _eASL]})) exitWith { _gz = false; };
                        } forEach [0, 0.3, -0.3];
                        if (_gz) exitWith { _sk = _puan; };
                    } forEach [["UP", 1.62, 3], ["MIDDLE", 1.08, 2], ["DOWN", 0.38, 1]];
                    if (_sk > _enIyiSk || {_sk isEqualTo _enIyiSk && {(abs _ofs) < (abs _enIyiOfs)}}) then { _enIyiSk = _sk; _enIyiOfs = _ofs; };
                } forEach [0, 0.3, -0.3, 0.6, -0.6];
                if (_enIyiOfs isNotEqualTo 0) then {
                    _tASL = _tASL vectorAdd (_perp vectorMultiply _enIyiOfs);
                    _t = ASLToATL _tASL;
                    _t set [2, (getPosATL _u) select 2];
                };

                private _durus = "DOWN";
                {
                    _x params ["_ad", "_h"];
                    private _bas = [_tASL select 0, _tASL select 1, _zeminASL + _h];
                    private _gizli = true;
                    {
                        private _nokta = _bas vectorAdd (_perp vectorMultiply _x);
                        if (!((lineIntersects [_nokta, _eASL, _u, _en]) || {terrainIntersectASL [_nokta, _eASL]})) exitWith { _gizli = false; };
                    } forEach [0, 0.3, -0.3];
                    if (_gizli) exitWith { _durus = _ad; };
                } forEach [["UP", 1.62], ["MIDDLE", 1.08], ["DOWN", 0.38]];

                // TEK yumusak kayma: son nokta (yuzey + 35 cm + yanal ince ayar); en fazla 4.5 m, 8 adim
                if (!surfaceIsWater _t && {((getPosATL _u) distance2D _t) >= 0.15} && {((getPosATL _u) distance2D _t) <= 4.5}) then {
                    [_u, getPosATL _u, _t] spawn {
                        params ["_a", "_p0", "_p1"];
                        for "_k" from 1 to 8 do {
                            if (!alive _a) exitWith {};
                            _a setPosATL (_p0 vectorAdd ((_p1 vectorDiff _p0) vectorMultiply (_k / 8)));
                            sleep 0.06;
                        };
                    };
                };

                // baski altinda bir kademe alcal
                if ((getSuppression _u) > 0.35) then {
                    _durus = switch (_durus) do { case "UP": {"MIDDLE"}; case "MIDDLE": {"DOWN"}; default {"DOWN"} };
                };
                _u setUnitPosWeak _durus;
                _u doWatch _en;

                _sayac set ["ayarlandi", (_sayac get "ayarlandi") + 1];
                _sayac set ["kaymaTop", (_sayac get "kaymaTop") + _kayma];
                _sayac set [_durus, (_sayac getOrDefault [_durus, 0]) + 1];
                _u setVariable [QGVAR(hugPos), _t];
                _u setVariable [QGVAR(hugAt), time];

                if (missionNamespace getVariable ["lambs_danger_coverHugLog", false]) then {
                    diag_log format [
                        "[SIPER-YAPIS] %1 | %2 | yuzey %3 m | kayma %4 m | durus %5 | dusman %6 m",
                        groupId _g, name _u, _d toFixed 2, _kayma toFixed 2, _durus, round _ed
                    ];
                };
            } forEach (units _g);
        } forEach allGroups;
    };
};

true
