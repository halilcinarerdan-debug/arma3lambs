#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * COVER OLCUM KATMANI (v8.661, v8.662 duzeltme: STAND sayimi, siper / uzak engel / acik ayrimi, hareketsiz duruş, komutan disi rol + forceMove kosucu; yol haritasi Asama 12 madde 1; kullanici: 'dediklerine basla'): temasli AI'in siper / manevra kalitesini sayilarla RPT'ye yazar (insan referansi karsilastirmasi icin).
 * 5 sn'de bir ornek (en cok 30 asker), 60 sn'de bir [COVER-OLCUM] ozeti:
 *   - ornek sayisi, dusman gozunden GIZLI % (VIEW LOD hatti arada nesneye / araziye carpiyor) / ACIKTA %
 *   - KUMELENME % (4 m icinde >= 2 dost) ve ort. en yakin dost mesafesi
 *   - DURUS dagilimi (UP / CROUCH / PRONE %)
 *   - KOSAN (hiz > 8 km/sa) asker sayisi ROLE GORE (RIFLE / MG / AT / MEDIC / MARKSMAN): 'MG kosan' ve 'MEDIC kosan' rol disiplini kontrolu
 * Yalniz YEREL AI, temasli (30 sn) grup, bilinen dusman <= 400 m. CBA: lambs_danger_coverOlcum (varsayilan ACIK).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_coverOlcumStarted") exitWith {false};
lambs_danger_coverOlcumStarted = true;

diag_log "[COVER-OLCUM] cover / manevra olcum katmani baslatildi (v8.661)";

