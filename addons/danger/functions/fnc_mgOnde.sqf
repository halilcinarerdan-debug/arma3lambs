#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MG TEHDIT YONUNDE (v8.732 ISKELET; kullanici: 'mg tehdit yonune konumlandirilsin, geride kaliyor'): temasli grupta (bilinen dusman 40-350 m) bosta duran (hiz < 1.5) MG, grubun GERI SAYILAN kisminda ise
 * (kendi grubunun MG disi uyelerinin agirlik merkezine gore tehdit ekseninde >= mgOndeGeriM (6 m) geride) tehdit yonune, hakim nokta / yoksa 4 m onde yanal ofsetli bir noktaya ilerler (en cok 25 sn'de bir).
 * KANIT / SINIR: tum RPT [DURUM] 'ileri' (lider yonune gore): MG ort. +10.5 m (geride <= -4 m: %38) vs tufekli +9.4 m (%32): MG belirgin SISTEMATIK geri degil ama daha sik geride; bu ISKELET (T) gozlem sonrasi ayarlanir.
 * Muaf: oyuncu grubu, geri cekilme / kacis / temas kes / bounding (bounding MG'yi kendi planlar) / taktik / pusu / sniper, LAMBS-TUTAN sahipli, binada, kosucu / taktik kilidi / siperTut / tedavi, baski >= 0.5.
 * hakimNokta (v8.669) MG'yi tehdide mevcut konumundan en cok hakimYaklasma (15 m) yaklastirir: asiri one cikmaz. CBA: mgOnde (varsayilan ACIK), mgOndeGeriM (6). Log: [MG-ONDE] (ilk 20).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_mgOndeStarted") exitWith {false};
lambs_danger_mgOndeStarted = true;
diag_log "[MG-ONDE] MG tehdit yonunde konumlanma (geride kalan MG ileri alinir) baslatildi (v8.732, iskelet)";

[] spawn {
    private _logN = 0;
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    while {true} do {
        sleep ([3, true, false, "mgOnde"] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_mgOnde", true]) then { continue };
        private _geriM = ((missionNamespace getVariable ["lambs_danger_mgOndeGeriM", 6]) max 3) min 20;
        private _esik = ["SUPHE"] call FUNC(bilgiEsik);
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {(_g getVariable [QGVAR(contact), 0]) <= time}) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isBounding), false]}
                || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
                || {([_g] call FUNC(wpSahip)) in ["LAMBS", "TUTAN"]}
            ) then { continue };
            private _en = _l findNearestEnemy _l;
            if (isNull _en || {!alive _en} || {!(_en isKindOf "CAManBase")} || {captive _en} || {(_l knowsAbout _en) < _esik}) then { continue };
            private _de = _l distance2D _en;
            if (_de < 40 || {_de > 350}) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            private _mgs = _us select {
                ([_x] call _rolFn) isEqualTo "MG" && {(speed _x) < 1.5} && {time >= (_x getVariable [QGVAR(mgOndeT), 0])} && {(_x getVariable [QGVAR(forceMove), false]) isNotEqualTo true}
                && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time} && {(_x getVariable [QGVAR(siperTutBit), 0]) <= time} && {time >= (_x getVariable [QGVAR(tcccBusy), 0])}
                && {(getSuppression _x) < 0.5} && {(insideBuilding _x) <= 0.5} && {!captive _x}
            };
            if (_mgs isEqualTo []) then { continue };
            private _digerler = _us select {([_x] call _rolFn) isNotEqualTo "MG"};
            if ((count _digerler) < 2) then { continue };
            private _cx = 0; private _cy = 0;
            { private _p = getPosATL _x; _cx = _cx + (_p select 0); _cy = _cy + (_p select 1); } forEach _digerler;
            private _c = [_cx / (count _digerler), _cy / (count _digerler), 0];
            private _dirT = _c getDir _en;
            {
                private _mg = _x;
                private _pm = getPosATL _mg;
                private _ileri = (((_pm select 0) - (_c select 0)) * (sin _dirT)) + (((_pm select 1) - (_c select 1)) * (cos _dirT));
                if (_ileri > -_geriM) then { continue };
                _mg setVariable [QGVAR(mgOndeT), time + 25];
                private _hn = [_mg, getPosATL _en, "MG"] call FUNC(hakimNokta);
                private _hedef = [];
                private _kaynak = "";
                if (_hn isNotEqualTo []) then { _hedef = _hn select 0; _kaynak = "hakim nokta"; } else {
                    private _pt = _c getPos [4, _dirT + (selectRandom [90, -90])];
                    _pt = _pt getPos [4, _dirT];
                    if (!surfaceIsWater _pt && {(_pt distance2D _en) >= 25}) then { _hedef = _pt; _kaynak = "grubun onu (4 m yanal)"; };
                };
                if (_hedef isEqualTo []) then { continue };
                _mg setVariable [QGVAR(taktikKilit), time + 8];
                _mg doMove _hedef;
                if (_logN < 20) then {
                    _logN = _logN + 1;
                    diag_log format ["[MG-ONDE] %1 | %2 | tehdit eksende %3 m geride (esik %4) | dusman %5 m -> %6 (%7 m)", groupId _g, name _mg, round _ileri, -_geriM, round _de, _kaynak, round (_mg distance2D _hedef)];
                };
            } forEach _mgs;
        } forEach allGroups;
    };
};
true
