#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEKANIZE DUR-KALK IZLEYICISI + DUZELTICI (v8.80) — kullanici: "APC cok hantal gidiyordu, dur kalk atiyordu; mekanize felc".
 *
 * IZLEME (2 sn'de bir, yerel / oyuncusuz surucu, kara araci - APC / IFV / tank / arac, lider aracta): son 40 sn hiz ornegi; hiz > 8 km/s'ten < 2 km/s'e dusus >= 3 kez = DUR-KALK.
 * TESHIS LOGU [MEKANIZE-DUR-KALK]: grup davranis / savas modu / hiz modu / formasyon, surucu komutu (currentCommand) / unitReady / beklenen hedef, baski, temas yasi, en yakin bilinen dusman, aktif taktik bayraklari,
 *   aracin onunde 10 m'de arazi nesnesi sayisi, motor / yakit / hasar  (60 sn'de bir; ilk 40) -> kok neden RPT'den okunur.
 * DUZELTICI (kapatma: lambs_danger_mekanizeDuzeltOff = true): dusman bilinmiyor / > 100 m ise
 *   - formasyon COLUMN (arac gruplarinda LINE / WEDGE slot kovalatir -> dur-kalk), formSet hakemi uzerinden
 *   - grup davranisi COMBAT ise (son temas > 15 sn) AWARE
 *   - surucu AUTOCOMBAT kapatilir (60 sn; 'tehlike gordu, durdu' tepkisi azalir); sure bitince geri acilir
 * AI hilesi yok. Esikler TASARIM tahmini. NOT: mekanize TAKTIKLER (arac ates destegi + inis mesafesi) ve ARACLI MEDEVAC bu surumde YOK — once bu logla kok neden okunacak.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_mekanizeStarted") exitWith {false};
lambs_danger_mekanizeStarted = true;

diag_log "[MEKANIZE] dur-kalk izleyicisi + duzeltici baslatildi (v8.80)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_mekanizeAdim", "basladi"];
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_mekanizeOff", false]) then { continue };
        private _duzelt = !(missionNamespace getVariable ["lambs_danger_mekanizeDuzeltOff", false]);
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l}) then { continue };
            private _veh = vehicle _l;
            if (_veh isEqualTo _l || {!(_veh isKindOf "LandVehicle")}) then { continue };
            private _d = driver _veh;
            if (isNull _d || {isPlayer _d} || {!alive _d}) then { continue };
            missionNamespace setVariable ["lambs_danger_mekanizeAdim", format ["grup %1", groupId _g]];

            // AUTOCOMBAT geri verme suresi
            if ((_d getVariable [QGVAR(mekAcT), 0]) > 0 && {time > (_d getVariable [QGVAR(mekAcT), 0])}) then {
                _d enableAI "AUTOCOMBAT";
                _d setVariable [QGVAR(mekAcT), nil];
            };

            private _hist = _veh getVariable [QGVAR(mekHist), []];
            _hist pushBack [time, speed _veh];
            _hist = _hist select {(time - (_x select 0)) <= 40};
            _veh setVariable [QGVAR(mekHist), _hist];
            _say set ["izlenen", (_say getOrDefault ["izlenen", 0]) + 1];

            private _gecis = 0;
            private _hareketli = false;
            {
                private _s = _x select 1;
                if (_s > 8) then { _hareketli = true; } else { if (_s < 2 && {_hareketli}) then { _gecis = _gecis + 1; _hareketli = false; }; };
            } forEach _hist;
            if (_gecis < 3) then { continue };
            if (_g getVariable [QGVAR(isRetreating), false] || {_g getVariable [QGVAR(isEvading), false]}) then { continue };
            if ((time - (_veh getVariable [QGVAR(mekRapT), -999])) < 60) then { continue };
            _veh setVariable [QGVAR(mekRapT), time];
            _say set ["DUR-KALK", (_say getOrDefault ["DUR-KALK", 0]) + 1];

            private _en = _d findNearestEnemy _d;
            private _enM = if (isNull _en) then { -1 } else { _d distance2D _en };
            private _bayrak = ["isBounding", "isExecutingTactic", "isAmbushing", "isBreakingContact", "isSonDirenis"] select {_g getVariable ["lambs_danger_" + _x, false]};
            private _onunde = count (nearestTerrainObjects [_veh modelToWorld [0, 10, 0], ["TREE", "ROCK", "WALL", "FENCE", "BUILDING", "HOUSE"], 5]);
            if (_logN < 40) then {
                _logN = _logN + 1;
                diag_log format ["[MEKANIZE-DUR-KALK] %1 | arac %2 | %3 gecis / 40 sn | grup: beh %4 savas %5 hizmodu %6 formasyon %7 | surucu: komut %8 hazir %9 hedef %10 baski %11 | temas yasi %12 sn | en yakin dusman %13 m | taktik bayrak %14 | onunde nesne %15 | motor %16 yakit %17 hasar %18",
                    groupId _g, typeOf _veh, _gecis, behaviour _l, combatMode _g, speedMode _g, formation _g,
                    currentCommand _d, unitReady _d, expectedDestination _d, (getSuppression _d) toFixed 2,
                    round (time - (_g getVariable [QGVAR(contact), -999])), round _enM, _bayrak, _onunde, isEngineOn _veh, (fuel _veh) toFixed 2, (damage _veh) toFixed 2];
            };
            if (_duzelt && {_enM < 0 || {_enM > 100}}) then {   // v8.82: 250 -> 100 m (RPT f3b1b53f: Stryker dur-kalk dusman 148 m'de yasandi, duzeltici 250 esiginde calismadi)
                [_g, "COLUMN", "mekanize", 1] call FUNC(formSet);
                if ((speedMode _g) isEqualTo "NORMAL") then { _g setSpeedMode "FULL"; };   // mekanize hizli yurur (NORMAL = surucu yarim hizda)
                if ((behaviour _l) isEqualTo "COMBAT" && {(time - (_g getVariable [QGVAR(contact), -999])) > 15}) then { _g setBehaviour "AWARE"; };
                if ((_d getVariable [QGVAR(mekAcT), 0]) == 0) then {
                    _d disableAI "AUTOCOMBAT";
                    _d setVariable [QGVAR(mekAcT), time + 60];
                };
                _say set ["duzeltildi", (_say getOrDefault ["duzeltildi", 0]) + 1];
                if (_logN < 40) then { diag_log format ["[MEKANIZE-DUR-KALK] %1 | DUZELTICI: COLUMN + FULL hiz + AWARE + surucu AUTOCOMBAT 60 sn kapali (dusman %2 m)", groupId _g, round _enM]; };
            };
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[MEKANIZE-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_mekanizeAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] mekanize betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_mekanizeAdim", "?"]];
        sleep 5;
    };
};

true
