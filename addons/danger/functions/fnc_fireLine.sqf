#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ATES HATTI KONTROLU (v8.388 yeniden yazildi; kullanici: 'arkadasinin ates hattindan cekilsin botlar, kendilerine zarar verebiliyorlar, saga sola kaysinlar, MG oncelikli olsun; calisiyor mu, yeterince etkili mi')
 *
 * TESPIT (v8.387 ve oncesi): fonksiyon VARSAYILAN KAPALIYDI (lambs_danger_fireLineOn = false; eski surum her hedefi olan askerde surekli yan adima yol aciyordu) VE bounding / geri cekilme / herhangi taktikte,
 *   komutanda, baskidaki ya da hareket edendeki askerde hic calismiyordu -> asil carpisma aninda (bounding kapsama atesi) dost ates hattinda kalma KONTROLU YOKTU.
 * YENI KURAL:
 *   - TETIK: yalniz GERCEKTEN ates eden asker (son 1.5 sn'de ates etti: firedHub sonAtisT) -> yan adim yalniz tehlike varken (eskiden 'hedefi var' yeterliydi, bu yuzden felc oldu).
 *   - TEHLIKE: atici ile hedef arasinda (2 m .. mesafe - 2 m) ates hattina 1.6 m'den yakin, +-40 derece icinde DOST var.
 *   - KIM KAYAR: varsayilan HATTIN ICINDEKI DOST (ates edenin onunde duran) yana kayar (kendini kurtarir). ONCELIK: MG 3 > nisanci 2 > AT / tufekci / diger 0-1 — oncelik dusuk olan kayar:
 *     engelleyen MG ise ya da atici MG'den dusuk oncelikliyse ATICI kayar; MG hic kimse icin yerini bozmaz, ama MG'nin hattindaki herkes kayar. Kayacak uygun degilse (kosucu forceMove, oyuncu, arac, bayginlik) digerine gecilir.
 *   - ADIM: hatta DIK 3.5 m (olmazsa 5.5 m), bos / engelsiz nokta (1.3 m'de asker yok, hat gorus engeli yok, 0.9 m'de agac / duvar yok); komutan da kayabilir (atici ondan dusuk oncelikliyse atici kayar).
 *     Kayan 20 sn tekrar kaymaz; ates edenin kendisi kayiyorsa yolda 2.5 sn ates kesilir (TARGET / AUTOTARGET kapali).
 *   - BOUNDING / GERI CEKILME: kosucular (forceMove) hic kaydirilmaz; kapsama (duran) askerleri kayar. Baskidaki (>= 0.6) asker kaymaz (siperinde kalir).
 * Kapatma: CBA 'Dost ates hatti' (lambs_danger_fireLineOn = false). Log: [ATES-HATTI] (ilk 60) + 60 sn ozeti [ATES-HATTI-OZET].
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_fireLineStarted") exitWith {false};
lambs_danger_fireLineStarted = true;
lambs_danger_flLogN = 0;

diag_log "[ATES-HATTI] ates hatti kontrolu baslatildi (v8.388: gercek atista tetik, hattin icindeki dost kayar, MG oncelikli, bounding kapsamasi dahil)";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _sayac = createHashMapFromArray [["tetik", 0], ["tehlike", 0], ["kayan_dost", 0], ["kayan_atici", 0], ["yer_yok", 0]];
    private _ozetT = time + 60;
    // oncelik: MG 3, MARKSMAN 2, diger 0
    private _oncelik = {
        params ["_u"];
        switch ([_u] call _rolFn) do { case "MG": {3}; case "MARKSMAN": {2}; default {0} }
    };

    // Hat uzerinde dost var mi? [atici pozisyon, hedef pozisyon, atici]
    private _hatDost = {
        params ["_a", "_t", "_shooter"];
        private _d = _a distance2D _t;
        private _dir = _a getDir _t;
        private _res = objNull;
        {
            if (!isNull _res) exitWith {};
            if (
                (_x isNotEqualTo _shooter) && {alive _x}
                && {((side group _shooter) getFriend (side group _x)) >= 0.6}
            ) then {
                private _ad = _a distance2D _x;
                if (_ad > 2 && {_ad < (_d - 2)}) then {
                    private _ang = ((_a getDir _x) - _dir + 540) mod 360 - 180;
                    if ((abs (_ad * sin _ang)) < 1.6 && {abs _ang < 40}) then { _res = _x; };
                };
            };
        } forEach (_a nearEntities ["CAManBase", ((_d - 2) min 200) max 3]);
        _res
    };

    // kayabilir mi?
    private _kayabilir = {
        params ["_u"];
        alive _u && {local _u} && {!isPlayer _u} && {isNull objectParent _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {!(_u getVariable ["ACE_isUnconscious", false])}
        && {!(_u getVariable [QGVAR(forceMove), false])} && {time >= (_u getVariable [QGVAR(flLast), 0])} && {(getSuppression _u) < 0.6}
        && {time >= (_u getVariable [QGVAR(tcccBusy), 0])} && {(_u getVariable [QGVAR(grState), []]) isEqualTo []}
    };

    while {true} do {
        sleep 0.5;

        // geri acma: adim bitti
        {
            if (alive _x && {time > (_x getVariable [QGVAR(flUntil), 0])} && {(_x getVariable [QGVAR(flUntil), 0]) > 0}) then {
                _x setVariable [QGVAR(flUntil), 0];
                _x enableAI "TARGET";
                _x enableAI "AUTOTARGET";
            };
        } forEach (allUnits select {local _x && {(_x getVariable [QGVAR(flUntil), 0]) > 0}});

        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_sayac get "tetik") > 0) then {
                diag_log format ["[ATES-HATTI-OZET] 60 sn: atis tetigi %1 | tehlike (hatta dost) %2 | kayan DOST %3 | kayan ATICI %4 | yer bulunamadi %5", _sayac get "tetik", _sayac get "tehlike", _sayac get "kayan_dost", _sayac get "kayan_atici", _sayac get "yer_yok"];
            };
            { _sayac set [_x, 0]; } forEach (keys _sayac);
        };
        if !(missionNamespace getVariable ["lambs_danger_fireLineOn", true]) then { continue };

        {
            private _u = _x;
            if (time < (_u getVariable [QGVAR(flBak), 0])) then { continue };
            _u setVariable [QGVAR(flBak), time + 1];
            _sayac set ["tetik", (_sayac get "tetik") + 1];

            private _t = assignedTarget _u;
            if (isNull _t || {!alive _t}) then {
                _t = _u findNearestEnemy _u;
                if (isNull _t || {(_u distance2D _t) > 400}) then { continue };
            };
            if ((_u distance2D _t) < 8) then { continue };

            private _aPos = getPosATL _u;
            private _tPos = getPosATL _t;
            private _blk = [_aPos, _tPos, _u] call _hatDost;
            if (isNull _blk) then { continue };
            _sayac set ["tehlike", (_sayac get "tehlike") + 1];

            // KIM KAYAR: dusuk oncelikli (esitlikte hattin icindeki dost); uygun degilse digeri
            private _pa = [_u] call _oncelik;
            private _pb = [_blk] call _oncelik;
            private _mover = if (_pa > _pb) then {_blk} else { if (_pb > _pa) then {_u} else {_blk} };
            // komutan: MG olmayan atici komutanin onunden kayar; komutan dost ise atici kayar (formasyon bozulmasin)
            if (_blk isEqualTo (leader _blk) && {_pa <= _pb}) then { _mover = _u; };
            if !([_mover] call _kayabilir) then {
                _mover = if (_mover isEqualTo _u) then {_blk} else {_u};
                if !([_mover] call _kayabilir) then { continue };
            };

            private _mPos = getPosATL _mover;
            private _dir = _aPos getDir _tPos;
            private _secildi = [];
            {
                private _off = _x;
                {
                    if (_secildi isNotEqualTo []) exitWith {};
                    private _c = _mPos getPos [_off, _dir + _x];
                    if (
                        !surfaceIsWater _c
                        && {((_c nearEntities ["CAManBase", 1.3]) select {(_x isNotEqualTo _mover)}) isEqualTo []}
                        && {!(lineIntersects [AGLToASL (_mPos vectorAdd [0, 0, 0.9]), AGLToASL (_c vectorAdd [0, 0, 0.9]), _mover])}
                        && {(nearestTerrainObjects [_c, ["TREE", "WALL", "FENCE", "BUILDING", "HOUSE", "ROCK"], 0.9, false, true]) isEqualTo []}
                    ) then {
                        // yeni konum ates hattinin disinda olmali (dik adim 3.5 m > 1.6 m koridor)
                        private _temiz = if (_mover isEqualTo _u) then {
                            isNull ([_c, _tPos, _u] call _hatDost)
                        } else { true };
                        if (_temiz) then { _secildi = _c; };
                    };
                } forEach (selectRandom [[90, -90], [-90, 90]]);
                if (_secildi isNotEqualTo []) exitWith {};
            } forEach [3.5, 5.5];

            if (_secildi isNotEqualTo []) then {
                _mover setVariable [QGVAR(flLast), time + 20];
                _mover setVariable [QGVAR(taktikKilit), time + 5];
                if (_mover isEqualTo _u) then {
                    _mover setVariable [QGVAR(flUntil), time + 2.5];
                    _mover disableAI "TARGET";
                    _mover disableAI "AUTOTARGET";
                    _sayac set ["kayan_atici", (_sayac get "kayan_atici") + 1];
                } else {
                    _sayac set ["kayan_dost", (_sayac get "kayan_dost") + 1];
                };
                _mover doMove _secildi;
                if (lambs_danger_flLogN < 60) then {
                    lambs_danger_flLogN = lambs_danger_flLogN + 1;
                    diag_log format [
                        "[ATES-HATTI] %1 | %2 (%3, oncelik %9) -> hedef %4 m | hatta dost: %5 (oncelik %10) | KAYAN: %6 (%7 m yana) | grup bounding:%8",
                        groupId (group _u), name _u, [_u] call _rolFn, round (_aPos distance2D _tPos), name _blk, name _mover, round (_mPos distance2D _secildi),
                        (group _u) getVariable [QGVAR(isBounding), false], _pa, _pb
                    ];
                };
            } else {
                _sayac set ["yer_yok", (_sayac get "yer_yok") + 1];
                _u setVariable [QGVAR(flBak), time + 6];
            };
        } forEach (allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
            && {(time - (_x getVariable [QGVAR(sonAtisT), -999])) < 1.5}
        });
    };
};

true
