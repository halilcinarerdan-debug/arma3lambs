#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YERE ATES = 'HOSTILE ACT' DOKTRINI: OLU / BAYGIN DUSMANA MAGDUMP (v8.789; kullanici: 'olu askerlere baygin askerlere magdump atsinlar yerde, hostile act doktrinleri olarak pesmerge duzensiz tipi onu da ekle').
 * Doktrin anahtari 'yereAtes' (olasilik 0-1) ve 'yereAtesMermi': GENEL / USMC / ABD / CHN 0; RUS 0.15; PESHMERGA 0.35; DUZENSIZ 0.7 (TASARIM; gercek uygulama degil, oyun davranisi). CBA yereAtes: 0 doktrine gore, 1 her doktrin (olasilik 1), 2 kapali.
 * KURAL: yerel, oyuncusuz AI grubu; lider 100 m icinde CANLI bilinen dusman YOKSA (once savas): grubun 'yereAtesM' (40 m) icindeki TAZE (olum <= 120 sn, EntityKilled kaydi) OLU ya da BAYGIN (INCAPACITATED / UNCONSCIOUS / ACE_isUnconscious)
 *   dusman askeri icin (CBA yereAtesOyuncu kapaliysa oyuncu haric; teslim olan / kelepceli / ACE teslim OLANA ATES YOK, sivil yok) olasilik BIR KEZ (govde + taraf basina) cekilir; evet cikarsa gorus hatti acik (VIEW), 3 m icinde dost yok,
 *   >= 5 mermisi olan, baskisiz, geri cekilmeyen en fazla 2 asker govdeye doSuppressiveFire ile yereAtesMermi (30) mermi bosaltir (25 sn bekleme). Baygin oyuncu revive nedeniyle captive olsa bile (teslim degil) hedef sayilir.
 * CBA: yereAtes (0 doktrine gore / 1 hep / 2 kapali), yereAtesOlu (olu govdeler), yereAtesBaygin (baygin / yarali yerde), yereAtesOyuncu, yereAtesM, yereAtesMermi. Teshis sayaclari [YERE-ATES-OZET]: govde_aday / sans_hayir / dost_yakin / atici_yok / secildi / tehdit_var.
 * Log: [YERE-ATES] (ilk 40: asker, grup, doktrin, hedef turu / mesafe, mermi, olasilik) + 90 sn [YERE-ATES-OZET].
 * SINIR: oyunda DENENMEDI; doSuppressiveFire konuma atesi AI'nin nisan alma / durma tepkisine bagli (bazen kisa burst); olu govdenin side'i config'ten okunur (ceket / mod degisimi etkilemez); yerde yatan (prone, canli) askere atilmaz.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yereAtesStarted") exitWith {false};
lambs_danger_yereAtesStarted = true;

diag_log "[YERE-ATES] hostile act: olu / baygin dusmana yere ates (doktrin 'yereAtes') baslatildi (v8.789)";

addMissionEventHandler ["EntityKilled", { params ["_k"]; if (_k isKindOf "CAManBase") then { _k setVariable [QGVAR(olumT), time]; }; }];

