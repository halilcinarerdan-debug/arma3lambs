#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEKANIZE HAREKET: ARAC + PIYADE KOORDINELI INIS (v8.789; kullanici: 'arac hareket mekanize ve araçla koordineli hareket ekle, bmp btr truck ekle bunlara').
 * KAPSAM: fnc_aracSinif'a gore IFV (BMP / Bradley / BTR-80A: top + >= 3 kargo), APC (BTR / Stryker: topsuz zirhli) ve KAMYON (yumusak tasiyici) sinifindaki kara araclari; icinde >= 2 AI yolcu (cargo koltugu) tasiyan, oyuncusuz, yerel arac.
 * SADE dal notu: v8.503'te taksi / plan katmani KALDIRILDI (binme tasarimci waypoint'iyle); bu modul BINDIRME yapmaz, yalniz TASIYAN aracin SAVAS ANINDAKI davranisini koordine eder (iniş + ates destegi / geride rezerv).
 *
 * 1) INIS TETIGI (yolculuktayken): arac hareketsiz kaldi / hasar aldi (+%8) / surucu baskisi > 0.6 / temas (grup contact) + bilinen dusman iniş esiginde. Esik = doktrin 'mekInisM' (GENEL 300; ABD / USMC 350; RUS 200; CHN 220; PESHMERGA 250; DUZENSIZ 280)
 *    x sinif (IFV 0.85, APC 1, KAMYON 1.3 = kamyon daha uzakta indirir) x CBA mekanizeInisCarpan. Arac durur (forceSpeed 0, hiz < 6 km/s olana kadar bekler), yolcular iner (unassignVehicle + GetOut, 8 sn sonra kalan varsa moveOut).
 * 2) INIS SONRASI: IFV = ATES DESTEGI (mekanizeDestekS sn yerinde durur, kule yapay zekasi ates eder; sonra serbest -> fnc_aracSenkron eskort takibi); APC / KAMYON = GERIDE REZERV (dusmandan uzaga mekanizeRezervM m, savasmaz, 90 sn bekler), sonra serbest.
 *    Serbest birakma: forceSpeed -1, grubun waypoint'i varsa yeniden etkinlestirilir (yoksa lidere doFollow). 60 sn tekrar tetik yok.
 * MUAF: oyuncu yolcu / surucu, MEDEVAC / TOPCU / HARIC / TASIMA / KARAKOL_ARAC / RECON_ARAC gorevli arac, isaretli canli bomba (eypBomba), disableAI surucu, LAMBS gorevi / kal-bekle waypoint (senaryoKapi sabit). Tasarimci MOVE waypoint'i muaf DEGIL (savas aninda inis gerekir).
 * CBA: lambs_danger_mekanizeHareket (varsayilan ACIK), mekanizeInisCarpan, mekanizeDestekS, mekanizeRezervM. Loglar [MEKANIZE-INIS] BASLA / INDI / SERBEST + 90 sn [MEKANIZE-INIS-OZET].
 * SINIR: oyunda DENENMEDI; GetOut animasyonu / kapi acilisi moda baglidir (kimi modlarda 8 sn yetmeyebilir -> moveOut); inis esikleri TASARIM (kitapta sayi yok).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_mekanizeHareketStarted") exitWith {false};
lambs_danger_mekanizeHareketStarted = true;

