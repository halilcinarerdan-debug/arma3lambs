#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON OPERATORU AVI — HQ DEVRIYE (v8.320; kullanici: 'objektiften uzaktan dron gonderdigimizde ... devriye gondersinler ama operasyon emrinde ayarlanabilsin, opsiyonel').
 * Cagiran: fnc_dronTepki (dron izi geri-yonu bulununca). Ayni tarafin IKI ayri gozleminden (>= 20 sn arayla) operator bolgesi tahmini cikarilir (dogrular kesisirse kesisim, yoksa son dogru uzerinde 700 m);
 * temasta olmayan, plan gorevinde olmayan en yakin YEREL dost gruptan 2 (ya da 4) asker AYRI bir devriye grubuna alinir ve tahmin edilen bolgeye (en cok 800 / 1000 m) kisa adimlarla (<= 220 m, AWARE / YELLOW)
 * gider, son noktada ARAMA (SAD, 70 m); sure (mesafe / 1.2 m/sn + 150 sn) dolunca / devriye kayiplariyla / hedefe varinca asil gruba katilir. Taraf basina 300 sn'de bir.
 * AYAR: OPERASYON EMRI (ELITE Objektif 4/4 'Dron operatoru avi'): 0 CBA'ya uy | 1 Hayir | 2 Evet: 3 kisilik alt grup | 3 Evet: 4 kisilik alt grup (guclu, 1000 m); asgari 3 (v8.327). Aktif plan yoksa / 0 ise CBA 'lambs_danger_dronAviAktif' (varsayilan acik = 2 kisilik).
 * Kapatma: lambs_danger_dronAviOff = true.   Log: [DRON-AVI]
 *
 * Arguments:
 * 0: Grup (dronu fark eden) <GROUP>
 * 1: Dron izinin ilk noktasi <ARRAY>
 * 2: Geri-yon (operator yonu, derece) <NUMBER>
 *
 * Return Value: Devriye asker sayisi <NUMBER>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_p0", [], [[]]], ["_geri", 0, [0]]];
if (isNull _g || {_p0 isEqualTo []} || {missionNamespace getVariable ["lambs_danger_dronAviOff", false]}) exitWith {0};
private _taraf = side _g;

// ---- ayar: operasyon emri (aktif plan) > CBA ----
private _mod = if (missionNamespace getVariable ["lambs_danger_dronAviAktif", true]) then {3} else {0};   // v8.327: _mod = devriye EN FAZLA kac asker (3 / 4); asgari 3 (kullanici: zorunlu 4 kisi sart degil, alt grup olabilir ama 3'ten kucuk olmasin)
private _aracIste = missionNamespace getVariable ["lambs_danger_dronAviArac", true];   // v8.322: CBA - arac (hafif, recon mantigi) varsa aracla
private _planlar = (values (missionNamespace getVariable ["lambs_danger_planlar", createHashMap])) select {(_x getOrDefault ["taraf", sideUnknown]) isEqualTo _taraf};
if (_planlar isNotEqualTo []) then {
    private _opt = ((_planlar select 0) getOrDefault ["ayar", createHashMap]) getOrDefault ["dronAvi", 0];
    if (_opt > 0) then {
        _mod = [0, 0, 3, 4, 3, 4] select (_opt min 5);
        if (_opt >= 2) then { _aracIste = _opt >= 4; };   // 2 / 3 = yaya, 4 / 5 = hafif aracla
    };
};
if (_mod <= 0) exitWith {0};

// ---- gozlem kaydi (tarafa ozel, 120 sn) ----
private _obs = (missionNamespace getVariable ["lambs_danger_dronAviObs", []]) select {(time - (_x select 2)) < 120 && {(_x select 3) isEqualTo _taraf}};
_obs pushBack [_p0, _geri, time, _taraf];
missionNamespace setVariable ["lambs_danger_dronAviObs", _obs];
if ((count _obs) < 2) exitWith {0};
private _ozK = format ["lambs_danger_dronAviT_%1", _taraf];
if ((time - (missionNamespace getVariable [_ozK, -999])) < 300) exitWith {0};

