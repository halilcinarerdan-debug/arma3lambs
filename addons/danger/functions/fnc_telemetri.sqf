#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TELEMETRI (v8.126) — kullanici: "taktikleri ve goremedigin seyleri gorebilecegin sekilde loggingi guclendir".
 * Oyuna mudahale ETMEZ; her makinede kendi YEREL AI gruplari icin RPT'ye ozet yazar (dedicated'da gruplar sunucuda -> SUNUCU RPT'si).
 *   [TELEMETRI-SUNUCU] 20 sn: sunucu FPS (ort / min), yerel AI grup / asker, taraf dagilimi, aktif plan sayisi, donus animasyonundaki asker
 *   [TELEMETRI-GRUP]    20 sn: grup | taraf | canli/toplam | konum (grid) | karar (son komutan karari + kac sn once) | taktik bayraklari
 *                       (BND bounding, RTR cekilme, EVD zirhtan kacis, AT, BRK temas kesme, TKT taktik, PLAN:faz, TCCC:n) |
 *                       davranis / combatMode / hiz modu / formasyon | hiz lider / ort / max (m/s) | temas yasi | ort. baski | en yakin dusman (m)
 *                       Sadece ilgi cekici gruplar (plan, son 90 sn temas, hareket halinde, ya da her 3. turda sakinler); en fazla 14 satir / tur
 *   [HIZ-ANOMALI]       2 sn: yaya asker hizi > 26 km/s (sprint ustu): grup, asker, hiz, animasyon, stance, bayraklar (asker basina 15 sn'de bir, en fazla 80 satir)
 *   [DONUS-OZET]        60 sn: donus animasyonu oynayan asker sayisi + uygulanan turnCoef
 * Kapatma: lambs_danger_telemetriOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_telemetriStarted") exitWith {false};
lambs_danger_telemetriStarted = true;

diag_log "[TELEMETRI] telemetri watchdog'u baslatildi (v8.126): [TELEMETRI-SUNUCU] / [TELEMETRI-GRUP] / [HIZ-ANOMALI] / [DONUS-OZET]";

private _bayrak = {
    params ["_g"];
    private _b = [];
    if (_g getVariable [QGVAR(isBounding), false]) then { _b pushBack "BND"; };
    if (_g getVariable [QGVAR(isRetreating), false]) then { _b pushBack "RTR"; };
    if (_g getVariable [QGVAR(isEvading), false]) then { _b pushBack "EVD"; };
    if (_g getVariable [QGVAR(isATEngage), false]) then { _b pushBack "AT"; };
    if (_g getVariable [QGVAR(isBreakingContact), false]) then { _b pushBack "BRK"; };
    if (_g getVariable [QGVAR(isExecutingTactic), false]) then { _b pushBack "TKT"; };
    if (_g getVariable [QGVAR(planAktif), false]) then {
        private _p = (missionNamespace getVariable ["lambs_danger_planlar", createHashMap]) getOrDefault [_g getVariable [QGVAR(planId), ""], createHashMap];
        _b pushBack format ["PLAN:%1", _p getOrDefault ["faz", "?"]];
    };
    private _tc = {alive _x && {_x getVariable [QGVAR(tcccBusy), false]}} count (units _g);
    if (_tc > 0) then { _b pushBack format ["TCCC:%1", _tc]; };
    _b joinString ","
};

private _calis = {
    missionNamespace setVariable ["lambs_danger_telemetriAdim", "basladi"];
    private _bayrakFn = missionNamespace getVariable ["lambs_danger_telemetriBayrak", {""}];
    private _tur = 0;
    while {true} do {
        sleep 20;
        if (missionNamespace getVariable ["lambs_danger_telemetriOff", false]) then { continue };
        _tur = _tur + 1;
        private _yerel = allGroups select {local _x && {!isNull (leader _x)} && {!isPlayer (leader _x)} && {({alive _x} count (units _x)) > 0}};
        private _asker = 0;
        private _taraf = createHashMap;
        {
            private _n = {alive _x} count (units _x);
            _asker = _asker + _n;
            private _s = str (side _x);
            private _e = _taraf getOrDefault [_s, [0, 0]];
            _taraf set [_s, [(_e select 0) + 1, (_e select 1) + _n]];
        } forEach _yerel;
        private _planN = count (missionNamespace getVariable ["lambs_danger_planlar", createHashMap]);
        private _donus = {local _x && {alive _x} && {!isPlayer _x} && {((toLower (animationState _x)) find "turn") >= 0}} count allUnits;
        missionNamespace setVariable ["lambs_danger_telemetriDonus", _donus];
        if (_yerel isNotEqualTo [] || {isServer}) then {
            diag_log format ["[TELEMETRI-SUNUCU] t=%1 | fps %2 (min %3) | yerel AI grup:%4 asker:%5 | taraf [grup, asker]: %6 | plan:%7 | donus animasyonunda:%8 | isServer:%9",
                round time, round diag_fps, round diag_fpsMin, count _yerel, _asker, _taraf toArray false, _planN, _donus, isServer];
        };
        private _satir = 0;
        {
            if (_satir >= 14) exitWith {};
            private _g = _x;
            missionNamespace setVariable ["lambs_danger_telemetriAdim", format ["grup %1", groupId _g]];
            private _l = leader _g;
            private _canli = (units _g) select {alive _x};
            private _tempoAkt = (_g getVariable [QGVAR(planAktif), false])
                || {(time - (_g getVariable [QGVAR(contact), -999])) < 90}
                || {(_canli findIf {isNull objectParent _x && {speed _x > 4}}) >= 0};
            if (!_tempoAkt && {(_tur % 3) != 0}) then { continue };
            private _hizlar = _canli apply {(speed _x) / 3.6};
            private _ort = if (_hizlar isEqualTo []) then {0} else {(_hizlar call BIS_fnc_arithmeticMean)};
            private _mx = if (_hizlar isEqualTo []) then {0} else {selectMax _hizlar};
            private _bask = if (_canli isEqualTo []) then {0} else {((_canli apply {getSuppression _x}) call BIS_fnc_arithmeticMean)};
            private _en = _l findNearestEnemy (getPosATL _l);
            private _enM = if (isNull _en) then {-1} else {round (_l distance _en)};
            private _cT = _g getVariable [QGVAR(contact), -999];
            private _karar = _g getVariable [QGVAR(cmdLastDecision), "-"];
            private _kz = _g getVariable [QGVAR(cmdSonKararZaman), -999];
            diag_log format ["[TELEMETRI-GRUP] %1 | %2 | %3/%4 | %5 | karar:%6 (%7 sn once) | bayrak:[%8] | %9/%10/%11/%12 | hiz lider:%13 ort:%14 max:%15 m/s | temas:%16 | baski:%17 | en yakin dusman:%18 m",
                groupId _g, side _g, count _canli, count (units _g), mapGridPosition _l,
                _karar, [round (time - _kz), "-"] select (_kz < 0),
                [_g] call _bayrakFn,
                behaviour _l, combatMode _g, speedMode _g, formation _g,
                (round (((speed _l) / 3.6) * 10)) / 10, (round (_ort * 10)) / 10, (round (_mx * 10)) / 10,
                [format ["%1 sn once", round (time - _cT)], "yok"] select (_cT < 0),
                (round (_bask * 100)) / 100, _enM];
            _satir = _satir + 1;
        } forEach _yerel;
        missionNamespace setVariable ["lambs_danger_telemetriAdim", "tur bitti"];
    };
};
missionNamespace setVariable ["lambs_danger_telemetriBayrak", _bayrak];

// HIZ ANOMALISI (2 sn): yaya asker sprint ustu hizda
private _hizFn = {
    private _bayrakFn = missionNamespace getVariable ["lambs_danger_telemetriBayrak", {""}];
    private _n = 0;
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_telemetriOff", false]) then { continue };
        if (_n >= 80) then { sleep 30; continue };
        {
            private _u = _x;
            if (!(local _u) || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u}) then { continue };
            if ((speed _u) <= 26) then { continue };
            if ((time - (_u getVariable [QGVAR(hizAnomT), -999])) < 15) then { continue };
            _u setVariable [QGVAR(hizAnomT), time];
            _n = _n + 1;
            private _g = group _u;
            diag_log format ["[HIZ-ANOMALI] %1 | %2 | hiz:%3 km/s (%4 m/s) | anim:%5 | stance:%6 | bayrak:[%7] | beh:%8 combat:%9 hizmodu:%10",
                groupId _g, name _u, round (speed _u), (round ((speed _u) / 3.6 * 10)) / 10, animationState _u, stance _u,
                [_g] call _bayrakFn, behaviour _u, combatMode _g, speedMode _g];
        } forEach allUnits;
    };
};

// DONUS OZETI (60 sn)
private _donusFn = {
    while {true} do {
        sleep 60;
        private _d = missionNamespace getVariable ["lambs_danger_telemetriDonus", 0];
        if (_d > 0 || {isServer}) then {
            diag_log format ["[DONUS-OZET] son tur: %1 asker donus animasyonunda | turnCoef:%2", _d, missionNamespace getVariable ["lambs_danger_turnCoef", "yok"]];
        };
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] telemetri betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_telemetriAdim", "?"]];
        sleep 5;
    };
};
[_hizFn] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] telemetri hiz betigi sonlandi (hata?)";
        sleep 5;
    };
};
[] spawn _donusFn;

true