diag_log "[MEKANIZE-INIS] mekanize hareket (inis / ates destegi / rezerv) baslatildi (v8.789)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_mekanizeHareketAdim", "basladi"];
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    private _haric = ["MEDEVAC", "TOPCU", "TOPCU_YOK", "HARIC", "TASIMA", "KARAKOL_ARAC", "RECON_ARAC"];
    private _birak = {
        params ["_v", "_d", "_neden"];
        if (alive _d) then {
            _d forceSpeed -1;
            _d setVariable [QGVAR(senkT), nil];
            private _gg = group _d;
            if ((count (waypoints _gg)) > 1) then { _gg setCurrentWaypoint [_gg, currentWaypoint _gg]; } else { if (!isNull (leader _gg) && {(leader _gg) isNotEqualTo _d}) then { [_d, leader _gg] call FUNC(doFollowGuvenli); }; };
        };
        _v setVariable [QGVAR(mekDurum), ""];
        _v setVariable [QGVAR(mekSoguT), time + 60];
        diag_log format ["[MEKANIZE-INIS] SERBEST | %1 | %2", typeOf _v, _neden];
    };
    while {true} do {
        sleep 2;
        if !(missionNamespace getVariable ["lambs_danger_mekanizeHareket", true]) then { continue };
        private _carpan = ((missionNamespace getVariable ["lambs_danger_mekanizeInisCarpan", 1]) max 0.5) min 2;
        private _destekS = ((missionNamespace getVariable ["lambs_danger_mekanizeDestekS", 30]) max 10) min 120;
        private _rezervM = ((missionNamespace getVariable ["lambs_danger_mekanizeRezervM", 120]) max 60) min 250;
        {
            private _v = _x;
            if (!local _v || {!alive _v} || {!(_v isKindOf "LandVehicle")} || {isNull driver _v}) then { continue };
            private _d = driver _v;
            if (isPlayer _d || {!alive _d} || {!local _d}) then { continue };
            private _g = group _d;
            if (((crew _v) findIf {isPlayer _x}) > -1) then { continue };
            if ((_v getVariable ["lambs_danger_gorev", ""]) in _haric || {(_g getVariable ["lambs_danger_gorev", ""]) in _haric} || {!isNil {_v getVariable QGVAR(eypBomba)}} || {_d getVariable [QGVAR(disableAI), false]}) then { continue };
            missionNamespace setVariable ["lambs_danger_mekanizeHareketAdim", format ["arac %1", typeOf _v]];
            private _durum = _v getVariable [QGVAR(mekDurum), ""];

            // ---- iniş sonrasi durumlar ----
            if (_durum isNotEqualTo "") then {
                private _bitis = _v getVariable [QGVAR(mekBitis), 0];
                if (_durum isEqualTo "INIS") then {
                    if ((time - (_v getVariable [QGVAR(mekT), 0])) > 25) then { [_v, _d, "inis zaman asimi"] call _birak; };
                } else {
                    if (_durum isEqualTo "DESTEK") then {
                        _d forceSpeed 0;
                        _d setVariable [QGVAR(senkT), time + 5];
                        if (time > _bitis || {!canMove _v} || {(damage _v) > 0.7}) then { [_v, _d, "ates destegi bitti / arac hasarli"] call _birak; };
                    } else {
                        // REZERV
                        private _rp = _v getVariable [QGVAR(mekRezervPoz), getPosATL _v];
                        _d setVariable [QGVAR(senkT), time + 5];
                        if ((_v distance2D _rp) < 20 || {(time - (_v getVariable [QGVAR(mekT), 0])) > 30}) then { _d forceSpeed 0; } else { _d forceSpeed -1; };
                        private _enR = _d findNearestEnemy _d;
                        if (time > _bitis || {!canMove _v} || {!isNull _enR && {alive _enR} && {(_v distance2D _enR) < 70}}) then { [_v, _d, "rezerv bitti / dusman yakin / arac hasarli"] call _birak; };
                    };
                };
                continue
            };

            // ---- yolculuk: iniş tetikleri ----
            if (time < (_v getVariable [QGVAR(mekSoguT), 0])) then { continue };
            private _cls = ([_v] call FUNC(aracSinif)) select 0;
            if !(_cls in ["IFV", "APC", "KAMYON"]) then { continue };
            private _cargo = ((fullCrew [_v, "cargo", false]) apply {_x select 0}) select {alive _x && {!isPlayer _x} && {local _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable [QGVAR(teslim), false])}};
            if ((count _cargo) < 2) then { continue };
            // v8.790: senaryo kapisi (TUTAN = kal-bekle waypoint dahil) kaldirildi (savasta inis tasarimci waypoint'inden bagimsiz); yalniz LAMBS gorevi ya da inis / binis waypoint'i (GETOUT / UNLOAD / GETIN) ELITE'i geri ceker
            if (([_g] call FUNC(wpSahip)) isEqualTo "LAMBS" || {(waypointType [_g, currentWaypoint _g]) in ["GETOUT", "TR UNLOAD", "UNLOAD", "GETIN"]}) then { continue };
            private _baz = [_g, "mekInisM", 300] call FUNC(dk);
            private _esik = ((_baz * ([0.85, 1, 1.3] select (["IFV", "APC", "KAMYON"] find _cls)) * _carpan) max 100) min 800;
            private _en = _d findNearestEnemy _d;
            private _gruplar = [_g];
            { _gruplar pushBackUnique (group _x); } forEach _cargo;
            private _temas = (_gruplar findIf {(_x getVariable [QGVAR(contact), 0]) > time}) >= 0;
            private _hasarOnce = _v getVariable [QGVAR(mekHasar), damage _v];
            _v setVariable [QGVAR(mekHasar), damage _v];
            private _neden = "";
            if (!canMove _v) then { _neden = "arac hareketsiz"; } else {
                if ((damage _v) > (_hasarOnce + 0.08)) then { _neden = "hasar aldi"; } else {
                    if (([_d] call FUNC(baskiSeviye)) >= 4) then { _neden = "surucu baskida"; } else {
                        if (_temas && {!isNull _en} && {alive _en} && {(_v distance2D _en) <= _esik}) then { _neden = format ["temas + dusman %1 m (esik %2 m)", round (_v distance2D _en), round _esik]; };
                    };
                };
            };
            if (_neden isEqualTo "") then { continue };

            _v setVariable [QGVAR(mekDurum), "INIS"];
            _v setVariable [QGVAR(mekT), time];
            _d forceSpeed 0;
            _d setVariable [QGVAR(senkT), time + 15];
            _say set ["inis", (_say getOrDefault ["inis", 0]) + 1];
            _say set [_cls, (_say getOrDefault [_cls, 0]) + 1];
            if (_logN < 40) then { _logN = _logN + 1; diag_log format ["[MEKANIZE-INIS] BASLA | %1 (%2) | %3 | yolcu %4 | doktrin %5 | neden: %6", typeOf _v, _cls, groupId _g, count _cargo, [_g, "ad", "GENEL"] call FUNC(dk), _neden]; };
            [_v, _d, _cargo, _cls, [[], getPosATL _en] select (!isNull _en), _destekS, _rezervM] spawn {
                params ["_v", "_d", "_cargo", "_cls", "_enPos", "_destekS", "_rezervM"];
                private _t0 = time;
                waitUntil { sleep 0.3; (speed _v) < 6 || {time > (_t0 + 6)} || {!alive _v} };
                { if (alive _x) then { unassignVehicle _x; _x action ["GetOut", _v]; }; sleep (0.1 + random 0.2); } forEach _cargo;
                private _t1 = time;
                waitUntil { sleep 0.5; (({alive _x && {!isNull objectParent _x}} count _cargo) isEqualTo 0) || {time > (_t1 + 8)} };
                { if (alive _x && {!isNull objectParent _x}) then { _x moveOut _v; }; } forEach _cargo;
                sleep 0.5;
                if (!alive _v || {!alive _d}) exitWith { _v setVariable [QGVAR(mekDurum), ""]; };
                private _indi = {alive _x && {isNull objectParent _x}} count _cargo;
                if (_cls isEqualTo "IFV") then {
                    _v setVariable [QGVAR(mekDurum), "DESTEK"];
                    _v setVariable [QGVAR(mekBitis), time + _destekS];
                } else {
                    private _yon = if (_enPos isEqualTo []) then { (getDir _v) + 180 } else { _enPos getDir (getPosATL _v) };
                    private _rp = (getPosATL _v) getPos [_rezervM, _yon];
                    _v setVariable [QGVAR(mekRezervPoz), _rp];
                    _v setVariable [QGVAR(mekDurum), "REZERV"];
                    _v setVariable [QGVAR(mekBitis), time + 90];
                    _v setVariable [QGVAR(mekT), time];
                    _d forceSpeed -1;
                    _d doMove _rp;
                };
                diag_log format ["[MEKANIZE-INIS] INDI | %1 (%2) | %3 / %4 yolcu indi | sonraki durum: %5", typeOf _v, _cls, _indi, count _cargo, _v getVariable [QGVAR(mekDurum), ""]];
            };
        } forEach (vehicles select {local _x && {_x isKindOf "LandVehicle"}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[MEKANIZE-INIS-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_mekanizeHareketAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] mekanizeHareket betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_mekanizeHareketAdim", "?"]];
        sleep 5;
    };
};

true