// ---- operator bolgesi tahmini ----
private _est = [];
private _tur = "TEK DOGRU";
{
    private _a = _x select 0; private _t1 = _x select 1;
    if ((time - (_x select 2)) >= 20 && {(abs ((((_geri - _t1) + 540) mod 360) - 180)) <= 165}) then {
        private _d1 = [sin _t1, cos _t1];
        private _d2 = [sin _geri, cos _geri];
        private _det = ((_d1 select 0) * (_d2 select 1)) - ((_d1 select 1) * (_d2 select 0));
        if ((abs _det) > 0.26) then {
            private _ab = [(_p0 select 0) - (_a select 0), (_p0 select 1) - (_a select 1)];
            private _t = (((_ab select 0) * (_d2 select 1)) - ((_ab select 1) * (_d2 select 0))) / _det;
            private _s = (((_ab select 0) * (_d1 select 1)) - ((_ab select 1) * (_d1 select 0))) / _det;
            if (_t > 150 && {_t < 2500} && {_s > 150} && {_s < 2500}) then { _est = [(_a select 0) + _t * (_d1 select 0), (_a select 1) + _t * (_d1 select 1), 0]; _tur = "KESISIM"; };
        };
    };
    if (_est isNotEqualTo []) exitWith {};
} forEach (_obs select [0, (count _obs) - 1]);
if (_est isEqualTo []) then { _est = _p0 getPos [700, _geri]; };

// ---- devriye grubu: temasta olmayan, plan gorevinde olmayan en yakin yerel dost grup ----
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
// v8.327 (RPT 40d48a79: tum EAST gruplari SAVUNMA planinda (planAktif) oldugu icin 16 dron gozleminde hic devriye cikmadi): savunma planindaki (tip 1) grup da kaynak olabilir; taarruz plani gruplari yine haric
private _savunmaPlani = { params ["_gg"]; (((missionNamespace getVariable ["lambs_danger_planlar", createHashMap]) getOrDefault [_gg getVariable ["lambs_danger_planId", ""], createHashMap]) getOrDefault ["tip", 0]) isEqualTo 1 };
private _adaylar = allGroups select {
    local _x && {(side _x) isEqualTo _taraf} && {!isNull (leader _x)} && {alive (leader _x)} && {!isPlayer (leader _x)} && {isNull objectParent (leader _x)}
    && {(_x getVariable [QGVAR(contact), 0]) <= time} && {!((_x getVariable [QGVAR(planAktif), false]) || {_x getVariable ["lambs_danger_planAktif", false]}) || {[_x] call _savunmaPlani}}
    && {!(_x getVariable [QGVAR(isRetreating), false])} && {!(_x getVariable [QGVAR(isEvading), false])} && {!(_x getVariable [QGVAR(teslimOldu), false])} && {!(_x getVariable [QGVAR(dronAviGrup), false])}
    && {(({alive _x} count (units _x)) >= 5)}   // lider + 1 asker kaynakta kalir, en az 3 asker cikar
    && {((leader _x) distance2D _est) >= 250} && {((leader _x) distance2D _est) <= 3000}
};
if (_adaylar isEqualTo []) exitWith {
    // v8.327 TANI: neden devriye cikmadi (60 sn'de bir)
    if ((time - (missionNamespace getVariable ["lambs_danger_dronAviTaniT", -999])) > 60) then {
        missionNamespace setVariable ["lambs_danger_dronAviTaniT", time];
        private _yerel = allGroups select {local _x && {(side _x) isEqualTo _taraf} && {!isNull (leader _x)} && {alive (leader _x)}};
        diag_log format ["[DRON-AVI] %1 | devriye cikmadi: aday grup yok | yerel grup %2 | temasta %3 | taarruz planinda %4 | kucuk (< %5 kisi) %6 | araci %7 | tahmin mesafesi disinda (250-3000 m) %8", _taraf, count _yerel,
            {(_x getVariable [QGVAR(contact), 0]) > time} count _yerel, {(_x getVariable [QGVAR(planAktif), false]) && {!([_x] call _savunmaPlani)}} count _yerel, 5, {({alive _x} count (units _x)) < 5} count _yerel,
            {!isNull objectParent (leader _x)} count _yerel, {private _dd = (leader _x) distance2D _est; _dd < 250 || {_dd > 3000}} count _yerel];
    };
    0
};
private _kaynak = ([_adaylar, [], {(leader _x) distance2D _est}, "ASCEND"] call BIS_fnc_sortBy) select 0;
private _l = leader _kaynak;
private _kisiler = ((units _kaynak) select {
    _x isNotEqualTo _l && {alive _x} && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
    && {!(_x getVariable [QGVAR(teslim), false])} && {!captive _x} && {(primaryWeapon _x) isNotEqualTo ""}
    && {!(([_x] call _rolFn) in ["MG", "AT", "MEDIC"])}
}) select [0, (_mod min (((count (units _kaynak select {alive _x})) - 2) max 3))];   // 5-6 kisilik gruptan 3, 7+ kisilikten _mod
if ((count _kisiler) < 3) exitWith {0};

