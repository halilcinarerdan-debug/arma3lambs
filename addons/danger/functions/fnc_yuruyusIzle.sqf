#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YURUNEBILIR ALAN BEKCISI (v8.331; v8.334 yogun kaya / nesne bantlari icin yeniden yazildi) — kullanici: 'yogun objeli trench'ler icin 3D editorden alan koyabilelim, ustunde yurusebilsin AI'; 'kayanin icinden gecme olmasin, kolizyon hilelerine izin veriyorum'.
 * AI yol bulma, cok sayida nesneyle (kum torbasi / tahta / kaya kumesi) dolu hendege YOL BULAMAZ. Eden / Zeus 'ELITE Yurunebilir Alan' modul alanlarinda (fnc_yuruyusAlani; ust uste binen alanlar tek bolge sayilir) YEREL AI yaya askerde:
 *   TESPIT (0.5 sn): hareket emri (currentCommand MOVE), hedef > 2.5 m (hedef = hendek / garnizon / gozetleme emrinin GERCEK noktasi [QGVAR(yurHedef), 90 sn] varsa o, yoksa expectedDestination), 2.5 sn'de < 0.4 m ilerleme ve
 *     asker alanda (ya da <= 12 m yaninda) VE (hedef alanda <= 3 m  ya da  askerden hedefe cizgi alandan GECIYOR [gecis koridoru: 3 m adimla, 80 m]).
 *   YURUTME (kare suresine gore, setPosASL): PATH kapanir; her adimda ILERI BAKIS: 0.5 / 1.0 / 1.6 m onundeki en yuksek yuzey (ayaktan +12 m'den -3 m'ye isin, GEOM; bina / arac / asker yok sayilir) olculur;
 *     * yukselme / alcalma YUMUSAK ve onceden (yukari 2.2 m/sn, asagi 3.5 m/sn; hedef yukseklik = 1.0 m ilerideki en yuksek yuzey) -> asker kayanin ICINE girmez, USTUNE cikar; tirmanis dikse yavaslar (en cok %60)
 *     * tirmanilamaz nesne (ayaktan > 3.0 m) onde ise yon +-25 / 50 / 80 derece denenir (0.8 sn sabit); hicbiri gecilemezse yurume birakilir ('gecilemez engel')
 *     * fizik hileleri: her adimda hiz sifirlanir (carpisma / dusme hasari, motor itmesi yok), yon hedefe cevrilir, yurume animasyonu (playMoveNow)
 *   Alanlar birbirine bagliysa (ust uste) asker alan icinde kaldikca yurur; hedef alan disindaysa alandan 4 m cikinca PATH acilir. Hedefe varinca / zaman asiminda (mesafe / hiz x 1.8 + 6 sn) PATH acilir, durus geri verilir.
 * Alan disinda hicbir sey yapmaz; kapatma: lambs_danger_yuruyusOff = true ya da CBA 'Yurunebilir alan'. Log: [YURUYUS] (ilk 40).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yuruyusStarted") exitWith {false};
lambs_danger_yuruyusStarted = true;
diag_log "[YURUYUS] yurunebilir alan bekcisi baslatildi (v8.334): ileri bakisli yuzey takibi, engel yan gecisi, gecis koridoru, emir hedefi baglantisi";

