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
    while {true} do {
        sleep 1.5;
        if (missionNamespace getVariable ["lambs_danger_coverHugOff", false]) then { continue };
        private _butce = 5;

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

                _u setVariable [QGVAR(hugT), time + 4];
                _butce = _butce - 1;

                private _eASL = eyePos _en;
                private _pASL = getPosASL _u;
                private _uASL = _pASL vectorAdd [0, 0, 1.1];

                // dusman -> asker hattindaki ILK sert yuzey (mermi durduran geometri)
                private _hit = lineIntersectsSurfaces [_eASL, _uASL, _en, _u, true, 1, "FIRE", "NONE"];
                if (_hit isEqualTo []) then { continue };   // acikta: siper yok
                private _hP = (_hit select 0) select 0;
                private _d = _uASL distance _hP;
                if (_d > 3.5 || {_d < 0.01}) then { continue };

                private _dir = vectorNormalized (_uASL vectorDiff _eASL);
                private _tASL = _hP vectorAdd (_dir vectorMultiply 0.45);
                _tASL set [2, _pASL select 2];
                private _t = ASLToATL _tASL;
                _t set [2, (getPosATL _u) select 2];

                private _kayma = (getPosATL _u) distance2D _t;
                private _yapisik = _kayma < 0.15;

                // yeni nokta gecerli mi: su yok, 0.9 m icinde dost yok, kayma <= 2.2 m, yon dusmana dogru
                if (!_yapisik) then {
                    if (_kayma > 2.2 || {surfaceIsWater _t}) then { continue };
                    if (((_u nearEntities ["CAManBase", 3]) findIf {_x isNotEqualTo _u && {(_x distance2D _t) < 0.9}}) > -1) then { continue };
                    [_u, getPosATL _u, _t] spawn {
                        params ["_a", "_p0", "_p1"];
                        for "_k" from 1 to 5 do {
                            if (!alive _a) exitWith {};
                            _a setPosATL (_p0 vectorAdd ((_p1 vectorDiff _p0) vectorMultiply (_k / 5)));
                            sleep 0.06;
                        };
                    };
                };

                // durus: bas + iki omuz dusmandan gizli en yuksek stance
                private _perp = [-(_dir select 1), _dir select 0, 0];
                private _zeminASL = _pASL select 2;
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

                // baski altinda bir kademe alcal
                if ((getSuppression _u) > 0.35) then {
                    _durus = switch (_durus) do { case "UP": {"MIDDLE"}; case "MIDDLE": {"DOWN"}; default {"DOWN"} };
                };
                _u setUnitPosWeak _durus;
                _u doWatch _en;

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
