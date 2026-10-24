#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON TOPCU DONGUSU (v8.338; kullanici: 'taciz atisi ve uzaktan gorunen dusmanlar icin kitaba uygun dron topcu gonderme olsun') — SUNUCU, acilista bir kez, 5 sn'de bir, taraf basina (west / east / independent):
 *   0) TOPCU YOKSA (AI, yerel, HE mermisi: fnc_topcuListe) hicbir sey yapmaz.
 *   1) GOZLEMCI SECIMI: tarafin AI muretttebatli, silahsiz GOZLEM turu IHA'si (fnc_ihaTip), yerden >= 10 m, fnc_ihaGozlem'in son 15 sn'de yazdigi gorus listesi ('lambs_danger_ihaGorulen' = gercek algi, nearTargets)
 *      olan en iyi dron ILERI GOZLEMCI (FO) olur. Algi yoksa gozlemci olmaz (haritadan konum OKUNMAZ).
 *   2) GOZLEMLI ATIS: gozlemcinin gorduklerini 60 m'lik kumelere ayirir (fnc_topcuKume), deger >= 3 (CBA 'dronTopcuMinDeger'), gozlemciden >= 150 m, son 240 sn'de atis yapilmamis bolge degil kumeyi alir;
 *      kume 10 sn boyunca ayni yerde (40 m) DURAGAN ise gorevi baslatir (fnc_dronTopcuMisyon: cagri -> adjust -> FFE -> BDA). Hareketli hedefe adjust yapilmaz.        [K: gozlemli atis akisi]
 *   3) UZAKTAN GORUNEN DUSMAN -> GOZLEMCI TALEBI: gozlemci yoksa ve tarafin AI gruplarinin (liderleri, en cok 10 grup / 20 sn, nearTargets 1500 m, knowsAbout >= 1.2) gordugu dusman kumesi deger >= 3 olup
 *      en yakin dosttan >= 'dronTopcuUzak' (700 m) uzaktaysa, topcu menzilindeyse ve guvenliyse: 'lambs_danger_dronGozlemIstegi' (fnc_dronGozlemci) ile hedefin dost tarafinda 380 m GERIDE
 *      (yaricap 130 m) bir gozlem istasyonuna gozlem dronu istenir (hazir GOZLEM IHA'si ya da gozlem dronu cantali asker). Dron gelince 2) devreye girer. 250 sn'de bir, taraf basina.   [T: 700 m ~ dogrudan ates + danger close disi]
 *   4) TEMAS BELLEGI: 20 sn'de bir gorulen kumeler (ground + dron) 1200 sn tutulur; fnc_topcuTaciz bu bellekteki BAYAT noktalari duzensiz aralikla ve az mermiyle tacizler.                   [K: taciz atesi tanimi]
 * Gozlemli atis ile taciz ayni mermi butcesini (fnc_topcuButce) ve ayni emniyet kontrolunu (fnc_topcuGuvenlik: RED, danger close, NFA, sivil) paylasir.
 * Sinirlama: yalniz SUNUCUDA yerel gruplar / araclar (Zeus ile istemcide yaratilan AI'lar sunucuya devredilene kadar gorunmez).
 * CBA (ELITE dron savunmasi): dronTopcuAktif, tacizAktif, dronTopcuButce, tacizAralik, tacizMermi, dronTopcuMinDeger, dronTopcuUzak. Kapatma: lambs_danger_dronTopcuOff = true.
 * Log: [DRON-TOPCU] (gorev adimlari), [TACIZ], [DRON-TOPCU-OZET] (90 sn: neden sayaci, bellek).
 *
 * Arguments: None (acilista bir kez; yalniz sunucu)
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer || {!isNil "lambs_danger_dronTopcuStarted"}) exitWith {false};
lambs_danger_dronTopcuStarted = true;