private _calis = {
    missionNamespace setVariable ["lambs_danger_yereAtesAdim", "basladi"];
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    private _kurbanMi = {
        params ["_b", "_gSide", "_oyuncuDahil", "_oluAcik", "_bayginAcik"];
        private _olu = !alive _b;
        private _inc = !_olu && {((lifeState _b) in ["INCAPACITATED", "UNCONSCIOUS"]) || {_b getVariable ["ACE_isUnconscious", false]}};
        if (!_olu && {!_inc}) exitWith {false};
        if ((_olu && {!_oluAcik}) || {_inc && {!_bayginAcik}}) exitWith {false};
        if (_olu && {(time - (_b getVariable [QGVAR(olumT), -9999])) > 120}) exitWith {false};
        if (!_oyuncuDahil && {isPlayer _b}) exitWith {false};
        if ((_b getVariable [QGVAR(teslim), false]) isEqualTo true || {(_b getVariable ["ace_captives_isHandcuffed", false]) isEqualTo true} || {(_b getVariable ["ace_captives_isSurrendering", false]) isEqualTo true}) exitWith {false};
        private _bs = if (_olu || {captive _b}) then { [east, west, independent, civilian] select (((getNumber (configOf _b >> "side")) max 0) min 3) } else { side group _b };
        (_bs isNotEqualTo civilian) && {(_gSide getFriend _bs) < 0.6}
    };
    while {true} do {
        sleep 2.5;
        private _mod = missionNamespace getVariable ["lambs_danger_yereAtes", 0];
        if (_mod isEqualTo 2) then { continue };
        private _menzil = ((missionNamespace getVariable ["lambs_danger_yereAtesM", 40]) max 10) min 100;
        private _mermiCba = ((missionNamespace getVariable ["lambs_danger_yereAtesMermi", 30]) max 5) min 60;
        private _oyuncuDahil = missionNamespace getVariable ["lambs_danger_yereAtesOyuncu", true];
        private _oluAcik = missionNamespace getVariable ["lambs_danger_yereAtesOlu", true];
        private _bayginAcik = missionNamespace getVariable ["lambs_danger_yereAtesBaygin", true];
        {
            private _g = _x;
            private _l = leader _g;
            if (!local _g || {isNull _l} || {!alive _l} || {(side _g) in [civilian, sideLogic]} || {((units _g) findIf {isPlayer _x}) > -1}) then { continue };
            // v8.790 (RPT f2a62ebb: [SENARYO-MODU-OZET] yereAtes/TUTAN=32 -> kal-bekle waypoint'li (TUTAN) gruplar kapiya takildi, baygin oyuncunun etrafindaki 8 asker hic ates etmedi): yere ates yalniz kisa bir ates eylemi, rota degistirmez -> senaryo kapisi YOK
            private _ol = if (_mod isEqualTo 1) then {1} else {[_g, "yereAtes", 0] call FUNC(dk)};
            if (_ol <= 0) then { continue };
            if ((_g getVariable [QGVAR(isRetreating), false]) isEqualTo true || {(_g getVariable [QGVAR(isBreakingContact), false]) isEqualTo true} || {(_g getVariable [QGVAR(isEvading), false]) isEqualTo true}) then { continue };
            // once savas: yakinda canli bilinen dusman varsa yere atilmaz
            private _e = _l findNearestEnemy _l;
            if (!isNull _e && {alive _e} && {(_l distance2D _e) < 100}) then { _say set ["tehdit_var", (_say getOrDefault ["tehdit_var", 0]) + 1]; continue };
            private _gSide = side _g;
            private _govdeler = (nearestObjects [getPosATL _l, ["CAManBase"], _menzil + 60]) select {[_x, _gSide, _oyuncuDahil, _oluAcik, _bayginAcik] call _kurbanMi};
            if (_govdeler isEqualTo []) then { continue };
            _say set ["govde_aday", (_say getOrDefault ["govde_aday", 0]) + (count _govdeler)];
            {
                private _b = _x;
                if ((_b getVariable [QGVAR(yereAtesN), 0]) >= 2) then { continue };
                private _kk = format ["lambs_danger_yereK_%1", str _gSide];
                if (isNil {_b getVariable _kk}) then { _b setVariable [_kk, (random 1) < _ol]; };
                if !(_b getVariable [_kk, false]) then { _say set ["sans_hayir", (_say getOrDefault ["sans_hayir", 0]) + 1]; continue };
                private _bp = (getPosASL _b) vectorAdd [0, 0, 0.3];
                private _dostYakin = ((_b nearEntities ["CAManBase", 3]) findIf {alive _x && {(_gSide getFriend (side group _x)) >= 0.6}}) >= 0;
                if (_dostYakin) then { _say set ["dost_yakin", (_say getOrDefault ["dost_yakin", 0]) + 1]; continue };
                private _atici = (units _g) select {
                    alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable [QGVAR(disableAI), false])} && {!(_x getVariable [QGVAR(teslim), false])}
                    && {time > (_x getVariable [QGVAR(yereAtesT), 0])} && {(getSuppression _x) < 0.5} && {(primaryWeapon _x) isNotEqualTo ""} && {(_x ammo (primaryWeapon _x)) >= 5}
                    && {(_x distance2D _b) <= _menzil} && {(lineIntersectsSurfaces [eyePos _x, _bp, _x, _b, true, 1, "VIEW", "NONE"]) isEqualTo []}
                };
                if (_atici isEqualTo []) then { _say set ["atici_yok", (_say getOrDefault ["atici_yok", 0]) + 1]; continue };
                _atici = [_atici, [], {_x distance2D _b}, "ASCEND"] call BIS_fnc_sortBy;
                private _secilen = _atici select [0, 2 - (_b getVariable [QGVAR(yereAtesN), 0])];
                private _mermi = if (_mod isEqualTo 1) then {_mermiCba} else {(([_g, "yereAtesMermi", _mermiCba] call FUNC(dk)) max 5) min 60};
                {
                    private _u = _x;
                    _b setVariable [QGVAR(yereAtesN), (_b getVariable [QGVAR(yereAtesN), 0]) + 1];
                    _u setVariable [QGVAR(yereAtesT), time + 25];
                    _say set ["secildi", (_say getOrDefault ["secildi", 0]) + 1];
                    if (_logN < 40) then { _logN = _logN + 1; diag_log format ["[YERE-ATES] %1 (%2) | doktrin %3 | hedef %4 %5 m | mermi %6 | olasilik %7", name _u, groupId _g, [_g, "ad", "GENEL"] call FUNC(dk), ["OLU", "BAYGIN"] select (alive _b), round (_u distance2D _b), _mermi, _ol]; };
                    [_u, _b, _mermi] spawn {
                        params ["_u", "_b", "_n"];
                        private _w = primaryWeapon _u;
                        private _hedefA = ((_u ammo _w) - _n) max 0;
                        private _t0 = time;
                        _u setVariable [QGVAR(taktikKilit), time + 10];
                        _u selectWeapon _w;
                        while {alive _u && {time < (_t0 + 9)} && {(_u ammo _w) > _hedefA} && {(lifeState _u) in ["HEALTHY", "INJURED"]}} do {
                            _u doSuppressiveFire (ASLToAGL ((getPosASL _b) vectorAdd [0, 0, 0.15]));
                            sleep 1.2;
                        };
                        if (alive _u) then { _u doWatch objNull; [_u] call FUNC(doFollowGuvenli); };
                    };
                } forEach _secilen;
            } forEach _govdeler;
        } forEach (allGroups select {local _x && {!isNull leader _x}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[YERE-ATES-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_yereAtesAdim", "tur bitti"];
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] yereAtes betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_yereAtesAdim", "?"]];
        sleep 5;
    };
};

true
