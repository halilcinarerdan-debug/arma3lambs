#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PUSUYA HIZLI TEPKI + KONUM TAHMINI + CAGRI ATESI (v8.308; kullanici: 'pusuya hizli tepki, konum tahmini cagri atesi, bizim konumumuza cagri atesi yapmadilar, tek objektife takili kalmasinlar').
 * Gorunmeyen atici (gerilla / pusu / uzak nisanci) tarafindan vurulan grubu hizla harekete gecirir. Izleyici 1.5 sn'de bir, yerel oyuncusuz gruplarda:
 *   ALARM = son 8 sn'de yeni kayip (olaySay_Casualty artisi) VEYA bir askerde baski >= 0.45 / grup ortalamasi >= 0.30; VE bilinen dusmana gorus hatti yok (gorunmeyen atici).
 *   TAHMIN (hile yok): sesSonPos (fnc_soundAwareness: ses / parlama / catlama ile duyulan atis, mesafenin %12'si hata) <= 12 sn tazeyse o nokta; yoksa yalniz 360 derece tepki (kanat / cagri yok).
 *   TEPKI (grup basina 40 sn'de bir):
 *     A) ANINDA: COMBAT, combatMode en az YELLOW, 3 asker tahmine bakar (doWatch 7 sn), en cok 2 asker tahmine bastirma ates eder (doSuppressiveFire; mesafe >= 25 m)
 *     B) KOMSU UYARISI: 600 m icindeki dost yerel gruplara sesSonPos / sesSonZaman verilir, AWARE, 2 asker tahmine bakar
 *     C) KANAT: grup >= 4, kayip orani < 0.5, tahmin 60-450 m ise fnc_istiksaf 'KANAT' (2 asker yandan, 90 sn'de bir); taktik / bounding yurutenlerde yok
 *     D) CAGRI ATESI: tahmin <= 8 sn taze, ikinci alarm (15 sn icinde tekrar) ya da kayip >= 2, tahmin 150-1800 m, dost 200 m icinde degil: topcu / havan HE (fnc_topcuDestek 'OPERATOR' modu; 3 mermi, 45 m yayilim);
 *        taraf basina 120 sn'de bir
 * CBA: lambs_danger_pusuTepkiAktif (ana), lambs_danger_pusuKanatAktif, lambs_danger_pusuCagriAktif.   Kapatma: lambs_danger_pusuTepkiOff = true.
 * Log: [PUSU-TEPKI] / [PUSU-CAGRI]
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_pusuTepkiStarted") exitWith {false};
lambs_danger_pusuTepkiStarted = true;
diag_log "[PUSU-TEPKI] pusuya hizli tepki + konum tahmini + cagri atesi izleyicisi baslatildi (v8.308)";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 1.5;
        if (missionNamespace getVariable ["lambs_danger_pusuTepkiOff", false] || {!(missionNamespace getVariable ["lambs_danger_pusuTepkiAktif", true])}) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l}) then { continue };
            if ((side _g) isEqualTo civilian || {_g getVariable [QGVAR(teslimOldu), false]}) then { continue };
            if ((units _g) findIf {isPlayer _x} >= 0) then { continue };

            // ---- ALARM ----
            private _kay = _g getVariable ["lambs_danger_olaySay_Casualty", 0];
            private _kayEski = _g getVariable [QGVAR(pusuKayip), _kay];
            _g setVariable [QGVAR(pusuKayip), _kay];
            private _yeniKayip = _kay > _kayEski;
            private _uye = (units _g) select {alive _x && {isNull objectParent _x} && {!(_x getVariable [QGVAR(teslim), false])}};
            if (_uye isEqualTo []) then { continue };
            private _baskilar = _uye apply { getSuppression _x };
            private _bMax = selectMax _baskilar;
            private _bOrt = (_baskilar call BIS_fnc_arithmeticMean);
            if (_yeniKayip) then { _g setVariable [QGVAR(pusuKayipT), time]; };
            private _alarm = _yeniKayip || {_bMax >= 0.45} || {_bOrt >= 0.30};
            if (!_alarm) then { continue };
            if ((time - (_g getVariable [QGVAR(pusuT), -999])) < 40) then {
                // aktif tepki suresi icinde yeni alarm: cagri atesi icin 'ikinci alarm' isareti
                _g setVariable [QGVAR(pusuAlarm2T), time];
                continue
            };

            // gorunmeyen atici: bilinen dusmana gorus hatti yok
            private _en = _l findNearestEnemy _l;
            private _gorunur = !isNull _en && {alive _en} && {(_l knowsAbout _en) >= 1.0} && {!(lineIntersects [eyePos _l, eyePos _en, _l, _en])};
            if (_gorunur) then { continue };   // gorulen dusman: LAMBS / ELITE normal akisi

            _g setVariable [QGVAR(pusuT), time];
            private _tazeEst = (time - (_g getVariable [QGVAR(sesSonZaman), -999])) <= 12;
            private _est = if (_tazeEst) then { _g getVariable [QGVAR(sesSonPos), []] } else { [] };
            if (_est isNotEqualTo []) then { _est = +_est; _est set [2, 0]; };
            private _kayipOran = 1 - (((count _uye) / ((_g getVariable [QGVAR(moralIlk), count _uye]) max (count _uye))));

            // ---- A) ANINDA ----
            if ((behaviour _l) isNotEqualTo "COMBAT") then { _g setBehaviour "COMBAT"; };
            if ((combatMode _g) in ["BLUE", "GREEN", "WHITE"]) then { _g setCombatMode "YELLOW"; };
            if (_est isNotEqualTo []) then {
                private _bak = [_uye, [], {_x distance2D _est}, "ASCEND"] call BIS_fnc_sortBy;
                { _x doWatch _est; [{ params ["_c"]; if (alive _c) then { _c doWatch objNull; }; }, [_x], 7] call CBA_fnc_waitAndExecute; } forEach (_bak select [0, 3]);
                private _mesafe = _l distance2D _est;
                if (_mesafe >= 25) then {
                    private _atici = ([_uye select {(primaryWeapon _x) isNotEqualTo "" && {(_x ammo (primaryWeapon _x)) > 0}}, [], {_x distance2D _est}, "ASCEND"] call BIS_fnc_sortBy) select [0, 2];
                    { _x doSuppressiveFire _est; } forEach _atici;
                };
            };

            // ---- B) KOMSU UYARISI ----
            private _komsuN = 0;
            if (_est isNotEqualTo []) then {
                {
                    private _g2 = _x;
                    if (_g2 isNotEqualTo _g && {local _g2} && {(side _g2) isEqualTo (side _g)} && {!isNull (leader _g2)} && {!isPlayer (leader _g2)} && {((leader _g2) distance2D _l) < 600}) then {
                        _g2 setVariable [QGVAR(sesSonZaman), time];
                        _g2 setVariable [QGVAR(sesSonPos), _est];
                        if ((behaviour (leader _g2)) in ["SAFE", "CARELESS"]) then { _g2 setBehaviour "AWARE"; };
                        { _x doWatch _est; [{ params ["_c"]; if (alive _c) then { _c doWatch objNull; }; }, [_x], 7] call CBA_fnc_waitAndExecute; } forEach (((units _g2) select {alive _x && {isNull objectParent _x}}) select [0, 2]);
                        _komsuN = _komsuN + 1;
                    };
                } forEach allGroups;
            };

            // ---- C) KANAT ----
            private _kanat = 0;
            private _mesgul = (_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isExecutingTactic), false]};
            if (_est isNotEqualTo [] && {missionNamespace getVariable ["lambs_danger_pusuKanatAktif", true]} && {(count _uye) >= 4} && {_kayipOran < 0.5} && {!_mesgul}) then {
                private _d = _l distance2D _est;
                if (_d >= 60 && {_d <= 450} && {(time - (_g getVariable [QGVAR(pusuKanatT), -999])) > 90}) then {
                    _g setVariable [QGVAR(pusuKanatT), time];
                    _kanat = [_g, _est, "KANAT"] call FUNC(istiksaf);
                };
            };

            // ---- D) CAGRI ATESI ----
            private _cagri = 0;
            private _ikinci = (time - (_g getVariable [QGVAR(pusuAlarm2T), -999])) < 15;
            private _kayipSon = _yeniKayip || {(time - (_g getVariable [QGVAR(pusuKayipT), -999])) < 15};
            if (_est isNotEqualTo [] && {missionNamespace getVariable ["lambs_danger_pusuCagriAktif", true]} && {_ikinci || _kayipSon}) then {
                private _d = _l distance2D _est;
                private _ozK = format ["lambs_danger_pusuCagriT_%1", side _g];
                if (_d >= 150 && {_d <= 1800} && {(time - (missionNamespace getVariable [_ozK, -999])) > 120}) then {
                    _cagri = [side _g, _est, "OPERATOR", groupId _g] call FUNC(topcuDestek);
                    if (_cagri > 0) then {
                        missionNamespace setVariable [_ozK, time];
                        diag_log format ["[PUSU-CAGRI] %1 | %2 | tahmini atici konumu %3 (lider %4 m) | %5 top 3'er mermi HE", groupId _g, side _g, mapGridPosition _est, round _d, _cagri];
                    };
                };
            };

            if (_logN < 80) then {
                _logN = _logN + 1;
                diag_log format ["[PUSU-TEPKI] %1 | alarm: %2 | kayip +%3 (oran %4) baski max %5 ort %6 | tahmin: %7 | komsu uyari %8 | kanat %9 asker | cagri %10 top", groupId _g, ["baski", "YENI KAYIP"] select _yeniKayip, _kay - _kayEski, _kayipOran toFixed 2, _bMax toFixed 2, _bOrt toFixed 2, if (_est isEqualTo []) then {"yok (taze ses yok -> 360 derece)"} else {format ["%1 m / %2 derece", round (_l distance2D _est), round (_l getDir _est)]}, _komsuN, _kanat, _cagri];
            };
        } forEach allGroups;
    };
};
true
