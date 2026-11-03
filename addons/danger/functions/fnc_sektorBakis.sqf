#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SEKTOR BAKISI (v8.371; kullanici: 'botlar CQB'de dusman yonune bakmiyordu; dusmanin gelebilecegi bolgelere baksinlar, herkes silah sesine bakmasin').
 *
 * NEDEN: fnc_tehditBakis (v8.47) TEMASTA hic calismiyor (catisma kendi hedefini secer); cqbReflex yalniz dusmani GOREN askeri cevirir. Sonuc: temasta hedefi gormeyen askerler
 *   rastgele / LAMBS'in son baktigi yone (cogunlukla herkes ayni ates sesine) bakiyor, kosulari, kapilari, yan yollari kimse izlemiyor.
 * DOKTRIN (MCWP 3-11.2 / TC 3-21.76: 'sorumluluk sektoru', 360 derece emniyet): her ates etmeyen asker FARKLI bir sektore bakar; sese yalniz TEK (buyuk gruplarda iki) asker doner.
 *
 * ISLEYIS (1.5 sn'de bir; yerel, oyuncusuz lider; grup temasli (son 90 sn) YA DA bilinen dusman < 60 m):
 *   - TEHDIT YONU: grubun en yakin bilinen dusmani -> son ses konumu -> komutan raporu -> liderin bakisi.
 *   - ATES UNSURU (dusmani goren / hedefi olan) dokunulmaz (cqbReflex / cqbCevik yonetir).
 *   - Digerleri sirayla sektor alir: tehdit yonu, -45, +45, -90, +90, (>= 4 kisi ise sonuncu) arka 180. Bakis yonu KAPALIYSA (8 m'de duvar / arazi) +-25 / +-50 / +-75 kayar; hepsi kapaliysa
 *     o askere dokunulmaz. Bina icinde acik yonler (kapi / pencere / koridor) otomatik secilir.
 *   - SES: son ses (6 sn) varsa yalniz sektoru sese EN YAKIN asker (>= 6 kisi ise 2 asker) sese doner (4 sn); digerleri sektorunde KALIR.
 *   - doWatch her 3 sn'de tazelenir (LAMBS / ses herkesi ayni yone cevirirse geri alinir).
 *   MUAF: forceMove / taktikKilit / hekim tedavisi / bomba tepkisi / yeniden doldurma / panik / yaralilar / bina temizleme / retreat / evade / peel / sniper. Kapatma: CBA lambs_danger_sektorBakisAktif.
 *   Log: [SEKTOR-BAKIS] (ilk 40) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_sektorBakisStarted") exitWith {false};
lambs_danger_sektorBakisStarted = true;

diag_log "[SEKTOR-BAKIS] CQB / temas sektor bakisi baslatildi (v8.371): ates etmeyen herkes ayri sektore bakar, sese yalniz 1-2 asker doner";

[] spawn {
    private _logN = 0;
    private _ozetT = time + 60;
    private _say = createHashMapFromArray [["atama", 0], ["ses", 0], ["kapali", 0]];
    while {true} do {
        sleep 1.5;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "atama") + (_say get "ses")) > 0) then {
                diag_log format ["[SEKTOR-BAKIS-OZET] 60 sn: sektor atamasi %1 | sese donen %2 | tum yonler kapali %3", _say get "atama", _say get "ses", _say get "kapali"];
            };
            { _say set [_x, 0]; } forEach (keys _say);
        };
        if (!(missionNamespace getVariable ["lambs_danger_sektorBakisAktif", true])) then { continue };

        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _g}) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isPeeling), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isSweeping), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
                || {_g getVariable [QGVAR(disableGroupAI), false]} || {_g getVariable ["lambs_danger_disableGroupAI", false]}
            ) then { continue };
            private _us = (units _g) select {alive _x && {local _x} && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!captive _x}};
            if ((count _us) < 2) then { continue };

            // temas ya da yakin dusman
            private _en = _l findNearestEnemy _l;
            private _enYakin = !isNull _en && {alive _en} && {(_l distance2D _en) < 60} && {(_l knowsAbout _en) >= (["SEZILDI"] call FUNC(bilgiEsik))};
            private _temasT = _g getVariable [QGVAR(contact), 0];
            private _temas = _temasT > 0 && {(_temasT + 90) > time};   // v8.376: contact=0 (hic temas olmadi) 'temas' sayilmaz (oyun basinda ilk 90 sn herkes sektor atiyordu)
            if (!_temas && {!_enYakin}) then { continue };

            // tehdit yonu
            private _yon = -1;
            if (_enYakin) then {
                _yon = _l getDir _en;
            } else {
                private _sp = _g getVariable [QGVAR(sesSonPos), []];
                private _sit = _g getVariable [QGVAR(cmdSit), []];
                if (_sp isNotEqualTo [] && {(time - (_g getVariable [QGVAR(sesSonZaman), -999])) < 30}) then {
                    _yon = _l getDir _sp;
                } else {
                    if (_sit isNotEqualTo [] && {(time - (_sit select 0)) < 300} && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]}) then {
                        _yon = _l getDir (_sit select 7);
                    } else {
                        _yon = getDir _l;
                    };
                };
            };

            // ates unsurlari hariç sektor adaylari
            private _adaylar = _us select {
                private _u = _x;
                (speed _u) < 6   // v8.376: yuruyen / kosan asker yana bakmaz (yan yurume animasyonu = titreme, yavaslama); yalniz duran / yavas asker sektor alir
                && {!(_u getVariable [QGVAR(forceMove), false])} && {(_u getVariable [QGVAR(taktikKilit), 0]) <= time} && {time >= (_u getVariable [QGVAR(tcccBusy), 0])}
                && {(_u getVariable [QGVAR(grState), []]) isEqualTo []} && {(_u getVariable [QGVAR(reloadState), []]) isEqualTo []}
                && {time >= (_u getVariable [QGVAR(panikBitis), 0])} && {!(_u getVariable [QGVAR(disableAI), false])}
                && {isNull (assignedTarget _u)}
                && {
                    private _e2 = _u findNearestEnemy _u;
                    isNull _e2 || {(_u distance2D _e2) > 80} || {(terrainIntersectASL [eyePos _u, eyePos _e2]) || {lineIntersects [eyePos _u, eyePos _e2, _u, _e2]}}
                }
            };
            if (_adaylar isEqualTo []) then { continue };

            // ses: sektoru sese en yakin 1-2 asker
            private _sesAktif = (time - (_g getVariable [QGVAR(sesSonZaman), -999])) < 6;
            private _sesPos = _g getVariable [QGVAR(sesSonPos), []];
            private _sesYon = if (_sesAktif && {_sesPos isNotEqualTo []}) then { _l getDir _sesPos } else { -1 };

            private _sektorOfs = [0, -45, 45, -90, 90];
            private _n = count _adaylar;
            private _dirler = [];
            {
                private _u = _x;
                private _i = _forEachIndex;
                private _ofs = if (_n >= 4 && {_i == _n - 1} && {_i >= 5}) then {180} else {_sektorOfs select (_i mod 5)};
                private _eye = eyePos _u;
                private _secildi = -999;
                // v8.376 KOR DUVARA BAKMA (kullanici: 'botlar mal mal duvara bakiyor'): eskiden yalniz 8 m acik olmasi yetiyordu (9 m'deki duvara bakilirdi). Simdi once 40 m, olmazsa 20 m gorus acik yon aranir; hicbiri yoksa asker dokunulmaz
                {
                    private _mesafe = _x;
                    {
                        private _b = _yon + _ofs + _x;
                        private _p = _eye vectorAdd [(sin _b) * _mesafe, (cos _b) * _mesafe, 0];
                        if (!(lineIntersects [_eye, _p, _u, objNull]) && {!(terrainIntersectASL [_eye, _p])}) exitWith { _secildi = _b; };
                    } forEach [0, 25, -25, 50, -50, 75, -75];
                    if (_secildi > -900) exitWith {};
                } forEach [40, 20];
                _dirler pushBack _secildi;
            } forEach _adaylar;

            // sese donecekler
            private _sesliler = [];
            if (_sesYon >= 0) then {
                private _sirali = [];
                {
                    if ((_dirler select _forEachIndex) > -900) then {
                        _sirali pushBack [abs ((((_dirler select _forEachIndex) - _sesYon) + 540) mod 360 - 180), _x];
                    };
                } forEach _adaylar;
                _sirali sort true;
                private _kac = [1, 2] select (_n >= 6);
                for "_k" from 0 to ((_kac min (count _sirali)) - 1) do { _sesliler pushBack ((_sirali select _k) select 1); };
            };

            {
                private _u = _x;
                private _b = _dirler select _forEachIndex;
                if (_b < -900) then {
                    _say set ["kapali", (_say get "kapali") + 1];
                    continue
                };
                private _sese = _u in _sesliler;
                if ((time - (_u getVariable [QGVAR(sektorT), -999])) < 3 && {!_sese}) then { continue };
                _u setVariable [QGVAR(sektorT), time];
                private _sesAcik = _sese && {
                    private _eyeS = eyePos _u;
                    private _pS = _eyeS vectorAdd [(sin _sesYon) * 20, (cos _sesYon) * 20, 0];
                    !(lineIntersects [_eyeS, _pS, _u, objNull]) && {!(terrainIntersectASL [_eyeS, _pS])}
                };   // v8.376: ses yonunde 20 m icinde duvar varsa sese donulmez (duvara bakmak anlamsiz)
                private _hedefYon = if (_sesAcik) then { _sesYon } else { _b };
                _u doWatch ((eyePos _u) getPos [100, _hedefYon]);
                private _eskiYon = _u getVariable [QGVAR(sektorYon), -999];
                _u setVariable [QGVAR(sektorYon), _hedefYon];
                if (_sese) then {
                    _say set ["ses", (_say get "ses") + 1];
                } else {
                    if (abs (((_eskiYon - _hedefYon) + 540) mod 360 - 180) > 30 || {_eskiYon < -900}) then {
                        _say set ["atama", (_say get "atama") + 1];
                        if (_logN < 40) then {
                            _logN = _logN + 1;
                            diag_log format ["[SEKTOR-BAKIS] %1 | %2 | tehdit yonu %3 (%4) | sektor %5 | %6", groupId _g, name _u, round _yon, ["temas", "yakin dusman"] select _enYakin, round _hedefYon, ["", "SESE DONDU"] select _sese];
                        };
                    };
                };
            } forEach _adaylar;
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
    };
};

true
