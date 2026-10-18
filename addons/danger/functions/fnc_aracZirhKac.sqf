#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC ZIRHTAN KACIS (v8.250) — kullanici (RPT 4cceba48, 18:31-18:48): "apcler tanktan kacmali, eger avlayacak donanima sahip degillerse; bu derece bir facia yasandi".
 * Olay: EAST T-14 (zirh 500) tek basina WEST'in 6 BTR-80'ini ve ~40 piyadeyi yok etti (tek tankcinin 19+ olumu); BTR'ler 'ZIRH DESTEK (geri cekilmez)' ile tank hedeflendi (planZirh 'HEDEF rhs_t14_tv 543 m'), gorus hatti
 * olmayan pozisyonlarda durdu, tasinamaz (canMove false) araca yine surus emri verildi. Kitap: ATP 3-20.15 3-95 / 3-97 (beklenmeyen ustun kuvvet: durumu bildir, alternatif harekat oner / temas kes); TC 3-21.76 13-7 (temas disindakiler yer degistirir).
 * Kural (2 sn'de bir, YEREL, AI suruculu, oyuncusuz kara araclari — TANK siniflari, ATGM'li araclar, topcu ve nakil yolundaki (tasimaMesgul) araclar HARIC): arac AT yetenegine sahip degilse (aracSinif: TANK degil ve atgm yok)
 * ve BILINEN, GERCEK dusman TANKI (CfgVehicles armor >= 300) <= 1200 m'de ise: arac gorus hattini kiran (tank gozunden engelli) bir konuma ceker (tanktan uzaga +-100 derece, 150 / 250 / 350 m, su / bina yakini degil; engel yoksa en uzak)
 *   ve savas modunu GREEN yapar (konumu ele vermez; kendini savunur). Tehdit 25 sn yoksa onceki mod geri verilir. planZirh bu araca 10 sn dokunmaz (hedef / hareket emri vermez). Sayilar TASARIM. Duman atma YOK (arac duman atici API'si dogrulanmadi).
 * Kapatma: lambs_danger_aracZirhKacOff = true.  Log: [ARAC-ZIRH-KAC] (ilk 60 olay).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_aracZirhKacStarted") exitWith {false};
lambs_danger_aracZirhKacStarted = true;

diag_log "[ARAC-ZIRH-KAC] arac zirhtan kacis watchdog'u baslatildi (v8.250): AT yetenegi olmayan arac bilinen dusman tankindan gorus hattini kirarak ceker";

private _calis = {
    private _logN = 0;
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_aracZirhKacOff", false]) then { continue };
        {
            private _v = _x;
            if (!local _v || {!alive _v} || {!(_v isKindOf "LandVehicle")} || {_v isKindOf "StaticWeapon"}) then { continue };
            private _d = driver _v;
            if (isNull _d || {!alive _d} || {isPlayer _d} || {(crew _v) findIf {isPlayer _x} >= 0}) then { continue };
            if (_v getVariable [QGVAR(tasimaMesgul), false]) then { continue };
            private _sn = [_v] call FUNC(aracSinif);
            if ((_sn select 0) in ["TANK", "TOPCU"] || {_sn select 3}) then { continue };
            private _g = group _d;
            private _l = leader _g;
            private _tf = side _g;
            if (_tf isEqualTo civilian) then { continue };
            // bilinen gercek dusman tanki <= 1200 m
            private _tank = objNull;
            private _tD = 99999;
            {
                private _o = _x select 4;
                if (!isNull _o && {alive _o} && {_o isKindOf "Tank"} && {(getNumber (configOf _o >> "armor")) >= 300} && {(_tf getFriend (_x select 2)) < 0.6}
                    && {[_o] call FUNC(gercekHedef)} && {(_l knowsAbout _o) >= 0.3}) then {
                    private _dd = _v distance2D _o;
                    if (_dd < _tD && {_dd <= 1200}) then { _tD = _dd; _tank = _o; };
                };
            } forEach (_l nearTargets 1300);
            private _aktif = _v getVariable [QGVAR(zirhKacAktif), false];
            if (isNull _tank) then {
                if (_aktif && {(time - (_v getVariable [QGVAR(zirhKacSonT), 0])) > 25}) then {
                    _v setVariable [QGVAR(zirhKacAktif), nil];
                    _g setCombatMode (_v getVariable [QGVAR(zirhKacMod), "YELLOW"]);
                    diag_log format ["[ARAC-ZIRH-KAC] %1 (%2) tehdit gecti (25 sn) -> savas modu %3'e geri", getText (configOf _v >> "displayName"), groupId _g, _v getVariable [QGVAR(zirhKacMod), "YELLOW"]];
                };
                continue
            };
            _v setVariable [QGVAR(zirhKacSonT), time];
            if ((time - (_v getVariable [QGVAR(zirhKacT), -999])) < 8) then { continue };
            _v setVariable [QGVAR(zirhKacT), time];
            if !(_aktif) then {
                _v setVariable [QGVAR(zirhKacMod), combatMode _g];
                _v setVariable [QGVAR(zirhKacAktif), true];
            };
            // gorus hattini kiran konum
            private _tp = getPosATL _tank;
            private _vp = getPosATL _v;
            private _uzak = _tp getDir _vp;
            private _tEye = (AGLToASL _tp) vectorAdd [0, 0, 2.5];
            private _en = [];
            private _enS = -1e9;
            {
                private _b = _uzak + _x;
                {
                    private _cand = _vp getPos [_x, _b];
                    if (!surfaceIsWater _cand && {(nearestObjects [_cand, ["House"], 8]) isEqualTo []}) then {
                        private _engel = (lineIntersectsSurfaces [_tEye, (AGLToASL _cand) vectorAdd [0, 0, 1.5], _tank, objNull, true, 1, "VIEW", "FIRE"]) isNotEqualTo [];
                        private _s = (if (_engel) then {100} else {0}) + ((_cand distance2D _tp) / 10) - (_x / 8) + (count (nearestTerrainObjects [_cand, ["TREE", "BUSH"], 25]));
                        if (_s > _enS) then { _enS = _s; _en = _cand; };
                    };
                } forEach [150, 250, 350];
            } forEach [0, 25, -25, 50, -50, 75, -75, 100, -100];
            if (_en isEqualTo []) then { _en = _vp getPos [300, _uzak]; };
            _g setCombatMode "GREEN";
            _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
            _d doMove _en;
            if (_logN < 60) then {
                _logN = _logN + 1;
                diag_log format ["[ARAC-ZIRH-KAC] %1 (%2, sinif %3) | bilinen dusman tanki %4 (zirh %5) %6 m -> gorus hattini kiran konuma cekiliyor %7 (%8 m, engel %9) | savas modu GREEN (onceki %10)",
                    getText (configOf _v >> "displayName"), groupId _g, _sn select 0, getText (configOf _tank >> "displayName"), getNumber (configOf _tank >> "armor"), round _tD, mapGridPosition _en, round (_vp distance2D _en),
                    _enS >= 90, _v getVariable [QGVAR(zirhKacMod), "?"]];
            };
        } forEach vehicles;
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] aracZirhKac betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
