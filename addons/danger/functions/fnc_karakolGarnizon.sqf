#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KARAKOL GARNIZONU (v8.130) — kullanici: "karakol tutan adamlar apc ve nobet tutabilirler, onemli pozisyonlara; LAMBS garrison ile uyumlu ama komutan karar versin, Zeus mudahalesinde bozulmasin;
 * ust katlar ve patrol alt gruplari olusturma, tekrar tekrar duzeltilebilsin ve yeni birim eklenebilsin sisteme".
 *
 * Zeus 'ELITE Karakol Garnizon' modulu bir KARAKOL (ELITE Karakol / HQ) icin su ayari tutar: nobetci sayisi, devriye grup sayisi + boyu, ust kat / cati pozisyonlari, araclarin mevzi olarak kullanimi.
 * Bu bekci SUNUCUDA 15 sn'de bir ayari uygular; modul tekrar calistirilinca ayar ve pozisyonlar yeniden hesaplanir (eski nobet / devriye bozulur, birimler orijinal gruplarina doner).
 *
 * HAVUZ: karakolun yaricap x1.5 icindeki ayni taraf AI piyadeleri (oyuncusuz grup, aracta degil, bayilmamis). Yeni eklenen birimler (Zeus'tan konan / gelen) bir sonraki turda havuza girer ve eksik nobet / devriyeyi tamamlar.
 *   Nobetci secimi: tufekci / nisanci once, lider / hekim / MG / AT en son; pozisyona en yakin.
 * NOBET POZISYONLARI (komutan karar verir; LAMBS rastgele garrison'u degil): (1) ust kat: karakol yaricapindaki binalarin >= 2.5 m yuksekteki en yuksek ic pozisyonu (buildingPos); skor = yukseklik x3 + dis cephe gorusu (8 isin 120 m) x4;
 *   (2) arazi: yaricapin %50-%80'inde 30 derecelik halka, yukseklik x2 + gorus x4. Secim: en yuksek skor + onceki pozisyonlardan uzaklik (en fazla 60 m x 0.6) - her yone dagilir; min aralik 18 m.
 *   Nobetci pozisyona gider (doMove), 3 m icinde PATH kapatilir (yerinde kalir), dis yone doWatch; 120 sn'de varamazsa pozisyona isinlanir (merdiven takilmasi).
 * DEVRIYE: alt gruplar (devriye boyu 2-6), karakolun %60 yaricapinda halka rotasi (CYCLE), AWARE / LIMITED / STAG COLUMN; temas / alarm olunca (grup temasi < 30 sn) rota kesilir, en yakin cevre noktasina savunmaya gecer, 120 sn temassizsa devam.
 * ARACLAR: karakol icindeki AI surucu + yerel kara araclari (APC / IFV / kamyon) cevrede %75 yaricapta ates mevzisine gider (tehdit yonu bilinmiyorsa esit dagilir), PATH kapatilir, mürettebat icinde kalir; gorev 'KARAKOL_ARAC'.
 * Altgruplar: grup degiskeni lambs_danger_garnizonAlt (NOBET / DEVRIYE) -> plan / taksi / tasima onlari almaz. Birim degiskeni lambs_danger_garnizonOrijin = eski grup (kaldirinca geri doner).
 * Kapatma: lambs_danger_garnizonOff = true.  Log: [KARAKOL-GARNIZON] (+ 60 sn ozet).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_garnizonStarted") exitWith {false};
lambs_danger_garnizonStarted = true;
if (isNil "lambs_danger_karakolAyar") then { lambs_danger_karakolAyar = createHashMap; };
if (isNil "lambs_danger_garnizonDurum") then { lambs_danger_garnizonDurum = createHashMap; };
if (isNil "lambs_danger_karakollar") then { lambs_danger_karakollar = []; };

diag_log "[KARAKOL-GARNIZON] karakol garnizonu (nobet / devriye / ust kat / arac mevzi) watchdog'u baslatildi (v8.130)";

// ---- yardimcilar ----
private _kapsama = {
    // acik cephe sayisi (8 isin, 120 m): yuksek = genis gorus
    params ["_p"];
    private _g = AGLToASL (_p vectorAdd [0, 0, 1.2]);
    private _n = 0;
    for "_a" from 0 to 315 step 45 do {
        private _e = AGLToASL ((_p getPos [120, _a]) vectorAdd [0, 0, 1.2]);
        if (!(lineIntersects [_g, _e, objNull, objNull]) && {!(terrainIntersectASL [_g, _e])}) then { _n = _n + 1; };
    };
    _n
};

private _pozisyonlar = {
    params ["_poz", "_yar", "_n", "_ustKat"];
    private _kapsama = missionNamespace getVariable "lambs_danger_garnizonKapsamaFn";
    private _aday = [];
    if (_ustKat) then {
        private _bl = (nearestObjects [_poz, ["House", "Building"], _yar]) select {(count (_x buildingPos -1)) > 0};
        {
            private _bp = _x buildingPos -1;
            private _en = _bp select 0;
            { if ((_x select 2) > (_en select 2)) then { _en = _x; }; } forEach _bp;
            if ((_en select 2) < 2.5) then { continue };
            private _cov = [_en] call _kapsama;
            private _yon = if ((_en distance2D _poz) < 15) then {random 360} else {_poz getDir _en};
            _aday pushBack [_en, _yon, "USTKAT", (_en select 2) * 3 + _cov * 4, typeOf _x];
        } forEach (_bl select [0, 40]);
    };
    for "_b" from 0 to 330 step 30 do {
        {
            private _p = _poz getPos [_yar * _x, _b];
            if (surfaceIsWater _p || {isOnRoad _p}) then { continue };
            private _h = (getTerrainHeightASL _p) - (getTerrainHeightASL _poz);
            private _cov = [_p] call _kapsama;
            _aday pushBack [_p, _b, "ARAZI", _h * 2 + _cov * 4, ""];
        } forEach [0.5, 0.8];
    };
    private _secilen = [];
    for "_i" from 1 to _n do {
        private _en = []; private _enS = -1e9;
        {
            private _a = _x;
            private _md = 200;
            { _md = _md min ((_a select 0) distance2D (_x select 0)); } forEach _secilen;
            if (_md < 18) then { continue };
            private _s = (_a select 3) + ([0, (_md min 60) * 0.6] select (_secilen isNotEqualTo []));
            if (_s > _enS) then { _enS = _s; _en = _a; };
        } forEach _aday;
        if (_en isEqualTo []) exitWith {};
        _secilen pushBack _en;
    };
    _secilen
};

private _serbest = {
    // karakol altgruplarini dagit: nobetciler / devriyeler orijinal gruplarina doner
    params ["_id"];
    private _d = lambs_danger_garnizonDurum getOrDefault [_id, createHashMap];
    {
        private _u = _x;
        if (alive _u) then {
            _u enableAI "PATH";
            _u setUnitPos "AUTO";
            _u setVariable ["lambs_danger_nobet", nil, true];
            private _o = _u getVariable ["lambs_danger_garnizonOrijin", grpNull];
            if (!isNull _o && {({alive _x} count (units _o)) > 0}) then { [_u] joinSilent _o; };
            _u setVariable ["lambs_danger_garnizonOrijin", nil];
        };
    } forEach (_d getOrDefault ["birimler", []]);
    { if (!isNull _x) then { { deleteWaypoint _x } forEach (waypoints _x); }; } forEach (_d getOrDefault ["devriyeG", []]);
    { if (!isNull _x) then { { _x enableAI "PATH"; } forEach (units _x); _x setVariable ["lambs_danger_gorev", ""]; (vehicle (leader _x)) setVariable ["lambs_danger_gorev", "", true]; }; } forEach (_d getOrDefault ["aracG", []]);
    lambs_danger_garnizonDurum deleteAt _id;
};

private _calis = {
    missionNamespace setVariable ["lambs_danger_garnizonAdim", "basladi"];
    private _pozFn = missionNamespace getVariable "lambs_danger_garnizonPozFn";
    private _serbestFn = missionNamespace getVariable "lambs_danger_garnizonSerbestFn";
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _ozetT = time + 60;
    while {true} do {
        sleep 15;
        if (missionNamespace getVariable ["lambs_danger_garnizonOff", false]) then { continue };
        // kaldirilmis karakolun garnizonu bosalt
        private _aktifAd = lambs_danger_karakollar apply {_x select 5};
        { if !(_x in _aktifAd) then { [_x] call _serbestFn; }; } forEach (keys lambs_danger_garnizonDurum);
        {
            private _k = _x;
            _k params ["_taraf", "_poz", "_yar", "_ad", "_sav", "_mn"];
            private _ay = lambs_danger_karakolAyar getOrDefault [_mn, createHashMap];
            private _durum = lambs_danger_garnizonDurum getOrDefault [_mn, createHashMap];
            if ((count _ay) isEqualTo 0) then {
                if ((count _durum) > 0) then { [_mn] call _serbestFn; };
                continue
            };
            missionNamespace setVariable ["lambs_danger_garnizonAdim", format ["karakol %1", _mn]];
            private _nobetN = _ay getOrDefault ["nobet", 0];
            private _devN = _ay getOrDefault ["devriye", 0];
            private _devBoy = _ay getOrDefault ["devBoy", 3];
            private _ustKat = _ay getOrDefault ["ustKat", true];
            private _arac = _ay getOrDefault ["arac", true];
            private _surum = _ay getOrDefault ["surum", 0];

            // ayar degisti: eskiyi bosalt, pozisyonlari yeniden hesapla
            if ((_durum getOrDefault ["surum", -1]) isNotEqualTo _surum) then {
                [_mn] call _serbestFn;
                _durum = createHashMap;
                _durum set ["surum", _surum];
                _durum set ["pozlar", [_poz, _yar, _nobetN, _ustKat] call _pozFn];
                _durum set ["birimler", []];
                _durum set ["devriyeG", []];
                _durum set ["aracG", []];
                _durum set ["atama", createHashMap];
                lambs_danger_garnizonDurum set [_mn, _durum];
                diag_log format ["[KARAKOL-GARNIZON] %1 %2 | AYAR: nobet %3 devriye %4 x %5 | ust kat:%6 arac:%7 | pozisyon: %8", _taraf, _ad, _nobetN, _devN, _devBoy, _ustKat, _arac,
                    (_durum get "pozlar") apply {format ["%1 %2 (%3 m, skor %4%5)", _x select 2, mapGridPosition (_x select 0), round ((_x select 0) distance2D _poz), round (_x select 3), ["", " " + (_x select 4)] select ((_x select 4) isNotEqualTo "")]}];
            };

            // ---- havuz ----
            private _altGrupAd = {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isNotEqualTo ""};
            private _havuz = [];
            {
                private _g = _x;
                if ((side _g) isNotEqualTo _taraf || {isNull (leader _g)} || {isPlayer (leader _g)}) then { continue };
                if (({isPlayer _x} count (units _g)) > 0) then { continue };
                if ((leader _g) distance2D _poz > (_yar * 1.5)) then { continue };
                // v8.136: kaynak gruptan EN AZ 3 asker (lider dahil) grupta kalir; aksi halde savunma plani / grup bosalir (RPT 013ca3b7: plan 24 sn'de "grup kalmadi" ile bitti)
                private _us = (units _g) select {alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {local _x}};
                private _ayril = ((count (units _g select {alive _x})) - 3) max 0;
                private _aday = (_us - [leader _g]);
                reverse _aday;
                { _havuz pushBack _x; } forEach (_aday select [0, _ayril min (count _aday)]);
            } forEach (allGroups select {!(call _altGrupAd)});
            // nobetci / devriye icin zaten kullanilanlar havuzda sayilmaz (altgrup disinda)
            private _atama = _durum getOrDefault ["atama", createHashMap];
            private _pozlar = _durum getOrDefault ["pozlar", []];
            private _birimler = _durum getOrDefault ["birimler", []];

            // ---- NOBETCILER ----
            private _nobetG = _durum getOrDefault ["nobetG", grpNull];
            if (isNull _nobetG) then {
                _nobetG = createGroup [_taraf, true];
                _nobetG setVariable ["lambs_danger_garnizonAlt", "NOBET", true];
                _durum set ["nobetG", _nobetG];
            };
            {
                private _i = _forEachIndex;
                private _p = _x select 0;
                private _u = _atama getOrDefault [str _i, objNull];
                if (alive _u && {_u in (units _nobetG)}) then {
                    // varmadi mi? (120 sn) -> isinla; varsa PATH kapat
                    if (((getPosATL _u) distance _p) < 4.5) then {
                        if !(_u getVariable ["lambs_danger_nobet", false]) then {
                            _u setVariable ["lambs_danger_nobet", true, true];
                            doStop _u;
                            _u disableAI "PATH";
                            _u setUnitPos (["MIDDLE", "UP"] select ((_x select 2) isEqualTo "USTKAT"));
                            _u doWatch (_p getPos [150, _x select 1]);
                            _u setBehaviour "AWARE";
                            diag_log format ["[KARAKOL-GARNIZON] %1 | NOBET pozisyonda: %2 (%3 %4)", _ad, name _u, _x select 2, mapGridPosition _p];
                        };
                    } else {
                        if ((time - (_u getVariable ["lambs_danger_nobetT", time])) > 120 && {!(_u getVariable ["lambs_danger_nobet", false])}) then {
                            _u setPosATL _p;
                            _u setVariable ["lambs_danger_nobetT", time];
                            // isinlanan nobetci hemen pozisyonda sayilir (RPT 23251a0a: ayni nobetciler 120 sn'de bir tekrar isinlaniyordu, PATH acik kalip yuruyordu)
                            _u setVariable ["lambs_danger_nobet", true, true];
                            doStop _u;
                            _u disableAI "PATH";
                            _u setUnitPos (["MIDDLE", "UP"] select ((_x select 2) isEqualTo "USTKAT"));
                            _u doWatch (_p getPos [150, _x select 1]);
                            diag_log format ["[KARAKOL-GARNIZON] %1 | NOBET %2 pozisyona 120 sn'de varamadi -> isinlandi", _ad, name _u];
                        };
                    };
                } else {
                    // bos / olu nobet: havuzdan en uygun
                    private _adaylar = _havuz select {!(_x in _birimler) && {!(_x in (units _nobetG))} && {(_x distance2D _poz) <= (_yar * 1.5)}};
                    if (_adaylar isEqualTo []) then { continue };
                    private _s = [_adaylar, [], { private _r = [_x] call _rolFn; (([0, 200, 400, 600, 900] select ((["RIFLE", "MARKSMAN", "RTO", "MEDIC", "MG"] find _r) max 0)) max ([0, 800] select (_r isEqualTo "AT"))) + ([0, 1500] select (_x isEqualTo (leader (group _x)))) + ((_x distance2D _p) / 5) }, "ASCEND"] call BIS_fnc_sortBy;
                    private _sec = _s select 0;
                    _sec setVariable ["lambs_danger_garnizonOrijin", group _sec];
                    [_sec] joinSilent _nobetG;
                    _sec setVariable ["lambs_danger_nobetT", time];
                    _sec setVariable ["lambs_danger_nobet", nil, true];
                    _sec enableAI "PATH";
                    _sec doMove _p;
                    _atama set [str _i, _sec];
                    _birimler pushBack _sec;
                    diag_log format ["[KARAKOL-GARNIZON] %1 | NOBET atandi: %2 -> %3 %4 (%5 m)", _ad, name _sec, _x select 2, mapGridPosition _p, round (_sec distance2D _p)];
                };
            } forEach _pozlar;

            // ---- DEVRIYELER ----
            private _devG = _durum getOrDefault ["devriyeG", []];
            _devG = _devG select {!isNull _x && {({alive _x} count (units _x)) > 0}};
            private _alarm = false;
            {
                if ((time - (_x getVariable [QGVAR(contact), -999])) < 30) exitWith { _alarm = true; };
            } forEach ((allGroups select {(side _x) isEqualTo _taraf && {!isNull (leader _x)} && {((leader _x) distance2D _poz) < (_yar * 2)}}));
            while {count _devG < _devN} do {
                private _adaylar = _havuz select {!(_x in _birimler) && {!(_x in (units _nobetG))} && {((group _x) getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}};
                if (count _adaylar < _devBoy) exitWith {};
                private _s = [_adaylar, [], {(rankId _x) * -10 + (_x distance2D _poz) / 20}, "ASCEND"] call BIS_fnc_sortBy;
                private _uyeler = _s select [0, _devBoy];
                private _dg = createGroup [_taraf, true];
                _dg setVariable ["lambs_danger_garnizonAlt", "DEVRIYE", true];
                { _x setVariable ["lambs_danger_garnizonOrijin", group _x]; [_x] joinSilent _dg; _birimler pushBack _x; } forEach _uyeler;
                _dg selectLeader (_uyeler select 0);
                _devG pushBack _dg;
                diag_log format ["[KARAKOL-GARNIZON] %1 | DEVRIYE kuruldu: %2 | %3 kisi", _ad, groupId _dg, _uyeler apply {name _x}];
            };
            {
                private _dg = _x;
                private _idx = _forEachIndex;
                private _wl = waypoints _dg;
                if (_alarm) then {
                    if !(_dg getVariable ["lambs_danger_devAlarm", false]) then {
                        _dg setVariable ["lambs_danger_devAlarm", true];
                        { deleteWaypoint _x } forEach _wl;
                        private _gp = _poz getPos [_yar * 0.7, (_poz getDir (leader _dg)) ];
                        _dg setBehaviour "COMBAT";
                        _dg setCombatMode "RED";
                        (leader _dg) doMove _gp;
                        diag_log format ["[KARAKOL-GARNIZON] %1 | ALARM: devriye %2 cevre savunmasina geciyor", _ad, groupId _dg];
                    };
                } else {
                    if (_dg getVariable ["lambs_danger_devAlarm", false] && {(time - (_dg getVariable [QGVAR(contact), -999])) > 120}) then { _dg setVariable ["lambs_danger_devAlarm", false]; _wl = []; { deleteWaypoint _x } forEach (waypoints _dg); _dg setBehaviour "AWARE"; _dg setCombatMode "YELLOW"; };
                    if (!(_dg getVariable ["lambs_danger_devAlarm", false]) && {count (waypoints _dg) < 2}) then {
                        { deleteWaypoint _x } forEach (waypoints _dg);
                        private _a0 = _idx * (360 / (_devN max 1));
                        for "_j" from 0 to 4 do {
                            private _wp = _dg addWaypoint [(_poz getPos [_yar * 0.6, _a0 + _j * 72]), 8];
                            _wp setWaypointType "MOVE";
                            _wp setWaypointName "ELITE GARNIZON: devriye";
                            _wp setWaypointBehaviour "AWARE";
                            _wp setWaypointSpeed "LIMITED";
                            _wp setWaypointFormation "STAG COLUMN";
                            _wp setWaypointCombatMode "YELLOW";
                            if (_j isEqualTo 4) then { _wp setWaypointType "CYCLE"; };
                        };
                    };
                };
            } forEach _devG;
            _durum set ["devriyeG", _devG];

            // ---- ARAC MEVZILERI ----
            private _aracG = _durum getOrDefault ["aracG", []];
            if (_arac) then {
                private _vl = (_poz nearEntities [["LandVehicle"], _yar * 1.2]) select {
                    alive _x && {canMove _x} && {!isNull (driver _x)} && {!isPlayer (driver _x)} && {local (driver _x)} && {(side (group (driver _x))) isEqualTo _taraf}
                    && {(_x emptyPositions "cargo") >= 2 || {(getNumber (configOf _x >> "armor")) >= 100}}
                    && {!(((group (driver _x)) getVariable ["lambs_danger_garnizonAlt", ""]) isNotEqualTo "")}
                };
                {
                    private _v = _x;
                    private _dg2 = group (driver _v);
                    if (_dg2 in _aracG) then { continue };
                    if ((_v getVariable ["lambs_danger_gorev", ""]) in ["MEDEVAC", "TASIMA", "TOPCU", "HARIC"] || {_v getVariable [QGVAR(tasimaMesgul), false]}) then { continue };
                    private _n = count _aracG;
                    private _a = (_poz getDir (getPosATL _v)) + 30 * _n;
                    private _vp = _poz getPos [_yar * 0.75, (_n * (360 / ((count _vl) max 1))) + 20];
                    if (surfaceIsWater _vp) then { _vp = _poz getPos [_yar * 0.5, (_n * 90)]; };
                    _dg2 setVariable ["lambs_danger_gorev", "KARAKOL_ARAC", true];
                    _v setVariable ["lambs_danger_gorev", "KARAKOL_ARAC", true];
                    _v setVariable ["lambs_danger_garnizonPoz", [_vp, _poz getDir _vp]];
                    (driver _v) enableAI "PATH";
                    (driver _v) doMove _vp;
                    _aracG pushBack _dg2;
                    diag_log format ["[KARAKOL-GARNIZON] %1 | ARAC mevzisine: %2 -> %3 (%4 m)", _ad, getText (configOf _v >> "displayName"), mapGridPosition _vp, round (_v distance2D _vp)];
                } forEach _vl;
                {
                    private _v = vehicle (leader _x);
                    private _pp = _v getVariable ["lambs_danger_garnizonPoz", []];
                    if (_pp isNotEqualTo [] && {alive _v} && {(_v distance2D (_pp select 0)) < 12} && {!((driver _v) getVariable ["lambs_danger_nobet", false])}) then {
                        private _d = driver _v;
                        _d setVariable ["lambs_danger_nobet", true, true];
                        doStop _d;
                        _d disableAI "PATH";
                        { _x doWatch ((_pp select 0) getPos [200, _pp select 1]); } forEach (crew _v);
                        diag_log format ["[KARAKOL-GARNIZON] %1 | ARAC mevzide: %2 (yon %3)", _ad, getText (configOf _v >> "displayName"), round (_pp select 1)];
                    };
                } forEach _aracG;
            };
            _durum set ["aracG", _aracG select {!isNull _x}];
            _atama = _atama;
            _durum set ["atama", _atama];
            _durum set ["birimler", _birimler select {alive _x}];
            _durum set ["alarm", _alarm];
            lambs_danger_garnizonDurum set [_mn, _durum];
        } forEach lambs_danger_karakollar;

        if (time > _ozetT) then {
            _ozetT = time + 60;
            {
                private _id = _x;
                private _d = _y;
                private _ay = lambs_danger_karakolAyar getOrDefault [_id, createHashMap];
                private _atama = _d getOrDefault ["atama", createHashMap];
                private _nb = {alive (_atama get _x)} count (keys _atama);
                diag_log format ["[KARAKOL-GARNIZON-OZET] %1 | nobet %2/%3 (pozisyonda %4) | devriye %5/%6 | arac %7 | alarm:%8",
                    _id, _nb, _ay getOrDefault ["nobet", 0], {(_atama get _x) getVariable ["lambs_danger_nobet", false]} count (keys _atama),
                    count (_d getOrDefault ["devriyeG", []]), _ay getOrDefault ["devriye", 0], count (_d getOrDefault ["aracG", []]), _d getOrDefault ["alarm", false]];
            } forEach lambs_danger_garnizonDurum;
        };
        missionNamespace setVariable ["lambs_danger_garnizonAdim", "tur bitti"];
    };
};
missionNamespace setVariable ["lambs_danger_garnizonKapsamaFn", _kapsama];
missionNamespace setVariable ["lambs_danger_garnizonPozFn", _pozisyonlar];
missionNamespace setVariable ["lambs_danger_garnizonSerbestFn", _serbest];

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] karakolGarnizon betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_garnizonAdim", "?"]];
        sleep 5;
    };
};

true
