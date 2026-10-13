#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HENDEK BILINCI (v8.230; kullanici: "hendek bilinci ekleyelim ki stratejik sekilde gerektiginde hendegi tercih etsinler; hendekte formasyona gerek yok") —
 * Plan DISI yerel AI piyade gruplari, elle konan hendek alani (isaret "elite_hendek*", bkz. fnc_hendekAlani) yakindaysa ve GEREKIYORSA hendege girer:
 *   GEREK = grup temasta (lambs_danger_contact) VE (baski > 0.15 ya da bilinen en yakin dusman < 400 m) VE dusman >= 25 m (yakin dovuste hendege kosulmaz);
 *   MESAFE = lider hendek alanina <= 70 m (kosarak ulasilabilir). Her asker KENDI konumuna en yakin ic noktaya gider (formasyon / aralik YOK), comelir (MIDDLE: 1.4 m hendekte siper).
 *   CIKIS = temas bitip 45 sn gectiyse (ya da grup bir plana alindiysa) serbest birakilir (setUnitPos AUTO + doFollow).
 * Plan gruplari (SAVUN) fnc_hendekYerles ile plan icinden yerlesir; SALDIRI / ORP / KESIF fazindaki gruplar hendek aramaz. Araclar, oyuncu gruplari, aracta lider dislanir.
 * Kaynak ilkesi: ATP 3-21.8 / FM 3-21.10 — mevcut koruyucu mevzileri kullan; ates altinda siper al. Sayisal esikler TASARIM degeri (25 m, 70 m, 400 m, 0.15, 45 sn).
 * Kapatma: lambs_danger_hendekBilincOff = true.  Log: [HENDEK-BILINC] (ilk 40).
 *
 * Arguments: None (acilista bir kez)
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_hendekBilincStarted") exitWith {false};
lambs_danger_hendekBilincStarted = true;
lambs_danger_hendekBLogN = 0;

[] spawn {
    while {true} do {
        sleep 4;
        if (missionNamespace getVariable ["lambs_danger_hendekBilincOff", false]) then { continue };
        if ((["LISTE"] call FUNC(hendekAlani)) isEqualTo []) then { sleep 6; continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            private _taraf = side _g;
            if (_taraf isEqualTo civilian) then { continue };
            private _plan = _g getVariable ["lambs_danger_planAktif", false];
            private _durum = _g getVariable [QGVAR(hendekB), []];   // [giris zamani]
            private _temas = (_g getVariable ["lambs_danger_contact", -999]);
            if (_durum isNotEqualTo []) then {
                // CIKIS: temas bitti + 45 sn, ya da plana alindi
                if (_plan || {(time - _temas) > 45 && {(time - (_durum select 0)) > 20}}) then {
                    _g setVariable [QGVAR(hendekB), nil];
                    { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "AUTO"; _x doFollow _l; }; } forEach (units _g);
                    diag_log format ["[HENDEK-BILINC] %1 | hendekten CIKTI (%2)", groupId _g, ["temas bitti + 45 sn", "plana alindi"] select _plan];
                };
                continue;
            };
            if (_plan || {_temas < time}) then { continue };   // plan grubu hendege kendi yerlesir; temas yoksa gerek yok
            private _bastir = 0;
            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            if (_us isEqualTo []) then { continue };
            { _bastir = _bastir max (getSuppression _x); } forEach _us;
            private _en = _l findNearestEnemy _l;
            private _enD = if (isNull _en) then {9999} else {_l distance2D _en};
            if (!((_bastir > 0.15) || {_enD < 400}) || {_enD < 25}) then { continue };
            private _h = ["EN-YAKIN", getPosATL _l, 70, _taraf] call FUNC(hendekAlani);
            if (_h isEqualTo []) then { continue };
            _g setVariable [QGVAR(hendekB), [time]];
            {
                private _u = _x;
                private _hn = ["EN-YAKIN", getPosATL _u, 90, _taraf] call FUNC(hendekAlani);
                if (_hn isNotEqualTo []) then {
                    _u enableAI "PATH"; _u enableAI "MOVE";
                    _u doMove ((_hn select 0) getPos [random 1, random 360]);
                    [_u] spawn {
                        params ["_u"];
                        sleep 6;
                        while {alive _u && {!isNull (group _u)} && {((group _u) getVariable [QGVAR(hendekB), []]) isNotEqualTo []}} do {
                            _u setUnitPos "MIDDLE";
                            sleep 2;
                        };
                    };
                };
            } forEach _us;
            lambs_danger_hendekBLogN = lambs_danger_hendekBLogN + 1;
            if (lambs_danger_hendekBLogN <= 40) then {
                diag_log format ["[HENDEK-BILINC] %1 | %2 asker hendege (alan %3, lidere %4 m) | neden: temas + baski %5 / dusman %6 m", groupId _g, count _us, _h select 1, round (_h select 2), _bastir toFixed 2, round _enD];
            };
        } forEach (allGroups select {!isNull leader _x});
    };
};

diag_log "[HENDEK-BILINC] hendek bilinci baslatildi (v8.230): temas + baski / yakin dusman -> en yakin hendek alanina siginma, formasyonsuz";
true
