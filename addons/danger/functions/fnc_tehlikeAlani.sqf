#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TEHLIKE ALANI GECISI (v8.92) — YOL (acik cizgisel tehlike alani) gecisi: once gozetle, sonra ikili takimlarla sirayla gec (genel doktrin ilkesi: danger area crossing = once guvenlik / gozetleme, sonra bolum bolum; kaynakli degil).
 * Kullanici gozlemi: iki taraf da otoyolu kullandi / yoldan gecti.
 *
 * TESPIT (3 sn'de bir): yerel piyade grubu (>= 5, oyuncusuz), temas yok (>= 20 sn), taktik / retreat / bounding / IED / sniper / pusu isi yok, lider arac disinda ve YOLDA DEGIL; liderin beklenen hedefi
 *   (expectedDestination, ilk 20-70 m) dogrultusunda 15 m adimla orneklenir: roadAt var + yol uzerinde degil + cevre ACIK (80 m'de yapi < 6 ve 40 m'de agac < 6) -> gecis noktasi C.
 *   Ayni grup 120 sn bekler. Lider yoldaysa (yol boyunca yuruyus) tetiklenmez.
 * ICRA (spawn, en fazla 70 sn; temas / retreat / taktik baslarsa HEMEN serbest):
 *   (1) DUR + GOZETLE (8 sn): herkes doStop + comelir; yolun iki ucuna (yol ekseni +-) 2 gozetleyici (gozcu / nisanci / MG oncelik) doWatch; digerleri yol kenarini izler
 *   (2) TAKIM A (lider + yarisi): yol karsisina 18 m koşar, orada yola bakar; TAKIM B gozetler
 *   (3) TAKIM B gecer; en son gozetleyiciler
 *   (4) serbest: doFollow + stance AUTO + mevcut waypoint yeniden (setCurrentWaypoint)
 * Kapatma: lambs_danger_tehlikeAlaniOff = true.   Log: [TEHLIKE-ALANI] (ilk 60) + [TEHLIKE-ALANI-OZET] 90 sn
 * v8.390 ACIK ALAN GECISI (ATP 3-21.8 / Ranger Handbook 'danger area': buyuk acik alan, karsi taraf gozlenebilir ve <= 250 m ise ONCE GOZETLEME + ONCU ELEMAN):
 *   TESPIT: lider ortu kenarinda (15 m'de agac / bina / kaya / duvar var), rotasi (expectedDestination yonu) <= 50 m ileride ORTUSUZ acik alana giriyor, acik serit >= 60 m ve karsi kenar <= 250 m (CBA menzil),
 *     karsi kenar gorus hattinda (terrainIntersect yok), su yok, hedef karsi kenarin otesinde. Yol gecisi bulunamazsa (yol onceligi) bu taranir; 9 sn'de bir, grup basina.
 *   (1) DUR + GOZETLE: lider + MG + nisanci (en az grubun 1/3'u) GOZETLEME ekibi: yatar, karsi kenari izler; digerleri comelir, karsi yonu izler
 *   (2) ONCU ELEMAN (gozcu / tufekli; 7+ kisilikte 2): karsi kenara kosar, orada 8 sn guvenlik (yatay izleme) - temas olursa HEMEN serbest (bounding / retreat devralir)
 *   (3) ANA GOVDE iki yarida (A sonra B) KARSI KENARA ~7 m YANAL ARALIKLA yayilarak gecer (dagilma)
 *   (4) GOZETLEME ekibi (lider dahil) EN SON gecer; serbest: doFollow + waypoint yeniden
 *   Kapatma: CBA 'tehlikeAcikAktif' / lambs_danger_tehlikeAcikOff = true.   Log: [TEHLIKE-ACIK] (ilk 60).
 * SINIR: karsi kenar > 250 m ise (cok genis alan) bu akis calismaz (uzun mesafe: bounding overwatch). Waypoint olmayan (expectedDestination bos) grup tetiklenmez.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_tehlikeAlaniStarted") exitWith {false};
lambs_danger_tehlikeAlaniStarted = true;

diag_log "[TEHLIKE-ALANI] yol gecisi (gozetle + sirayla gec) watchdog'u baslatildi (v8.92)";

private _gecis = {
    params ["_g", "_c", "_yonYol", "_hedefYon"];
    private _t0 = time;
    private _l = leader _g;
    private _bitir = {
        params ["_g", "_neden"];
        if (isNull _g) exitWith {};
        _g setVariable [QGVAR(isExecutingTactic), nil];
        _g setVariable [QGVAR(tehlikeAlaniT), time];
        {
            if (alive _x) then {
                _x setVariable [QGVAR(taktikKilit), nil];
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _g);
            };
        } forEach (units _g);
        if (!isNull (leader _g) && {currentWaypoint _g > 0 || {(count (waypoints _g)) > 0}}) then { _g setCurrentWaypoint [_g, currentWaypoint _g]; };
        diag_log format ["[TEHLIKE-ALANI] %1 | SERBEST: %2", groupId _g, _neden];
    };
    private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
    if ((count _us) < 5) exitWith {};
    private _iptalMi = { params ["_g"]; isNull _g || {(_g getVariable [QGVAR(contact), 0]) > time} || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} };

    _g setVariable [QGVAR(isExecutingTactic), true];
    { _x setVariable [QGVAR(taktikKilit), time + 75]; } forEach _us;
    // takimlar: lider + en yakin yarisi = A; kalan = B (gozetleyiciler B'den: gozcu / nisanci once)
    private _digerler = _us select {_x isNotEqualTo _l};
    _digerler = [_digerler, [], {_x distance2D _c}, "ASCEND"] call BIS_fnc_sortBy;
    private _nA = ceil ((count _digerler) / 2);
    private _A = [_l] + (_digerler select [0, _nA]);
    private _B = _digerler select [_nA, count _digerler];
    private _gz = _B select {(_x getVariable [QGVAR(gozcu), false]) || {_x isEqualTo (_g getVariable [QGVAR(gozcu), objNull])}};
    private _gozetleyen = (_gz + _B) arrayIntersect _B;
    private _gozetA = _gozetleyen select [0, 2 min (count _gozetleyen)];
    diag_log format ["[TEHLIKE-ALANI] %1 | YOL GECISI basladi | gecis noktasi %2 m ileride | takim A:%3 B:%4 | gozetleyen:%5", groupId _g, round (_l distance2D _c), count _A, count _B, _gozetA apply {name _x}];

    // (1) dur + gozetle
    { doStop _x; _x setUnitPos "MIDDLE"; } forEach _us;
    private _uc1 = _c getPos [100, _yonYol];
    private _uc2 = _c getPos [100, _yonYol + 180];
    { _x doWatch ([_uc1, _uc2] select (_forEachIndex mod 2)); } forEach _gozetA;
    { _x doWatch _c; } forEach (_us - _gozetA);
    private _bek = time + 8;
    waitUntil { sleep 0.5; time > _bek || {[_g] call _iptalMi} };
    if ([_g] call _iptalMi) exitWith { [_g, "temas / retreat / grup yok"] call _bitir; };

    // (2) takim A gecer
    private _hedefNokta = _c getPos [20, _hedefYon];
    { _x setUnitPos "UP"; _x forceSpeed -1; _x setSpeedMode "FULL"; _x doMove (_hedefNokta getPos [random 4, random 360]); } forEach _A;
    private _bitisA = time + 25;
    waitUntil { sleep 0.5; time > _bitisA || {[_g] call _iptalMi} || {(_A findIf {alive _x && {(_x distance2D _hedefNokta) > 10}}) < 0} };
    if ([_g] call _iptalMi) exitWith { [_g, "A gecerken temas / retreat"] call _bitir; };
    { _x setUnitPos "MIDDLE"; _x doWatch _c; } forEach _A;

    // (3) takim B gecer
    { _x setUnitPos "UP"; _x forceSpeed -1; _x setSpeedMode "FULL"; _x doMove (_hedefNokta getPos [random 5, random 360]); } forEach _B;
    private _bitisB = time + 25;
    waitUntil { sleep 0.5; time > _bitisB || {[_g] call _iptalMi} || {(_B findIf {alive _x && {(_x distance2D _hedefNokta) > 12}}) < 0} };
    [_g, ["TAMAM (" + str (round (time - _t0)) + " sn)", "temas / retreat (B gecerken)"] select ([_g] call _iptalMi)] call _bitir;
};
missionNamespace setVariable ["lambs_danger_tehlikeAlaniGecisFn", _gecis];

// ---- v8.390: ACIK ALAN GECISI (gozetle + oncu eleman + yayilarak gec) ----
private _acikGecis = {
    params ["_g", "_kenar", "_karsi", "_yon", "_gen"];
    private _t0 = time;
    private _l = leader _g;
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _bitir = {
        params ["_g", "_neden"];
        if (isNull _g) exitWith {};
        _g setVariable [QGVAR(isExecutingTactic), nil];
        _g setVariable [QGVAR(tehlikeAlaniT), time];
        {
            if (alive _x) then {
                _x setVariable [QGVAR(taktikKilit), nil];
                _x setVariable [QGVAR(forceMove), nil];
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _g);
            };
        } forEach (units _g);
        if (!isNull (leader _g) && {currentWaypoint _g > 0 || {(count (waypoints _g)) > 0}}) then { _g setCurrentWaypoint [_g, currentWaypoint _g]; };
        diag_log format ["[TEHLIKE-ACIK] %1 | SERBEST: %2", groupId _g, _neden];
    };
    private _iptalMi = { params ["_g"]; isNull _g || {(_g getVariable [QGVAR(contact), 0]) > time} || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} };
    // yanal yayilma: merkez noktaya yon + 90 eksende ofs (m, +/-) kayik nokta
    private _yanNokta = {
        params ["_c", "_yon", "_ofs"];
        _c getPos [abs _ofs, _yon + ([90, -90] select (_ofs < 0))]
    };
    // takimi noktalara yollar, hepsi varana ya da sure bitene kadar bekler; false = iptal
    private _gecir = {
        params ["_g", "_takim", "_karsi", "_yon", "_sure", "_dur"];
        private _n = count _takim;
        {
            private _nokta = [_karsi getPos [random 3, random 360], _yon, (_forEachIndex - ((_n - 1) / 2)) * 7] call _yanNokta;
            _x setVariable [QGVAR(taktikKilit), time + _sure + 30];
            _x setUnitPos "UP";
            _x forceSpeed -1;
            _x setSpeedMode "FULL";
            _x doMove _nokta;
            _x setVariable [QGVAR(acikHedef), _nokta];
        } forEach _takim;
        private _bitis = time + _sure;
        waitUntil {
            sleep 0.5;
            time > _bitis || {[_g] call (missionNamespace getVariable "lambs_danger_tehlikeAcikIptalFn")}
            || {(_takim findIf {alive _x && {(_x distance2D (_x getVariable [QGVAR(acikHedef), _karsi])) > 12}}) < 0}
        };
        if ([_g] call (missionNamespace getVariable "lambs_danger_tehlikeAcikIptalFn")) exitWith {false};
        { _x setUnitPos _dur; _x doWatch (_karsi getPos [120, _yon]); } forEach (_takim select {alive _x});
        true
    };
    missionNamespace setVariable ["lambs_danger_tehlikeAcikIptalFn", _iptalMi];

    private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
    if ((count _us) < 5) exitWith {};
    private _sure = 20 + (_gen + (_kenar distance2D _karsi)) / 4;
    _g setVariable [QGVAR(isExecutingTactic), true];

    // takimlar: gozetleme (lider + MG + nisanci, en az 1/3), oncu (gozcu / tufekli, 7+ kisi = 2), ana govde (kalan)
    private _digerler = _us select {_x isNotEqualTo _l};
    private _ozel = _digerler select {([_x] call _rolFn) in ["MG", "MARKSMAN"]};
    private _ow = [_l] + (_ozel select [0, 2 min (count _ozel)]);
    private _owMin = ceil ((count _us) / 3);
    if ((count _ow) < _owMin) then {
        private _ek = [_digerler - _ow, [], {_x distance2D _l}, "ASCEND"] call BIS_fnc_sortBy;
        _ow = _ow + (_ek select [0, _owMin - (count _ow)]);
    };
    private _kalan = _digerler - _ow;
    private _oncuAdet = [1, 2] select ((count _us) >= 7);
    private _gozcu = _kalan select {(_x getVariable [QGVAR(gozcu), false]) || {_x isEqualTo (_g getVariable [QGVAR(gozcu), objNull])}};
    private _tufekli = _kalan select {([_x] call _rolFn) isEqualTo "RIFLE"};
    private _oncu = ((_gozcu + _tufekli + _kalan) arrayIntersect _kalan) select [0, _oncuAdet min (count _kalan)];
    private _ana = _kalan - _oncu;
    private _nA = ceil ((count _ana) / 2);
    private _A = _ana select [0, _nA];
    private _B = _ana select [_nA, count _ana];
    diag_log format ["[TEHLIKE-ACIK] %1 | ACIK ALAN GECISI basladi | acik serit %2 m, karsi kenar %3 m | gozetleme:%4 oncu:%5 (%6) ana govde A:%7 B:%8",
        groupId _g, round _gen, round (_l distance2D _karsi), count _ow, count _oncu, _oncu apply {name _x}, count _A, count _B];

    // (1) dur + gozetle
    { _x setVariable [QGVAR(taktikKilit), time + _sure * 4 + 40]; doStop _x; } forEach _us;
    { _x setUnitPos "DOWN"; _x doWatch _karsi; } forEach _ow;
    { _x setUnitPos "MIDDLE"; _x doWatch _karsi; } forEach (_us - _ow);
    private _bek = time + 8;
    waitUntil { sleep 0.5; time > _bek || {[_g] call _iptalMi} };
    if ([_g] call _iptalMi) exitWith { [_g, "temas / retreat (gozetleme)"] call _bitir; };

    // (2) oncu eleman karsi kenara
    if (_oncu isNotEqualTo []) then {
        private _ok = [_g, _oncu, _karsi, _yon, _sure, "MIDDLE"] call _gecir;
        if (!_ok) exitWith { [_g, "temas / retreat (oncu gecerken)"] call _bitir; };
        private _guv = time + 8;
        waitUntil { sleep 0.5; time > _guv || {[_g] call _iptalMi} };
        if ([_g] call _iptalMi) exitWith { [_g, "temas (karsi kenar guvenligi)"] call _bitir; };
        diag_log format ["[TEHLIKE-ACIK] %1 | oncu eleman karsi kenarda, temiz (%2 sn)", groupId _g, round (time - _t0)];
    };
    if (isNull _g || {!(_g getVariable [QGVAR(isExecutingTactic), false])}) exitWith {};

    // (3) ana govde iki yari, yayilarak
    private _devam = true;
    {
        if (_devam && {_x isNotEqualTo []}) then {
            private _ok = [_g, _x, _karsi, _yon, _sure, "MIDDLE"] call _gecir;
            if (!_ok) then { _devam = false; };
        };
    } forEach [_A, _B];
    if (!_devam) exitWith { [_g, "temas / retreat (ana govde gecerken)"] call _bitir; };

    // (4) gozetleme ekibi en son
    private _ok4 = [_g, _ow select {alive _x}, _karsi, _yon, _sure, "MIDDLE"] call _gecir;
    [_g, ["TAMAM (" + str (round (time - _t0)) + " sn)", "temas / retreat (gozetleme ekibi gecerken)"] select (!_ok4)] call _bitir;
};

