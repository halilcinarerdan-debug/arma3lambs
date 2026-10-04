#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * NOKTA ELEMANI — TRAVELING OVERWATCH (v8.66): temas muhtemelken hareket halindeki squad'in onunde 2 askerlik gozetleme / nokta elemani.
 *
 * Doktrin ilkesi (genel; sayisal esik kaynakta yok — MCWP 3-11.2 / TC 3-21.76'da ayrintisi alintilanmadi): traveling overwatch = on takim ana govdenin ONUNDE gider, ana govde destek mesafesinde izler;
 * temas olursa on takim temas kurar, ana govde manevra / destek eder.
 * Kosullar (5 sn'de bir, yerel AI grup): >= 6 canli piyade, lider hareket halinde (> 4 km/s), temas YOK, taktik / retreat / evade / bounding / temas kesme / keskin nisanci / IED isi YOK,
 *   TEMAS MUHTEMEL: son temas bitiminden < 240 sn VEYA lider 700 m icinde bilinen dusman (nearTargets), VE serbest birakmadan sonra 20 sn gecmis.
 * Secim: 2 tufekli (gercek rol RIFLE; lider / saglikci / EOD / baski tufekcisi / UGL tasiyici / yan guvenlik disinda), hareket yonunde en onde olanlar.
 * Hareket: ana govdenin 55 m onundeki noktaya (yanal +-7 m) doMove; her 5 sn'de nokta lider hareketiyle ilerler; taktikKilit (8 sn) ile diger sistemler (cohesion, role station, dispersion) karismaz.
 * Serbest: kosullar bozulunca (durma / temas / taktik) -> doFollow. Kapatma: lambs_danger_noktaOff = true.   Log: [ZEKA-NOKTA] (atama, durum 30 sn'de bir, SERBEST + neden)
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_noktaStarted") exitWith {false};
lambs_danger_noktaStarted = true;

diag_log "[ZEKA-NOKTA] nokta elemani (traveling overwatch) watchdog'u baslatildi (v8.66)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_noktaAdim", "basladi"];
    private _logN = 0;
    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_noktaOff", false]) then { continue };
        private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
        private _uglFn = missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}];
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_noktaAdim", format ["grup %1", groupId _g]];

            private _canli = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x}};
            private _eski = (_g getVariable [QGVAR(noktaListe), []]) select {!isNull _x && {alive _x}};

            // serbest birakma / baslamama nedeni
            private _neden = "";
            if ((count _canli) < 6) then { _neden = "asker < 6"; };
            if (_neden isEqualTo "" && {(speed _l) <= 4}) then { _neden = "lider durdu / yavas"; };
            if (_neden isEqualTo "" && {(_g getVariable [QGVAR(contact), 0]) > time}) then { _neden = "temas"; };
            if (_neden isEqualTo "" && {
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
                || {(_g getVariable [QGVAR(iedIs), []]) isNotEqualTo []}
            }) then { _neden = "taktik / retreat / bounding / IED isi"; };

            // temas muhtemel mi
            private _muhtemel = "";
            if (_neden isEqualTo "") then {
                private _c = _g getVariable [QGVAR(contact), 0];
                if (_c > 0 && {(time - _c) < 240}) then { _muhtemel = format ["son temastan %1 sn", round (time - _c)]; };
                if (_muhtemel isEqualTo "") then {
                    private _nt = (_l nearTargets 700) findIf {(((_x select 2) getFriend (side _g)) < 0.6) && {(_x select 2) isNotEqualTo civilian} && {(_x select 2) isNotEqualTo sideUnknown}};
                    if (_nt >= 0) then { _muhtemel = "700 m icinde bilinen dusman"; };
                };
                if (_muhtemel isEqualTo "") then { _neden = "temas muhtemel degil"; };
                if (_neden isEqualTo "" && {(time - (_g getVariable [QGVAR(noktaGecT), -999])) < 20}) then { _neden = "serbest birakma bekleme (20 sn)"; };
            };

            if (_neden isNotEqualTo "") then {
                if (_eski isNotEqualTo []) then {
                    {
                        _x setVariable [QGVAR(noktaEk), nil];
                        _x setVariable [QGVAR(taktikKilit), nil];
                        _x doFollow _l;
                    } forEach _eski;
                    _g setVariable [QGVAR(noktaListe), []];
                    _g setVariable [QGVAR(noktaGecT), time];
                    if (_logN < 100) then { _logN = _logN + 1; diag_log format ["[ZEKA-NOKTA] %1 | SERBEST | neden: %2 | eleman:%3", groupId _g, _neden, _eski apply {name _x}]; };
                };
                continue;
            };

            // hareket yonu + nokta
            private _v = velocity _l;
            private _dir = if (((_v select 0) ^ 2 + (_v select 1) ^ 2) > 0.5) then { (_v select 0) atan2 (_v select 1) } else { getDir _l };
            private _lp = getPosATL _l;
            private _ileri = 55;
            private _P = _lp getPos [_ileri, _dir];
            if (surfaceIsWater _P) then { _ileri = 30; _P = _lp getPos [_ileri, _dir]; };
            if (surfaceIsWater _P) then { continue };

            // eleman secimi (yoksa / biri oldu ise tamamla)
            if ((count _eski) < 2) then {
                private _aday = _canli select {
                    !(_x isEqualTo _l) && {([_x, true] call _rolFn) isEqualTo "RIFLE"} && {!(_x getUnitTrait "medic")} && {!(_x getUnitTrait "explosiveSpecialist")}
                    && {!(_x getVariable [QGVAR(baskiTuf), false])} && {([_x] call _uglFn) isEqualTo ""} && {isNil {_x getVariable QGVAR(yanGuv)}}
                    && {!(_x getVariable [QGVAR(iedGuv), false])} && {!(_x getVariable [QGVAR(iedIsci), false])} && {!(_x in _eski)}
                    && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time} && {!(_x getVariable [QGVAR(forceMove), false])}
                };
                // hareket yonunde en onde olanlar
                private _sir = _aday apply { [((_lp distance2D _x) * (cos ((_lp getDir _x) - _dir))), _x] };
                _sir sort false;
                private _eksik = 2 - (count _eski);
                {
                    if (_forEachIndex < _eksik) then { _eski pushBack (_x select 1); };
                } forEach _sir;
                if ((count _eski) < 2 && {_eski isEqualTo []}) then { continue };
            };

            // her eleman kendi noktasina (yanal +-7 m): 10 m'den uzaksa doMove
            private _hareket = 0;
            {
                private _u = _x;
                private _Pi = _P getPos [7, _dir + ([90, -90] select (_forEachIndex mod 2))];
                _u setVariable [QGVAR(noktaEk), true];
                _u setVariable [QGVAR(taktikKilit), time + 8];
                // lidere 95 m'den uzaga kacmasin
                if ((_u distance2D _l) > 95) then { _Pi = _lp getPos [30, _dir]; };
                if ((_u distance2D _Pi) > 10) then { _u doMove _Pi; _hareket = _hareket + 1; };
            } forEach _eski;
            _g setVariable [QGVAR(noktaListe), _eski];

            // log: yeni atama / 30 sn'de bir durum
            private _imza = _eski apply {name _x};
            if ((_imza isNotEqualTo (_g getVariable [QGVAR(noktaImza), []])) || {(time - (_g getVariable [QGVAR(noktaLogT), -999])) > 30}) then {
                _g setVariable [QGVAR(noktaImza), _imza];
                _g setVariable [QGVAR(noktaLogT), time];
                if (_logN < 100) then {
                    _logN = _logN + 1;
                    diag_log format ["[ZEKA-NOKTA] %1 | NOKTA ELEMANI: %2 | temas muhtemel: %3 | ana govdenin %4 m onunde (gercek: %5 m ve %6 m) | hareket yonu:%7 | lider hiz:%8 km/s | yeni emir:%9",
                        groupId _g, _imza joinString ", ", _muhtemel, _ileri, round ((_eski select 0) distance2D _l), round ((_eski param [1, _l]) distance2D _l), round _dir, round (speed _l), _hareket];
                };
            };
        } forEach (allGroups select {local _x && {!isNull leader _x}});
        missionNamespace setVariable ["lambs_danger_noktaAdim", "tur bitti"];
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] nokta elemani betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_noktaAdim", "?"]];
        sleep 5;
    };
};

true
