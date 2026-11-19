#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CQB KUMELENME (v8.557; kullanici: 'cqb de cok dagınık durmasinlar, tek olunca kolay avlaniyorlar').
 * Yakin dovuste (bilinen dusman <= 45 m) arkadaslarindan kopuk (en yakin saglam dost > 14 m [CBA cqbKumeM]) kalan yerel AI piyade, en yakin dostunun 5-8 m yanina (dusmandan uzak taraf, tercihen siperli nokta) kisa mesafe gelir.
 *  - fnc_dispersion lider <= 40 m dusmanda artik dagitmaz; yigilma cozucu yaricapi 4 m oldugu icin hedef 5-8 m (yigilma yaratmaz).
 *  - kosullar: grup >= 3 kisi, temasta (son 20 sn), grup bounding / geri cekilme / kacis / AT / taktik yurutmuyor, birim forceMove / taktik kilidi / istasyon / hekim / bina / baski >= 0.6 degil; hedef yol dusmana yaklasmaz.
 *  - birim basina 10 sn bekleme, tick basina <= 3 birim, taktik kilidi 6 sn, senaryo kapisi (fnc_senaryoKapi [g, "cqbKume", true]) uyumlu.
 * Log: [CQB-KUME] (ilk 20) + 60 sn ozeti. Kapatma: CBA 'cqbKume'.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_cqbKumeStarted") exitWith {false};
lambs_danger_cqbKumeStarted = true;
diag_log "[CQB-KUME] CQB kumelenme (kopuk askeri yakin dostuna cek) baslatildi (v8.557)";

[] spawn {
    private _logN = 0;
    private _toplam = 0;
    private _ozetT = time + 60;
    while {true} do {
        sleep ([2, false, true, "cqbKume"] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_cqbKume", true]) then { continue };
        private _kopukM = missionNamespace getVariable ["lambs_danger_cqbKumeM", 14];
        private _butce = 3;
        {
            if (_butce <= 0) exitWith {};
            private _g = _x;
            if (isNull _g || {(count (units _g)) < 3}) then { continue };
            if (((_g getVariable [QGVAR(contact), 0]) < (time - 20))) then { continue };
            if (
                (_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isATEngage), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]}
            ) then { continue };
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {((units _g) findIf {isPlayer _x}) > -1} || {_g getVariable [QGVAR(disableGroupAI), false]}) then { continue };   // oyunculu grup yok (v8.558); disableGroupAI / ALiVE grubu yok (v8.561)
            if ([_g, "cqbKume", true] call FUNC(senaryoKapi)) then { continue };
            private _e = _l findNearestEnemy _l;
            if (isNull _e || {!alive _e} || {(_l distance2D _e) > 45} || {(_l knowsAbout _e) < (["SUPHE"] call FUNC(bilgiEsik))}) then {
                // lider uzak olabilir: grubun herhangi bir uyesinin bilinen dusmani
                private _bul = objNull;
                { private _x2 = _x findNearestEnemy _x; if (!isNull _x2 && {alive _x2} && {(_x distance2D _x2) <= 45} && {(_x knowsAbout _x2) >= (["SUPHE"] call FUNC(bilgiEsik))}) exitWith { _bul = _x2; }; } forEach ((units _g) select {alive _x && {local _x}});
                _e = _bul;
            };
            if (isNull _e || {[_e] call FUNC(teslimMi)}) then { continue };
            private _saglam = (units _g) select {alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {isNull objectParent _x}};
            if ((count _saglam) < 3) then { continue };
            {
                if (_butce <= 0) exitWith {};
                private _u = _x;
                if (!local _u || {isPlayer _u} || {_u isEqualTo _l}) then { continue };
                if ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {time < (_u getVariable [QGVAR(kumeT), 0])}) then { continue };
                if ((getSuppression _u) >= 0.6 || {(insideBuilding _u) >= 0.5} || {(_u getVariable [QGVAR(stationPos), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(tcccBusy), false]) isEqualTo true}) then { continue };
                if ((_u getVariable [QGVAR(reloadState), []]) isNotEqualTo [] || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []}) then { continue };
                private _dostlar = _saglam - [_u];
                if (_dostlar isEqualTo []) then { continue };
                private _en = objNull;
                private _enM = 9999;
                { private _m = _u distance2D _x; if (_m < _enM) then { _enM = _m; _en = _x; }; } forEach _dostlar;
                if (_enM <= _kopukM) then { continue };
                // hedef: en yakin dostun 5-8 m yani, dusmandan uzak taraf; yol dusmana yaklastirmasin
                private _yonD = _e getDir _en;   // dusmandan dosta
                private _aday = [];
                {
                    private _p = (getPosATL _en) getPos [5 + (random 3), _yonD + _x];
                    _p set [2, 0];
                    if (!surfaceIsWater _p && {(_p distance2D _e) >= ((_en distance2D _e) - 2)} && {!(terrainIntersectASL [(AGLToASL (_u modelToWorld [0, 0, 1.3])), (AGLToASL (_p vectorAdd [0, 0, 1.3]))])}) exitWith { _aday = _p; };
                } forEach [0, 40, -40, 80, -80];
                if (_aday isEqualTo []) then { continue };
                _butce = _butce - 1;
                _toplam = _toplam + 1;
                _u setVariable [QGVAR(kumeT), time + 10];
                _u setVariable [QGVAR(taktikKilit), time + 6];
                _u doMove _aday;
                if (_logN < 20) then {
                    _logN = _logN + 1;
                    diag_log format ["[CQB-KUME] %1 %2 | %3 dostundan %4 m kopuk (esik %5), dusman %6 m -> %7 (%8 m) yanina cekiliyor (6 sn) | xy %9", str (side _g), groupId _g, name _u, round _enM, _kopukM, round (_u distance2D _e), name _en, round (_u distance2D _aday), (getPosATL _u) select [0, 2] apply { round _x }];
                };
            } forEach (units _g);
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!isPlayer leader _x}});
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_toplam > 0) then { diag_log format ["[CQB-KUME-OZET] 60 sn: kopuk askerin toplanma hareketi %1", _toplam]; };
            _toplam = 0;
        };
    };
};
true
