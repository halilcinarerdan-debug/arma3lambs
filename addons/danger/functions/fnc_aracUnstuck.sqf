#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC UNSTUCK (v8.328) — kullanici: 'araclar agaclara kayalara takilmasin, takilirsa unstuck atsin'. Plan / nakil / recon'dan BAGIMSIZ genel bekci: her YEREL AI suruculu kara araci (tank, APC, kamyon, hafif arac).
 * TESPIT (1 sn'de bir): surucu hareket emrinde (currentCommand MOVE, PATH + MOVE acik), hedef > 35 m, motor acik, hareket edebilir, hiz < 2 km/sa, son 10 sn'de murettebat ates etmedi (savas durusu degil) ve
 *   ENGEL kapisi: arac cevresinde (yarim boy + 2.5 m) agac / kaya / duvar / bina (hafif araclarda KUCUK AGAC da) var.
 *   Bekleme esigi: on koridorda engel 3 sn | yan / cevrede engel 7 sn | engel gorunmuyor 40 sn (baska neden: arac / arazi). Plan / nakil tarafindan yonetilen (planZirh, tasimaMesgul) araclarda esikler engel varsa x3 (9 / 21 sn), yoksa x2 (kendi kurtarmalari once dener).
 * KADEMELER (ayni araca 120 sn icinde art arda; 120 sn sorunsuz gecerse sifirlanir):
 *   1) GERI AL + YAN GEC: arka koridor bossa 2.5 sn geri (setVelocityModelSpace) -> hedef yonune gore 7 aci arasinda en az engelli 30 m ara nokta (yol bonusu, su cezasi) -> ulasinca asil hedefe doMove
 *   2) daha uzun geri (4 sn) + 45 m ara nokta
 *   3) KALDIR + YAN KAYDIR: bos yana 2.5 m + 0.6 m yukari, hiz sifirlanir, setVectorUp (govde agaca saplanmissa kurtarir) + 65 m ara nokta
 *   4+) TASI: hedef yonune 12-30 m icinde engelsiz (genislik + 3 m) en yakin bos konuma setVehiclePosition, yon hedefe cevrilir
 * Atlanir: oyuncu surucu, kinematik surus (kinSurus), recon araci, yolcu birakma, murettebat bekleme, KARAKOL_ARAC gorevi, planZirh mevzide (Vardi), forceSpeed 0. Kapatma: lambs_danger_aracUnstuckOff = true ya da CBA 'Arac takilma kurtarma'.
 * Log: [ARAC-UNSTUCK] (kademe, neden, engel, konum) + 60 sn ozet.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_aracUnstuckStarted") exitWith {false};
lambs_danger_aracUnstuckStarted = true;
diag_log "[ARAC-UNSTUCK] genel arac kurtarma bekcisi baslatildi (v8.328): agac / kaya / duvar / bina engeli + kademeli geri al, yan gec, kaldir, tasi";

