#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MOTOR SESI FARKINDALIGI (v8.247; kullanici: "arac ses farkindaligi gelmeli, motoru duyabilmeliler; ayni sey helikopter ve ucak icin") — hile yok: DUSMAN gruplar,
 * calisan motorlu aracin SESINI mesafe / hiz / hava / arazi / kendi gurultusune gore duyar; kesin konum DEGIL, hata payli YON ve 'bir sey yaklasiyor' bilgisi verilir (ates sesi farkindaligi [SES] ile ayni ilke).
 * Mevcut sistemler: [SES] yalniz silah atesi; [HAVA-FARK] yalniz gorulen / bilinen heli-dron. Bu fonksiyon araç / ucak MOTORUNU duyma boslugunu doldurur. Kaynakta SAYISAL ESIK yok: TUM degerler TASARIM tahminidir.
 *
 * Kaynaklar (3 sn'de bir, tum makineler; motoru calisan, murettebatli, statik olmayan arac): taban duyulma menzili (m, sakin gunduz) hareketli / rolanti:
 *   tank 900 / 400 | zirhli tasiyici (IFV/APC) 700 / 300 | kamyon, cip 500 / 200 | helikopter (ucarken) 2500 / yerde rolanti 800 | ucak (jet) 4000, pervaneli 2500 | kucuk IHA 400
 *   Carpanlar: rolanti (hiz < 3 km/s) x0.45 (ucak / heli ucuyorsa 1); gece x1.3; yagmur (> 0.3) x0.7; ruzgar (> 6 m/sn) x0.75; sis (> 0.4) x0.9; dinleyici ile kaynak arasi arazi engeli (terrainIntersectASL) x0.6;
 *   dinleyici grup temasta (son 15 sn) x0.4 (catisma sesi bastirir); dinleyici bir bina icinde x0.8.
 * Dinleyici: dusman (getFriend < 0.6), YEREL, oyuncusuz, lideri yaya ve canli AI grubu; grup bu araci zaten biliyorsa (knowsAbout >= 0.5) dokunulmaz. Tepki: grup 'AWARE' (temasta degilse), lider + 2 asker hata payli yone bakar (doWatch ~15 sn);
 *   zirh sesi + grupta AT varsa AT askerleri hazir bakar; grup degiskenleri lambs_danger_motorSesT / Yon / Tip / Mesafe yazilir (diger sistemler okuyabilir). Hile yok: reveal verilmez (konum bilgisi yok).
 *   Yon hatasi: +-(8 + mesafe/60) derece. Grup basina 20 sn'de bir; tur basina en cok 8 dinleyici.
 * Kapatma: lambs_danger_motorSesOff = true. Log: [MOTOR-SES] (ilk 60 olay), 90 sn ozet [MOTOR-SES-OZET].
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_motorSesStarted") exitWith {false};
lambs_danger_motorSesStarted = true;

diag_log "[MOTOR-SES] motor sesi farkindaligi baslatildi (v8.247): arac / heli / ucak motoru mesafe + hava + arazi ile duyulur, yon hata payli (hile yok)";

private _calis = {
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_motorSesOff", false]) then { continue };
        // ortam carpani (tum kaynaklar icin ortak)
        private _gece = sunOrMoon < 0.1;
        private _env = (if (_gece) then {1.3} else {1}) * (if (rain > 0.3) then {0.7} else {1}) * (if ((vectorMagnitude wind) > 6) then {0.75} else {1}) * (if (fog > 0.4) then {0.9} else {1});
        private _kaynaklar = vehicles select {
            alive _x && {isEngineOn _x} && {!(_x isKindOf "StaticWeapon")} && {!(_x isKindOf "Ship")} && {(crew _x) findIf {alive _x} >= 0}
        };
        if (_kaynaklar isEqualTo []) then { continue };
        private _dinleyiciler = allGroups select {
            local _x && {!isNull (leader _x)} && {alive (leader _x)} && {!isPlayer (leader _x)} && {isNull objectParent (leader _x)} && {(side _x) isNotEqualTo civilian} && {(units _x) findIf {isPlayer _x} < 0}
        };
        if (_dinleyiciler isEqualTo []) then { continue };
        private _islenen = 0;
        {
            private _v = _x;
            private _sTaraf = side (group (effectiveCommander _v));
            if (_sTaraf isEqualTo civilian) then { continue };
            private _hiz = (speed _v) max 0;
            private _hava = _v isKindOf "Air";
            private _taban = 0;
            private _tip = "";
            // v8.290 PERVANE SESI (kullanici: 'dronun sesini duysunlar pervane sesini'; RPT 22-10 19:17: FPV'ye knowsAbout 0.00 ile 30-90 m'ye kadar tepki yok; ses 20 sn aralikla + arazi x0.6 ile gec / bir kez duyuldu):
            //   FPV (Crocus) pervanesi YUKSEK sesli: taban 700 m (lambs_danger_dronSesM), bomba / diger IHA 450, gozlem IHA 400; arazi engeli IHA'da x0.8 (ses yayilir); grup basina 5 sn'de bir; duyunca reveal (asagida)
            if (unitIsUAV _v) then {
                _tip = "IHA";
                private _ihaT = [_v] call FUNC(ihaTip);
                _taban = if (_ihaT in ["FPV-AT", "FPV-AP"]) then { missionNamespace getVariable ["lambs_danger_dronSesM", 700] } else { if (_ihaT isEqualTo "BOMBA") then {450} else {400} };
            }
            else { if (_v isKindOf "Helicopter") then { _tip = "HELI"; _taban = if (((getPosATL _v) select 2) > 3) then {2500} else {800}; }
            else { if (_v isKindOf "Plane") then { _tip = "UCAK"; _taban = if (_v isKindOf "UAV") then {400} else { if ((getNumber (configOf _v >> "maxSpeed")) > 600) then {4000} else {2500} }; }
            else { if (_hava) then { _tip = "IHA"; _taban = 400; }
            else { if (_v isKindOf "Tank") then { _tip = "TANK"; _taban = if (_hiz >= 3) then {900} else {400}; }
            else { if (_v isKindOf "Wheeled_APC_F" || {_v isKindOf "APC"} || {getNumber (configOf _v >> "armor") >= 120}) then { _tip = "ZIRHLI"; _taban = if (_hiz >= 3) then {700} else {300}; }
            else { _tip = "ARAC"; _taban = if (_hiz >= 3) then {500} else {200}; }; }; }; }; }; };
            if (_taban <= 0) then { continue };
            private _vp = getPosASL _v;
            {
                private _g = _x;
                if (_islenen >= 8) exitWith {};
                private _l = leader _g;
                if ((side _g) getFriend _sTaraf >= 0.6) then { continue };
                private _d = _l distance _v;
                if (_d > (_taban * _env * 1.0)) then { continue };
                if ((time - (_g getVariable [QGVAR(motorSesT), -999])) < ([20, 5] select (_tip isEqualTo "IHA"))) then { continue };
                if ((_g knowsAbout _v) >= 0.5) then { continue };
                private _m = _taban * _env;
                if ((_l distance _v) > _m) then { continue };
                // engel / gurultu carpanlari
                private _carp = 1;
                if (terrainIntersectASL [eyePos _l, _vp]) then { _carp = _carp * ([0.6, 0.8] select (_tip isEqualTo "IHA")); };
                if ((time - (_g getVariable ["lambs_danger_contact", -999])) < 15) then { _carp = _carp * 0.4; };
                if !(isNull (nearestBuilding _l)) then { if ((_l distance (nearestBuilding _l)) < 6) then { _carp = _carp * 0.8; }; };
                if (_d > (_m * _carp)) then { continue };
                // duyuldu: hata payli yon
                _g setVariable [QGVAR(motorSesT), time];
                _islenen = _islenen + 1;
                private _yon = (_l getDir _v) + (random [-1, 0, 1]) * (8 + _d / 60);
                private _bakisP = (getPosATL _l) getPos [(_d min 300) max 60, _yon];
                _g setVariable [QGVAR(motorSesYon), _yon];
                _g setVariable [QGVAR(motorSesTip), _tip];
                _g setVariable [QGVAR(motorSesMesafe), round _d];
                // v8.290: IHA pervane sesi duyuldu -> grup dronu BILIR (reveal; mesafeye gore seviye 0.45-1.3) -> fnc_havaFarkindalik / fnc_dronTepki (dagil + saklan + ates + operator yonu) devreye girer. Kapatma: lambs_danger_dronSesReveal = false.
                if (_tip isEqualTo "IHA" && {missionNamespace getVariable ["lambs_danger_dronSesReveal", true]}) then {
                    private _lvl = (0.45 + (0.85 * (1 - (_d / (_m max 1))))) min 1.3;
                    if (_lvl > (_g knowsAbout _v)) then { _g reveal [_v, _lvl]; };
                };
                private _temasta = (time - (_g getVariable ["lambs_danger_contact", -999])) < 15;
                if (!_temasta && {(behaviour _l) in ["SAFE", "CARELESS"]}) then { _g setBehaviour "AWARE"; };
                private _bak = (units _g) select {alive _x && {isNull objectParent _x}};
                { _x doWatch _bakisP; } forEach (_bak select [0, 3]);
                if (_tip in ["TANK", "ZIRHLI"]) then {
                    { if ((secondaryWeapon _x) isNotEqualTo "" && {(getNumber (configFile >> "CfgWeapons" >> (secondaryWeapon _x) >> "type")) == 4}) then { _x doWatch _bakisP; }; } forEach _bak;
                };
                [{ params ["_gg"]; if (!isNull _gg && {(time - (_gg getVariable [QGVAR(motorSesT), 0])) >= 14}) then { { if (alive _x && {isNull objectParent _x}) then { _x doWatch objNull; }; } forEach ((units _gg) select [0, 3]); }; }, [_g], 15] call CBA_fnc_waitAndExecute;
                _say set [_tip, (_say getOrDefault [_tip, 0]) + 1];
                if (_logN < 60) then {
                    _logN = _logN + 1;
                    diag_log format ["[MOTOR-SES] %1 (%2) duyuldu -> %3 | %4 m (menzil %5 m, ortam x%6, engel x%7) | yon %8 (hata +-%9 derece) | hiz %10 km/s | grup davranisi %11", _tip, typeOf _v, groupId _g, round _d, round _m, _env toFixed 2, _carp toFixed 2, round _yon, round (8 + _d / 60), round _hiz, behaviour _l];
                };
            } forEach _dinleyiciler;
        } forEach _kaynaklar;
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[MOTOR-SES-OZET] son 90 sn (duyulma sayaci): %1", (keys _say) apply { format ["%1:%2", _x, _say get _x] }]; };
            _say = createHashMap;
        };
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] motorSes betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
