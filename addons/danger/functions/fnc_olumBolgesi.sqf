#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * OLUM BOLGESI HAFIZASI + TEMAS OLAYLARI IZLEYICISI (v8.60, "ateşten ogrenme" + karsi pusu girdisi)
 *
 * 1) OLUM BOLGESI: bir grupta kayip (Casualty olayi) olunca katilin konumu (isim eslesmesi; yoksa grubun bildigi dusman konumu cmdSit[7]) kaydedilir:
 *      lambs_danger_olumBolgeleri = [[taraf, katilKonum, kurbanKonum, zaman, agirlik], ...]  (en fazla 24; 240 sn sonra silinir; 40 m icindeki tekrar -> agirlik +1, zaman yenilenir)
 *    KULLANIM: fnc_rotaPlan, ayni tarafin gruplari icin rota maruziyetini hesaplarken bu konumlari EK GOZLEMCI sayar (kayip verilen yerden gorulen hatlar kacinilir).
 * 2) TEMAS IZLEYICI (karsi pusu girdisi): InContact -> zekaTemasBas, temas oncesi sakin sure (zekaSakinT), temas basindaki kayip sayaci; AllClear -> zekaSakinT. fnc_pusuKarsi okur.
 *
 * Kapatma: lambs_danger_olumBOff = true.   Log: [ZEKA-OLUM] [ZEKA-TEMAS] [ZEKA-NABIZ]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_olumBStarted") exitWith {false};
lambs_danger_olumBStarted = true;
if (isNil "lambs_danger_olumBolgeleri") then { lambs_danger_olumBolgeleri = []; };

diag_log "[ZEKA-OLUM] olum bolgesi hafizasi + temas izleyici baslatildi (v8.60)";

if (!isNil "CBA_fnc_addEventHandler") then {
    ["lambs_danger_grupOlayi", {
        params ["_g", "_ad", "_veri"];
        if (missionNamespace getVariable ["lambs_danger_olumBOff", false]) exitWith {};
        if (isNull _g) exitWith {};

        // --- TEMAS IZLEYICI ---
        if (_ad isEqualTo "AllClear") exitWith {
            _g setVariable [QGVAR(zekaSakinT), time];
            _g setVariable [QGVAR(zekaTemasBas), -999];
            _g setVariable [QGVAR(zekaPusuT), -999];
        };
        if (_ad isEqualTo "InContact") exitWith {
            // yeni temas: yalniz onceki temas bitmisse (zekaTemasBas sifirli) bas zamani yazilir
            if ((_g getVariable [QGVAR(zekaTemasBas), -999]) < 0) then {
                _g setVariable [QGVAR(zekaTemasBas), time];
                _g setVariable [QGVAR(zekaTemasKayip0), _g getVariable [format ["lambs_danger_olaySay_%1", "Casualty"], 0]];
                private _sakin = time - (_g getVariable [QGVAR(zekaSakinT), -99999]);
                if ((missionNamespace getVariable ["lambs_danger_zekaLogN", 0]) < 120) then {
                    missionNamespace setVariable ["lambs_danger_zekaLogN", (missionNamespace getVariable ["lambs_danger_zekaLogN", 0]) + 1];
                    diag_log format ["[ZEKA-TEMAS] %1 | yeni temas basladi | onceki sakin sure:%2 sn (>=25 = ani temas / pusu adayi) | askerler:%3", groupId _g, if (_sakin > 9999) then {"ilk temas"} else {round _sakin}, {alive _x} count (units _g)];
                };
            };
        };

        // --- OLUM BOLGESI ---
        if (_ad isNotEqualTo "Casualty") exitWith {};
        private _l = leader _g;
        if (isNull _l) exitWith {};
        private _kn = if (_veri isEqualType [] && {(count _veri) > 1}) then { _veri select 1 } else { "" };
        private _kPos = [];
        private _yontem = "";
        if (_kn isEqualType "" && {_kn isNotEqualTo ""} && {_kn isNotEqualTo "?"}) then {
            private _i = allUnits findIf {alive _x && {(name _x) isEqualTo _kn} && {((side _x) getFriend (side _g)) < 0.6}};
            if (_i >= 0) then { _kPos = getPosATL (allUnits select _i); _yontem = "katil ismi: " + _kn; };
        };
        if (_kPos isEqualTo []) then {
            private _sit = _g getVariable [QGVAR(cmdSit), []];
            if ((count _sit) > 7 && {((_sit select 7) isEqualType [])} && {((_sit select 7) isNotEqualTo [0, 0, 0])} && {(time - (_sit select 0)) < 60}) then {
                _kPos = +(_sit select 7);
                _yontem = "grubun bildigi dusman konumu (cmdSit)";
            };
        };
        if (_kPos isEqualTo []) exitWith {
            if ((missionNamespace getVariable ["lambs_danger_zekaLogN", 0]) < 120) then {
                missionNamespace setVariable ["lambs_danger_zekaLogN", (missionNamespace getVariable ["lambs_danger_zekaLogN", 0]) + 1];
                diag_log format ["[ZEKA-OLUM] %1 | kayip var ama katil konumu BILINMIYOR (isim:%2, cmdSit yok / eski) -> bolge yazilmadi", groupId _g, _kn];
            };
        };

        private _liste = missionNamespace getVariable ["lambs_danger_olumBolgeleri", []];
        _liste = _liste select {(time - (_x select 3)) < 240};
        private _sd = side _g;
        private _var = _liste findIf {((_x select 0) isEqualTo _sd) && {((_x select 1) distance2D _kPos) < 40}};
        private _w = 1;
        if (_var >= 0) then {
            private _e = _liste select _var;
            _w = (_e select 4) + 1;
            _liste set [_var, [_sd, _kPos, getPosATL _l, time, _w]];
        } else {
            _liste pushBack [_sd, _kPos, getPosATL _l, time, 1];
            if ((count _liste) > 24) then { _liste deleteAt 0; };
        };
        missionNamespace setVariable ["lambs_danger_olumBolgeleri", _liste];
        if ((missionNamespace getVariable ["lambs_danger_zekaLogN", 0]) < 120) then {
            missionNamespace setVariable ["lambs_danger_zekaLogN", (missionNamespace getVariable ["lambs_danger_zekaLogN", 0]) + 1];
            diag_log format ["[ZEKA-OLUM] %1 (%2) | kayip | katil konumu:%3 (%4) | kurban konumu:%5 | agirlik:%6 | aktif bolge:%7", groupId _g, _sd, mapGridPosition _kPos, _yontem, mapGridPosition _l, _w, count _liste];
        };
    }] call CBA_fnc_addEventHandler;
};

// nabiz: 90 sn'de bir aktif bolge sayisi (ZEKA katmaninin yasadigini kanitlar)
[] spawn {
    while {true} do {
        sleep 90;
        private _l = (missionNamespace getVariable ["lambs_danger_olumBolgeleri", []]) select {(time - (_x select 3)) < 240};
        diag_log format ["[ZEKA-NABIZ] aktif olum bolgesi:%1 | karsi pusu tepkisi:%2 | rota gozcu kullanimi:%3", count _l, missionNamespace getVariable ["lambs_danger_zekaPusuSay", 0], missionNamespace getVariable ["lambs_danger_zekaRotaSay", 0]];
    };
};

true