// ---- devriye ----
private _pg = createGroup _taraf;
_kisiler joinSilent _pg;
_pg setVariable [QGVAR(dronAviGrup), true];
_pg setBehaviour "AWARE";
_pg setCombatMode "YELLOW";
_pg setSpeedMode "NORMAL";
_pg setFormation "WEDGE";
private _lp = getPosATL _l;
private _brg = _lp getDir _est;
private _maxM = [800, 1000] select (_mod > 3);
private _mesafe = ((_lp distance2D _est) min _maxM) max 150;
private _adim = (ceil (_mesafe / 220)) max 1;
// ---- v8.322 ARAC (RECON MANTIGI: kullanici 'reconla ayni kafada gitsinler, ayni mantikta, kitaba uygunsa kucuk ve hizli arac, humvee gibi') ----
//   fnc_reconArac (SEC + CALIS) sentetik plan ile kullanilir: ayrilmis, AI surucusu olan HAFIF arac (Car, <= 8 koltuk, en kucuk = en hizli) alma noktasina gelir, devriye biner, SESSIZ surus (SAFE / GREEN, isiksiz, ~32 km/s, yol zinciri),
//   hedefe 150 m kala iner, arac 250 m geri cekilir; devriye son yaklasmayi YAYA yapar (SAD). Arac yoksa / basarisizsa YAYA devriye (eski davranis).
private _aracVar = false;
private _arPlan = createHashMap;
private _opN = _lp getPos [((_lp distance2D _est) min 1600) max 250, _brg];
if (_aracIste) then {
    _arPlan = createHashMapFromArray [["id", format ["DRONAVI-%1", round time]], ["taraf", _taraf], ["reconG", [_pg]], ["rp", _lp], ["hqPoz", _lp], ["aracHafif", true]];
    private _av = ["SEC", _arPlan] call FUNC(reconArac);
    // v8.323 (kullanici: 'ama mumkunse, yoksa eldekini degerlendirsinler'): hafif arac yoksa eldeki uygun araca (APC / kamyon / IFV; recon arac secimi) bin; o da yoksa yaya
    if (isNull _av) then {
        _arPlan set ["aracHafif", false];
        _av = ["SEC", _arPlan] call FUNC(reconArac);
        if (!isNull _av) then { diag_log format ["[DRON-AVI] %1 | hafif arac yok -> eldeki arac: %2", groupId _kaynak, getText (configOf _av >> "displayName")]; };
    };
    if (!isNull _av) then { _arPlan set ["reconArac", _av]; _aracVar = true; };
};

if (!_aracVar) then {
for "_i" from 1 to _adim do {
    private _nokta = _lp getPos [_mesafe * (_i / _adim), _brg];
    if (surfaceIsWater _nokta) then { _nokta = _lp getPos [(_mesafe * (_i / _adim)) * 0.9, _brg + 25]; };
    private _w = _pg addWaypoint [_nokta, 20];
    _w setWaypointType (["MOVE", "SAD"] select (_i isEqualTo _adim));
    _w setWaypointBehaviour "AWARE";
    _w setWaypointCombatMode "YELLOW";
    _w setWaypointSpeed "NORMAL";
    _w setWaypointCompletionRadius ([35, 70] select (_i isEqualTo _adim));
};
};
missionNamespace setVariable [_ozK, time];
diag_log format ["[DRON-AVI] %1 | %2 | devriye: %3 asker (%4) %5 m ileriye (tahmin %6, %7 yonu %8 derece) | kaynak grup %9 | operasyon emri modu %10", groupId _kaynak, _taraf, count _kisiler, "3-4 kisilik alt grup", round _mesafe, _tur, mapGridPosition _est, round _brg, groupId _kaynak, _mod];