[] spawn {
    private _tick = 0;
    private _sayac = createHashMap;
    private _ozetT = time + 90;
    private _say = {
        params ["_k"];
        _sayac set [_k, (_sayac getOrDefault [_k, 0]) + 1];
    };
    while {true} do {
        sleep 5;
        _tick = _tick + 1;
        private _dronA = missionNamespace getVariable ["lambs_danger_dronTopcuAktif", true];
        private _tacizA = missionNamespace getVariable ["lambs_danger_tacizAktif", true];
        if ((missionNamespace getVariable ["lambs_danger_dronTopcuOff", false]) || {!_dronA && {!_tacizA}}) then { continue };
        private _minD = missionNamespace getVariable ["lambs_danger_dronTopcuMinDeger", 3];
        private _uzak = missionNamespace getVariable ["lambs_danger_dronTopcuUzak", 700];
        private _gozleyiciler = vehicles select {unitIsUAV _x && {alive _x} && {local _x} && {((getPosATL _x) select 2) > 10}};

        {
            private _taraf = _x;
            private _topcular = [_taraf] call FUNC(topcuListe);
            if (_topcular isEqualTo []) then { continue };
            { [_x select 0] call FUNC(topcuIzle); } forEach _topcular;
            private _kKilit = format ["lambs_danger_dtKilit_%1", _taraf];
            private _kilitli = time < (missionNamespace getVariable [_kKilit, 0]);

            // ---- 1) gozlemci secimi ----
            private _fo = objNull;
            private _goru = [];
            {
                private _u = _x;
                private _mur = (crew _u) select {alive _x};
                if (_mur isNotEqualTo [] && {({isPlayer _x} count _mur) isEqualTo 0} && {(side (group (_mur select 0))) isEqualTo _taraf}) then {
                    private _gk = _u getVariable ["lambs_danger_ihaGorulen", [-99, []]];
                    if ((time - (_gk select 0)) < 15 && {(count (_gk select 1)) > (count _goru)} && {([_u] call FUNC(ihaTip)) isEqualTo "GOZLEM"} && {(_u weaponsTurret [0]) isEqualTo []}) then {
                        _fo = _u;
                        _goru = _gk select 1;
                    };
                };
            } forEach _gozleyiciler;

            // ---- 1b) YER GOZLEMCISI (v8.342): dron yoksa gorus hatti ACIK lider (hakim noktaya cikan lider once) FO olur ----
            if (isNull _fo && {_dronA} && {missionNamespace getVariable ["lambs_danger_foAktif", true]}) then {
                private _foSt = missionNamespace getVariable [format ["lambs_danger_foGorev_%1", _taraf], []];
                private _lgrp = allGroups select {
                    (side _x) isEqualTo _taraf && {local _x} && {!isNull (leader _x)} && {alive (leader _x)} && {!isPlayer (leader _x)} && {isNull objectParent (leader _x)}
                    && {(lifeState (leader _x)) in ["HEALTHY", "INJURED"]} && {(getSuppression (leader _x)) < 0.5} && {!(_x getVariable [QGVAR(isRetreating), false])}
                };
                private _bak = [];
                if (_foSt isNotEqualTo [] && {alive (_foSt select 1)}) then { _bak pushBack (_foSt select 1); };
                if (_lgrp isNotEqualTo []) then {
                    for "_i" from 0 to (((count _lgrp) min 6) - 1) do { _bak pushBackUnique (leader (_lgrp select ((_tick * 6 + _i) mod (count _lgrp)))); };
                };
                {
                    private _gkF = [_x, _taraf] call FUNC(topcuGoru);
                    if ((count (_gkF select 1)) > (count _goru)) then { _fo = _x; _goru = _gkF select 1; };
                } forEach _bak;
            };

            // ---- 4) temas bellegi (20 sn'de bir) ----
            if ((_tick mod 4) isEqualTo 0) then {
                private _gorulen = +_goru;
                private _grlar = allGroups select {(side _x) isEqualTo _taraf && {local _x} && {!isNull (leader _x)} && {alive (leader _x)} && {!isPlayer (leader _x)}};
                if (_grlar isNotEqualTo []) then {
                    private _n0 = (floor (_tick / 4)) * 10;
                    for "_i" from 0 to (((count _grlar) min 10) - 1) do {
                        private _l = leader (_grlar select ((_n0 + _i) mod (count _grlar)));
                        {
                            private _o = _x select 4;
                            if (!isNull _o && {alive _o} && {(_taraf getFriend (_x select 2)) < 0.6} && {(_l knowsAbout _o) >= 1.2}) then { _gorulen pushBackUnique _o; };
                        } forEach (_l nearTargets 1500);
                    };
                };
                private _kl2 = [_gorulen, _taraf] call FUNC(topcuKume);
                missionNamespace setVariable [format ["lambs_danger_dtGuncel_%1", _taraf], _kl2 select {(_x select 2) >= _minD}];
                private _bk = format ["lambs_danger_dtBellek_%1", _taraf];
                private _bel = (missionNamespace getVariable [_bk, []]) select {(time - (_x select 1)) < 1200};
                {
                    private _c = _x;
                    private _i2 = _bel findIf {((_x select 0) distance2D (_c select 0)) < 100};
                    if (_i2 >= 0) then {
                        private _e = _bel select _i2;
                        _e set [0, _c select 0];
                        _e set [1, time];
                        _e set [2, _c select 2];
                    } else {
                        _bel pushBack [_c select 0, time, _c select 2, 0, -999];
                    };
                } forEach (_kl2 select {(_x select 2) >= 3});
                missionNamespace setVariable [_bk, _bel select [0, 30]];
            };

            // ---- 2) gozlemli atis ----
            if (_dronA && {!_kilitli}) then {
                if (!isNull _fo) then {
                    private _kl = [_goru, _taraf] call FUNC(topcuKume);
                    private _bolge = (missionNamespace getVariable ["lambs_danger_dtBolge", []]) select {(_x select 1) > time};
                    missionNamespace setVariable ["lambs_danger_dtBolge", _bolge];
                    private _aday = _kl select {
                        private _cl = _x;
                        (_cl select 2) >= _minD && {((_cl select 0) distance2D _fo) >= 150} && {(_bolge findIf {((_x select 0) distance2D (_cl select 0)) < 150}) < 0}
                    };
                    private _aK = format ["lambs_danger_dtAday_%1", _taraf];
                    if (_aday isEqualTo []) then {
                        missionNamespace setVariable [_aK, [[0, 0, 0], -999]];
                        ["gozlemci hedef gormuyor / deger dusuk / bolge kilitli"] call _say;
                    } else {
                        private _c = _aday select 0;
                        private _ad = missionNamespace getVariable [_aK, [[0, 0, 0], -999]];
                        if (((_ad select 0) distance2D (_c select 0)) < 40) then {
                            if ((time - (_ad select 1)) >= 10) then {
                                missionNamespace setVariable [_aK, [[0, 0, 0], -999]];
                                missionNamespace setVariable [_kKilit, time + 900];
                                lambs_danger_dtN = (missionNamespace getVariable ["lambs_danger_dtN", 0]) + 1;
                                [_taraf, _fo, _c select 0, format ["%1-DT%2", _taraf, lambs_danger_dtN]] spawn FUNC(dronTopcuMisyon);
                                ["gozlemli atis gorevi baslatildi"] call _say;
                            };
                        } else {
                            missionNamespace setVariable [_aK, [_c select 0, time]];
                            ["hedef duragan degil / yeni aday (10 sn bekleniyor)"] call _say;
                        };
                    };
                } else {
                    // ---- 3) uzaktan gorunen dusman -> gozlemci talebi ----
                    private _aktifD = missionNamespace getVariable [format ["lambs_danger_dronGozIHA_%1", _taraf], objNull];
                    private _tK = format ["lambs_danger_dtTalepT_%1", _taraf];
                    if ((isNull _aktifD || {!alive _aktifD} || {(diag_tickTime - (_aktifD getVariable [QGVAR(ihaTok), -999])) > 650}) && {(time - (missionNamespace getVariable [_tK, -999])) > 250}) then {
                        private _guncel = missionNamespace getVariable [format ["lambs_danger_dtGuncel_%1", _taraf], []];
                        private _istendi = false;
                        {
                            private _c = _x;
                            private _p = _c select 0;
                            private _in = _topcular select { _p inRangeOfArtillery [[_x select 0], _x select 1] };
                            if (!_istendi && {_in isNotEqualTo []}) then {
                                private _red = [(_in select 0) select 0, (_in select 0) select 1] call FUNC(topcuRed);
                                ([_taraf, _p, _red] call FUNC(topcuGuvenlik)) params ["_ok", "_neden", "_dF", "_dc", "_fP"];
                                if (_ok && {_dF >= _uzak} && {_fP isNotEqualTo []}) then {
                                    private _ist = _p getPos [380, _p getDir _fP];
                                    missionNamespace setVariable [_tK, time];
                                    ["lambs_danger_dronGozlemIstegi", [_taraf, _ist, _p getDir _ist, true, 0, 0, 130]] call CBA_fnc_serverEvent;
                                    diag_log format ["[DRON-TOPCU] %1 | UZAKTAN GORUNEN DUSMAN (deger %2, adam %3 arac %4, en yakin dost %5 m): gozlemci talebi -> istasyon %6 (hedefin 380 m dost tarafinda), hedef %7",
                                        _taraf, _c select 2, _c select 3, _c select 4, round _dF, mapGridPosition _ist, mapGridPosition _p];
                                    ["gozlemci talebi gonderildi"] call _say;
                                    _istendi = true;
                                };
                            };
                        } forEach _guncel;
                    } else {
                        ["gozlemci yok; talep beklemede / dron zaten gorevde"] call _say;
                    };
                };
            };

            // ---- yer gozlemcisi: lider hakim noktaya (ev ust kati / cati / arazi) (20 sn'de bir) ----
            if (_dronA && {(_tick mod 4) isEqualTo 2}) then {
                [_taraf, !isNull _fo] call FUNC(foHakim);
            };

            // ---- taciz zamani ----
            if (_tacizA) then {
                private _tzK = format ["lambs_danger_dtTacizT_%1", _taraf];
                private _due = missionNamespace getVariable [_tzK, -1];
                if (_due < 0) then {
                    _due = time + 120 + (random 120);
                    missionNamespace setVariable [_tzK, _due];
                };
                if (time >= _due && {!_kilitli}) then {
                    private _min = (missionNamespace getVariable ["lambs_danger_tacizAralik", 240]) max 60;
                    private _katsayi = [1, 0.6] select (sunOrMoon < 0.3);
                    missionNamespace setVariable [_tzK, time + ((_min + (random _min)) * _katsayi)];
                    if ([_taraf] call FUNC(topcuTaciz)) then { ["taciz atisi"] call _say; } else { ["taciz: uygun bayat hedef / top / emniyet yok"] call _say; };
                };
            };
        } forEach [west, east, independent];

        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _sayac > 0) then {
                diag_log format ["[DRON-TOPCU-OZET] son 90 sn: %1 | temas bellegi (taraf: kayit): %2", (keys _sayac) apply {format ["%1:%2", _x, _sayac get _x]}, [west, east, independent] apply {format ["%1:%2", _x, count (missionNamespace getVariable [format ["lambs_danger_dtBellek_%1", _x], []])]}];
                _sayac = createHashMap;
            };
        };
    };
};

diag_log "[DRON-TOPCU] dron gozlemli topcu + taciz atisi baslatildi (v8.338): gozlemci = AI GOZLEM dronu (ihaGorulen), cagri -> adjust -> FFE -> BDA; taciz = bayat temas noktalari, duzensiz aralik, az mermi";
true