[] spawn {
    private _sayac = createHashMapFromArray [["n", 0], ["siper", 0], ["uzak", 0], ["acik", 0], ["kume", 0], ["dostMes", 0], ["sSTAND", 0], ["sCROUCH", 0], ["sPRONE", 0], ["sN", 0], ["hN", 0], ["lider", 0], ["fmRIFLE", 0], ["fmMG", 0], ["fmAT", 0], ["fmMEDIC", 0], ["fmMARKSMAN", 0], ["rolMG", 0], ["rolAT", 0], ["rolMEDIC", 0], ["rolRIFLE", 0], ["rolMARKSMAN", 0]];
    private _ozetT = time + 60;
    private _rf = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    while {true} do {
        sleep 5;
        if !(missionNamespace getVariable ["lambs_danger_coverOlcum", true]) then { continue };
        private _esik = ["SUPHE"] call FUNC(bilgiEsik);
        private _k = 0;
        {
            private _u = _x;
            if (_k >= 30) exitWith {};
            if (
                !local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                || {((group _u) getVariable [QGVAR(contact), 0]) < (time - 30)} || {(insideBuilding _u) > 0.5}
            ) then { continue };
            private _e = _u findNearestEnemy _u;
            if (isNull _e || {!alive _e} || {(_u distance _e) > 400} || {(_u knowsAbout _e) < _esik}) then { continue };
            _k = _k + 1;
            _sayac set ["n", (_sayac get "n") + 1];
            private _lider = _u isEqualTo (leader group _u);
            private _rol = [_u] call _rf;
            if (_lider) then { _sayac set ["lider", (_sayac get "lider") + 1]; } else {
                _sayac set ["rol" + _rol, (_sayac getOrDefault ["rol" + _rol, 0]) + 1];
                // v8.662: rol disiplini: bounding / siper kosucusu (forceMove) olan komutan disi MG / AT / saglikci / nisanci sayilir (eski: hiz > 8 km/sa = grup yuruyusunu de sayiyordu)
                if ((time - (_u getVariable [QGVAR(bndSonKos), -999])) < 20) then { _sayac set ["fm" + _rol, (_sayac getOrDefault ["fm" + _rol, 0]) + 1]; };   // v8.664: forceMove 30+ farkli kaynaktan (geri cekilme, kacis, sarjor siperi, MG yer degistirme...) set edilir; rol ihlali = son 20 sn BOUNDING kosucusu
            };
            // v8.662: GIZLILIK SINIFI: 'siper' = dusman hatti askerin <= 4 m onundeki nesneye carpiyor (gercek siper / gizlenme); 'uzak' = daha uzak nesne / arazi (dogal engel, cover degil); 'acik' = hat acik
            private _pa = (getPosASL _u) vectorAdd [0, 0, 0.9];
            private _ht = lineIntersectsSurfaces [eyePos _e, _pa, _e, _u, true, 1, "VIEW", "NONE"];
            private _sinif = if (_ht isNotEqualTo []) then { ["uzak", "siper"] select ((((_ht select 0) select 0) distance _pa) < 4) } else { ["acik", "uzak"] select (terrainIntersectASL [eyePos _e, _pa]) };
            _sayac set [_sinif, (_sayac get _sinif) + 1];
            // v8.737: HAREKETSIZ asker icin ayri siniflar (kullanici: 'botlari sipere yapistir'; hareketli askerler siper % 'yi sulandiriyordu) + ates edebiliyor mu (dusmani su an goruyor)
            if ((speed _u) < 1.5) then {
                _sayac set ["hs_n", (_sayac getOrDefault ["hs_n", 0]) + 1];
                _sayac set ["hs_" + _sinif, (_sayac getOrDefault ["hs_" + _sinif, 0]) + 1];
                if (([_u, "VIEW", _e] checkVisibility [eyePos _u, eyePos _e]) >= 0.3) then { _sayac set ["hs_gorur", (_sayac getOrDefault ["hs_gorur", 0]) + 1]; };
            };
            // v8.662: DURUS: hareketsiz (< 1.5 m/sn) askerin duruşu = siper duruşu (STAND, CROUCH, PRONE); eskiden 'UP' sayiliyordu, stance 'STAND' doner
            if ((speed _u) < 1.5) then {
                _sayac set ["sN", (_sayac get "sN") + 1];
                private _st = stance _u;
                if (_st in ["STAND", "CROUCH", "PRONE"]) then { _sayac set ["s" + _st, (_sayac get ("s" + _st)) + 1]; };
            } else { _sayac set ["hN", (_sayac get "hN") + 1]; };
            private _dm = ((_u nearEntities ["CAManBase", 12]) select {_x isNotEqualTo _u && {alive _x} && {(side group _x) isEqualTo (side group _u)}}) apply {_x distance _u};
            private _en = if (_dm isEqualTo []) then {12} else {selectMin _dm};
            _sayac set ["dostMes", (_sayac get "dostMes") + _en];
            if ((count (_dm select {_x < 4})) >= 2) then { _sayac set ["kume", (_sayac get "kume") + 1]; };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            private _n = _sayac get "n";
            if (_n > 0) then {
                private _sN = (_sayac get "sN") max 1;
                diag_log format ["[COVER-OLCUM] 60 sn: ornek %1 | SIPER (<= 4 m nesne) %2 %% / UZAK ENGEL (arazi / uzak nesne) %3 %% / ACIKTA %4 %% | KUMELENME (4 m icinde >= 2 dost) %5 %% | ort. en yakin dost %6 m | HAREKETSIZ %7 asker: STAND %8 %% CROUCH %9 %% PRONE %10 %% | HAREKETLI %11 | ROL (komutan disi): MG %12 AT %13 MEDIC %14 MARKSMAN %15 RIFLE %16 (komutan %17) | BOUNDING KOSUCUSU (son 20 sn) ROLE GORE: RIFLE %18 MG %19 AT %20 MEDIC %21 MARKSMAN %22",
                    _n, round (100 * (_sayac get "siper") / _n), round (100 * (_sayac get "uzak") / _n), round (100 * (_sayac get "acik") / _n), round (100 * (_sayac get "kume") / _n), ((_sayac get "dostMes") / _n) toFixed 1,
                    _sayac get "sN", round (100 * (_sayac get "sSTAND") / _sN), round (100 * (_sayac get "sCROUCH") / _sN), round (100 * (_sayac get "sPRONE") / _sN), _sayac get "hN",
                    _sayac get "rolMG", _sayac get "rolAT", _sayac get "rolMEDIC", _sayac get "rolMARKSMAN", _sayac get "rolRIFLE", _sayac get "lider",
                    _sayac get "fmRIFLE", _sayac get "fmMG", _sayac get "fmAT", _sayac get "fmMEDIC", _sayac get "fmMARKSMAN"];
            };
            private _hsn = _sayac getOrDefault ["hs_n", 0];
            if (_hsn > 0) then {
                diag_log format ["[COVER-OLCUM-HAREKETSIZ] 60 sn: hareketsiz ornek %1 | GERCEK SIPER (<= 4 m nesne) %%%2 | uzak engel %%%3 | acik %%%4 | dusmani su an goruyor (ates edebilir) %%%5", _hsn, round (100 * (_sayac getOrDefault ["hs_siper", 0]) / _hsn), round (100 * (_sayac getOrDefault ["hs_uzak", 0]) / _hsn), round (100 * (_sayac getOrDefault ["hs_acik", 0]) / _hsn), round (100 * (_sayac getOrDefault ["hs_gorur", 0]) / _hsn)];
            };
            { _sayac set [_x, 0]; } forEach (keys _sayac);
        };
    };
};
true
