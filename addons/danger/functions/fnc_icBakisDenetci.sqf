#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BINA ICI BAKIS DENETCISI (v8.617; kullanici: 'bakis yonu kusursuz olsun'; RPT eec0f873: bina ici namlu hala duvar arkasi dusmana / sese donuk, bakis tek tek watcher'lara dagilmisti):
 * TEK YETKILI bakis denetcisi, 0.5 sn'de bir (cqb izleyici hizi); kor iken motorun hedef secimi (AUTOTARGET / TARGET) kapatilir, gorus acilinca acilir (v8.619) bina ICINDEKI her yerel AI askere bakar:
 *   - Bilinen dusman (knowsAbout >= SEZILDI, <= 150 m) var VE gorus hatti (FIRE) kapali (fnc_icKorMu) ise namlu dusmana / sese degil, tehdit yonundeki ACIK yone (fnc_icBakisYonu: merdiven / kapi / pencere / koridor)
 *     verilir; acik yon yoksa 12 yonlu tarama ile en uzun acik yon (dusman yonunun +-40 derecesi haric); doWatch HER turda tazelenir (baska bir izleyici / motor namluyu kaydirsa da geri alinir).
 *   - Dusman GORUNUYORSA (hat acik) denetci karismaz: refleks / yakinAtes dusmana doner ve ates eder.
 *   - Temas yok ama grup bina temizliginde (isSweeping) ve asker yuruyorsa: yuruyus yonune (acik ise) bakar.
 *   - Yumusatma: ayni tehdit icin yon 25 dereceden az degisiyorsa ve 1.5 sn dolmadiysa ayni nokta korunur (titreme / durma yok).
 * Atlanir: oyuncu / oyuncu komutasi, arac icinde, yarali-bayginlik, teslim / esir, kose temkini aktif (QGVAR(koseAktif)), oda pususu (kapiya bakar), forceMove.
 * Olcum: [IC-BAKIS-OZET] 60 sn: bina ici asker, duvar arkasi dusman bilen, duzeltme oncesi namlu dusmana <= 30 derece, duzeltilen, acik yon / tarama / yuruyus sayilari. [IC-BAKIS] ilk 15 satir.
 * CBA: lambs_danger_icBakisKose (kapaliysa denetci pasif).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_icBakisDenetciStarted") exitWith {false};
lambs_danger_icBakisDenetciStarted = true;