missionNamespace setVariable ["lambs_danger_tehlikeAcikGecisFn", _acikGecis];

private _calis = {
    missionNamespace setVariable ["lambs_danger_tehlikeAdim", "basladi"];
    private _gecisFn = missionNamespace getVariable "lambs_danger_tehlikeAlaniGecisFn";
    private _acikFn = missionNamespace getVariable "lambs_danger_tehlikeAcikGecisFn";
    // v8.390: lider ortu kenarinda mi + rota <= 50 m ileride >= 60 m acik serit + karsi kenar <= menzil. Doner: [neden, karsi, serit] (neden "" = uygun)
    private _ortuVar = {
        params ["_p"];
        surfaceIsWater _p || {(count (nearestTerrainObjects [_p, ["TREE", "BUILDING", "HOUSE", "ROCK", "WALL", "HIDE", "FOREST"], 15, false, true])) > 0}
    };
    private _acikTara = {
        params ["_lp", "_yon", "_menzil", "_hedefD"];
        if !([_lp] call _ortuVar) exitWith {["lider ortusuz", [], 0]};
        private _liste = [];
        for "_d" from 10 to _menzil step 10 do { _liste pushBack ([_lp getPos [_d, _yon]] call _ortuVar); };
        private _i1 = _liste findIf {!_x};
        if (_i1 < 0 || {_i1 > 4}) exitWith {["acik serit yok", [], 0]};
        private _k = (_liste select [_i1]) findIf {_x};
        if (_k < 0) exitWith {["karsi kenar menzil disi", [], 0]};
        private _gen = _k * 10;
        if (_gen < 60) exitWith {["serit dar", [], 0]};
        private _d2 = (_i1 + _k + 1) * 10;
        if (_hedefD < (_d2 + 20)) exitWith {["hedef serit icinde", [], 0]};
        private _karsi = _lp getPos [_d2, _yon];
        if (surfaceIsWater _karsi) exitWith {["karsi kenar su", [], 0]};
        if (terrainIntersectASL [AGLToASL (_lp vectorAdd [0, 0, 1.6]), AGLToASL (_karsi vectorAdd [0, 0, 1.6])]) exitWith {["karsi kenar gorulmuyor", [], 0]};
        ["", _karsi, _gen]
    };
    private _say = createHashMap;
    private _ozetT = time + 90;
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_tehlikeAlaniOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if ((time - (_g getVariable [QGVAR(tehlikeAlaniT), -999])) < 120) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) > (time - 20)) then { continue };
            if (({_g getVariable [_x, false]} count [QGVAR(isRetreating), QGVAR(isEvading), QGVAR(isBounding), QGVAR(isExecutingTactic), QGVAR(isBreakingContact), QGVAR(isAmbushing), QGVAR(sniperTeam), QGVAR(isSonDirenis), QGVAR(disableGroupAI)]) > 0) then { continue };
            if ((_g getVariable [QGVAR(iedIs), []]) isNotEqualTo []) then { continue };
            if (((units _g) select {alive _x && {isNull objectParent _x}}) isEqualTo [] || {(count ((units _g) select {alive _x && {isNull objectParent _x}})) < 5}) then { continue };
            if ((speed _l) < 2) then { continue };
            missionNamespace setVariable ["lambs_danger_tehlikeAdim", format ["grup %1", groupId _g]];
            private _lp = getPosATL _l;
            if (isOnRoad _lp) then { continue };
            private _ed = expectedDestination _l;
            private _hedef = _ed select 0;
            if (!(_hedef isEqualType []) || {_hedef isEqualTo [0,0,0]} || {(_l distance2D _hedef) < 40}) then { continue };
            private _yon = _lp getDir _hedef;
            private _bulunan = [];
            for "_d" from 20 to 70 step 15 do {
                private _p = _lp getPos [_d, _yon];
                private _yol = roadAt _p;
                if (!isNull _yol) exitWith { _bulunan = [_p, _yol, _d]; };
            };
            if (_bulunan isEqualTo []) then {
                // v8.390: yol yok -> ACIK ALAN taramasi (9 sn'de bir)
                if (!(missionNamespace getVariable ["lambs_danger_tehlikeAcikAktif", true]) || {missionNamespace getVariable ["lambs_danger_tehlikeAcikOff", false]}) then { continue };
                if ((time - (_g getVariable [QGVAR(tehlikeAcikBakT), -999])) < 9) then { continue };
                _g setVariable [QGVAR(tehlikeAcikBakT), time];
                private _ac = [_lp, _yon, missionNamespace getVariable ["lambs_danger_tehlikeAcikMenzil", 250], _l distance2D _hedef] call _acikTara;
                if ((_ac select 0) isNotEqualTo "") then {
                    if ((_ac select 0) in ["karsi kenar menzil disi", "karsi kenar gorulmuyor", "hedef serit icinde"]) then { _say set [_ac select 0, (_say getOrDefault [_ac select 0, 0]) + 1]; };
                    continue
                };
                _g setVariable [QGVAR(tehlikeAlaniT), time];
                _say set ["acik alan gecisi", (_say getOrDefault ["acik alan gecisi", 0]) + 1];
                [_g, _lp, _ac select 1, _yon, _ac select 2] spawn _acikFn;
                continue
            };
            _bulunan params ["_c", "_yolObj", "_d"];
            // cevre ACIK mi
            private _bina = count (nearestTerrainObjects [_c, ["BUILDING", "HOUSE"], 80, false, true]);
            private _agac = count (nearestTerrainObjects [_c, ["TREE", "SMALL TREE", "BUSH"], 40, false, true]);
            if (_bina >= 6 || {_agac >= 6}) then { _say set ["kapali cevre", (_say getOrDefault ["kapali cevre", 0]) + 1]; continue };
            // yol ekseni
            private _bagli = roadsConnectedTo _yolObj;
            private _yonYol = if (_bagli isEqualTo []) then { _yon + 90 } else { (getPosATL _yolObj) getDir (getPosATL (_bagli select 0)) };
            _g setVariable [QGVAR(tehlikeAlaniT), time];
            _say set ["gecis", (_say getOrDefault ["gecis", 0]) + 1];
            [_g, _c, _yonYol, _yon] spawn _gecisFn;
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[TEHLIKE-ALANI-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_tehlikeAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] tehlike alani betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_tehlikeAdim", "?"]];
        sleep 5;
    };
};

true
