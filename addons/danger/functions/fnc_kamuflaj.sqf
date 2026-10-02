#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KAMUFLAJ BILINCI v1 (watcher) — AI kendini tehdit gozunden gizleme: UFUK cizgisinden kacinma, hareket / isik ile gorunurluk,
 * STEALTH iken gizlenme.
 *
 * NOT: Cali / cimen / agac ARKASI gorusu bu fork'ta ELE ALINMAZ (kullanicinin ortaminda bunu kapatan mod zaten var ve cok etkili;
 * ustune bastirmak AI'yi gereginden gorunmez yapardi). Burada yalnizca ufuk, hareket ve isik.
 *
 * 1) camouflageCoef (setUnitTrait, kucuk = gorunmesi zor; her 2 sn'de en fazla 25 yerel AI askeri):
 *      1.00 taban
 *      -0.10 duruyor (hiz < 1.5 km/s)           +0.10 kosuyor (> 12 km/s)
 *      +0.20 en yakin bilinen dusman (<= 400 m) gozunden UFUK cizgisi arkasinda (silueti gokyuzune dusuyor)
 *      -0.10 sabah / aksam alacasi (04:30-07:30, 18:00-20:30)   -0.15 gece (sunOrMoon < 0.2)   -0.10 x sis
 *    sinir [kamuflajMin (0.6), 1.2]
 * 2) STEALTH GIZLENME: grup davranisi STEALTH, temas yok, bilinen dusman 60-400 m ve asker bos (durmus, emir yok) ise:
 *      - yatar ("DOWN")
 *      - ufuk cizgisindeyse 8-16 m cevresinde ufuk DISI, dusman gozunden arazi ile gizli bir yere gecer (30 sn'de bir)
 *
 * Kapatma: lambs_danger_kamuflajV1 = false ya da doktrin anahtari kamuflaj = false. Log: [KAMUFLAJ] / [KAMUFLAJ-YER]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_kamuflajStarted") exitWith {false};
lambs_danger_kamuflajStarted = true;

diag_log "[KAMUFLAJ] kamuflaj bilinci baslatildi (ufuk / hareket / isik katsayisi + STEALTH gizlenme; cali-cimen arkasi gorusu MOD'a birakildi)";

[] spawn {
    private _ufukFn = missionNamespace getVariable ["lambs_danger_fnc_ufukMu", {false}];
    private _indeks = 0;
    while {true} do {
        sleep 2;
        if (!(missionNamespace getVariable ["lambs_danger_kamuflajV1", true])) then { continue };

        // ortam (tek sefer / tick)
        private _saat = (date select 3) + ((date select 4) / 60);
        private _alaca = ((_saat >= 4.5) && {_saat <= 7.5}) || {(_saat >= 18) && {_saat <= 20.5}};
        private _gece = (sunOrMoon < 0.2);
        private _isikBonus = ([0, 0.1] select _alaca) + ([0, 0.15] select _gece) + (0.1 * (fog min 1));

        private _askerler = [];
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            { if (alive _x && {isNull objectParent _x} && {local _x}) then { _askerler pushBack _x; }; } forEach (units _g);
        } forEach allGroups;

        private _n = count _askerler;
        if (_n isEqualTo 0) then { continue };
        private _kesit = 25 min _n;
        for "_i" from 0 to (_kesit - 1) do {
            private _u = _askerler select ((_indeks + _i) mod _n);
            private _g = group _u;
            if (!([_g, "kamuflaj", true] call FUNC(dk))) then { continue };
            private _minC = [_g, "kamuflajMin", 0.6] call FUNC(dk);

            private _hizKmh = (speed _u) max 0;
            private _en = _u findNearestEnemy _u;
            private _enVar = !isNull _en && {alive _en} && {(_u distance2D _en) <= 400};
            private _st = stance _u;
            private _h = [1.7, 1.0, 0.4] select ((["STAND", "CROUCH", "PRONE"] find _st) max 0);

            private _c = 1;
            if (_hizKmh < 1.5) then { _c = _c - 0.1; };
            if (_hizKmh > 12) then { _c = _c + 0.1; };
            private _ufukta = false;
            if (_enVar && {(_u distance2D _en) > 40}) then {
                _ufukta = [eyePos _en, getPosATL _u, _h] call _ufukFn;
                if (_ufukta) then { _c = _c + 0.2; };
            };
            _c = _c - _isikBonus;
            _c = (_c max _minC) min 1.2;

            private _eski = _u getVariable [QGVAR(kamuflajC), 1];
            if ((abs (_c - _eski)) >= 0.05) then {
                _u setUnitTrait ["camouflageCoef", _c];
                _u setVariable [QGVAR(kamuflajC), _c];
                if (isNil "lambs_danger_kamuflajLogN") then { lambs_danger_kamuflajLogN = 0; };
                if (lambs_danger_kamuflajLogN < 40) then {
                    lambs_danger_kamuflajLogN = lambs_danger_kamuflajLogN + 1;
                    diag_log format ["[KAMUFLAJ] %1 | coef:%2 | durus:%3 | hiz:%4 | ufukta:%5 | alaca:%6 gece:%7", name _u, _c toFixed 2, _st, round _hizKmh, _ufukta, _alaca, _gece];
                };
            };

            // --- STEALTH gizlenme ---
            if (
                (behaviour _u) isEqualTo "STEALTH" && {_enVar} && {(_u distance2D _en) >= 60}
                && {(_g getVariable [QGVAR(contact), 0]) < time}
                && {!(_u getVariable [QGVAR(forceMove), false])} && {(_u getVariable [QGVAR(taktikKilit), 0]) < time}
                && {_hizKmh < 1.5}
                && {!(_g getVariable [QGVAR(isRetreating), false])} && {!(_g getVariable [QGVAR(isBounding), false])}
            ) then {
                if (_st isNotEqualTo "PRONE" && {(time - (_u getVariable [QGVAR(kamuDownT), -99])) > 6}) then {
                    _u setVariable [QGVAR(kamuDownT), time];
                    _u setUnitPosWeak "DOWN";
                };
                if (_ufukta && {(time - (_u getVariable [QGVAR(kamuYerT), -99])) > 30}) then {
                    _u setVariable [QGVAR(kamuYerT), time];
                    private _gozE = eyePos _en;
                    private _upos = getPosATL _u;
                    private _enIyi = [];
                    private _enIyiS = -999;
                    {
                        private _r = _x;
                        {
                            private _c2 = _upos getPos [_r, _x];
                            if (surfaceIsWater _c2) then { continue };
                            private _bina = (count (nearestTerrainObjects [_c2, ["BUILDING", "HOUSE"], 5, false, true])) > 0;
                            if (_bina) then { continue };
                            private _s = -(_r * 0.3);
                            if (!([_gozE, _c2, 1.0] call _ufukFn)) then { _s = _s + 10; };
                            private _c2ASL = AGLToASL (_c2 vectorAdd [0, 0, 0.4]);
                            if (terrainIntersectASL [_gozE, _c2ASL] || {lineIntersects [_gozE, _c2ASL, objNull, objNull]}) then { _s = _s + 12; };
                            if ((count (nearestTerrainObjects [_c2, ["TREE", "BUSH", "SMALL TREE", "HIDE", "ROCK", "WALL"], 3, false, true])) > 0) then { _s = _s + 4; };
                            if (_s > _enIyiS) then { _enIyiS = _s; _enIyi = _c2; };
                        } forEach [0, 45, 90, 135, 180, 225, 270, 315];
                    } forEach [8, 16];
                    if (_enIyi isNotEqualTo [] && {_enIyiS >= 8}) then {
                        _u setVariable [QGVAR(forceMove), true];
                        _u setVariable [QGVAR(taktikKilit), time + 10];
                        _u setUnitPosWeak "MIDDLE";
                        _u doMove _enIyi;
                        [_u, _enIyi] spawn {
                            params ["_a", "_p"];
                            private _t = time + 12;
                            waitUntil { sleep 1; !alive _a || {(_a distance2D _p) < 3} || {time > _t} };
                            if (alive _a) then {
                                _a setVariable [QGVAR(forceMove), nil];
                                _a setUnitPosWeak "DOWN";
                            };
                        };
                        diag_log format ["[KAMUFLAJ-YER] %1 | ufuk cizgisinden cekildi | puan:%2 | dusman:%3 m", name _u, round _enIyiS, round (_u distance2D _en)];
                    };
                };
            };
        };
        _indeks = _indeks + _kesit;
    };
};

true
