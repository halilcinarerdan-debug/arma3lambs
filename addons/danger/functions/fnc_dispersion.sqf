#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DAGILMA BILINCI — askerler bitisik durmasin: tek el bombasi / RPG hepsini oldurmesin.
 *
 * Arma formasyonlari cok sikisik (3-4 m); catismada 3+ asker ayni noktada yigilinca tek bir
 * el bombasi / roket / HE hepsini alir. Bu watchdog (server / HC basina bir kez baslar, 3 sn'de bir)
 * catisma halindeki gruplarda YIGILMAYI bozar:
 *
 *   - YIGILMA: bir askerin etrafinda (yaricap) 2+ dost varsa (yani 3+ kisi) = yigilma. 2 kisilik buddy
 *     cifti yigilma SAYILMAZ (doktrin: cift birlikte).
 *   - TEHDIT BILINCI: bilinen dusman launcher'li piyade / tank / APC (350m) varsa yaricap 5 -> 8 m
 *     (RPG / HE alan etkisi buyuktur)
 *   - Yigilmanin merkezinden uzaga, 7-10 m'ye tasinir; yakinda (15m) SIPER varsa orayi tercih eder
 *     (findCover DEFEND; merkezden >= yaricap, baska dostun 4m icinde degil)
 *   - grup basina tikte en fazla 2 asker, asker basina 10 sn cooldown
 *   - ATLANIR: hareket ederken (forceMove / hizli), baski >= 0.6 (FSM siper alir), binada,
 *     rol istasyonuna yeni gonderilen asker (fnc_roleStation, 25 sn),
 *     oyuncu, retreat / evade / temas kes / AT taarruz (kendi hareket duzenleri var)
 *   - doMove (kalici emir): asker oraya gider ve orada KALIR (formasyon slotuna geri cekilmez)
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_dispersionStarted") exitWith {false};
lambs_danger_dispersionStarted = true;

diag_log "[DAGILMA] dagilma bilinci watchdog baslatildi";

[] spawn {
    while {true} do {
        sleep 3;
        private _butce = 6;   // tikte en fazla bu kadar findCover (tum gruplar)

        {
            private _g = _x;
            if (isNull _g) then { continue };
            if ((count (units _g)) < 3) then { continue };

            // Sadece CATISMA halindeki gruplar
            private _savasta = ((_g getVariable [QGVAR(contact), 0]) > time) || {_g getVariable [QGVAR(isBounding), false]};
            if (!_savasta) then { continue };

            // Kendi hareket duzeni olan taktikler: atla
            if (
                (_g getVariable [QGVAR(isRetreating), false])
                || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isATEngage), false]}
                || {_g getVariable [QGVAR(isExecutingTactic), false]}
                || {((_g getVariable [QGVAR(cmdLastDecision), ""]) in ["FLANK", "ASSAULT", "SUPPRESS_ASSAULT"]) && {(time - (_g getVariable [QGVAR(cmdSonKararZaman), -999])) < 30}}
            ) then { continue };

            private _leader = leader _g;
            if (isNull _leader || {isPlayer _leader}) then { continue };

            // Uygun birimler
            private _u = (units _g) select {
                alive _x
                && {local _x}
                && {isNull objectParent _x}
                && {!isPlayer _x}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]}
                && {!(_x getVariable [QGVAR(forceMove), false])} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time}
                && {(speed _x) < 1.5}
                && {(getSuppression _x) < 0.6}
                && {(insideBuilding _x) < 0.5}
                && {(time - (_x getVariable [QGVAR(stationLast), -999])) > 25}
                && {(_x getVariable [QGVAR(stationPos), []]) isEqualTo []}
                && {(_x getVariable [QGVAR(reloadState), []]) isEqualTo []}
                && {(_x getVariable [QGVAR(grState), []]) isEqualTo []}
            };
            if ((count _u) < 3) then { continue };

            // TEHDIT BILINCI: launcher'li dusman piyade / tank / APC
            private _tehditler = _leader targets [true, 450];   // v8.93: 350 -> 450 m (kullanici: karsida RPG goruldu ise mesafe / yigilma yok)
            private _buyukTehdit = (_tehditler findIf {
                ((secondaryWeapon _x) isNotEqualTo "")
                || {(vehicle _x) isKindOf "Tank"}
                || {(vehicle _x) isKindOf "Wheeled_APC_F"}
            }) > -1;
            private _yaricap = [9, 16] select _buyukTehdit;   // v7.5: 5/8 -> 9/14 (tek RPG / el bombasi hepsini almasin)

            // Komsu sayilari
            private _komsuSay = _u apply {
                private _a = _x;
                [count (_u select {_x isNotEqualTo _a && {(_x distance2D _a) < _yaricap}}), _a]
            };

            // En kalabalik asker (komsu >= 2 = 3+ kisilik yigilma); lideri tercihen yerinde birak
            private _tasinan = 0;
            private _sirali = [];
            private _gecici = +_komsuSay;
            while {_gecici isNotEqualTo []} do {
                private _enIyi = 0;
                private _enIyiSay = -1;
                {
                    if ((_x select 0) > _enIyiSay) then {
                        _enIyiSay = _x select 0;
                        _enIyi = _forEachIndex;
                    };
                } forEach _gecici;
                _sirali pushBack (_gecici select _enIyi);
                _gecici deleteAt _enIyi;
            };

            {
                _x params ["_say", "_a"];
                if (_say >= 2 && {_tasinan < 2} && {_a isNotEqualTo _leader}
                    && {(time - (_a getVariable [QGVAR(dispLast), -999])) > 10}) then {

                    _a setVariable [QGVAR(dispLast), time];
                    _tasinan = _tasinan + 1;

                    private _apos = getPosATL _a;
                    private _yakin = _u select {_x isNotEqualTo _a && {(_x distance2D _a) < _yaricap}};
                    private _merkez = _apos;
                    if (_yakin isNotEqualTo []) then {
                        private _toplam = [0, 0, 0];
                        { _toplam = _toplam vectorAdd (getPosATL _x); } forEach _yakin;
                        _merkez = _toplam vectorMultiply (1 / (count _yakin));
                    };
                    private _dir = _merkez getDir _apos;

                    // Hedef: merkezden uzaga 7-10m; yakinda siper varsa orayi tercih et
                    private _hedef = _apos getPos [(_yaricap + 3) max 12, _dir + ((random 40) - 20)];

                    private _dusman = _a findNearestEnemy _a;
                    if (!isNull _dusman && {_butce > 0}) then {
                        _butce = _butce - 1;
                        private _cover = [_a, _dusman, 15, "ASCEND", 1, "DEFEND"] call EFUNC(main,findCover);
                        if (_cover isNotEqualTo []) then {
                            private _cp = (_cover select 0) select 0;
                            private _digerYakin = (_u select {_x isNotEqualTo _a && {(_x distance2D _cp) < 4}}) isNotEqualTo [];
                            if ((_cp distance2D _merkez) >= _yaricap && {!_digerYakin}) then {
                                _hedef = _cp;
                            };
                        };
                    };

                    if (!surfaceIsWater _hedef) then {
                        _a doMove _hedef;
                        _a setUnitPosWeak "MIDDLE";
                        diag_log format [
                            "[DAGILMA] %1 | %2 | komsu:%3 | yaricap:%4m%5 | tasindi",
                            groupId _g, name _a, _say, _yaricap, ["", " (RPG/zirh tehdidi)"] select _buyukTehdit
                        ];
                    };
                };
            } forEach _sirali;
        } forEach allGroups;
    };
};

true
