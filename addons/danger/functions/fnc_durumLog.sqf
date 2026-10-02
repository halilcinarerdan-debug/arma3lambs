#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DURUM / DOKTRIN GOZLEMCISI — RPT'ye her asker icin anlik durum + grup basina doktrin uyum puani yazar (tani amacli, oyuna mudahale ETMEZ).
 *
 *   [DURUM-GRUP] grup | kisi | karar | formasyon | davranis | bayraklar | temas | en yakin dusman
 *   [DURUM]      grup | asker | rol | konum | lidere gore ileri/yanal | lider mesafesi | stance | hiz | baski | cephane | dusman mesafesi | gorev | bayrak
 *   [DOKTRIN]    grup | komutan onde mi | yigilma | ort. aralik | temasta ayakta | hareket orani | bound donusumu | dusuk cephane | PUAN /100
 *
 * Sikligi: temasta (son 60 sn) 20 sn'de bir, sakinde 60 sn'de bir; grup basina en fazla 16 asker satiri.
 * KAPATMA: lambs_danger_durumLogOff = true
 *
 * PUAN (yaklasik): 100 - komutan en onde (temasta, >= 4 kisi) 30 - yigilma orani x 30 - temasta ayakta orani x 20
 *                  - bound sirasinda herkes ayni anda hareket / kimse hareket etmiyor 20 - dusuk cephane orani x 10
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_durumLogStarted") exitWith {false};
lambs_danger_durumLogStarted = true;

diag_log "[DURUM] durum / doktrin gozlemcisi baslatildi (her asker: konum, rol, stance, hiz, gorev; grup: doktrin puani)";

