#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * UFUK CIZGISI FARKINDALIGI v2 (v8.528; kullanici: 'ufuk cizgisi farkindaligi ekle, ufukta dolasmasinlar, ufuk cizgisine sahip diger dusmanlari daha hizli spotlasinlar').
 * Onceki durum: fnc_kamuflaj yalniz camouflageCoef (+0.2) ve STEALTH iken ufuktan cekilme yapiyordu. Bu izleyici (1.5 sn'de bir, tick basina en fazla 12 yerel AI piyade) iki sey ekler:
 *
 * A) HIZLI SPOT (dusmani gokyuzu karsisinda gormek): gozlemci AWARE / COMBAT / STEALTH, dusman 700 m (CBA ufukSpotM) icinde, SILUET (fnc_ufukMu: gozlemci gozunden dusmanin arkasinda arazi / nesne yok = gokyuzune karsi)
 *    + gorus hatti (checkVisibility >= 0.25) + gozlemci yonune +-110 derece iciyse: bilgi (reveal) yukselir: 0.25 + 0.55 x (1 - mesafe / menzil), hareketli dusman +0.1, gece NVG'siz x0.5, CBA ufukSpotHiz carpani (0.5-2),
 *    en cok 0.95 (KESIN 1.2'nin altinda: yaklasik yer, kesin hedef degil). HILE YOK: yalniz gorus hatti olan ve ufukta siluet veren dusman. Gozlemci basina 3 sn'de bir.
 * B) UFUKTA DOLASMA: kendi askerimiz, BILINEN (knowsAbout >= SEZILDI) en yakin dusmanin gozunden UFUK cizgisinde (siluet, dusman 40-700 m) ise:
 *    - yurur / kosarken: COMEL (MIDDLE) ile gecer (siluet alcalir), ufuktan cikinca eski durusa (AUTO) doner;  retreat / temas kesme / sipere zorla / forceMove / taktik kilidi / araca bagli iken DOKUNULMAZ.
 *    - duruyor (>= 8 sn) ve temas yok (son 20 sn) ise: yatar ya da 8-16 m cevrede ufuk DISI + dusman gozunden gizli + (palet uyumu) en iyi noktaya kisa yer degistirir (30 sn'de bir, tick'te en fazla 3 kisi); varinca fnc_siperTut.
 *    - temasta: yalniz comel (yerinden oynamaz).
 *    LAMBS gorevi / kal-bekle waypoint'li gruplar (fnc_senaryoKapi 'sabit') ve oyuncu dokunulmaz.
 * C) PALET: yer secerken fnc_palet 'uyum' puani (uniforma + vest paleti x zemin paleti) +4'e kadar eklenir (zemine karisan renk tercih edilir).
 * Kapatma: CBA lambs_danger_ufukAlgi = false.  Log: [UFUK-SPOT] / [UFUK-CEK] (ilk 30) + [UFUK-ALGI-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_ufukAlgiStarted") exitWith {false};
lambs_danger_ufukAlgiStarted = true;
diag_log "[UFUK-ALGI] ufuk cizgisi farkindaligi v2 baslatildi (v8.528): siluet dusmani hizli spot + ufukta comel / yer degistirme + palet uyumu";

[] spawn {
    private _ufukFn = missionNamespace getVariable ["lambs_danger_fnc_ufukMu", {false}];
    private _indeks = 0;
    private _say = createHashMapFromArray [["spot", 0], ["comel", 0], ["cek", 0]];
    private _logN = 0;
    private _ozetT = time + 60;
    while {true} do {
        sleep 1.5;
        if !(missionNamespace getVariable ["lambs_danger_ufukAlgi", true]) then { continue };
        private _menzil = missionNamespace getVariable ["lambs_danger_ufukSpotM", 700];
        private _spotHiz = (missionNamespace getVariable ["lambs_danger_ufukSpotHiz", 1]) max 0 min 3;
        private _gece = (sunOrMoon < 0.2);
        private _adaylar = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side group _x) in [west, east, resistance]}
            && {!captive _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(behaviour _x) in ["AWARE", "COMBAT", "STEALTH"]}
            && {(primaryWeapon _x) isNotEqualTo ""} && {!(_x getVariable [QGVAR(teslim), false])}
        };
        private _n = count _adaylar;
        if (_n > 0) then {
            private _kesit = 12 min _n;
            private _cekHak = 3;
            for "_i" from 0 to (_kesit - 1) do {
                private _u = _adaylar select ((_indeks + _i) mod _n);
                private _g = group _u;
                private _tf = side _g;
                private _st = stance _u;
                private _h = [1.7, 1.0, 0.4] select ((["STAND", "CROUCH", "PRONE"] find _st) max 0);
                private _eyeU = eyePos _u;

                // ---------- A) HIZLI SPOT ----------
                if (_spotHiz > 0 && {time >= (_u getVariable [QGVAR(ufukSpotT), 0])}) then {
                    _u setVariable [QGVAR(ufukSpotT), time + 3];
                    private _nvgYok = _gece && {(hmd _u) isEqualTo ""};
                    private _hedefler = ((_u nearEntities ["CAManBase", _menzil]) select {
                        alive _x && {!captive _x} && {(side group _x) isNotEqualTo civilian} && {(_tf getFriend (side group _x)) < 0.6}
                        && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {[_x] call FUNC(gercekHedef)}
                    });
                    if (_hedefler isNotEqualTo []) then {
                        _hedefler = [_hedefler, [], {_x distance _u}, "ASCEND"] call BIS_fnc_sortBy;
                        {
                            private _e = _x;
                            private _d = _u distance _e;
                            if ((_u knowsAbout _e) >= (["SUPHE"] call FUNC(bilgiEsik))) then { continue };
                            private _hE = [1.7, 1.0, 0.4] select ((["STAND", "CROUCH", "PRONE"] find (stance _e)) max 0);
                            if !([_eyeU, getPosATL _e, _hE] call _ufukFn) then { continue };
                            if ((abs ((((_u getDir _e) - (getDir _u)) + 540) mod 360 - 180)) > 110) then { continue };
                            if (([_u, "VIEW", _e] checkVisibility [_eyeU, eyePos _e]) < 0.25) then { continue };
                            private _lvl = 0.25 + (0.55 * (1 - (_d / (_menzil max 1))));
                            if ((speed _e) > 6) then { _lvl = _lvl + 0.1; };
                            if (_nvgYok) then { _lvl = _lvl * 0.5; };
                            _lvl = ((_lvl * _spotHiz) max 0.15) min 0.95;
                            if (_lvl > (_u knowsAbout _e)) then {
                                _u reveal [_e, _lvl];
                                _say set ["spot", (_say get "spot") + 1];
                                if (_logN < 30) then {
                                    _logN = _logN + 1;
                                    diag_log format ["[UFUK-SPOT] %1 | %2 -> %3 | %4 m | siluet (gokyuzu karsisinda) | bilgi %5%6", groupId _g, name _u, name _e, round _d, _lvl toFixed 2, ["", " (gece NVG'siz)"] select _nvgYok];
                                };
                            };
                        } forEach (_hedefler select [0, 3]);
                    };
                };

                // ---------- B) UFUKTA DOLASMA ----------
                if ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true || {(_u getVariable [QGVAR(zorlaBitis), 0]) > time} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                    || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                    || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                    || {_g getVariable [QGVAR(isBounding), false]}) then { continue };
                if ([_g, "ufukAlgi", true] call FUNC(senaryoKapi)) then { continue };
                private _en = _u findNearestEnemy _u;
                if (isNull _en || {!alive _en} || {!(_en isKindOf "CAManBase")} || {captive _en}) then {
                    // ufuk durusunu biz koyduysak birak
                    if (_u getVariable [QGVAR(ufukComel), false]) then { _u setVariable [QGVAR(ufukComel), false]; _u setUnitPosWeak "AUTO"; };
                    continue
                };
                private _dd = _u distance2D _en;
                private _biliyor = (_u knowsAbout _en) >= (["SEZILDI"] call FUNC(bilgiEsik));
                private _sil = _biliyor && {_dd >= 40} && {_dd <= _menzil} && {[eyePos _en, getPosATL _u, _h] call _ufukFn};
                if (!_sil) then {
                    if (_u getVariable [QGVAR(ufukComel), false]) then { _u setVariable [QGVAR(ufukComel), false]; _u setUnitPosWeak "AUTO"; };
                    _u setVariable [QGVAR(ufukDurT), -1];
                    continue
                };
                private _temas = (_g getVariable [QGVAR(contact), 0]) > (time - 20);
                private _hiz = speed _u;
                if (_hiz >= 1) then {
                    // yurur / kosarken ufuk cizgisini comelerek gec
                    if (_st isEqualTo "STAND") then {
                        _u setUnitPosWeak "MIDDLE";
                        _u setVariable [QGVAR(ufukComel), true];
                        _say set ["comel", (_say get "comel") + 1];
                    };
                    _u setVariable [QGVAR(ufukDurT), -1];
                    continue
                };
                // duruyor
                private _dur = _u getVariable [QGVAR(ufukDurT), -1];
                if (_dur < 0) then { _u setVariable [QGVAR(ufukDurT), time]; _dur = time; };
                if (_st isEqualTo "STAND") then {
                    _u setUnitPosWeak "MIDDLE";
                    _u setVariable [QGVAR(ufukComel), true];
                    _say set ["comel", (_say get "comel") + 1];
                };
                if (_temas || {(time - _dur) < 8} || {_cekHak <= 0} || {time < (_u getVariable [QGVAR(ufukCekT), 0])}) then { continue };
                // yer degistir: 8-16 m cevre, 8 yon; puan: ufuk DISI +10, dusman gozunden gizli +12, ortu +4, palet uyumu x4, uzaklik cezasi
                _u setVariable [QGVAR(ufukCekT), time + 30];
                private _gozE = eyePos _en;
                private _upos = getPosATL _u;
                private _enIyi = [];
                private _enIyiS = -999;
                {
                    private _r = _x;
                    {
                        private _c2 = _upos getPos [_r, _x];
                        if (surfaceIsWater _c2) then { continue };
                        if ((nearestTerrainObjects [_c2, ["BUILDING", "HOUSE"], 5, false, true]) isNotEqualTo []) then { continue };
                        private _s = -(_r * 0.3);
                        if !([_gozE, _c2, 1.0] call _ufukFn) then { _s = _s + 10; };
                        private _c2ASL = AGLToASL (_c2 vectorAdd [0, 0, 0.4]);
                        if (terrainIntersectASL [_gozE, _c2ASL] || {lineIntersects [_gozE, _c2ASL, objNull, objNull]}) then { _s = _s + 12; };
                        if ((nearestTerrainObjects [_c2, ["TREE", "BUSH", "SMALL TREE", "HIDE", "ROCK", "WALL"], 3, false, true]) isNotEqualTo []) then { _s = _s + 4; };
                        _s = _s + (4 * (["uyum", _u, _c2] call FUNC(palet)));
                        _s = _s + (0.6 * ([_tf, _c2, getPosATL _en, true] call FUNC(mevziPuan)));   // v8.529: ufukta vurulan / kotu hucrelerden kacin
                        if (_s > _enIyiS) then { _enIyiS = _s; _enIyi = _c2; };
                    } forEach [0, 45, 90, 135, 180, 225, 270, 315];
                } forEach [8, 16];
                if (_enIyi isEqualTo [] || {_enIyiS < 8}) then { continue };
                _cekHak = _cekHak - 1;
                _u setVariable [QGVAR(forceMove), true];
                _u setVariable [QGVAR(taktikKilit), time + 10];
                _u setUnitPosWeak "MIDDLE";
                _u doMove _enIyi;
                _say set ["cek", (_say get "cek") + 1];
                if (_logN < 30) then {
                    _logN = _logN + 1;
                    diag_log format ["[UFUK-CEK] %1 | %2 | ufuk cizgisinden cekildi | puan:%3 | renk(rgb):%4 uyum:%5 | dusman:%6 m", groupId _g, name _u, round _enIyiS, (["renk", _u] call FUNC(palet)) apply { _x toFixed 2 }, (["uyum", _u, _enIyi] call FUNC(palet)) toFixed 2, round _dd];
                };
                [_u, _enIyi] spawn {
                    params ["_a", "_p"];
                    private _t = time + 12;
                    waitUntil { sleep 1; !alive _a || {(_a distance2D _p) < 3} || {time > _t} };
                    if (alive _a) then {
                        _a setVariable [QGVAR(forceMove), nil];
                        _a setVariable [QGVAR(taktikKilit), 0];
                        _a setUnitPosWeak "DOWN";
                        [_a] call FUNC(siperTut);
                    };
                };
            };
            _indeks = _indeks + _kesit;
        };
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "spot") + (_say get "comel") + (_say get "cek")) > 0) then {
                diag_log format ["[UFUK-ALGI-OZET] 60 sn: siluet spot %1 | ufukta comelme %2 | yer degistirme %3", _say get "spot", _say get "comel", _say get "cek"];
            };
            { _say set [_x, 0]; } forEach ["spot", "comel", "cek"];
        };
    };
};
true
