#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PANIK / FELC (v8.73) — savasta insan deterministik degildir: bazi askerler donar, kor atar ya da kosar. LAMBS panik sistemiyle entegre.
 *
 * LAMBS ENTEGRASYONU: (1) bu modul bir panik bolumu baslatirken lambs_main_fnc_doPanic'i cagirir (callout "panic" + LAMBS "OnPanic" olayi, tum LAMBS dinleyicileri bilir);
 *   (2) LAMBS'in KENDI paniki (doPanic -> birimin gorevi "Panic") tespit edilirse ayni etki UYGULANIR (LAMBS'te panik sadece callout idi; felc / kor ates / kacis yoktu).
 *
 * GERILIM (3 sn'de bir, yerel / oyuncusuz / piyade asker, yalniz grup temasta): s = 0.6 x baski + 0.35 (12 sn / 25 m icinde dost oldu) + 0.30 x (1 - grup morali) [moral modulu]
 *   + 0.15 (lider olu / grup liderine > 60 m) + 0.10 (en yakin dost > 60 m)           (hepsi TASARIM tahmini, doktrin sayisi degil)
 * SANS: s >= 0.45 ise tikte p = (s - 0.45) x 0.5 x (1.3 - courage) x lambs_danger_panikSans (varsayilan 0.35: oyuncu karsisinda PvE zorlugu korunur) x (lider ? 0.4 : 1), azami 0.12.
 *   Sinirlar: ayni asker 40 sn bagisiklik (bolumden sonra), grupta ayni anda en fazla %30 panikte, retreat sirasinda x0.5, saglikci tedavi / EOD imha / IED isinde x0.5.
 * TURLER (agirliklar gerilime gore): DONMA (3-7 sn: yere yatar, hareket etmez, emir almaz; lider 20 m icindeyse %40 daha kisa) | KOR ATES (4-8 sn: yere yatar, nisan bozuk dusmana dogru rastgele ates) |
 *   KACIS (4-7 sn: tehditten uzaga 25-40 m kosar; gerilim >= 0.7 iken yaygin).
 * Bolum bitince normale doner (doFollow, beceri / AI bayraklari geri). Kapatma: lambs_danger_panikOff = true.   Log: [PANIK] (ilk 150) + [PANIK-OZET] 90 sn
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_panikStarted") exitWith {false};
lambs_danger_panikStarted = true;

diag_log "[PANIK] panik / felc watchdog'u baslatildi (v8.73)";

// ---- bolum yurutucu (birim basina) ----
private _bolum = {
    params ["_u", "_tur", "_sure", "_tehditPos", "_neden"];
    if (!alive _u) exitWith {};
    private _g = group _u;
    // v8.82: ust uste binen bolumde (RPT f3b1b53f: Jabr Takhtar DONMA ardindan KOR) ikinci bolum KENDI yazdigimiz disableAI = true'yu "eski deger" sanip kalici birakiyordu (BIRIM-AI-KAPALI).
    //   Orijinal deger yalniz ilk bolumde kaydedilir; bagisiklik sure sonunda DEGIL basta konur.
    if (time < (_u getVariable [QGVAR(panikBitis), 0])) exitWith {};
    private _eskiAcc = _u skill "aimingAccuracy";
    private _eskiDAI = _u getVariable [QGVAR(panikEskiDAI), _u getVariable [QGVAR(disableAI), false]];
    _u setVariable [QGVAR(panikEskiDAI), _eskiDAI];
    private _bitis = time + _sure;
    _u setVariable [QGVAR(panikBitis), _bitis];
    _u setVariable [QGVAR(panikBagT), _bitis + 40];
    _u setVariable [QGVAR(taktikKilit), _bitis];
    _u setVariable [QGVAR(disableAI), true];     // LAMBS birim duzeyi tepkileri durur (FSM bu birimi yonetmez)
    private _lambsPanik = missionNamespace getVariable ["lambs_main_fnc_doPanic", {}];
    [_u] call _lambsPanik;                        // callout "panic" + LAMBS OnPanic olayi
    _u setVariable [QEGVAR(main,currentTask), "Panic", EGVAR(main,debug_functions)];
    doStop _u;
    switch (_tur) do {
        case "DONMA": {
            _u setUnitPos "DOWN";
            _u disableAI "MOVE";
            _u disableAI "PATH";
            _u disableAI "AUTOTARGET";
        };
        case "KOR": {
            _u setUnitPos "DOWN";
            _u disableAI "MOVE";
            _u disableAI "PATH";
            _u setSkill ["aimingAccuracy", (_eskiAcc * 0.3) max 0.02];
            if (_tehditPos isNotEqualTo [0,0,0]) then { _u doSuppressiveFire (_tehditPos vectorAdd [(random 20) - 10, (random 20) - 10, 0]); };
        };
        case "KACIS": {
            _u enableAI "MOVE";
            _u enableAI "PATH";
            _u disableAI "TARGET";
            _u disableAI "AUTOTARGET";
            _u setBehaviour "AWARE";
            _u setSpeedMode "FULL";
            _u setUnitPos "UP";
            _u forceSpeed -1;
            private _yon = if (_tehditPos isNotEqualTo [0,0,0]) then { (_tehditPos getDir _u) + ((random 50) - 25) } else { random 360 };
            private _p = (getPosATL _u) getPos [25 + (random 15), _yon];
            if (surfaceIsWater _p) then { _p = getPosATL _u; };
            _u doMove _p;
        };
    };
    waitUntil { sleep 0.5; time > _bitis || {!alive _u} };
    if (alive _u) then {
        _u enableAI "MOVE";
        _u enableAI "PATH";
        _u enableAI "TARGET";
        _u enableAI "AUTOTARGET";
        _u setSkill ["aimingAccuracy", _eskiAcc];
        _u setUnitPos "AUTO";
        _u setVariable [QGVAR(disableAI), [nil, true] select _eskiDAI];
        _u setVariable [QGVAR(panikEskiDAI), nil];
        _u setVariable [QGVAR(taktikKilit), nil];
        _u setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
        _u setVariable [QGVAR(panikBagT), time + 40];
        if (!isNull (leader _g) && {_u isNotEqualTo (leader _g)}) then { _u doFollow (leader _g); };
    };
};
missionNamespace setVariable ["lambs_danger_panikBolumFn", _bolum];

private _calis = {
    missionNamespace setVariable ["lambs_danger_panikAdim", "basladi"];
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    private _bolumFn = missionNamespace getVariable "lambs_danger_panikBolumFn";
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_panikOff", false]) then { continue };
        private _sansCarpan = missionNamespace getVariable ["lambs_danger_panikSans", 0.35];   // v8.74: PvE zorluk korunur (oyuncu karsisinda) - varsayilan 0.35
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_panikAdim", format ["grup %1", groupId _g]];
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x}};

            // olum izleme: onceki turdaki birimlerden olenlerin son konumu
            private _eski = _g getVariable [QGVAR(panikPoz), []];
            private _olum = (_g getVariable [QGVAR(panikOlum), []]) select {(time - (_x select 1)) < 12};
            { if (!alive (_x select 0)) then { _olum pushBack [_x select 1, time]; }; } forEach _eski;
            _g setVariable [QGVAR(panikOlum), _olum];
            _g setVariable [QGVAR(panikPoz), _us apply {[_x, getPosATL _x]}];

            private _temas = (_g getVariable [QGVAR(contact), 0]) > time;
            private _panikte = {(time < (_x getVariable [QGVAR(panikBitis), 0]))} count _us;
            private _moral = _g getVariable [QGVAR(moral), 1];
            private _liderOlu = !alive _l;
            private _retreat = _g getVariable [QGVAR(isRetreating), false];

            {
                private _u = _x;
                if (time < (_u getVariable [QGVAR(panikBitis), 0]) || {time < (_u getVariable [QGVAR(panikBagT), 0])}) then { continue };
                if (_u getVariable [QGVAR(teslim), false]) then { continue };

                // LAMBS'in kendi paniki: gorev "Panic" ise (bizim bolumumuz degil) ayni etkiyi uygula
                private _lambsPanik = (_u getVariable [QEGVAR(main,currentTask), ""]) isEqualTo "Panic";

                private _s = 0;
                private _neden = [];
                if (_temas || _lambsPanik) then {
                    private _bask = getSuppression _u;
                    _s = _s + (0.6 * (_bask min 1));
                    if (_bask >= 0.3) then { _neden pushBack format ["baski %1", _bask toFixed 2]; };
                    private _yakinOlum = _olum findIf {((_x select 0) distance2D _u) <= 25};
                    if (_yakinOlum >= 0) then { _s = _s + 0.35; _neden pushBack "yakinda dost oldu"; };
                    if (_moral < 1) then { _s = _s + (0.3 * (1 - _moral)); if (_moral < 0.6) then { _neden pushBack format ["moral %1", _moral toFixed 2]; }; };
                    if (_liderOlu || {(_u distance2D _l) > 60}) then { _s = _s + 0.15; _neden pushBack "lider yok/uzak"; };
                    private _yakinDost = (_us - [_u]) findIf {(_x distance2D _u) <= 60};
                    if (_yakinDost < 0) then { _s = _s + 0.10; _neden pushBack "yalniz"; };
                };

                private _tetik = _lambsPanik;
                private _p = 0;
                if (!_tetik && {_s >= 0.45}) then {
                    private _cesaret = _u skill "courage";
                    _p = ((_s - 0.45) * 0.5 * ((1.3 - _cesaret) max 0.3) * _sansCarpan * ([1, 0.4] select (_u isEqualTo _l))) min 0.12;
                    if (_retreat || {_u getVariable [QGVAR(forceMove), false]}) then { _p = _p * 0.5; };
                    if ((_u getVariable [QGVAR(iedIsci), false]) || {_u getVariable [QGVAR(iedGuv), false]} || {_u getUnitTrait "explosiveSpecialist"}) then { _p = _p * 0.5; };
                    if (_us isNotEqualTo [] && {(_panikte / (count _us)) >= 0.3}) then { _p = 0; };
                    if ((random 1) < _p) then { _tetik = true; };
                };
                if (!_tetik) then { continue };

                private _tehdit = _u findNearestEnemy _u;
                private _tp = if (isNull _tehdit) then { (_g getVariable [QGVAR(cmdSit), []]) param [7, [0,0,0]] } else { getPosATL _tehdit };
                if !(_tp isEqualType []) then { _tp = [0,0,0]; };
                private _a = [0.55, 0.35, 0.10];
                if (_s >= 0.7) then { _a = [0.35, 0.25, 0.40]; };
                private _r = random 1;
                private _tur = if (_r < (_a select 0)) then {"DONMA"} else { ["KACIS", "KOR"] select (_r < ((_a select 0) + (_a select 1))) };
                private _sure = switch (_tur) do { case "DONMA": {3 + (random 4)}; case "KOR": {4 + (random 4)}; default {4 + (random 3)}; };
                if (_tur isEqualTo "DONMA" && {!_liderOlu} && {(_u distance2D _l) <= 20}) then { _sure = _sure * 0.6; };

                _panikte = _panikte + 1;
                _say set [_tur, (_say getOrDefault [_tur, 0]) + 1];
                if (_lambsPanik) then { _say set ["LAMBS-panigi", (_say getOrDefault ["LAMBS-panigi", 0]) + 1]; };
                if (_logN < 150) then {
                    _logN = _logN + 1;
                    diag_log format ["[PANIK] %1 | %2 | %3 %4 sn | gerilim %5 (p=%6) | neden: %7%8 | courage %9 | grupta panikte %10/%11", groupId _g, name _u, _tur, _sure toFixed 1, _s toFixed 2, _p toFixed 2, _neden joinString ", ", ["", " + LAMBS panigi"] select _lambsPanik, (_u skill "courage") toFixed 2, _panikte, count _us];
                };
                [_u, _tur, _sure, _tp, _neden joinString ","] spawn _bolumFn;
            } forEach _us;
        } forEach (allGroups select {local _x && {!isNull leader _x}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[PANIK-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_panikAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] panik betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_panikAdim", "?"]];
        sleep 5;
    };
};

true
