#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ATIS USTUNLUGU (v8.355; kullanici: 'botlar bazen cok yavas kaliyor atis ustunlugu kurmada, saydirsin baskilasin'). Temasta bilinen dusman konumuna, hareket etmeyen askerlerin HEMEN ve SUREKLI bastirma atesi acmasi:
 * RPT 30-10'da [ATES-HAREKET-OZET] 'taban ates emri 0' idi (bounding / flank calisirken taban ates hic devreye girmiyordu) ve bounding kapisi 5.3-5.9 sn bekliyordu.
 *
 * ILKE (genel; kaynak setinde sayisal esik YOK [T]): manevra unsuru hareket etmeden once ates unsuru dusmani bastirir ve manevra boyunca surdurur (TC 3-21.76 / MCWP 3-11.1: bastirici ates + manevra; ates ustunlugu).
 * ISLEYIS (0.8 sn'de bir, tick butcesi 6 asker):
 *   - Grup: yerel, oyuncusuz, temasta (QGVAR(contact) damgasi > time), ates yasagi (GREEN / BLUE) ya da STEALTH degil, pusu (isAmbushing) / keskin nisanci takimi degil.
 *   - HEDEF: liderin 30-400 m icinde bilinen (knowsAbout >= 0.35) ve son 25 sn icinde gorulmus (targetKnowledge) en yakin dusman piyadesi / statik silah; hedef konumu +-3 m dagitilir. Grup basina 2 sn'de bir yenilenir.
 *   - ASKER: hareket etmiyor (< 1.5 km/s) ve hareket emri yok (currentCommand MOVE + hedefe > 8 m degil), taktikKilit / forceMove / yeniden doldurma / tedavi yok, teslim degil, son 2 sn ates etmemis (zaten ates ediyor),
 *     keskin nisanci / AT haric; mermi: >= 3 uyumlu sarjor (MG >= 2) ve yuklu sarjor > 25%. Hat uzerinde dost (8 derece koridor) ya da hedefe 12 m'de dost varsa atmaz; shouldSuppressPosition kapali (duvar) ise atmaz.
 *   - ILK TEMAS PATLAMASI (ilk 12 sn, 20 sn sessizlikten sonra): tum uygun askerler; sonra MG her zaman, tufekliler 8 sn'lik dilimlerde yarisi sirayla (mermi ekonomisi). Asker basina 4 sn'de bir emir.
 * Komut: doSuppressiveFire (doWatch KALICI birakilmaz). Kapatma: CBA 'ELITE siper' > Atis ustunlugu (lambs_danger_atisUstunlugu) ya da lambs_danger_atisUstunluguOff = true. Log: [ATIS-USTUNLUK] (ilk 40) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_atisUstunluguStarted") exitWith {false};
lambs_danger_atisUstunluguStarted = true;

diag_log "[ATIS-USTUNLUK] atis ustunlugu (surekli bastirma) watchdog baslatildi (v8.355)";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _sayac = createHashMapFromArray [["emir", 0], ["grup", 0], ["patlama", 0], ["hatDost", 0], ["duvar", 0]];
    private _sonOzet = time;
    private _logN = 0;

    while {true} do {
        sleep 0.8;
        if ((time - _sonOzet) >= 60) then {
            _sonOzet = time;
            if ((_sayac get "emir") > 0) then {
                diag_log format ["[ATIS-USTUNLUK-OZET] 60 sn: bastirma emri %1 | grup %2 | ilk temas patlamasi %3 | hatta dost (atilmadi) %4 | duvar / hat kapali (atilmadi) %5", _sayac get "emir", _sayac get "grup", _sayac get "patlama", _sayac get "hatDost", _sayac get "duvar"];
            };
            { _sayac set [_x, 0]; } forEach (keys _sayac);
        };
        if (missionNamespace getVariable ["lambs_danger_atisUstunluguOff", false] || {!(missionNamespace getVariable ["lambs_danger_atisUstunlugu", true])}) then { continue };
        private _butce = 6;
        private _supFn = missionNamespace getVariable ["lambs_main_fnc_shouldSuppressPosition", {true}];

        {
            private _g = _x;
            if (_butce <= 0) exitWith {};
            if (isNull _g || {!local _g}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then { continue };
            private _l = leader _g;
            if (isNull _l || {!alive _l} || {isPlayer _l}) then { continue };
            if ((combatMode _g) in ["GREEN", "BLUE"] || {(behaviour _l) isEqualTo "STEALTH"}) then { continue };
            if (_g getVariable [QGVAR(sniperTeam), false] || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(teslimOldu), false]}) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };

            // ---- hedef (2 sn'de bir) ----
            private _hd = _g getVariable [QGVAR(atisHedef), [0, []]];
            if ((time - (_hd select 0)) > 2) then {
                private _taraf = side _g;
                private _adaylar = (_l nearTargets 400) select {
                    private _o = _x select 4;
                    !isNull _o && {alive _o} && {(_taraf getFriend (side (group _o))) < 0.6} && {(side (group _o)) isNotEqualTo civilian}
                    && {(_o isKindOf "CAManBase") || {_o isKindOf "StaticWeapon"}} && {(_l knowsAbout _o) >= 0.35}
                    && {((_l targetKnowledge _o) select 2) > (time - 25)} && {(_l distance2D _o) >= 30}
                };
                private _poz = [];
                if (_adaylar isNotEqualTo []) then {
                    _adaylar = [_adaylar, [], {(_x select 4) distance2D _l}, "ASCEND"] call BIS_fnc_sortBy;
                    _poz = getPosATL ((_adaylar select 0) select 4);
                };
                _hd = [time, _poz];
                _g setVariable [QGVAR(atisHedef), _hd];
            };
            private _hedef = _hd select 1;
            if (_hedef isEqualTo []) then { continue };

            // ilk temas patlamasi: 20 sn sessizlikten sonra ilk 12 sn
            if ((time - (_g getVariable [QGVAR(atisSonT), -999])) > 20) then {
                _g setVariable [QGVAR(atisBasT), time];
                _sayac set ["grup", (_sayac get "grup") + 1];
            };
            _g setVariable [QGVAR(atisSonT), time];
            private _patlama = (time - (_g getVariable [QGVAR(atisBasT), -999])) < 12;
            private _dilim = (floor (time / 8)) mod 2;

            {
                private _u = _x;
                if (_butce <= 0) exitWith {};
                if (
                    !alive _u || {!local _u} || {isPlayer _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                    || {captive _u} || {_u getVariable [QGVAR(teslim), false]}
                    || {(speed _u) > 1.5} || {(time - (_u getVariable [QGVAR(atisT), -999])) < 4}
                    || {(time - (_u getVariable [QGVAR(sonAtisT), -999])) < 2}
                    || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                    || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []}
                    || {(primaryWeapon _u) isEqualTo ""}
                ) then { continue };
                // hareket emri var mi
                if ((currentCommand _u) isEqualTo "MOVE" && {(((expectedDestination _u) select 0) distance2D _u) > 8}) then { continue };
                private _rol = [_u] call _rolFn;
                if (_rol in ["AT", "MARKSMAN"]) then { continue };
                // sira: MG her zaman; tufekliler patlamada hepsi, sonra yarisi 8 sn dilimlerinde
                if (_rol isNotEqualTo "MG" && {!_patlama} && {((_forEachIndex mod 2) isNotEqualTo _dilim)}) then { continue };
                // mermi
                private _w = primaryWeapon _u;
                private _uyum = (compatibleMagazines _w) apply {toLower _x};
                private _yedek = {(toLower _x) in _uyum} count (magazines _u);
                if (_yedek < ([3, 2] select (_rol isEqualTo "MG")) || {(_u ammo _w) < 8}) then { continue };

                private _aim = _hedef getPos [random 3, random 360];
                private _uASL = eyePos _u;
                private _aASL = (ATLToASL _aim) vectorAdd [0, 0, 1];
                // hatta dost / hedefte dost
                private _mesafe = _u distance2D _aim;
                private _yon = _u getDir _aim;
                private _dost = ((_u nearEntities ["CAManBase", (_mesafe min 150)]) select {
                    _x isNotEqualTo _u && {alive _x} && {((side _g) getFriend (side (group _x))) >= 0.6}
                    && {((_x distance2D _aim) < 12) || {((abs ((((_u getDir _x) - _yon) + 540) mod 360 - 180)) < 8) && {(_u distance2D _x) < _mesafe}}}
                });
                if (_dost isNotEqualTo []) then { _sayac set ["hatDost", (_sayac get "hatDost") + 1]; _u setVariable [QGVAR(atisT), time]; continue };
                if (!([_u, _aASL vectorAdd [0, 0, 4]] call _supFn)) then { _sayac set ["duvar", (_sayac get "duvar") + 1]; _u setVariable [QGVAR(atisT), time]; continue };

                _u setVariable [QGVAR(atisT), time];
                _u doSuppressiveFire _aim;
                _butce = _butce - 1;
                _sayac set ["emir", (_sayac get "emir") + 1];
                if (_patlama) then { _sayac set ["patlama", (_sayac get "patlama") + 1]; };
                if (_logN < 40 && {(time - (_g getVariable [QGVAR(atisLogT), -999])) > 25}) then {
                    _g setVariable [QGVAR(atisLogT), time];
                    _logN = _logN + 1;
                    diag_log format ["[ATIS-USTUNLUK] %1 | %2 (%3) -> bastirma | hedef %4 m | %5 | yedek sarjor %6", groupId _g, name _u, _rol, round _mesafe, ["surdurme (MG + tuflek dilimi)", "ILK TEMAS PATLAMASI"] select _patlama, _yedek];
                };
            } forEach (units _g);
        } forEach allGroups;
    };
};

true
