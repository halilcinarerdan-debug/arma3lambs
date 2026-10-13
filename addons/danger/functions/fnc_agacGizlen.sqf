#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AGACLIK GIZLENME (v8.232; kullanici: "dron savasi basliyor; askerlere mumkun oldukca AWARE iken bile agaclik alanlara, kamufle olabilecekleri yerlere gecsinler") —
 * Duran (30 sn), temassiz (20 sn), AWARE / SAFE davranisli, plan DISI, bina / hendek / arac disindaki yerel AI piyade gruplari ACIKTA ise (lider 15 m'de < 4 agac / calı)
 * 150 m icinde AGAC ORTUSU en iyi noktaya (>= 6 agac / cali, 14 m icinde; yol / su / dik egim cezali) yerlesir: her asker agaclik icinde kendi noktasina gider, comelir (MIDDLE), doStop.
 *   Birakma: temas (5 sn), plana alinma ya da grup lideri baska emirle > 40 m uzaklasirsa. Grup basina 180 sn'de bir yer degisimi.
 * Kaynak ilkesi: ATP 3-21.8 gizleme / ortu (cover and concealment), hava gozetlemesine karsi dagilma ve agac altinda gizlenme (ATP 3-01.8 pasif onlemler); Ukrayna deneyimi: insansiz hava araci gozunden gizlenme.
 *   Sayilar (30 / 20 sn, 15 m, 150 m, 6 agac) TASARIM degeri. NOT: bu fork'ta cali / agac ARKASI gorusu MOD'a birakilmistir (bkz. fnc_kamuflaj); burada yalnizca KONUM secimi.
 * Muaf: Zeus 'HARIC' grubu, garnizon / karakol gruplari, 2'den fazla waypoint'i olan gruplar, lambs_danger_agacMuaf = true grup degiskeni. Kapatma: lambs_danger_agacGizlenOff = true.  Log: [AGAC-GIZLEN] (ilk 30).
 *
 * Arguments: None (acilista bir kez)
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_agacGizlenStarted") exitWith {false};
lambs_danger_agacGizlenStarted = true;
lambs_danger_agacLogN = 0;

private _agacSay = {
    params ["_p", ["_r", 14]];
    count (nearestTerrainObjects [_p, ["TREE", "BUSH", "SMALL TREE"], _r, false, true])
};
lambs_danger_agacSayFn = _agacSay;

[] spawn {
    while {true} do {
        sleep 10;
        if (missionNamespace getVariable ["lambs_danger_agacGizlenOff", false]) then { continue };
        private _grs = allGroups select {local _x && {!isNull leader _x} && {!isPlayer leader _x} && {alive leader _x} && {isNull objectParent leader _x} && {(side _x) in [west, east, independent]}};
        private _islem = 0;
        {
            private _g = _x;
            private _l = leader _g;
            // --- birakma kontrolu (gizlenmis grup)
            private _gz = _g getVariable [QGVAR(agacGizli), []];
            if (_gz isNotEqualTo []) then {
                private _birak = ((_g getVariable ["lambs_danger_contact", -999]) > (time - 5)) || {_g getVariable ["lambs_danger_planAktif", false]} || {(_l distance2D (_gz select 0)) > 40 && {(time - (_gz select 1)) > 20}};
                if (_birak) then {
                    _g setVariable [QGVAR(agacGizli), nil];
                    { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "AUTO"; _x doFollow _l; }; } forEach (units _g);
                };
                continue;
            };
            if (_islem >= 4) then { continue };
            // --- hareket takibi
            if ((speed _l) > 3) then { _g setVariable [QGVAR(agacHrkT), time]; };
            // --- uygunluk
            if ((time - (_g getVariable [QGVAR(agacHrkT), -999])) < 30) then { continue };
            if ((time - (_g getVariable [QGVAR(agacT), -999])) < 180) then { continue };
            if (((_g getVariable ["lambs_danger_contact", -999]) > (time - 20)) || {_g getVariable ["lambs_danger_planAktif", false]} || {_g getVariable [QGVAR(agacMuaf), false]}) then { continue };
            if (!((behaviour _l) in ["AWARE", "SAFE"]) || {((_g getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "KARAKOL_ARAC", "TASIMA", "RECON", "RECON_ARAC", "MEDEVAC"])} || {(_g getVariable ["lambs_danger_garnizonAlt", ""]) isNotEqualTo ""}) then { continue };
            if ((count (waypoints _g)) > 2 || {!((_g getVariable [QGVAR(hendekB), []]) isEqualTo [])} || {_g getVariable [QGVAR(hendekte), false]} || {_g getVariable [QGVAR(tasimaBekle), false]}) then { continue };
            if (((nearestBuilding _l) distance2D _l) < 12) then { continue };   // binada / binanin yaninda (garnizon, bina savunmasi)
            if (!(isNull (_l findNearestEnemy _l)) && {(_l distance2D (_l findNearestEnemy _l)) < 500}) then { continue };   // yakin bilinen dusman varsa gizlenme degil temas mantigi
            // --- aciktaysa en iyi agaclik noktasi
            private _mevcut = [getPosATL _l, 15] call lambs_danger_agacSayFn;
            if (_mevcut >= 4) then { continue };
            private _en = [];
            private _enS = -1e9;
            {
                private _r = _x;
                {
                    private _c = (getPosATL _l) getPos [_r, _x];
                    if (!surfaceIsWater _c) then {
                        private _n = [_c, 14] call lambs_danger_agacSayFn;
                        if (_n >= 6) then {
                            private _s = (_n min 25) - 0.05 * _r - ([0, 8] select (isOnRoad _c)) - ([0, 6] select (((surfaceNormal _c) select 2) < 0.93));
                            if (_s > _enS) then { _enS = _s; _en = _c; };
                        };
                    };
                } forEach [0, 45, 90, 135, 180, 225, 270, 315];
            } forEach [35, 70, 110, 150];
            if (_en isEqualTo []) then { _g setVariable [QGVAR(agacT), time - 120]; continue };   // uygun agaclik yok: 60 sn sonra tekrar bak
            _islem = _islem + 1;
            _g setVariable [QGVAR(agacT), time];
            _g setVariable [QGVAR(agacGizli), [_en, time]];
            private _dirB = (getPosATL _l) getDir _en;
            {
                private _u = _x;
                if (alive _u && {isNull objectParent _u} && {!isPlayer _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]}) then {
                    private _pt = _en getPos [2 + random 8, random 360];
                    _u enableAI "PATH"; _u enableAI "MOVE";
                    _u doMove _pt;
                    [_u, _pt, _g] spawn {
                        params ["_u", "_pt", "_g"];
                        private _bit = time + 60;
                        waitUntil { sleep 1; !alive _u || {(_u distance2D _pt) < 2.5} || {time > _bit} || {(_g getVariable [QGVAR(agacGizli), []]) isEqualTo []} };
                        if (alive _u && {(_g getVariable [QGVAR(agacGizli), []]) isNotEqualTo []}) then {
                            doStop _u;
                            _u setUnitPos "MIDDLE";
                        };
                    };
                };
            } forEach (units _g);
            lambs_danger_agacLogN = lambs_danger_agacLogN + 1;
            if (lambs_danger_agacLogN <= 30) then {
                diag_log format ["[AGAC-GIZLEN] %1 | acikta (%2 agac) -> agaclik %3 (%4 agac, %5 m) | beh %6", groupId _g, _mevcut, mapGridPosition _en, [_en, 14] call lambs_danger_agacSayFn, round ((getPosATL _l) distance2D _en), behaviour _l];
            };
        } forEach _grs;
    };
};

diag_log "[AGAC-GIZLEN] agaclik gizlenme baslatildi (v8.232): duran / temassiz / AWARE grup acikta ise 150 m icinde agac ortulu noktaya";
true
