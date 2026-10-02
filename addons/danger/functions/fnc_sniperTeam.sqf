#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KESKIN NISANCI TAKIMI — nisanci + (varsa) gozlemci, ana timin buddy / formasyon / komutan yapisindan AYRI.
 *
 * 1) CIKARMA (4 sn'de bir): yerel AI grubunda keskin nisanci (fnc_isSniper) varsa, nisanci + gozlemci
 *    (sinif adi "spotter" ya da 20 m icindeki en yakin TUFEKLI; lider / MG / AT / saglikci degil) AYRI bir
 *    "<grup> SNIPER" grubuna alinir (kalan tim en az 2 kisi kalmali). Boylece ana timin buddy cifti, dagilma,
 *    rol istasyonu, bounding, geri cekilme, komutan beyni ve "<4 asker temas kes" mantigina GIRMEZLER.
 *    Ana grup oldugunde / bosaldiginda ekip bagimsiz kalir (flag temizlenir).
 *
 * 2) DAVRANIS (3 sn'de bir):
 *    - BARIS (temas yok): ana komutanin ARKA-YAN tarafinda 70 m'de formasyonu izler (komutan yonune gore sag/sol
 *      yan sabit; 35 m'den fazla koparsa istasyona doner). Davranis AWARE.
 *    - TEMAS: bilinen en yakin dusmana LOS'lu, 140-700 m, yuksek / ortulu, dost 20 m'den uzak, ana komutandan
 *      <= 160 m, onceki (yanmis) pozisyonlardan >= 50 m, SEKTOR: ana timin onunde degil (yan / arka) nokta secer.
 *      Varinca YATAR (DOWN) + STEALTH + combatMode YELLOW. Gozlemci GREEN (ates etmez, yerini ele vermez),
 *      nisanciya hedef bildirir (reveal). Hedef onceligi: MG / AT / lider / digerleri (mesafeyle azalan).
 *    - STEALTH ENTEGRASYONU: tespit edilmediyse (kimse bilgisinde >= 1.5 yok) sessiz kalir: ilk atis oncesi
 *      posizyon degistirmez. Yakilirsa (baski >= 0.5 / dusman <= 150 m ve nisanciyi biliyor) "ates + yer degistir":
 *      mevcut pozisyon cezali isaretlenir, 20 sn'de yeni pozisyon aranir.
 *    - Dusman <= 70 m: ana komutanin arkasina cekilir, davranis COMBAT, ates serbest.
 *
 *    RPT: [SNIPER] satirlari.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_sniperTeamStarted") exitWith {false};
lambs_danger_sniperTeamStarted = true;

diag_log "[SNIPER] keskin nisanci takimi watchdog baslatildi";

[] spawn {
    private _isSn = missionNamespace getVariable ["lambs_danger_fnc_isSniper", {false}];
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];

    // Hedef onceligi
    private _oncelik = {
        params ["_e", "_ref"];
        private _p = 1;
        if (_e isKindOf "CAManBase") then {
            if (_e isEqualTo (leader (group _e))) then { _p = 2; };
            if ((secondaryWeapon _e) isNotEqualTo "") then { _p = 3; };
            if (([_e] call _rolFn) isEqualTo "MG") then { _p = 3; };
        } else { _p = 0; };
        _p - ((_e distance2D _ref) / 500)
    };

    // Pozisyon secimi
    private _pozSec = {
        params ["_s", "_pl", "_dusman", "_kotu"];
        private _lp = getPosATL _pl;
        private _tp = getPosATL _dusman;
        private _b = _lp getDir _tp;
        private _tASL = eyePos _dusman;
        private _en = [];
        private _enSkor = -999;
        private _yonler = [75, -75, 110, -110, 140, -140, 180, 45, -45];
        private _mesafeler = [60, 100, 140];
        {
            private _ang = _b + _x;
            {
                private _c = _lp getPos [_x, _ang];
                if (!surfaceIsWater _c) then {
                    private _de = _c distance2D _tp;
                    if (_de >= 140 && {_de <= 700}) then {
                        private _a = (AGLToASL _c) vectorAdd [0, 0, 0.5];
                        private _los = !(terrainIntersectASL [_a, _tASL]) && {!(lineIntersects [_a, _tASL, _s, _dusman])};
                        private _skor = if (_los) then {6} else {-8};
                        _skor = _skor + ((((getTerrainHeightASL _c) - (getTerrainHeightASL _tp)) / 10) max -2 min 3);
                        _skor = _skor + (((count (nearestTerrainObjects [_c, ["TREE", "BUSH", "ROCK", "WALL", "BUILDING", "HIDE"], 5, false, true])) min 3) * 0.8);
                        _skor = _skor + (4 - ((abs (_de - 320)) / 120));
                        if (_de < 160) then { _skor = _skor - 3; };
                        if ((_kotu findIf {(_c distance2D _x) < 50}) > -1) then { _skor = _skor - 6; };
                        if (((units (group _pl)) findIf {alive _x && {(_x distance2D _c) < 20}}) > -1) then { _skor = _skor - 3; };
                        if (_skor > _enSkor) then { _enSkor = _skor; _en = _c; };
                    };
                };
            } forEach _mesafeler;
        } forEach _yonler;
        if (_enSkor < 0) then { [] } else { _en }
    };

    while {true} do {
        sleep 3;

        // =================================================================
        // 1) CIKARMA — ana gruplardaki keskin nisancilari ayri takima al
        // =================================================================
        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            if (missionNamespace getVariable ["lambs_danger_sniperTeamOff", false]) then { continue };
            if (_g getVariable [QGVAR(sniperTeam), false]) then { continue };
            if ((count (units _g)) < 4) then { continue };
            private _l = leader _g;
            if (isNull _l || {!alive _l} || {isPlayer _l}) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };

            private _adaylar = (units _g) select {
                alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
                && {_x isNotEqualTo _l} && {[_x] call _isSn}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]}
            };
            if (_adaylar isEqualTo []) then { continue };
            private _s = _adaylar select 0;

            // gozlemci: sinif adinda spotter, yoksa 20 m icindeki en yakin tufekli
            private _sp = objNull;
            private _gA = (units _g) select {
                alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
                && {_x isNotEqualTo _s} && {_x isNotEqualTo _l}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]}
            };
            private _spAd = _gA select {((toLower (typeOf _x)) find "spotter") >= 0};
            if (_spAd isNotEqualTo []) then {
                _sp = _spAd select 0;
            } else {
                private _riflemen = _gA select {
                    (([_x] call _rolFn) isEqualTo "RIFLE") && {(_x distance2D _s) < 20}
                };
                if (_riflemen isNotEqualTo []) then {
                    _sp = ([_riflemen, [], {_x distance2D _s}, "ASCEND"] call BIS_fnc_sortBy) select 0;
                };
            };

            private _takim = [_s];
            if (!isNull _sp) then { _takim pushBack _sp; };
            if (((count (units _g)) - (count _takim)) < 2) then { continue };

            private _ng = createGroup [side _g, true];
            _takim joinSilent _ng;
            _ng selectLeader _s;
            _ng setVariable [QGVAR(sniperTeam), true];
            _ng setVariable [QGVAR(sniperParent), _g];
            _ng setVariable [QGVAR(sniperSide), selectRandom [1, -1]];
            _ng setBehaviour "AWARE";
            _ng setCombatMode "YELLOW";
            _ng setFormation "FILE";
            diag_log format [
                "[SNIPER] %1 | nisanci:%2 (%3) | gozlemci:%4 | ana tim:%5 kisi",
                groupId _g, name _s, primaryWeapon _s, if (isNull _sp) then {"yok"} else {name _sp}, count (units _g)
            ];
        } forEach allGroups;

        // =================================================================
        // 2) DAVRANIS
        // =================================================================
        {
            private _ng = _x;
            if (isNull _ng || {!local _ng}) then { continue };
            if !(_ng getVariable [QGVAR(sniperTeam), false]) then { continue };

            private _takim = (units _ng) select {alive _x && {isNull objectParent _x}};
            if (_takim isEqualTo []) then { continue };

            private _pg = _ng getVariable [QGVAR(sniperParent), grpNull];
            private _pUyeler = if (isNull _pg) then {[]} else {(units _pg) select {alive _x}};
            if (_pUyeler isEqualTo []) then {
                // ana tim yok: bagimsiz birak
                _ng setVariable [QGVAR(sniperTeam), false];
                _ng setBehaviour "AWARE";
                { _x setUnitPos "AUTO"; } forEach _takim;
                diag_log format ["[SNIPER] %1 | ana tim kalmadi: bagimsiz", groupId _ng];
                continue;
            };

            private _s = leader _ng;
            if (!alive _s) then { _s = _takim select 0; _ng selectLeader _s; };
            private _sp = (_takim - [_s]) param [0, objNull];
            private _pl = leader _pg;
            if (isNull _pl || {!alive _pl}) then { _pl = _pUyeler select 0; };

            private _lp = getPosATL _pl;
            private _dusman = _pl findNearestEnemy _pl;
            if (isNull _dusman || {!alive _dusman}) then { _dusman = _s findNearestEnemy _s; };
            private _savas = ((_pg getVariable [QGVAR(contact), 0]) > time) && {!isNull _dusman} && {alive _dusman};

            // ---------------------------------------------------------
            // BARIS: formasyonu izle (arka-yan 70 m)
            // ---------------------------------------------------------
            if (!_savas) then {
                // savastan cik: yatma / stealth birak (20 sn sonra)
                if ((time - (_ng getVariable [QGVAR(snpSavasSon), -999])) > 20 && {(_ng getVariable [QGVAR(snpHoldPos), []]) isNotEqualTo []}) then {
                    _ng setVariable [QGVAR(snpHoldPos), []];
                    _ng setBehaviour "AWARE";
                    _ng setCombatMode "YELLOW";
                    { _x setUnitPos "AUTO"; _x doWatch objNull; } forEach _takim;
                };
                if ((time - (_ng getVariable [QGVAR(snpSavasSon), -999])) > 20) then {
                    private _yan = _ng getVariable [QGVAR(sniperSide), 1];
                    private _yon = (getDir _pl) + 180 - (35 * _yan);
                    private _istasyon = _lp getPos [70, _yon];
                    if (!surfaceIsWater _istasyon && {(_s distance2D _istasyon) > 35}) then {
                        if ((time - (_ng getVariable [QGVAR(snpMoveLast), -999])) > 8) then {
                            _ng setVariable [QGVAR(snpMoveLast), time];
                            _s doMove (_istasyon getPos [random 8, random 360]);
                        };
                    };
                };
                continue;
            };

            // ---------------------------------------------------------
            // TEMAS
            // ---------------------------------------------------------
            _ng setVariable [QGVAR(snpSavasSon), time];
            private _tp = getPosATL _dusman;
            private _dEn = _s distance2D _tp;
            private _hold = _ng getVariable [QGVAR(snpHoldPos), []];

            // Yakin tehdit (<= 70 m): ana komutanin arkasina cekil, serbest ates
            if ((_dEn <= 70) || {(_pl distance2D _tp) <= 60}) then {
                _ng setBehaviour "COMBAT";
                _ng setCombatMode "RED";
                { _x setUnitPos "AUTO"; } forEach _takim;
                if ((time - (_ng getVariable [QGVAR(snpMoveLast), -999])) > 6) then {
                    _ng setVariable [QGVAR(snpMoveLast), time];
                    _ng setVariable [QGVAR(snpHoldPos), []];
                    _s doMove (_lp getPos [15, (_lp getDir _tp) + 180]);
                    diag_log format ["[SNIPER] %1 | dusman %2 m: ana komutanin arkasina cekiliyor", groupId _ng, round _dEn];
                };
                continue;
            };

            // Yanma: baski / yakinda ve bizi biliyor -> pozisyon degistir
            private _yandik = ((getSuppression _s) >= 0.5)
                || {(_dEn <= 150) && {(_dusman knowsAbout _s) >= 2}};
            private _kotu = _ng getVariable [QGVAR(snpKotu), []];
            if (_yandik && {_hold isNotEqualTo []}) then {
                _kotu pushBack _hold;
                if ((count _kotu) > 5) then { _kotu deleteAt 0; };
                _ng setVariable [QGVAR(snpKotu), _kotu];
                _ng setVariable [QGVAR(snpHoldPos), []];
                _ng setVariable [QGVAR(snpPosLast), -999];
                _hold = [];
                diag_log format ["[SNIPER] %1 | yakildi (baski %2): yer degistiriyor", groupId _ng, (getSuppression _s) toFixed 2];
            };

            // Yeni pozisyon (ilk kez / 20 sn'de bir / hedef 80 m'den fazla kaydi / yanma)
            private _sonPoz = _ng getVariable [QGVAR(snpPosLast), -999];
            private _sonHedef = _ng getVariable [QGVAR(snpHedefPos), [0, 0, 0]];
            if (_hold isEqualTo [] || {((time - _sonPoz) > 20) && {(_tp distance2D _sonHedef) > 80}}) then {
                private _yeni = [_s, _pl, _dusman, _kotu] call _pozSec;
                _ng setVariable [QGVAR(snpPosLast), time];
                _ng setVariable [QGVAR(snpHedefPos), _tp];
                if (_yeni isNotEqualTo []) then {
                    _hold = _yeni;
                    _ng setVariable [QGVAR(snpHoldPos), _hold];
                    _ng setBehaviour "AWARE";
                    _s doMove _hold;
                    diag_log format [
                        "[SNIPER] %1 | pozisyon: hedef %2 m | komutandan %3 m | gidis %4 m",
                        groupId _ng, round (_hold distance2D _tp), round (_hold distance2D _lp), round (_s distance2D _hold)
                    ];
                };
            };

            // Pozisyona vardi mi
            if (_hold isNotEqualTo [] && {(_s distance2D _hold) < 7}) then {
                _ng setBehaviour "STEALTH";
                _ng setCombatMode "YELLOW";
                _s setUnitPos "DOWN";
                if (!isNull _sp) then {
                    _sp setUnitPos "DOWN";
                    _sp setCombatMode "GREEN";
                    // gozlemci: gordugu dusmani nisanciya bildir
                    { _s reveal [_x, (_sp knowsAbout _x) max 0.5]; } forEach (_sp targets [true, 700]);
                    _sp doWatch _tp;
                    // nisanci ates ederse (veya baski altinda) gozlemci de serbest
                    if ((getSuppression _sp) >= 0.5 || {_dEn <= 150}) then { _sp setCombatMode "YELLOW"; };
                };

                // hedef secimi
                private _hedefler = (_s targets [true, 700]) select {_x isKindOf "CAManBase" && {alive _x} && {(_s knowsAbout _x) >= 1.0}};
                if (_hedefler isNotEqualTo []) then {
                    private _best = _hedefler select 0;
                    private _bestP = -99;
                    {
                        private _p = [_x, _s] call _oncelik;
                        if (_p > _bestP) then { _bestP = _p; _best = _x; };
                    } forEach _hedefler;
                    if ((time - (_s getVariable [QGVAR(snpTgtLast), -999])) > 4) then {
                        _s setVariable [QGVAR(snpTgtLast), time];
                        _s doWatch _best;
                        _s doTarget _best;
                        _s doFire _best;
                    };
                } else {
                    _s doWatch _tp;
                };
            };
        } forEach allGroups;
    };
};

true
