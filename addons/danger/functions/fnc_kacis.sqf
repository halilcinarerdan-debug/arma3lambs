#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KACIS KATMANI (v8.544; kullanici: 'fleeing katmani ekle: tek kaldiklarinda, mermileri azaldiginda topuga vursunlar; saklanma var ama surekli rekabet dorukta oldugu icin retreat pek islemedi; cooldown ekle; amac tek dusmani
 * oldurmek degil, zaiyat fazlaysa daha da geri cekil, dusmanin sayisi azaldi diye riske atmak olgun degil').
 * NEDEN (RPT 14:35, v8.543): zaiyat agir gruplar (12 -> 3-4 etkin) WITHDRAW / PEEL / DELAY arasinda gidip gelip dusmana 47-100 m'de dakikalarca kaldi. fnc_commanderAssess 'kucuk ekip (<= 3) / dusman < 60 m: kosarak kacilmaz -> DELAY' kuralini
 * uyguluyor; tacticsRetreat 'ilerleme yok (2 sicrama 0 varis)' ile erken bitiyor ve ardindan dusmana yakin DELAY'e donuluyor.
 *
 * BU WATCHER (2 sn): BIREYSEL KACIS (CBA kacisBireysel): grubu temasta (son 25 sn), bilinen dusman 20-250 m'de, yaya, yerel AI asker; asagidakilerden biri saglaniyorsa 'topuga vurur':
 *   (a) TEK KALAN: grupta <= 1 etkin dost (grup etkini <= 2) VEYA (40 m icinde (CBA kacisTekM) saglikli / yarali dost yok VE grupta <= 3 etkin dost) — dagilmis ama kalabalik grup tek kalan sayilmaz;
 *   (b) MERMI KRITIK: birincil silahin yedek sarjoru yok ve sarjordaki mermi <= max(5, kapasite x %30).
 *   Aksiyon: dusman yonunun TERSINE 70-120 m'de, dusman gozunden arazi ile gizli + ortulu en iyi noktaya (8 aday) kosar (hedef secimi / otomatik ates kapali, FULL hiz, ayakta); varinca yatar, siperde 45 sn bekler (fnc_siperTut).
 *   Askerin kacis tekrari 90 sn bekler. Tibbi islem yapan, bounding / zorla kosucusu, geri cekilen grup (isRetreating), araca bagli, dusman < 20 m (kacilmaz: dovus) birimlere dokunmaz.
 * GRUP KACIS KILIDI (fnc_commanderAssess'te): kayip >= CBA kacisKayip iken WITHDRAW / PEEL / DELAY karari 'kacis kilidi' kurar (CBA kacisKilitS, 150 sn): kilit boyunca dusman sayisi azalsa da hucum ailesi (BOUNDING / FLANK / ASSAULT /
 *   SUPPRESS_ASSAULT) YOK, DELAY -> WITHDRAW'a (daha da geri) cevrilir, ve 'kucuk ekip kosarak kacilmaz' kurali uygulanmaz (dusman >= 25 m).
 * SENARYO MODU: geri cekilme kapi disindadir; bu katman da waypoint'ten bagimsiz calisir. Oyuncular dokunulmaz. Kapatma: CBA kacisAktif / kacisBireysel.  Log: [KACIS] (ilk 40 + 60 sn ozeti).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_kacisStarted") exitWith {false};
