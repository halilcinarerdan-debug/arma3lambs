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
 * Kapatma: lambs_danger_liderDevriOff = true.   Log (ilk 150 satir + 120 sn ozet): [LIDER-DEVRI-HALEF] halef degisimi + ilk 3 aday; [LIDER-DEVRI] BAYILDI / BAYILMA DEVRI / DEVIR BASARISIZ / HALEF YOK / LIDER DEGISTI (motor secimi) / DUZELTME YOK / MOTOR SECIMI DUZELTILDI
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

    // log: ilk 150 satir (sinirsiz spam yok); ozet sayaclari her zaman artar
    private _logla = {
        params ["_etiket", "_metin"];
        _say set [_etiket, (_say getOrDefault [_etiket, 0]) + 1];
        if (_logN < 150) then { _logN = _logN + 1; diag_log _metin; };
    };
    private _tabloMetin = {
        params ["_liste", "_rolFn2"];
        (_liste select [0, 3]) apply { format ["%1 (%2 r%3 cmd%4 %5 =%6)", name (_x select 1), rank (_x select 1), rankId (_x select 1), ((_x select 1) skill "commanding") toFixed 2, [_x select 1] call _rolFn2, round (_x select 0)] }
    };
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
            private _eskiHalef = _g getVariable [QGVAR(halef), objNull];
            // yapiskanlik (RPT 38f4018a: esit puanli onbasilar arasinda halef 2 sn'de bir degisiyordu): eski halef hala aday ve en iyiden <= 1 puan geride ise degismez
            if (!isNull _eskiHalef && {_eskiHalef isNotEqualTo _l} && {_eskiHalef isNotEqualTo _halef}) then {
                private _ei = _puanli findIf {(_x select 1) isEqualTo _eskiHalef};
                if (_ei >= 0 && {((_puanli select _ei) select 0) >= (_halefSkor - 1)}) then { _halef = _eskiHalef; _halefSkor = (_puanli select _ei) select 0; };
            };
            _g setVariable [QGVAR(halef), _halef];
            _g setVariable [QGVAR(halefSkor), _halefSkor];
            if (_eskiHalef isNotEqualTo _halef) then {
                ["halefDegisti", format ["[LIDER-DEVRI-HALEF] %1 | lider %2 (%3) | halef %4 (%5) | ilk 3 aday: %6", groupId _g, name _l, rank _l, ["YOK", name _halef] select (!isNull _halef), ["-", rank _halef] select (!isNull _halef), [_puanli, _rolFn] call _tabloMetin]] call _logla;
            };

            private _liderBilincli = [_l] call _bilincli;
            // DEVIR 1: lider bayilmis
            if (!_liderBilincli && {alive _l}) then {
                if ((_g getVariable [QGVAR(liderBadT), -1]) < 0) then {
                    _g setVariable [QGVAR(liderBadT), time];
                    ["liderBayildi", format ["[LIDER-DEVRI] %1 | LIDER BAYILDI: %2 (%3) | halef %4 | devir 3 sn sonra", groupId _g, name _l, rank _l, ["YOK", name _en] select (!isNull _en && {_en isNotEqualTo _l})]] call _logla;
                };
                if ((time - (_g getVariable [QGVAR(liderBadT), time])) >= 3 && {(isNull _en) || {_en isEqualTo _l}} && {(time - (_g getVariable [QGVAR(halefYokLogT), -999])) > 30}) then {
                    _g setVariable [QGVAR(halefYokLogT), time];
                    ["halefYok", format ["[LIDER-DEVRI] %1 | LIDER BAYIK ama HALEF YOK (bilincli aday sayisi %2)", groupId _g, count _adaylar]] call _logla;
                };
                if ((time - (_g getVariable [QGVAR(liderBadT), time])) >= 3 && {!isNull _en} && {_en isNotEqualTo _l}) then {
                    _g selectLeader _en;
                    _g setVariable [QGVAR(liderBadT), -1];
                    _g setVariable [QGVAR(liderDevirT), time];
                    ["devirBayilma", format ["[LIDER-DEVRI] %1 | BAYILMA DEVRI: %2 (%3) -> %4 (%5 | rutbe %6 | commanding %7 | courage %8 | rol %9 | puan %10) | aday tablosu: %11", groupId _g, name _l, rank _l, name _en, rank _en, rankId _en, (_en skill "commanding") toFixed 2, (_en skill "courage") toFixed 2, [_en] call _rolFn, round _enSkor, [_puanli, _rolFn] call _tabloMetin]] call _logla;
                    // dogrulama: 3 sn sonra lider gercekten degisti mi
                    [_g, _en] spawn { params ["_gg", "_hh"]; sleep 3; if (!isNull _gg && {(leader _gg) isNotEqualTo _hh}) then { diag_log format ["[LIDER-DEVRI] %1 | DEVIR BASARISIZ: beklenen %2, mevcut lider %3", groupId _gg, name _hh, name (leader _gg)]; }; };
                };
                continue;
            };
            _g setVariable [QGVAR(liderBadT), -1];

            // DEVIR 2: lider degisti (olum vb.) ve yeni lider belirgin sekilde daha zayif aday
            private _sonL = _g getVariable [QGVAR(liderSon), objNull];
            if (_sonL isNotEqualTo _l) then {
                _g setVariable [QGVAR(liderSon), _l];
                if (!isNull _sonL) then {
                    _g setVariable [QGVAR(liderDegisT), time];
                    private _lSkor0 = [_l] call _puanFn;
                    ["liderDegisti", format ["[LIDER-DEVRI] %1 | LIDER DEGISTI: %2 (%3, %4) -> %5 (%6 | rutbe %7 | commanding %8 | rol %9 | puan %10) | en iyi aday %11 (puan %12) | motor secimi %13", groupId _g, name _sonL, ["OLU", "yasiyor"] select (alive _sonL), ["-", lifeState _sonL] select (alive _sonL), name _l, rank _l, rankId _l, (_l skill "commanding") toFixed 2, [_l] call _rolFn, round _lSkor0, name _en, round _enSkor, ["EN IYI ADAY", "EN IYI DEGIL"] select (_en isNotEqualTo _l)]] call _logla;
                };
            };
            if ((time - (_g getVariable [QGVAR(liderDegisT), -999])) < 15 && {(time - (_g getVariable [QGVAR(liderDevirT), -999])) > 15}) then {
                private _lSkor = [_l] call _puanFn;
                if (_en isNotEqualTo _l && {(_enSkor - _lSkor) < 30} && {(time - (_g getVariable [QGVAR(devirYokLogT), -999])) > 20}) then {
                    _g setVariable [QGVAR(devirYokLogT), time];
                    ["devirYok", format ["[LIDER-DEVRI] %1 | DUZELTME YOK: motorun lideri %2 (puan %3), en iyi %4 (puan %5), fark %6 < 30", groupId _g, name _l, round _lSkor, name _en, round _enSkor, round (_enSkor - _lSkor)]] call _logla;
                };
                if (_en isNotEqualTo _l && {(_enSkor - _lSkor) >= 30}) then {
                    _g selectLeader _en;
                    _g setVariable [QGVAR(liderDevirT), time];
                    _g setVariable [QGVAR(liderDegisT), -999];
                    ["devirDuzeltme", format ["[LIDER-DEVRI] %1 | MOTOR SECIMI DUZELTILDI: %2 (%3 | puan %4) -> %5 (%6 | rutbe %7 | puan %8) | aday tablosu: %9", groupId _g, name _l, rank _l, round _lSkor, name _en, rank _en, rankId _en, round _enSkor, [_puanli, _rolFn] call _tabloMetin]] call _logla;
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