private _calis = {
    private _turBuyuk = ["TREE", "ROCK", "ROCKS", "WALL", "BUILDING", "HOUSE"];
    private _turHafif = ["TREE", "SMALL TREE", "ROCK", "ROCKS", "WALL", "BUILDING", "HOUSE"];
    private _sayac = createHashMapFromArray [["tespit", 0], ["asama1", 0], ["asama2", 0], ["asama3", 0], ["asama4", 0], ["kurtuldu", 0]];
    private _ozetT = time + 60;

    // [genislik, uzunluk, engel turleri]
    private _olcu = {
        params ["_v"];
        private _bb = boundingBoxReal _v;
        [abs (((_bb select 1) select 0) - ((_bb select 0) select 0)), abs (((_bb select 1) select 1) - ((_bb select 0) select 1)), [_turHafif, _turBuyuk] select ((getMass _v) > 12000)]
    };
    // asama icin ara nokta: hedef yonune gore 9 aci arasinda engeli en az olan
    private _yanNokta = {
        params ["_v", "_dest", "_mesafe", "_gen", "_tur"];
        private _pos = getPosATL _v;
        private _brg = if (_dest isEqualTo []) then { getDir _v } else { _pos getDir _dest };
        private _en = [];
        private _enS = 1e9;
        {
            private _a = _x;
            private _p = _pos getPos [_mesafe, _brg + _a];
            if (!surfaceIsWater _p) then {
                private _s = (abs _a) * 0.04;
                { _s = _s + (3 * (count (nearestTerrainObjects [_pos getPos [_mesafe * _x, _brg + _a], _tur, (_gen / 2) + 2.5, false, true]))); } forEach [0.25, 0.5, 0.75, 1];
                if ((_p nearRoads 14) isNotEqualTo []) then { _s = _s - 4; };
                if (_s < _enS) then { _enS = _s; _en = _p; };
            };
        } forEach [-35, 35, -60, 60, -90, 90, -125, 125, 180];
        _en
    };

    while {true} do {
        sleep 1;
        if (missionNamespace getVariable ["lambs_danger_aracUnstuckOff", false] || {!(missionNamespace getVariable ["lambs_danger_aracUnstuck", true])}) then { continue };
        {
            private _v = _x;
            private _d = driver _v;
            private _uygun = alive _v && {local _v} && {!(_v isKindOf "StaticWeapon")} && {!isNull _d} && {!isPlayer _d} && {alive _d} && {isEngineOn _v} && {canMove _v} && {(fuel _v) > 0.01}
                && {_d checkAIFeature "MOVE"} && {_d checkAIFeature "PATH"} && {(currentCommand _d) isEqualTo "MOVE"}
                && {!(_v getVariable [QGVAR(kinSurus), false])} && {!(_v getVariable [QGVAR(reconArac), false])} && {!(_v getVariable [QGVAR(yolcuBirak), false])}
                && {(_v getVariable ["lambs_danger_murBekleT0", -1]) < 0} && {!(_v getVariable [QGVAR(unstuckBusy), false])}
                && {(_v getVariable ["lambs_danger_gorev", ""]) isNotEqualTo "KARAKOL_ARAC"} && {!((group _d) getVariable ["lambs_danger_planZirhVardi", false])}
                && {(forceSpeed _d) isNotEqualTo 0}
                && {((crew _v) findIf {(time - (_x getVariable [QGVAR(sonAtisT), -999])) < 10}) < 0};
            private _dest = if (_uygun) then { (expectedDestination _d) select 0 } else { [] };
            if (_dest isEqualTo [0, 0, 0]) then { _dest = []; };
            if (!_uygun || {_dest isEqualTo []} || {(_v distance2D _dest) < 35} || {(abs (speed _v)) >= 2}) then {
                // hareket ediyor / bekleme nedeni mesru: sayaci sifirla; 120 sn sorunsuzsa kademe sifirlanir
                if ((_v getVariable [QGVAR(ukT0), -1]) >= 0) then { _v setVariable [QGVAR(ukT0), -1]; };
                if ((_v getVariable [QGVAR(ukAsama), 0]) > 0 && {(time - (_v getVariable [QGVAR(ukEylemT), -999])) > 120}) then {
                    _v setVariable [QGVAR(ukAsama), 0];
                    _sayac set ["kurtuldu", (_sayac get "kurtuldu") + 1];
                };
                continue
            };

            if ((_v getVariable [QGVAR(ukT0), -1]) < 0) then { _v setVariable [QGVAR(ukT0), time]; continue };
            ([_v] call _olcu) params ["_gen", "_boy", "_tur"];
            private _pos = getPosATL _v;
            private _yakinEngel = nearestTerrainObjects [_pos, _tur, (_boy / 2) + 2.5, false, true];
            private _onEngel = nearestTerrainObjects [_v modelToWorld [0, (_boy / 2) + 2.5, 0], _tur, (_gen / 2) + 1.2, false, true];
            private _esik = if (_onEngel isNotEqualTo []) then {3} else { if (_yakinEngel isNotEqualTo []) then {7} else {40} };
            if ((_v getVariable [QGVAR(ukAsama), 0]) > 0) then { _esik = _esik max 6; };   // kademe arasi bekleme
            if ((_v getVariable [QGVAR(tasimaMesgul), false]) || {(group _d) getVariable ["lambs_danger_planZirh", false]}) then { _esik = _esik * ([2, 3] select (_yakinEngel isNotEqualTo [] || {_onEngel isNotEqualTo []})); };
            if ((time - (_v getVariable [QGVAR(ukT0), time])) < _esik || {(time - (_v getVariable [QGVAR(ukEylemT), -999])) < 8}) then { continue };

            // ---- kademe ----
            private _eskiAsama = _v getVariable [QGVAR(ukAsama), 0];
            if ((time - (_v getVariable [QGVAR(ukEylemT), -999])) > 120) then { _eskiAsama = 0; };
            private _asama = _eskiAsama + 1;
            _v setVariable [QGVAR(ukAsama), _asama];
            _v setVariable [QGVAR(ukEylemT), time];
            _v setVariable [QGVAR(ukT0), time];
            _v setVariable [QGVAR(unstuckBusy), true];
            _sayac set ["tespit", (_sayac get "tespit") + 1];
            _sayac set [format ["asama%1", _asama min 4], (_sayac get (format ["asama%1", _asama min 4])) + 1];
            private _nedenI = (([0, 1] select (_yakinEngel isNotEqualTo [])) max ([0, 2] select (_onEngel isNotEqualTo [])));
            private _neden = ["engel yok (40 sn)", "yanda / cevrede engel", "ON KORIDORDA engel"] select _nedenI;
            private _ilkEngel = if (_onEngel isNotEqualTo []) then { _onEngel select 0 } else { if (_yakinEngel isNotEqualTo []) then { _yakinEngel select 0 } else { objNull } };
            diag_log format ["[ARAC-UNSTUCK] %1 | %2 | KADEME %3 | neden: %4 | en yakin engel %5 (%6 m) | konum %7 | hedefe %8 m | hasar %9",
                typeOf _v, groupId (group _d), _asama, _neden, if (isNull _ilkEngel) then {"-"} else {str _ilkEngel select [0, 40]}, if (isNull _ilkEngel) then {-1} else {round (_ilkEngel distance2D _v)}, mapGridPosition _v, round (_v distance2D _dest), (damage _v) toFixed 2];

            [_v, _d, _dest, _asama, _gen, _boy, _tur, _yanNokta] spawn {
                params ["_v", "_d", "_dest", "_asama", "_gen", "_boy", "_tur", "_yanNokta"];
                private _pos0 = getPosATL _v;
                private _bitis = {
                    if (!isNull _v) then { _v setVariable [QGVAR(unstuckBusy), nil]; _v setVariable [QGVAR(ukT0), time]; };
                };
                if (!alive _v || {!alive _d}) exitWith { call _bitis };

                // 4+) TASI: hedef yonune en yakin engelsiz bos konum
                if (_asama >= 4) exitWith {
                    private _brg = _pos0 getDir _dest;
                    private _en = [];
                    private _enS = 1e9;
                    {
                        private _a = _x;
                        {
                            private _p = _pos0 getPos [_x, _brg + _a];
                            if (!surfaceIsWater _p && {(nearestTerrainObjects [_p, _tur, (_gen / 2) + 3, false, true]) isEqualTo []}) then {
                                private _s = _x + (abs _a) * 0.15;
                                if (_s < _enS) then { _enS = _s; _en = _p; };
                            };
                        } forEach [12, 20, 30];
                    } forEach [0, -30, 30, -60, 60, -90, 90, 180];
                    if (_en isNotEqualTo []) then {
                        _v setVehiclePosition [_en, [], 0, "NONE"];
                        _v setDir (_en getDir _dest);
                        _v setVelocity [0, 0, 0];
                        diag_log format ["[ARAC-UNSTUCK] %1 | TASINDI: %2 m ilerideki engelsiz konuma (%3)", typeOf _v, round (_pos0 distance2D _en), mapGridPosition _en];
                    } else {
                        diag_log format ["[ARAC-UNSTUCK] %1 | TASINAMADI: 30 m icinde engelsiz konum yok (%2)", typeOf _v, mapGridPosition _v];
                    };
                    _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
                    _d doMove _dest;
                    call _bitis;
                };

                // 3) KALDIR + YAN KAYDIR
                if (_asama isEqualTo 3) then {
                    private _sol = count (nearestTerrainObjects [_v modelToWorld [-((_gen / 2) + 3), 0, 0], _tur, 3, false, true]);
                    private _sag = count (nearestTerrainObjects [_v modelToWorld [(_gen / 2) + 3, 0, 0], _tur, 3, false, true]);
                    private _yan = [-1, 1] select (_sag <= _sol);
                    private _kay = _v vectorModelToWorld [_yan * 2.5, -1.5, 0];
                    _v setVectorUp [0, 0, 1];
                    _v setPosATL [(_pos0 select 0) + (_kay select 0), (_pos0 select 1) + (_kay select 1), (_pos0 select 2) + 0.6];
                    _v setVelocity [0, 0, 0];
                    diag_log format ["[ARAC-UNSTUCK] %1 | KALDIRILDI: %2 tarafina 2.5 m kaydirildi (sol engel %3, sag engel %4)", typeOf _v, ["sol", "sag"] select (_yan > 0), _sol, _sag];
                    sleep 0.5;
                } else {
                    // 1 / 2) GERI AL (arka koridor bossa)
                    private _arka = nearestTerrainObjects [_v modelToWorld [0, -((_boy / 2) + 3), 0], _tur, (_gen / 2) + 0.6, false, true];
                    if (_arka isEqualTo []) then {
                        private _sure = [2.5, 4] select (_asama > 1);
                        private _vHiz = [-3, -2.2] select (_v isKindOf "Tank");
                        private _tB = time + _sure;
                        _d disableAI "PATH";
                        while {alive _v && {time < _tB}} do {
                            private _vm = velocityModelSpace _v;
                            _v setVelocityModelSpace [_vm select 0, _vHiz, _vm select 2];
                            sleep 0.1;
                        };
                        _d enableAI "PATH";
                        diag_log format ["[ARAC-UNSTUCK] %1 | GERI ALINDI (%2 sn, geri %3 m)", typeOf _v, _sure, round ((getPosATL _v) distance2D _pos0)];
                    } else {
                        diag_log format ["[ARAC-UNSTUCK] %1 | geri alinamadi: arkada da engel (%2) - yan gecis denenecek", typeOf _v, count _arka];
                    };
                };

                // yan gec: ara nokta, sonra asil hedef
                private _ara = [_v, _dest, [30, 45, 65] select ((_asama - 1) min 2), _gen, _tur] call _yanNokta;
                if (_ara isNotEqualTo []) then {
                    _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
                    _d doMove _ara;
                    private _tS = time + 16;
                    waitUntil { sleep 1; !alive _v || {!alive _d} || {(_v distance2D _ara) < 12} || {time > _tS} };
                    diag_log format ["[ARAC-UNSTUCK] %1 | ara noktaya %2 (%3 m kaldi) -> asil hedefe devam", typeOf _v, ["ULASILDI", "ULASILAMADI"] select ((_v distance2D _ara) >= 12), round (_v distance2D _ara)];
                };
                if (alive _v && {alive _d}) then {
                    _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
                    _d doMove _dest;
                };
                call _bitis;
            };
        } forEach (vehicles select {_x isKindOf "LandVehicle"});

        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_sayac get "tespit") > 0 || {(_sayac get "kurtuldu") > 0}) then {
                diag_log format ["[ARAC-UNSTUCK-OZET] 60 sn: tespit %1 | kademe1 %2 kademe2 %3 kademe3 %4 kademe4 %5 | sorunsuz gecen (kademe sifirlandi) %6",
                    _sayac get "tespit", _sayac get "asama1", _sayac get "asama2", _sayac get "asama3", _sayac get "asama4", _sayac get "kurtuldu"];
                { _sayac set [_x, 0]; } forEach (keys _sayac);
            };
        };
    };
};
[] spawn _calis;
true