// KOMUT GECISLERI: "ilerle / dur" spam'ini gormek icin temasli gruplarin askerlerinde currentCommand degisimi (1 sn'de bir kontrol,
// asker basina en fazla 3 sn'de bir satir, toplam 400 satir)
[] spawn {
    private _n = 0;
    while {true} do {
        sleep 1;
        if (missionNamespace getVariable ["lambs_danger_durumLogOff", false]) then { continue };
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {isPlayer (leader _g)}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) < (time - 60)) then { continue };
            {
                private _u = _x;
                if (!alive _u || {!isNull objectParent _u}) then { continue };
                private _c = currentCommand _u;
                private _o = _u getVariable [QGVAR(durumKomut), ""];
                if (_c isNotEqualTo _o) then {
                    _u setVariable [QGVAR(durumKomut), _c];
                    if (_o isNotEqualTo "" && {_n < 400} && {time > (_u getVariable [QGVAR(durumKomutT), 0])}) then {
                        _u setVariable [QGVAR(durumKomutT), time + 3];
                        _n = _n + 1;
                        diag_log format ["[KOMUT] %1 | %2 | %3 -> %4 | gorev:%5 | hiz:%6", groupId _g, name _u, _o, _c, _u getVariable [QEGVAR(main,currentTask), "-"], round (speed _u)];
                    };
                };
            } forEach (units _g);
        } forEach allGroups;
    };
};

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];

    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_durumLogOff", false]) then { continue };

        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!alive _l}) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            if (_us isEqualTo []) then { continue };

            private _temas = (_g getVariable [QGVAR(contact), 0]) > (time - 60);
            if ((time - (_g getVariable [QGVAR(durumT), -999])) < ([60, 20] select _temas)) then { continue };
            _g setVariable [QGVAR(durumT), time];

            private _lPos = getPosATL _l;
            private _en = _l findNearestEnemy _l;
            private _enMes = if (isNull _en) then {-1} else {round (_l distance2D _en)};
            private _yon = if (isNull _en) then {getDir _l} else {_l getDir _en};
            private _fwd = [sin _yon, cos _yon, 0];
            private _sag = [cos _yon, -(sin _yon), 0];

            private _bayrak = [];
            { if (_g getVariable [_x select 0, false]) then { _bayrak pushBack (_x select 1); }; } forEach [
                [QGVAR(isBounding), "BND"], [QGVAR(isRetreating), "RET"], [QGVAR(isEvading), "EVD"],
                [QGVAR(isBreakingContact), "BRK"], [QGVAR(isExecutingTactic), "TAK"], [QGVAR(isATEngage), "ATE"]
            ];

            diag_log format [
                "[DURUM-GRUP] %1 | %2 kisi | karar:%3 | form:%4 | beh:%5 cm:%6 | bayrak:%7 | temas:%8 | dusman:%9 m yon:%10",
                groupId _g, count _us, _g getVariable [QGVAR(cmdLastDecision), "-"], formation _g, behaviour _l, combatMode _g,
                _bayrak joinString "+", ["yok", "var"] select _temas, _enMes, round _yon
            ];

            private _lProj = 0;
            private _onde = 0;
            private _yigil = 0;
            private _aralikT = 0;
            private _ayakta = 0;
            private _hareket = 0;
            private _dusukC = 0;
            private _n = count _us;
            private _i = 0;
            {
                private _u = _x;
                private _fark = (getPosATL _u) vectorDiff _lPos;
                private _ileri = (_fark vectorDotProduct _fwd);
                private _yanal = (_fark vectorDotProduct _sag);
                if (_u isNotEqualTo _l && {_ileri > 6}) then { _onde = _onde + 1; };

                private _komsu = 9999;
                { if (_x isNotEqualTo _u) then { _komsu = _komsu min (_u distance2D _x); }; } forEach _us;
                if (_n > 1) then {
                    _aralikT = _aralikT + (_komsu min 60);
                    if (_komsu < 2.5) then { _yigil = _yigil + 1; };
                };

                private _st = stance _u;
                if (_st isEqualTo "STAND" && {(getSuppression _u) > 0.2 || {_temas}}) then { _ayakta = _ayakta + 1; };
                if ((speed _u) > 1.5) then { _hareket = _hareket + 1; };
                private _mag = count (magazines _u);
                if (_mag <= 1 && {(_u ammo (primaryWeapon _u)) < 10}) then { _dusukC = _dusukC + 1; };

                if (_i < 16) then {
                    private _e = _u findNearestEnemy _u;
                    diag_log format [
                        "[DURUM] %1 | %2%3 | %4 | poz:[%5,%6] | ileri:%7 yanal:%8 | lider:%9 m | %10 | %11 km/s | baski:%12 | sarjor:%13 | dusman:%14 m | gorev:%15 | %16 | komut:%17 | anim:%18 | katsayi:%19 | yon:%20",
                        groupId _g, name _u, ["", " (K)"] select (_u isEqualTo _l), [_u] call _rolFn,
                        round ((getPosATL _u) select 0), round ((getPosATL _u) select 1),
                        round _ileri, round _yanal, round (_u distance2D _l), _st, round (speed _u),
                        (getSuppression _u) toFixed 2, _mag,
                        if (isNull _e) then {"-"} else {round (_u distance2D _e)},
                        _u getVariable [QEGVAR(main,currentTask), "-"],
                        ([
                            ["fm", _u getVariable [QGVAR(forceMove), false]],
                            ["ist", (_u getVariable [QGVAR(stationPos), []]) isNotEqualTo []],
                            ["bomba", (_u getVariable [QGVAR(grState), []]) isNotEqualTo []],
                            ["arka", (_g getVariable [QGVAR(rearGuardU), objNull]) isEqualTo _u]
                        ] select {_x select 1} apply {_x select 0}) joinString ",",
                        currentCommand _u,
                        (animationState _u) select [((count (animationState _u)) - 16) max 0],
                        _u getVariable [QGVAR(mvAnim), "-"],
                        round (getDir _u)
                    ];
                };
                _i = _i + 1;
            } forEach _us;

            // komutan en onde mi? (hicbir asker liderin 6 m'den fazla onunde degil, grup >= 4, temasta)
            private _komutanOnde = _temas && {_n >= 4} && {_onde isEqualTo 0};
            private _yigilOran = if (_n > 1) then {_yigil / _n} else {0};
            private _ayaktaOran = [0, _ayakta / _n] select _temas;
            private _hareketOran = _hareket / _n;
            private _boundOk = true;
            if (_g getVariable [QGVAR(isBounding), false]) then {
                _boundOk = (_hareketOran >= 0.2) && {_hareketOran <= 0.75};
            };
            private _puan = 100
                - ([0, 30] select _komutanOnde)
                - (_yigilOran * 30)
                - (_ayaktaOran * 20)
                - ([20, 0] select _boundOk)
                - ((_dusukC / _n) * 10);

            diag_log format [
                "[DOKTRIN] %1 | komutan_onde:%2 | yigilma(<2.5m):%3/%4 | ort.aralik:%5 m | temasta_ayakta:%6/%7 | hareket:%8%% | bound_donusum:%9 | dusuk_cephane:%10 | PUAN:%11/100",
                groupId _g, _komutanOnde, _yigil, _n, if (_n > 1) then {round (_aralikT / _n)} else {0},
                _ayakta, _n, round (_hareketOran * 100), ["IHLAL", "ok"] select _boundOk, _dusukC, round (_puan max 0)
            ];
        } forEach allGroups;
    };
};

true