private _calis = {
    private _logN = 0;
    private _maxYuk = 3.0;   // ayaktan itibaren tirmanilabilir en yuksek nesne (m)

    // [yukseklik ASL, tirmanilamaz mi]: (x, y) noktasinin en yuksek yurunebilir yuzeyi; zRef = ayak yuksekligi
    private _yuzey = {
        params ["_px", "_py", "_zRef", "_yok", "_mx"];
        private _h = getTerrainHeightASL [_px, _py];
        private _bl = false;
        private _r = lineIntersectsSurfaces [[_px, _py, _zRef + 12], [_px, _py, _zRef - 3], _yok, objNull, true, 4, "GEOM", "NONE"];
        {
            private _o = _x select 2;
            if (!isNull _o && {!(_o isKindOf "House")} && {!(_o isKindOf "AllVehicles")}) exitWith {
                private _hh = (_x select 0) select 2;
                if (_hh > _h) then { _h = _hh; };
                if ((_hh - _zRef) > _mx) then { _bl = true; };
            };
        } forEach _r;
        [_h, _bl]
    };

    while {true} do {
        sleep 0.5;
        if (missionNamespace getVariable ["lambs_danger_yuruyusOff", false] || {!(missionNamespace getVariable ["lambs_danger_yuruyusAktif", true])}) then { sleep 5; continue };
        private _alanlar = ["LISTE"] call FUNC(yuruyusAlani);
        if (_alanlar isEqualTo []) then { sleep 5; continue };
        {
            private _u = _x;
            if (_u getVariable [QGVAR(yurAktif), false]) then { continue };
            if ((currentCommand _u) isNotEqualTo "MOVE") then { _u setVariable [QGVAR(yurSon), nil]; continue };
            private _en = ["MESAFE", getPosATL _u] call FUNC(yuruyusAlani);
            if ((_en select 0) < 0 || {(_en select 1) > 12}) then { _u setVariable [QGVAR(yurSon), nil]; continue };
            // hedef: emrin gercek noktasi (hendek / garnizon / gozetleme) varsa o; yoksa expectedDestination
            private _dest = (expectedDestination _u) select 0;
            private _hv = _u getVariable [QGVAR(yurHedef), []];
            if ((count _hv) isEqualTo 2 && {(time - (_hv select 1)) < 90} && {(_u distance2D (_hv select 0)) > 2.5}) then { _dest = _hv select 0; };
            if (_dest isEqualTo [0, 0, 0] || {(_u distance2D _dest) < 2.5}) then { _u setVariable [QGVAR(yurSon), nil]; continue };
            private _icinde = (_en select 1) <= 0.5;
            private _destM = (["MESAFE", _dest] call FUNC(yuruyusAlani)) select 1;
            private _izin = _icinde || {_destM <= 3};
            if (!_izin) then {
                // gecis koridoru: askerden hedefe cizgi alandan geciyor mu
                private _yonG = _u getDir _dest;
                private _pos0 = getPosATL _u;
                for "_m" from 3 to ((_u distance2D _dest) min 80) step 3 do {
                    if (!_izin && {((["MESAFE", _pos0 getPos [_m, _yonG]] call FUNC(yuruyusAlani)) select 1) <= 0.5}) then { _izin = true; };
                };
            };
            if (!_izin) then { _u setVariable [QGVAR(yurSon), nil]; continue };
            // takilma: 2.5 sn'de < 0.4 m
            private _son = _u getVariable [QGVAR(yurSon), [[0, 0, 0], -1]];
            if ((_son select 1) < 0 || {(_u distance2D (_son select 0)) > 0.4}) then {
                _u setVariable [QGVAR(yurSon), [getPosATL _u, time]];
                continue
            };
            if ((time - (_son select 1)) < 2.5) then { continue };

            // ---- YURUME ----
            _u setVariable [QGVAR(yurAktif), true];
            _u setVariable [QGVAR(yurSon), nil];
            if (_logN < 40) then {
                _logN = _logN + 1;
                diag_log format ["[YURUYUS] %1 | %2 | takildi (2.5 sn < 0.4 m), hedefe %3 m | %4 | alana %5 m, hedef alana %6 m | yuzey takibi ile yuruyor", name _u, groupId (group _u), round (_u distance2D _dest), ["kenarda / disarida", "alanin icinde"] select _icinde, round (_en select 1), round _destM];
            };
            [_u, _dest, _icinde, _destM <= 3, _yuzey, _maxYuk] spawn {
                params ["_u", "_dest", "_icinde", "_destAlanda", "_yuzey", "_maxYuk"];
                private _stance = unitPos _u;
                private _comel = (stance _u) in ["CROUCH"];
                private _hiz = [1.7, 1.2] select _comel;
                private _silahli = (primaryWeapon _u) isNotEqualTo "" && {(currentWeapon _u) isEqualTo (primaryWeapon _u)};
                private _anim = if (_silahli) then { ["AmovPercMwlkSrasWrflDf", "AmovPknlMwlkSrasWrflDf"] select _comel } else { ["AmovPercMwlkSnonWnonDf", "AmovPknlMwlkSnonWnonDf"] select _comel };
                if ((stance _u) isEqualTo "PRONE") then { _u setUnitPos "MIDDLE"; };
                _u disableAI "PATH";
                private _t0 = time;
                private _sure = ((_u distance2D _dest) / _hiz) * 1.8 + 6;
                private _animT = 0;
                private _tOnce = diag_tickTime;
                private _neden = "zaman asimi";
                private _girdi = _icinde;
                private _off = 0;
                private _offT = 0;
                private _enYuk = 0;
                while {time < (_t0 + _sure)} do {
                    if (!alive _u || {!local _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}) exitWith { _neden = "asker durumu"; };
                    if (missionNamespace getVariable ["lambs_danger_yuruyusOff", false]) exitWith { _neden = "kapatildi"; };
                    if ((_u distance2D _dest) < 1.0) exitWith { _neden = "vardi"; };
                    private _kon = ["MESAFE", getPosATL _u] call FUNC(yuruyusAlani);
                    if ((_kon select 1) <= 0.5) then { _girdi = true; };
                    if (!_destAlanda && {_girdi} && {(_kon select 1) > 4}) exitWith { _neden = "alandan cikti"; };
                    if (time > _animT) then { _animT = time + 1.5; _u playMoveNow _anim; };
                    private _p = getPosASL _u;
                    private _yon0 = _u getDir _dest;
                    // ---- yon secimi: ileri bakis; tirmanilamaz nesne varsa yan acilar ----
                    private _adaylar = [0, 25, -25, 50, -50, 80, -80];
                    if (time < _offT) then { _adaylar = [_off] + (_adaylar - [_off]); };   // sabit yon once denenir, kapaliysa digerleri
                    private _sec = false;
                    private _hedefZ = _p select 2;
                    {
                        private _a = _x;
                        private _d = _yon0 + _a;
                        private _blk = false;
                        private _hRise = -1e9;
                        private _hNear = -1e9;
                        {
                            private _s = _x;
                            private _sx = (_p select 0) + ((sin _d) * _s);
                            private _sy = (_p select 1) + ((cos _d) * _s);
                            ([_sx, _sy, _p select 2, _u, _maxYuk] call _yuzey) params ["_hh", "_bl"];
                            if (_bl) then { _blk = true; };
                            if (_s <= 1.0) then { _hRise = _hRise max _hh; };
                            if (_s <= 0.5) then { _hNear = _hh; };
                        } forEach [0.5, 1.0, 1.6];
                        if (!_blk && {!_sec}) then {
                            _sec = true;
                            if (_a isNotEqualTo _off || {time >= _offT}) then { _off = _a; _offT = [0, time + 0.8] select (_a isNotEqualTo 0); };
                            _hedefZ = [_hNear, _hRise] select (_hRise > (_p select 2));
                        };
                    } forEach _adaylar;
                    if (!_sec) exitWith { _neden = "gecilemez engel (> 3 m, yan acilar da kapali)"; };
                    // ---- hareket: yumusak yukselme / alcalma, dik tirmanista yavaslama ----
                    private _dt = ((diag_tickTime - _tOnce) max 0.01) min 0.2;
                    _tOnce = diag_tickTime;
                    private _d2 = _yon0 + _off;
                    private _egim = ((_hedefZ - (_p select 2)) max 0) / 3;
                    private _vh = _hiz * (1 - (_egim min 0.6));
                    private _nx = (_p select 0) + ((sin _d2) * _vh * _dt);
                    private _ny = (_p select 1) + ((cos _d2) * _vh * _dt);
                    private _z = (_p select 2) + (((((_hedefZ + 0.03) - (_p select 2)) max (-3.5 * _dt)) min (2.2 * _dt)));
                    if ((_z - (getTerrainHeightASL [_nx, _ny])) > _enYuk) then { _enYuk = _z - (getTerrainHeightASL [_nx, _ny]); };
                    _u setDir _d2;
                    _u setPosASL [_nx, _ny, _z];
                    _u setVelocity [0, 0, 0];
                    sleep 0.04;
                };
                if (!isNull _u) then {
                    _u enableAI "PATH";
                    _u setVariable [QGVAR(yurAktif), nil];
                    if (alive _u) then { _u setUnitPos _stance; };
                    diag_log format ["[YURUYUS] %1 | bitti: %2 | %3 sn | hedefe kalan %4 m | en yuksek yuzey %5 m", name _u, _neden, round (time - _t0), round (_u distance2D _dest), _enYuk toFixed 1];
                };
            };
        } forEach (allUnits select {local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}});
    };
};
[] spawn _calis;
true
