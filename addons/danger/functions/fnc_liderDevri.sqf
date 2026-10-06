#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * LIDER DEVRI (v8.104) — kullanici: "lider devri oncesine hesaplama: kim ne olacak, becerisine ve rutbesine gore".
 * Sorun: (1) Lider olunce Arma motoru yeni lideri kendi kurallariyla secer (rutbe ve sira); beceri / rol dikkate alinmaz (hekim / MG lider olabilir).
 *        (2) Lider BAYILIRSA (ACE unconscious) motor onu lider olarak TUTAR: grup lidersiz kalir (formasyon, taktik, HQ hep bayilmis liderde).
 * Bu watchdog (2 sn'de bir, yerel AI gruplar, oyuncu icermeyen):
 *   ON HESAP: her grup icin halef puani (grup degiskeni lambs_danger_halef = en iyi aday; lambs_danger_halefSkor)
 *     puan = rutbe (rankId 0..6) x 100 + commanding x 40 + courage x 15 + general x 15 - rol cezasi (hekim 45, EOD 40, MG 35, AT 25, nisanci 15, RTO 5)
 *     aday: canli, bilincli (ACE_isUnconscious / INCAPACITATED degil), esir degil, arac disinda (arac icindeyse -20), oyuncu degil
 *   DEVIR 1 (bayilma): lider 3 sn bayilmis / bilinci yok -> selectLeader halef
 *   DEVIR 2 (olum): lider degisti ve yeni lider halef degilse (puan farki >= 30) 15 sn icinde bir kez halef secilir
 *   Devirden sonra eski lider uyanirsa lider OLMAZ (kararlilik); halef ayri hesaplanir.
 * Kapatma: lambs_danger_liderDevriOff = true.   Log: [LIDER-DEVRI] (ilk 80)
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_liderDevriStarted") exitWith {false};
lambs_danger_liderDevriStarted = true;

diag_log "[LIDER-DEVRI] lider devri (halef on hesabi) watchdog'u baslatildi (v8.104)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_liderDevriAdim", "basladi"];
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 120;

    private _bilincli = {
        params ["_u"];
        alive _u && {!((lifeState _u) in ["INCAPACITATED", "UNCONSCIOUS"])} && {!(_u getVariable ["ACE_isUnconscious", false])}
    };
    private _puanFn = {
        params ["_u"];
        private _p = (rankId _u) * 100 + (_u skill "commanding") * 40 + (_u skill "courage") * 15 + (_u skill "general") * 15;
        private _rol = [_u] call _rolFn;
        if (_rol isEqualTo "MEDIC" || {_u getUnitTrait "Medic"}) then { _p = _p - 45; };
        if (_u getUnitTrait "explosiveSpecialist" || {_u getVariable ["ACE_isEOD", false]}) then { _p = _p - 40; };
        if (_rol isEqualTo "MG") then { _p = _p - 35; };
        if (_rol isEqualTo "AT") then { _p = _p - 25; };
        if (_rol isEqualTo "MARKSMAN") then { _p = _p - 15; };
        if (((group _u) getVariable ["lambs_danger_rto", objNull]) isEqualTo _u) then { _p = _p - 5; };
        if !(isNull objectParent _u) then { _p = _p - 20; };
        _p
    };

    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_liderDevriOff", false]) then { continue };
        {
            private _g = _x;
            if (!local _g || {isNull (leader _g)} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            if (_g getVariable ["lambs_danger_tarafKapali", false]) then { continue };
            missionNamespace setVariable ["lambs_danger_liderDevriAdim", format ["grup %1", groupId _g]];
            private _adaylar = (units _g) select {[_x] call _bilincli && {!captive _x}};
            if (count _adaylar < 1) then { continue };
            private _l = leader _g;

            // on hesap: en iyi aday (mevcut lider haric ve dahil)
            private _puanli = _adaylar apply {[[_x] call _puanFn, _x]};
            _puanli = [_puanli, [], {_x select 0}, "DESCEND"] call BIS_fnc_sortBy;
            private _en = (_puanli select 0) select 1;
            private _enSkor = (_puanli select 0) select 0;
            private _halef = objNull; private _halefSkor = -1e9;
            { if ((_x select 1) isNotEqualTo _l) exitWith { _halef = _x select 1; _halefSkor = _x select 0; }; } forEach _puanli;
            _g setVariable [QGVAR(halef), _halef];
            _g setVariable [QGVAR(halefSkor), _halefSkor];

            private _liderBilincli = [_l] call _bilincli;
            // DEVIR 1: lider bayilmis
            if (!_liderBilincli && {alive _l}) then {
                if ((_g getVariable [QGVAR(liderBadT), -1]) < 0) then { _g setVariable [QGVAR(liderBadT), time]; };
                if ((time - (_g getVariable [QGVAR(liderBadT), time])) >= 3 && {!isNull _en} && {_en isNotEqualTo _l}) then {
                    _g selectLeader _en;
                    _g setVariable [QGVAR(liderBadT), -1];
                    _g setVariable [QGVAR(liderDevirT), time];
                    _say set ["bayilma", (_say getOrDefault ["bayilma", 0]) + 1];
                    if (_logN < 80) then {
                        _logN = _logN + 1;
                        diag_log format ["[LIDER-DEVRI] %1 | BAYILMA: %2 (%3) -> %4 (%5 | rutbe %6 | commanding %7 | rol %8 | puan %9)", groupId _g, name _l, rank _l, name _en, rank _en, rankId _en, (_en skill "commanding") toFixed 2, [_en] call _rolFn, round _enSkor];
                    };
                };
                continue;
            };
            _g setVariable [QGVAR(liderBadT), -1];

            // DEVIR 2: lider degisti (olum vb.) ve yeni lider belirgin sekilde daha zayif aday
            private _sonL = _g getVariable [QGVAR(liderSon), objNull];
            if (_sonL isNotEqualTo _l) then {
                _g setVariable [QGVAR(liderSon), _l];
                if (!isNull _sonL) then { _g setVariable [QGVAR(liderDegisT), time]; };
            };
            if ((time - (_g getVariable [QGVAR(liderDegisT), -999])) < 15 && {(time - (_g getVariable [QGVAR(liderDevirT), -999])) > 15}) then {
                private _lSkor = [_l] call _puanFn;
                if (_en isNotEqualTo _l && {(_enSkor - _lSkor) >= 30}) then {
                    _g selectLeader _en;
                    _g setVariable [QGVAR(liderDevirT), time];
                    _g setVariable [QGVAR(liderDegisT), -999];
                    _say set ["olum", (_say getOrDefault ["olum", 0]) + 1];
                    if (_logN < 80) then {
                        _logN = _logN + 1;
                        diag_log format ["[LIDER-DEVRI] %1 | MOTOR SECIMI DUZELTILDI: %2 (%3 | puan %4) -> %5 (%6 | rutbe %7 | puan %8)", groupId _g, name _l, rank _l, round _lSkor, name _en, rank _en, rankId _en, round _enSkor];
                    };
                };
            };
        } forEach allGroups;
        if (time > _ozetT) then {
            _ozetT = time + 120;
            if (count _say > 0) then { diag_log format ["[LIDER-DEVRI-OZET] son 120 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_liderDevriAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] liderDevri betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_liderDevriAdim", "?"]];
        sleep 5;
    };
};

true