diag_log "[IC-BAKIS] bina ici bakis denetcisi (duvar arkasi dusmana / sese namlu cevrilmez) baslatildi (v8.617)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["ic", 0], ["bilen", 0], ["yanlis", 0], ["duzelt", 0], ["acik", 0], ["tarama", 0], ["yuruyus", 0], ["gorunen", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep ([0.5, true, true] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_icBakisKose", true]) then {
            { _x enableAI "AUTOTARGET"; _x enableAI "TARGET"; _x setVariable [QGVAR(icHedefKapali), nil]; } forEach (allUnits select {local _x && {_x getVariable [QGVAR(icHedefKapali), false]}});
            continue
        };
        private _esik = ["SEZILDI"] call FUNC(bilgiEsik);
        {
            private _u = _x;
            if (
                !local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {(insideBuilding _u) <= 0.5}
                || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {captive _u} || {_u getVariable [QGVAR(teslim), false]}
                || {_u getVariable [QGVAR(forceMove), false]} || {!isNil {_u getVariable QGVAR(koseAktif)}}
                || {(_u getVariable [QGVAR(odaPusuPoz), []]) isNotEqualTo []}
                || {[_u] call FUNC(oyuncuKomutaMi)}
            ) then {
                if (local _u && {alive _u} && {_u getVariable [QGVAR(icHedefKapali), false]}) then { _u enableAI "AUTOTARGET"; _u enableAI "TARGET"; _u setVariable [QGVAR(icHedefKapali), nil]; };
                continue
            };
            private _g = group _u;
            _say set ["ic", (_say get "ic") + 1];
            private _e = _u findNearestEnemy _u;
            private _bilinen = !isNull _e && {alive _e} && {(_u distance _e) <= 150} && {(_u knowsAbout _e) >= _esik};
            private _hedefPoz = [];
            private _kaynak = "";
            if (_bilinen) then {
                _say set ["bilen", (_say get "bilen") + 1];
                if !([_u, _e] call FUNC(icKorMu)) then {
                    _say set ["gorunen", (_say get "gorunen") + 1];
                    if (_u getVariable [QGVAR(icHedefKapali), false]) then { _u enableAI "AUTOTARGET"; _u enableAI "TARGET"; _u setVariable [QGVAR(icHedefKapali), nil]; };   // gorus acildi: motor hedef secimi geri
                    continue
                };
                // v8.619 MOTOR HEDEF SECIMI KAPAT (kullanici: 'hala dogru yere bakamiyorlar'; RPT 39835e40: duvar arkasi dusman 4-9 m, bilgi 4.00 -> motor namluyu 0.5 sn icinde dusmana ceviriyor, [IC-BAKIS-OZET] 32 duvar arkasi askerin 11'i <= 30 derece): kor iken AUTOTARGET + TARGET kapali, gorus acilinca (yukari) acilir
                if !(_u getVariable [QGVAR(icHedefKapali), false]) then { _u disableAI "AUTOTARGET"; _u disableAI "TARGET"; _u setVariable [QGVAR(icHedefKapali), true]; };
                private _brg = _u getDir _e;
                private _wd = _u weaponDirection (currentWeapon _u);
                private _fark = abs ((((_wd select 0) atan2 (_wd select 1)) - _brg + 540) mod 360 - 180);
                if (_fark <= 30) then { _say set ["yanlis", (_say get "yanlis") + 1]; };
                // yumusatma: ayni tehdit, ayni yon -> mevcut nokta (1.5 sn)
                private _eski = _u getVariable [QGVAR(icBakisPoz), []];
                if (_eski isNotEqualTo [] && {(time - (_u getVariable [QGVAR(icBakisT), -999])) < 1.5} && {(abs (((_u getDir _eski) - _brg + 540) mod 360 - 180)) > 40}) then {
                    _hedefPoz = _eski; _kaynak = "korundu";
                } else {
                    _hedefPoz = [_u, _brg] call FUNC(icBakisYonu);
                    if (_hedefPoz isNotEqualTo []) then {
                        _kaynak = "acik yon";
                        _say set ["acik", (_say get "acik") + 1];
                    } else {
                        // 12 yonlu tarama: dusman yonunun +-40 derecesi disinda en uzun acik yon
                        private _eye = eyePos _u;
                        private _eniyi = -1; private _enB = -999;
                        for "_k" from 0 to 11 do {
                            private _b = _k * 30;
                            if ((abs ((_b - _brg + 540) mod 360 - 180)) <= 40) then { continue };
                            private _m = 0;
                            { if (!(lineIntersects [_eye, _eye vectorAdd [(sin _b) * _x, (cos _b) * _x, 0], _u, objNull])) exitWith { _m = _x; }; } forEach [12, 8, 5, 3];
                            if (_m > _eniyi) then { _eniyi = _m; _enB = _b; };
                        };
                        if (_enB > -900 && {_eniyi > 0}) then {
                            _hedefPoz = _eye getPos [20, _enB];
                            _kaynak = "tarama";
                            _say set ["tarama", (_say get "tarama") + 1];
                        };
                    };
                };
                if (_hedefPoz isNotEqualTo []) then {
                    if (_fark <= 30 && {_logN < 15}) then {
                        _logN = _logN + 1;
                        diag_log format ["[IC-BAKIS] %1 | %2 | dusman %3 m duvar arkasi (yon %4) | namlu dusmana %5 derece idi -> %6 (yon %7)", groupId _g, name _u, round (_u distance _e), round _brg, round _fark, _kaynak, round (_u getDir _hedefPoz)];
                    };
                    if (_fark <= 30) then { _say set ["duzelt", (_say get "duzelt") + 1]; };
                };
            } else {
                if (_u getVariable [QGVAR(icHedefKapali), false]) then { _u enableAI "AUTOTARGET"; _u enableAI "TARGET"; _u setVariable [QGVAR(icHedefKapali), nil]; };
                if ((_g getVariable [QGVAR(isSweeping), false]) && {(speed _u) > 1.5}) then {
                    private _v = velocity _u;
                    private _vb = (_v select 0) atan2 (_v select 1);
                    private _by = [_u, _vb, [0, 20, -20], [12, 6]] call FUNC(bakisAcikYon);
                    if (_by > -900) then {
                        _hedefPoz = (eyePos _u) getPos [20, _by];
                        _kaynak = "yuruyus";
                        _say set ["yuruyus", (_say get "yuruyus") + 1];
                    };
                };
            };
            if (_hedefPoz isNotEqualTo []) then {
                _u setVariable [QGVAR(icBakisPoz), _hedefPoz];
                if (_kaynak isNotEqualTo "korundu") then { _u setVariable [QGVAR(icBakisT), time]; };
                _u doWatch _hedefPoz;
            };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say get "ic") > 0) then {
                diag_log format ["[IC-BAKIS-OZET] 60 sn (tur basina toplam): bina ici asker %1 | dusman bilen %2 (gorunen %3) | duvar arkasi, namlu dusmana <= 30 derece %4 | duzeltilen %5 | acik yon %6 / tarama %7 / yuruyus %8", _say get "ic", _say get "bilen", _say get "gorunen", _say get "yanlis", _say get "duzelt", _say get "acik", _say get "tarama", _say get "yuruyus"];
            };
            { _say set [_x, 0]; } forEach ["ic", "bilen", "yanlis", "duzelt", "acik", "tarama", "yuruyus", "gorunen"];
        };
    };
};
true
