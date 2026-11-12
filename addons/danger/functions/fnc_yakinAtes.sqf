#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YAKIN MESAFE ATES KALIBRASYONU (v8.510; kullanici: 'cok yakin mesafelerde bot ates etmiyor, 1 metre kala falan').
 * Neden: Arma AI cok yakin (< ~3 m) hedefe sik sik ATES ETMEZ (hedefle namlu ic ice, silah kaldirma / nisan animasyonu, 'dur-bekle' emri, pusu / ates yasagi, doFire emri yutulur);
 * fnc_cqbReflex yalniz 4 sn'de bir doTarget + doFire komutu verir (komut, AI karar verir; 1 m'de yutuluyor) ve TESPIT (0.8) bilgi ister.
 * Bu bekci 0.3 sn'de bir, BILDIGI (knowsAbout >= 0.3; hile yok) dusman <= 7 m (CBA lambs_danger_yakinAtesM) ise:
 *   - namlu / tufek secili degilse tufege gecer (roketatar elinde dusman 7 m'de bos),
 *   - RAYCAST: gozden dusmanin govdesine hat (FIRE LOD) temiz degilse (duvar / kapi arada) ATMAZ; hatta dost (0.7 m serit, hedeften yakin) varsa ATMAZ,
 *   - doWatch + doTarget; nisan hedefe oturdu mu (aimedAtTarget >= 0.25) -> forceWeaponFire (mevcut muzzle / mod); 0.3-0.45 sn aralik,
 *   - baygin / esir / teslim hedefe atmaz. Pusu / ates yasagi (GREEN / BLUE) 7 m'de iptal (kasitli: bu mesafede temas acilmistir).
 * ATLANIR: oyuncu, arac, baygin, teslim, sarjor bos, yeniden doldurma. Kapatma: lambs_danger_yakinAtes = false.  Log: [YAKIN-ATES] (ilk 40) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yakinAtesStarted") exitWith {false};
lambs_danger_yakinAtesStarted = true;
diag_log "[YAKIN-ATES] yakin mesafe ates kalibrasyonu baslatildi (v8.510): bilinen dusman <= 7 m -> raycast + nisan oturunca forceWeaponFire";

[] spawn {
    private _indeks = 0;
    private _say = createHashMapFromArray [["ates", 0], ["engel", 0], ["dost", 0], ["nisan", 0]];
    private _ozetT = time + 60;
    private _logN = 0;
    while {true} do {
        sleep 0.3;
        if !(missionNamespace getVariable ["lambs_danger_yakinAtes", true]) then { continue };
        private _menzil = missionNamespace getVariable ["lambs_danger_yakinAtesM", 7];
        private _adaylar = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side group _x) in [west, east, resistance]}
            && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!captive _x} && {!(_x getVariable [QGVAR(teslim), false])}
            && {(primaryWeapon _x) isNotEqualTo ""} && {time >= (_x getVariable [QGVAR(yakinAtesT), 0])}
        };
        private _n = count _adaylar;
        if (_n > 0) then {
            private _kesit = 14 min _n;
            for "_i" from 0 to (_kesit - 1) do {
                private _u = _adaylar select ((_indeks + _i) mod _n);
                private _e = _u findNearestEnemy _u;
                if (isNull _e || {!alive _e} || {!(_e isKindOf "CAManBase")} || {captive _e} || {(lifeState _e) in ["INCAPACITATED", "UNCONSCIOUS"]} || {_e getVariable ["ACE_isUnconscious", false]}) then { continue };
                private _d = _u distance _e;
                if (_d > _menzil) then { continue };
                if ((_u knowsAbout _e) < (["SEZILDI"] call FUNC(bilgiEsik))) then { continue };
                if ((_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []) then { continue };
                // roketatar / UGL elindeyse tufege don
                private _pw = primaryWeapon _u;
                if ((currentWeapon _u) isNotEqualTo _pw && {!(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false])}) then { _u selectWeapon _pw; };
                private _mz = currentMuzzle _u;
                if (_mz isEqualTo "" || {(_u ammo _mz) <= 0}) then { continue };
                // RAYCAST: goz -> govde hatti temiz mi (arada duvar / kapi / cit yok)
                private _eye = eyePos _u;
                private _hedef = aimPos _e;
                if ((lineIntersectsSurfaces [_eye, _hedef, _u, _e, true, 1, "FIRE", "NONE"]) isNotEqualTo []) then {
                    _say set ["engel", (_say get "engel") + 1];
                    _u setVariable [QGVAR(yakinAtesT), time + 0.6];
                    continue;
                };
                // hatta dost (hedeften yakin, 0.7 m serit)
                private _yon = _hedef vectorDiff _eye;
                private _dost = ((_u nearEntities ["CAManBase", _d + 1]) findIf {
                    _x isNotEqualTo _u && {_x isNotEqualTo _e} && {alive _x} && {((side group _u) getFriend (side group _x)) >= 0.6}
                    && {
                        private _v = (eyePos _x) vectorDiff _eye;
                        private _t = ((_v vectorDotProduct _yon) / ((vectorMagnitudeSqr _yon) max 0.01));
                        _t > 0.05 && {_t < 1} && {(vectorMagnitude (_v vectorDiff (_yon vectorMultiply _t))) < 0.7}
                    }
                }) > -1;
                if (_dost) then {
                    _say set ["dost", (_say get "dost") + 1];
                    _u setVariable [QGVAR(yakinAtesT), time + 0.8];
                    continue;
                };
                _u doWatch _e;
                _u doTarget _e;
                private _aim = _u aimedAtTarget [_e, _mz];
                if (_aim >= 0.25) then {
                    _u forceWeaponFire [_mz, currentWeaponMode _u];
                    _say set ["ates", (_say get "ates") + 1];
                    _u setVariable [QGVAR(yakinAtesT), time + (0.3 + (random 0.15))];
                    if (_logN < 40) then {
                        _logN = _logN + 1;
                        diag_log format ["[YAKIN-ATES] %1 | %2 | dusman %3 m | nisan %4 | forceWeaponFire (%5)", groupId (group _u), name _u, _d toFixed 1, _aim toFixed 2, _mz];
                    };
                } else {
                    _say set ["nisan", (_say get "nisan") + 1];
                    _u setVariable [QGVAR(yakinAtesT), time + 0.2];
                };
            };
            _indeks = _indeks + _kesit;
        };
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "ates") + (_say get "engel") + (_say get "dost") + (_say get "nisan")) > 0) then {
                diag_log format ["[YAKIN-ATES-OZET] 60 sn: forceWeaponFire %1 | hat engelli %2 | hatta dost %3 | nisan oturmadi %4", _say get "ates", _say get "engel", _say get "dost", _say get "nisan"];
            };
            { _say set [_x, 0]; } forEach ["ates", "engel", "dost", "nisan"];
        };
    };
};
true
