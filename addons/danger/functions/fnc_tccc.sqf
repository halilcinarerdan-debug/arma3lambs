#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TCCC — TAKTIK SAHA YARALI BAKIMI (ACE Medical / Advanced Combat Medicine (ACM) uyumlu)
 *
 * Yerel AI gruplari icin 3 sn'de bir; grupta yarali (baygin / yarali / kan kaybi) varsa en yakin HEKIM secilir
 * (medic rolu > Medic trait'i > sargi tasiyan tufekli). Evre:
 *
 *   ATES ALTINDA (temas suruyor): sadece BAYGIN yarali, hekim baskida degil (< 0.4) ve en yakin dusman > 50 m ise
 *       yarali dusmandan uzaga, siperli KENARA CEKILIR (ACE drag) + M adimi (kanama).  Aksi halde bekler.
 *   GUVENLI (temas bitti 6 sn+ ya da hic temas yok): once baygin yarali kenara cekilir, sonra tam MARCH:
 *       M  Massive hemorrhage : paketleme / elastik / sahra sargisi tum vucut bolgelerine; kanama suruyorsa turnike (uzuvlar)
 *       A/R Airway / Respiration : ACM'ye ozgu adimlar DEVIR_LOGU'nda yapilacak (kalp durmasinda CPR + epinefrin burada)
 *       C  Circulation : kan hacmi dusukse IV (BloodIV_500 / BloodIV / SalineIV), agri yuksekse morfin
 *       H  Hypothermia : yapilacak
 *
 * ACE API (surum farki icin ozellik tespiti + RPT'ye [TCCC] satiri):
 *   ace_medical_treatment_fnc_treatment [hekim, hasta, bolge, sinif]  -> tedavi (ACM bunu kendi sinif listesiyle ezer)
 *   ace_medical_status_fnc_getBloodLoss, ace_dragging_fnc_startDrag / dropObject
 *   Fonksiyon yoksa: tedavi vanilla "HealSoldier" aksiyonuna duser, cekme atlanir.
 *   Hekimde malzeme yoksa adim atlanir (ACE kendisi de reddeder).
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_tcccStarted") exitWith {false};
lambs_danger_tcccStarted = true;

diag_log format [
    "[TCCC] baslatildi | ace_medical:%1 ACM:%2 treatment_fn:%3 drag_fn:%4 bloodloss_fn:%5",
    isClass (configFile >> "CfgPatches" >> "ace_medical"), isClass (configFile >> "CfgPatches" >> "ACM_core"),
    !isNil "ace_medical_treatment_fnc_treatment", !isNil "ace_dragging_fnc_startDrag", !isNil "ace_medical_status_fnc_getBloodLoss"
];

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];

    private _yarali = {
        params ["_u"];
        alive _u && {
            ((lifeState _u) isEqualTo "INCAPACITATED")
            || {_u getVariable ["ACE_isUnconscious", false]}
            || {damage _u > 0.2}
            || {(_u getVariable ["ace_medical_bloodVolume", 6]) < 5.3}
        }
    };
    private _baygin = { params ["_u"]; ((lifeState _u) isEqualTo "INCAPACITATED") || {_u getVariable ["ACE_isUnconscious", false]} };
    private _kanKaybi = {
        params ["_u"];
        if (isNil "ace_medical_status_fnc_getBloodLoss") then {0} else {[_u] call ace_medical_status_fnc_getBloodLoss}
    };
    lambs_danger_tcccMalzeme = createHashMapFromArray [
        ["packingbandage", ["ace_packingbandage"]], ["elasticbandage", ["ace_elasticbandage"]],
        ["fielddressing", ["ace_fielddressing"]], ["pressurebandage", ["ace_fielddressing", "ace_elasticbandage"]],
        ["quikclot", ["ace_quikclot"]], ["applytourniquet", ["ace_tourniquet"]],
        ["morphine", ["ace_morphine"]], ["epinephrine", ["ace_epinephrine"]],
        ["bloodiv", ["ace_bloodiv"]], ["bloodiv_500", ["ace_bloodiv_500"]], ["bloodiv_250", ["ace_bloodiv_250"]],
        ["salineiv", ["ace_salineiv"]], ["salineiv_500", ["ace_salineiv_500"]]
    ];
    lambs_danger_tcccVarMi = {
        params ["_m", "_cls"];
        private _l = lambs_danger_tcccMalzeme getOrDefault [toLower _cls, []];
        _l isEqualTo [] || {((items _m) findIf {(toLower _x) in _l}) > -1}
    };

    // Tek tedavi adimi: true = envanter degisti (uygulandi)
    private _tx = {
        params ["_m", "_c", "_part", "_cls"];
        if !([_m, _cls] call lambs_danger_tcccVarMi) exitWith {false};
        private _once = count (items _m);
        _m playActionNow "MedicOther";
        if (isNil "ace_medical_treatment_fnc_treatment") then {
            _m action ["HealSoldier", _c];
        } else {
            [_m, _c, _part, _cls] call ace_medical_treatment_fnc_treatment;
        };
        sleep 2.5;
        (count (items _m)) < _once || {_cls isEqualTo "CPR"}
    };

    private _birak = {
        params ["_m", "_c"];
        if (!isNil "ace_dragging_fnc_dropObject" && {!isNull _c} && {!isNull (attachedTo _c)}) then {
            [_m, _c] call ace_dragging_fnc_dropObject;
        };
        if (alive _m) then {
            _m setVariable [QGVAR(forceMove), nil];
            _m setVariable [QGVAR(tcccBusy), 0];
            _m setUnitPos "AUTO";
            _m doFollow (leader _m);
        };
        if (!isNull _c) then { _c setVariable [QGVAR(tcccBy), objNull]; _c setVariable [QGVAR(tcccDone), time]; };
    };

    private _tedavi = {
        params ["_g", "_m", "_c", "_baygin", "_birak", "_tx", "_kanKaybi"];
        private _t0 = time;
        _m setVariable [QGVAR(tcccBusy), time + 150];
        _m setVariable [QGVAR(forceMove), true];
        _c setVariable [QGVAR(tcccBy), _m];
        private _guvenliFn = { (((_this select 0) getVariable [QGVAR(contact), 0]) < time) };
        diag_log format ["[TCCC] %1 | hekim %2 -> yarali %3 | baygin:%4 | %5", groupId _g, name _m, name _c, [_c] call _baygin, ["ATES ALTINDA", "GUVENLI"] select ([_g] call _guvenliFn)];

        // 1) yaralıya git
        // uzaktan gelen hekim (kumanda medevac): yuruyus suresi mesafeye gore (25 sn sabit uzak yaraliya yetmiyordu)
        private _bitis = time + ((25 max (((_m distance2D _c) / 3) + 8)) min 100);
        _m setUnitPos "UP";
        _m doMove (getPosATL _c);
        waitUntil {
            sleep 0.7;
            !alive _m || {!alive _c} || {(_m distance2D _c) < 3} || {time > _bitis}
            || {!([_g] call _guvenliFn) && {(getSuppression _m) > 0.6}}
        };
        if (!alive _m || {!alive _c} || {(_m distance2D _c) >= 5}) exitWith { [_m, _c] call _birak; };

        // 2) baygin ise dusmandan uzaga siperli kenara cek
        if ([_c] call _baygin && {!isNil "ace_dragging_fnc_startDrag"}) then {
            private _tp = [];
            private _sit = _g getVariable [QGVAR(cmdSit), []];
            if (_sit isNotEqualTo [] && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]}) then { _tp = _sit select 7; };
            if (_tp isEqualTo []) then {
                private _en = _m findNearestEnemy _m;
                if (!isNull _en) then { _tp = getPosATL _en; };
            };
            private _cp = getPosATL _c;
            private _kac = if (_tp isEqualTo []) then {random 360} else {_tp getDir _cp};
            private _hedef = [];
            private _hS = -9999;
            {
                private _a = _kac + _x;
                {
                    private _p = _cp getPos [_x, _a];
                    if (!surfaceIsWater _p) then {
                        private _s = 6 * (count (nearestTerrainObjects [_p, ["WALL", "BUILDING", "HOUSE", "TREE", "ROCK", "FENCE"], 6, false, true])) min 12;
                        if (_tp isNotEqualTo []) then {
                            _s = _s + 0.05 * (_p distance2D _tp);
                            if (lineIntersects [AGLToASL (_tp vectorAdd [0,0,1.5]), AGLToASL (_p vectorAdd [0,0,0.5])]) then { _s = _s + 15; };
                        };
                        if (_s > _hS) then { _hS = _s; _hedef = _p; };
                    };
                } forEach [10, 15];
            } forEach [0, 35, -35];

            if (_hedef isNotEqualTo []) then {
                [_m, _c] call ace_dragging_fnc_startDrag;
                _m doMove _hedef;
                private _b2 = time + 22;
                waitUntil { sleep 0.7; !alive _m || {!alive _c} || {(_m distance2D _hedef) < 3} || {time > _b2} };
                if (!isNull (attachedTo _c)) then { [_m, _c] call ace_dragging_fnc_dropObject; };
                diag_log format ["[TCCC] %1 | %2 yaraliyi %3 m kenara cekti", groupId _g, name _m, round ((getPosATL _c) distance2D _cp)];
            };
        };
        if (!alive _m || {!alive _c}) exitWith { [_m, _c] call _birak; };

        // 3) M — kanama: sarma / paketleme / elastik; durmazsa turnike
        private _guvenli = [_g] call _guvenliFn;
        private _parcalar = ["Body", "LeftLeg", "RightLeg", "LeftArm", "RightArm"];
        private _tur = 0;
        while {alive _m && {alive _c} && {([_c] call _kanKaybi) > 0.001} && {_tur < 3} && {time < (_t0 + 140)}} do {
            if (_tur >= 1) then {
                { [_m, _c, _x, "ApplyTourniquet"] call _tx; } forEach ["LeftLeg", "RightLeg", "LeftArm", "RightArm"];
            } else {
                {
                    private _p = _x;
                    private _ok = false;
                    {
                        if (!_ok) then { _ok = [_m, _c, _p, _x] call _tx; };
                    } forEach ["PackingBandage", "ElasticBandage", "FieldDressing"];
                } forEach _parcalar;
            };
            _tur = _tur + 1;
            if (!_guvenli) then { break };
        };

        // ates altinda sadece M; ilerisi guvenli olunca
        if ([_g] call _guvenliFn) then {
            // A/R: kalp durmasi -> CPR + epinefrin (ACM'ye ozgu hava yolu / pnomotoraks yapilacak)
            if (_c getVariable ["ace_medical_inCardiacArrest", false]) then {
                for "_i" from 1 to 5 do {
                    if (alive _m && {alive _c} && {_c getVariable ["ace_medical_inCardiacArrest", false]}) then { [_m, _c, "Body", "CPR"] call _tx; };
                };
                if (_c getVariable ["ace_medical_inCardiacArrest", false]) then { [_m, _c, "Body", "Epinephrine"] call _tx; };
            };
            // C: kan hacmi / agri
            private _iv = 0;
            while {alive _m && {alive _c} && {(_c getVariable ["ace_medical_bloodVolume", 6]) < 5.2} && {_iv < 2}} do {
                private _ok = false;
                { if (!_ok) then { _ok = [_m, _c, "LeftArm", _x] call _tx; }; } forEach ["BloodIV_500", "BloodIV", "SalineIV_500", "SalineIV"];
                _iv = _iv + 1;
                if (!_ok) then { break };
            };
            if ((_c getVariable ["ace_medical_pain", 0]) > 0.35) then { [_m, _c, "Body", "Morphine"] call _tx; };
        };

        diag_log format [
            "[TCCC] %1 | %2 -> %3 | tamam %4 sn | kanKaybi:%5 kan:%6 baygin:%7",
            groupId _g, name _m, name _c, round (time - _t0),
            ([_c] call _kanKaybi) toFixed 3, (_c getVariable ["ace_medical_bloodVolume", 6]) toFixed 2, [_c] call _baygin
        ];
        [_m, _c] call _birak;
    };

    while {true} do {
        sleep 3;
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l}) then { continue };
            if (_g getVariable [QGVAR(isRetreating), false] || {_g getVariable [QGVAR(isEvading), false]}) then { continue };

            private _contact = (_g getVariable [QGVAR(contact), 0]) > time;
            private _sonKes = time - (_g getVariable [QGVAR(contact), 0]);
            private _guvenli = !_contact && {_sonKes > 6};

            private _yaralilar = (units _g) select {
                [_x] call _yarali && {isNull (_x getVariable [QGVAR(tcccBy), objNull])} && {(time - (_x getVariable [QGVAR(tcccDone), -999])) > 60}
            };
            if (_yaralilar isEqualTo []) then { continue };

            {
                private _c = _x;
                // ates altinda: sadece baygin yarali
                if (!_guvenli && {!([_c] call _baygin)}) then { continue };

                private _adaylar = (units _g) select {
                    (_x isNotEqualTo _c) && {alive _x} && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
                    && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!([_x] call _baygin)}
                    && {time > (_x getVariable [QGVAR(tcccBusy), 0])}
                    && {!(_x getVariable [QGVAR(forceMove), false])}
                    && {(_x getVariable [QGVAR(grState), []]) isEqualTo []}
                };
                // hekim onceligi: MEDIC rolu > Medic trait > sargi tasiyan
                private _hekim = _adaylar select {([_x] call _rolFn) isEqualTo "MEDIC" || {_x getUnitTrait "Medic"}};
                if (_hekim isEqualTo []) then {
                    _hekim = _adaylar select {((items _x) findIf {(toLower _x) in ["ace_packingbandage", "ace_elasticbandage", "ace_fielddressing", "ace_quikclot", "ace_tourniquet", "firstaidkit"]}) > -1};
                };
                // KUMANDA MEDEVAC (fnc_hqMedevac): grupta hekim yoksa baska gruptan atanan hekim
                if (_hekim isEqualTo []) then {
                    private _hqM = _c getVariable [QGVAR(hqMedic), objNull];
                    if (!isNull _hqM && {alive _hqM} && {local _hqM} && {!isPlayer _hqM} && {isNull objectParent _hqM}
                        && {(lifeState _hqM) in ["HEALTHY", "INJURED"]} && {time > (_hqM getVariable [QGVAR(tcccBusy), 0])}) then {
                        _hekim = [_hqM];
                    };
                };
                if (_hekim isEqualTo []) then { continue };
                _hekim = [_hekim, [], {_x distance2D _c}, "ASCEND"] call BIS_fnc_sortBy;
                private _m = _hekim select 0;

                // ates altinda: hekim baskida degil ve dusman uzak olmali
                if (!_guvenli) then {
                    private _en = _m findNearestEnemy _m;
                    if ((getSuppression _m) >= 0.4 || {!isNull _en && {(_m distance2D _en) < 50}}) then { continue };
                };
                [_g, _m, _c, _baygin, _birak, _tx, _kanKaybi] spawn _tedavi;
            } forEach _yaralilar;
        } forEach (allGroups select {local _x && {!isNull leader _x}});
    };
};

true
