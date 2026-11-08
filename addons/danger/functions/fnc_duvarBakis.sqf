#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DUVAR BAKISI BEKCISI (v8.500w; kullanici: 'askerler hala kor duvara bakabiliyor, bakis degistirme pek iyi calismiyor').
 *
 * NEDEN: bakis yonunu cok modul yazar (tehditBakis, noktaEleman, roleStation, sektorBakis, bina vb.); acik-yon kontrolu yalniz bazilarinda var (sektorBakis, yan / arka emniyet). Hepsini tek tek yamamak yerine
 *   MERKEZI bir son kontrol: gozu ileri baktigi yonde 3 m icinde nesne (duvar / konteyner / kaya) varsa asker o yone 'bakiyor' sayilir ve ACIK yone cevrilir.
 * KOSUL (2 sn'de bir, en fazla 10 asker, donusumlu; yerel, oyuncusuz, aracta degil): AYAKTA (STAND), hareketsiz (< 1 km/sa), hedefi yok (getAttackTarget bos), bina icinde degil, forceMove / taktikKilit / tedavi /
 *   yeniden doldurma / bomba tepkisi yok, yaralanmamis. Birim basi 8 sn bekleme.
 * YON: tercih = en yakin BILINEN dusman yonu (<= 400 m), yoksa liderin bakis yonu (lider ise kendi govde yonu). lib: FUNC(bakisAcikYon) (40 / 20 m acik, +-25 / 50 / 75 kayar). Hicbiri acik degilse asker serbest birakilir (doWatch objNull).
 * Kapatma: lambs_danger_duvarBakisOff = true.  Log: [DUVAR-BAKIS] (ilk 30) + 120 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_duvarBakisStarted") exitWith {false};
lambs_danger_duvarBakisStarted = true;
diag_log "[DUVAR-BAKIS] duvar bakisi bekcisi baslatildi (v8.500w): ayakta hareketsiz asker 3 m icinde duvara bakiyorsa acik yone cevrilir";

[] spawn {
    private _indeks = 0;
    private _logN = 0;
    private _say = [0, 0, 0];   // [cevrilen, serbest (hic acik yon yok), kontrol]
    private _ozetT = time + 120;
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_duvarBakisOff", false]) then { continue };
        private _adaylar = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side group _x) in [west, east, resistance]}
            && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(stance _x) isEqualTo "STAND"} && {(speed _x) < 1}
        };
        private _n = count _adaylar;
        if (_n > 0) then {
            private _kesit = 10 min _n;
            for "_i" from 0 to (_kesit - 1) do {
                private _u = _adaylar select ((_indeks + _i) mod _n);
                if (time < (_u getVariable [QGVAR(dvrBakT), 0])) then { continue };
                if (!isNull (getAttackTarget _u) || {(insideBuilding _u) > 0.5}) then { continue };
                if ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                    || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []} || {_u getUnitTrait "medic" && {(damage _u) > 0}}) then { continue };
                _say set [2, (_say select 2) + 1];
                private _eye = eyePos _u;
                private _bak = _eye vectorAdd ((eyeDirection _u) vectorMultiply 3);
                private _vur = lineIntersectsSurfaces [_eye, _bak, _u, objNull, true, 1, "VIEW", "NONE"];
                if (_vur isEqualTo []) then { continue };
                private _o = (_vur select 0) select 2;
                if (isNull _o || {_o isKindOf "CAManBase"}) then { continue };
                // tercih edilen yon: bilinen en yakin dusman, yoksa liderin bakisi
                private _g = group _u;
                private _tercih = getDir _u;
                private _ld = leader _g;
                if (!isNull _ld && {_ld isNotEqualTo _u}) then { _tercih = getDir _ld; };
                private _dus = _u findNearestEnemy _u;
                if (!isNull _dus && {(_u distance2D _dus) < 400} && {(_u knowsAbout _dus) > (["SEZILDI"] call FUNC(bilgiEsik))}) then { _tercih = _u getDir _dus; };
                private _by = [_u, _tercih] call FUNC(bakisAcikYon);
                _u setVariable [QGVAR(dvrBakT), time + 8];
                if (_by > -900) then {
                    _u doWatch ((getPosATL _u) getPos [40, _by]);
                    _say set [0, (_say select 0) + 1];
                } else {
                    _u doWatch objNull;
                    _say set [1, (_say select 1) + 1];
                };
                if (_logN < 30) then {
                    _logN = _logN + 1;
                    diag_log format ["[DUVAR-BAKIS] %1 (%2) | %3 m'de %4 duvari / nesneyi izliyordu -> %5", name _u, groupId _g, ((_eye distance (((_vur select 0) select 0))) toFixed 1), typeOf _o, ["ACIK YONE cevrildi (yon " + str (round _by) + ")", "hic acik yon yok: bakis serbest"] select (_by < -900)];
                };
            };
            _indeks = _indeks + _kesit;
        };
        if (time > _ozetT) then {
            _ozetT = time + 120;
            if ((_say select 0) + (_say select 1) > 0) then { diag_log format ["[DUVAR-BAKIS-OZET] 120 sn: cevrilen %1 | serbest %2 | kontrol %3", _say select 0, _say select 1, _say select 2]; };
            _say = [0, 0, 0];
        };
    };
};
true