lambs_danger_kacisStarted = true;
diag_log "[KACIS] kacis katmani baslatildi (v8.544): tek kalan / mermisi az asker dusmanin tersine kacar + zaiyat agirsa grup kacis kilidi";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["tek", 0], ["mermi", 0], ["yer_yok", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep 2;
        if !((missionNamespace getVariable ["lambs_danger_kacisAktif", true]) && {missionNamespace getVariable ["lambs_danger_kacisBireysel", true]}) then { continue };
        private _tekM = missionNamespace getVariable ["lambs_danger_kacisTekM", 40];
        private _adaylar = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side group _x) in [west, east, resistance]}
            && {!captive _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable ["ACE_isUnconscious", false])} && {!(_x getVariable [QGVAR(teslim), false])}
            && {time >= (_x getVariable [QGVAR(kacisT), 0])} && {(primaryWeapon _x) isNotEqualTo ""}
        };
        private _bu = 0;
        {
            if (_bu >= 4) exitWith {};
            private _u = _x;
            private _g = group _u;
            if (((_g getVariable [QGVAR(contact), 0]) < (time - 25)) || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}) then { continue };
            if ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true || {(_u getVariable [QGVAR(zorlaBitis), 0]) > time} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                || {(_u getVariable [QGVAR(siperTutBit), 0]) > time} || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}) then { continue };
            private _en = _u findNearestEnemy _u;
            if (isNull _en || {!alive _en} || {!(_en isKindOf "CAManBase")} || {captive _en} || {(lifeState _en) in ["INCAPACITATED", "UNCONSCIOUS"]}) then { continue };
            private _d = _u distance2D _en;
            if (_d < 20 || {_d > 250}) then { continue };
            if ((_u knowsAbout _en) < (["SEZILDI"] call FUNC(bilgiEsik))) then { continue };

            // (a) tek kalan
            private _dostlar = (units _g) select {alive _x && {_x isNotEqualTo _u} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable ["ACE_isUnconscious", false])}};
            private _yakinDost = _dostlar findIf {(_x distance2D _u) <= _tekM};
            // v8.545: 'tek kalan' = grupta <= 1 etkin dost VEYA (40 m'de dost yok VE grupta <= 3 etkin dost); ormanda dagilma (> 40 m) tek basina 'tek kalan' SAYILMAZ (RPT 15:06: dost 4 iken kacti)
            private _tek = ((count _dostlar) <= 1) || {(_yakinDost < 0) && {(count _dostlar) <= 3}};
            // (b) mermi kritik: yedek sarjor yok + sarjorda az
            private _w = primaryWeapon _u;
            private _yedek = (magazines _u) select {_x in (compatibleMagazines _w)};
            private _simdi = _u ammo _w;
            private _mag = (primaryWeaponMagazine _u) param [0, ""];
            private _kap = [getNumber (configFile >> "CfgMagazines" >> _mag >> "count"), 20] select ((getNumber (configFile >> "CfgMagazines" >> _mag >> "count")) <= 0);
            private _mermiAz = (_yedek isEqualTo []) && {_simdi <= ((5 max (_kap * 0.3)))};
            if (!_tek && {!_mermiAz}) then { continue };

            // kacis noktasi: dusmanin tersi +-35 derece, 70-120 m; gizli (arazi / nesne) + ortu + su yok
            private _enGozASL = eyePos _en;
            private _yonTers = (_en getDir _u);
            private _en2 = [];
            private _en2P = -999;
            {
                _x params ["_ac", "_mes"];
                private _p = _u getPos [_mes, _yonTers + _ac];
                _p set [2, 0];
                if (!surfaceIsWater _p) then {
                    private _pASL = AGLToASL [_p select 0, _p select 1, 0];
                    private _puan = 0;
                    if (terrainIntersectASL [_enGozASL, _pASL vectorAdd [0, 0, 1.0]] || {lineIntersects [_enGozASL, _pASL vectorAdd [0, 0, 1.0], _en, _u]}) then { _puan = _puan + 12; };
                    if ((nearestTerrainObjects [_p, ["TREE", "BUSH", "SMALL TREE", "ROCK", "WALL", "HIDE"], 4, false, true]) isNotEqualTo []) then { _puan = _puan + 4; };
                    _puan = _puan + ((_p distance2D _en) * 0.05);
                    _puan = _puan + (3 * ([side _g, _p, getPosATL _en] call (missionNamespace getVariable ["lambs_danger_fnc_mevziPuan", {0}])) / 5);
                    if (_puan > _en2P) then { _en2P = _puan; _en2 = _p; };
                };
            } forEach [[0, 90], [30, 80], [-30, 80], [0, 110], [35, 100], [-35, 100], [15, 120], [-15, 120]];
            if (_en2 isEqualTo [] || {_en2P < 10}) then { _say set ["yer_yok", (_say get "yer_yok") + 1]; _u setVariable [QGVAR(kacisT), time + 20]; continue };

            _bu = _bu + 1;
            _u setVariable [QGVAR(kacisT), time + 90];
            _say set [["mermi", "tek"] select _tek, (_say get (["mermi", "tek"] select _tek)) + 1];
            _u setVariable [QGVAR(forceMove), true];
            _u setVariable [QGVAR(taktikKilit), time + 30];
            _u disableAI "AUTOTARGET";
            _u disableAI "TARGET";
            _u setBehaviour "AWARE";
            _u setSpeedMode "FULL";
            _u forceSpeed -1;
            _u setUnitPosWeak "UP";
            _u doMove _en2;
            if (_logN < 40) then {
                _logN = _logN + 1;
                diag_log format ["[KACIS] %1 %2 | %3 | neden:%4 (dost %5, mermi %6/%7 yedek %8) | dusman %9 m | xy %10 -> %11 | puan %12", str (side _g), groupId _g, name _u, ["MERMI KRITIK", "TEK KALAN"] select _tek, count _dostlar, _simdi, _kap, count _yedek, round _d,
                    (getPosATL _u) select [0, 2] apply { round _x }, _en2 select [0, 2] apply { round _x }, round _en2P];
            };
            [{
                params ["_uu", "_pp"];
                !alive _uu || {(_uu distance2D _pp) < 4}
            }, {
                params ["_uu", "_pp"];
                if (alive _uu) then {
                    _uu enableAI "AUTOTARGET";
                    _uu enableAI "TARGET";
                    _uu setVariable [QGVAR(forceMove), nil];
                    _uu setVariable [QGVAR(taktikKilit), 0];
                    _uu setUnitPosWeak "DOWN";
                    [_uu] call FUNC(siperTut);
                };
            }, [_u, _en2], 28, {
                params ["_uu", "_pp"];
                if (alive _uu) then {
                    _uu enableAI "AUTOTARGET";
                    _uu enableAI "TARGET";
                    _uu setVariable [QGVAR(forceMove), nil];
                    _uu setVariable [QGVAR(taktikKilit), 0];
                    _uu setUnitPosWeak "DOWN";
                };
            }] call CBA_fnc_waitUntilAndExecute;
        } forEach _adaylar;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "tek") + (_say get "mermi") + (_say get "yer_yok")) > 0) then {
                diag_log format ["[KACIS-OZET] 60 sn: tek kalan kacisi %1 | mermi kritik kacisi %2 | uygun nokta yok %3", _say get "tek", _say get "mermi", _say get "yer_yok"];
            };
            { _say set [_x, 0]; } forEach ["tek", "mermi", "yer_yok"];
        };
    };
};
true