[_pg, _kaynak, _kisiler, _mesafe, _aracVar, _arPlan, _opN, _est] spawn {
    params ["_pg", "_orijin", "_kisiler", "_mesafe", "_aracVar", "_arPlan", "_opN", "_est"];
    // yaya devriye waypoint'leri (poz -> hedef, en cok _max m, <= 220 m adimlar, son nokta SAD)
    private _yayaGit = {
        params ["_grp", "_poz", "_hdf", "_max"];
        private _brg2 = _poz getDir _hdf;
        private _ms = ((_poz distance2D _hdf) min _max) max 100;
        private _ad = (ceil (_ms / 220)) max 1;
        for "_i" from 1 to _ad do {
            private _nk = _poz getPos [_ms * (_i / _ad), _brg2];
            if (surfaceIsWater _nk) then { _nk = _poz getPos [(_ms * (_i / _ad)) * 0.9, _brg2 + 25]; };
            private _w = _grp addWaypoint [_nk, 20];
            _w setWaypointType (["MOVE", "SAD"] select (_i isEqualTo _ad));
            _w setWaypointBehaviour "AWARE";
            _w setWaypointCombatMode "YELLOW";
            _w setWaypointSpeed "NORMAL";
            _w setWaypointCompletionRadius ([35, 70] select (_i isEqualTo _ad));
        };
        _ms
    };
    private _sure = (_mesafe / 1.2) + 150;
    if (_aracVar) then {
        // v8.322 RECON MANTIGI: ayrilmis hafif arac alir, sessiz surus, 150 m kala indirir, arac 250 m geri cekilir (fnc_reconArac CALIS)
        private _h = ["CALIS", _arPlan, [_pg], _opN] spawn FUNC(reconArac);
        private _tout = time + 480 + ((_pg distance2D _opN) / 5);
        waitUntil {
            sleep 3;
            scriptDone _h || {_arPlan getOrDefault ["reconAracInis", false]} || {_arPlan getOrDefault ["reconAracBasarisiz", false]} || {time > _tout} || {({alive _x} count (units _pg)) isEqualTo 0}
        };
        private _lider = (units _pg) select {alive _x};
        if (_lider isNotEqualTo []) then {
            private _inis = _arPlan getOrDefault ["reconAracInis", false];
            if (!_inis && {!scriptDone _h}) then { terminate _h; };
            private _pos = getPosATL (_lider select 0);
            // indiyse: iniş noktasindan hedefe en cok 350 m yaya; indirilemediyse (arac yok / basarisiz): baslangictan 800 m yaya (eski davranis)
            private _ms = [_pg, _pos, _est, [800, 350] select _inis] call _yayaGit;
            _sure = (_ms / 1.2) + 150;
            diag_log format ["[DRON-AVI] %1 | arac asamasi bitti: %2 | yaya son yaklasma %3 m", groupId _pg, ["BASARISIZ / zaman asimi -> yaya devriye", "INDI (recon mantigi)"] select _inis, round _ms];
        };
    };
    private _bit = time + _sure;
    waitUntil {
        sleep 5;
        time > _bit || {({alive _x} count (units _pg)) isEqualTo 0} || {(currentWaypoint _pg) >= (count (waypoints _pg))}
    };
    sleep 30;
    private _kalan = (units _pg) select {alive _x};
    if (!isNull _orijin && {({alive _x} count (units _orijin)) > 0}) then {
        _kalan joinSilent _orijin;
    };
    deleteGroup _pg;
    diag_log format ["[DRON-AVI] devriye bitti | %1 asker asil gruba katildi | sure %2 sn", count _kalan, round (_sure - (_bit - time))];
};
count _kisiler
