#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RPG KARAR KATMANI (v8.746; kullanici: 'lambs rpg arastir' + 'rpg sistemi yapalim'; v8.706'da ELITE script roketi KALDIRILMISTI: motor piyadeye roketatari secmiyordu, script atisi guvenilmezdi -> LAMBS RPG (config) kullaniliyor):
 * BU KATMAN roketi SCRIPT ILE FIRLATMAZ; yalniz uygun hedefi SECER ve motora emri verir (CBA_fnc_selectWeapon + doTarget + doFire); atisi motor / LAMBS RPG yapar. Atis guvenligi fnc_rpgKapisi'nda (Fired) ayrica denetlenir.
 * HEDEF TURLERI (zirh YOK: AT taarruzu fnc_tacticsATEngage; hava: fnc_havaAA):
 *   MG_YUVASI : bilinen dusman SABIT SILAH (StaticWeapon, mürettebatli)
 *   BINA      : bilinen dusman BINA ICINDE (insideBuilding > 0.5) ve atici hattinin ilk vurusu hedefe <= 30 m bir yapi (duvara roket: ic bolgeyi temizler)
 *   KUME      : acikta bilinen >= 3 dusman piyade 8 m cap icinde (gorunurluk >= 0.3, hat acik)
 * KOSULLAR: yerel AI, grup 25 sn icinde temasli, yuklu GUDUMSUZ roketatar (weaponLockSystem / maxControlRange = 0), bina disinda, kosucu / tedavi / geri cekilme degil, atis 6 sn'den eski, hedef rpgMinM + 10 .. rpgMaxM (250 m),
 *   bilgi >= SUPHE ve grup son 20 sn icinde gormus, fnc_rpgGuvenli (min / dost / geri duvar / arkada dost / zirh yedegi) temiz. Birim basina rpgBekleS (20 sn) bekleme, grup basina 8 sn, tur basina en cok 2 emir.
 * OLCUM: [RPG-KARAR] (ilk 60: tur, mesafe, hedef) + [RPG-KARAR-SONUC] (7 sn sonra: mermi a -> b, atildi mi) + [RPG-OZET] (rpgKapisi ile ortak). Karne: RPG SISTEMI.
 * CBA: lambs_danger_rpgSistem, rpgKarar (varsayilan ACIK; kapali = yalniz kapi / olcum), rpgMinM, rpgMaxM, rpgDostM, rpgYedek, rpgBekleS.
 * SINIR: oyunda DENENMEDI; motor roketatari secmezse [RPG-KARAR-SONUC] 'atilmadi' sayar (v8.705 bulgusu: motor aiAmmoUsageFlags'e bagli; LAMBS RPG bunu degistirir, kanitlanmadi).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_rpgSistemStarted") exitWith {false};
lambs_danger_rpgSistemStarted = true;

diag_log "[RPG-SISTEM] RPG karar katmani (MG yuvasi / bina ici dusman / piyade kumesi -> roketatar emri; atis motor / LAMBS RPG) + atis kapisi baslatildi (v8.746)";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 2;
        if !(missionNamespace getVariable ["lambs_danger_rpgSistem", true]) then { continue };
        if !(missionNamespace getVariable ["lambs_danger_rpgKarar", true]) then { continue };
        private _say = missionNamespace getVariable ["lambs_danger_rpgSay", createHashMap];
        missionNamespace setVariable ["lambs_danger_rpgSay", _say];
        private _minM = ((missionNamespace getVariable ["lambs_danger_rpgMinM", 25]) max 10) min 80;
        private _maxM = ((missionNamespace getVariable ["lambs_danger_rpgMaxM", 250]) max (_minM + 30)) min 600;
        private _bekle = ((missionNamespace getVariable ["lambs_danger_rpgBekleS", 20]) max 5) min 120;
        private _oyEsit = missionNamespace getVariable ["lambs_danger_oyuncuGrubuBot", false];
        private _esit = ["SUPHE"] call FUNC(bilgiEsik);
        private _verilen = 0;
        private _adaylar = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(secondaryWeapon _x) isNotEqualTo ""}
            && {((group _x) getVariable [QGVAR(contact), 0]) > (time - 25)} && {_x isKindOf "CAManBase"}
            && {(side group _x) in [west, east, resistance]} && {(!([_x] call FUNC(oyuncuKomutaMi))) || {_oyEsit}}
        };
        {
            if (_verilen >= 2) exitWith {};
            private _u = _x;
            private _g = group _u;
            private _ls = secondaryWeapon _u;
            if (
                time < (_u getVariable [QGVAR(rpgBekleT), 0]) || {(time - (_g getVariable [QGVAR(rpgGrupT), -999])) < 8}
                || {(_u ammo _ls) <= 0} || {(insideBuilding _u) >= 0.5} || {_u getVariable [QGVAR(forceMove), false]} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                || {(_g getVariable [QGVAR(isRetreating), false]) isEqualTo true} || {(_g getVariable [QGVAR(isBreakingContact), false]) isEqualTo true}
                || {(time - (_u getVariable [QGVAR(hvAAT), -999])) < 12} || {(time - (_u getVariable [QGVAR(sonAtisT), -999])) < 6}
                || {(getSuppression _u) >= 0.7} || {_u getVariable [QGVAR(disableAI), false]} || {captive _u} || {_u getVariable ["ACE_isUnconscious", false]}
            ) then { continue };
            private _mag = (secondaryWeaponMagazine _u) param [0, ""];
            private _ammo = if (_mag isEqualTo "") then {""} else { getText (configFile >> "CfgMagazines" >> _mag >> "ammo") };
            if (_ammo isEqualTo "" || {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "weaponLockSystem")) > 0} || {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "maxControlRange")) > 0}) then { continue };

            private _taraf = side _g;
            private _eye = eyePos _u;
            private _gor = (_u nearTargets _maxM) select {
                private _o = _x select 4;
                !isNull _o && {alive _o} && {(_taraf getFriend (side group _o)) < 0.6} && {(side group _o) isNotEqualTo civilian}
                && {(_u knowsAbout _o) >= _esit} && {((_u targetKnowledge _o) select 2) > (time - 20)}
            } apply {_x select 4};
            if (_gor isEqualTo []) then { continue };
            private _piyade = _gor select {_x isKindOf "CAManBase" && {!((lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"])} && {!(_x getVariable ["ACE_isUnconscious", false])} && {!([_x] call FUNC(teslimMi))}};
            private _en = objNull;
            private _enTur = "";
            private _enDeger = 0;
            {
                private _o = _x;
                private _d = _u distance _o;
                if (_d < (_minM + 10) || {_d > _maxM}) then { continue };
                private _tur = "";
                private _deger = 0;
                if (_o isKindOf "StaticWeapon") then {
                    if ((crew _o) isNotEqualTo []) then { _tur = "MG_YUVASI"; _deger = 3; };
                } else {
                    if (_o isKindOf "CAManBase") then {
                        if ((insideBuilding _o) > 0.5) then {
                            if (_d >= 40) then { _tur = "BINA"; _deger = 2; };
                        } else {
                            private _kn = {_x isNotEqualTo _o && {(_x distance2D _o) <= 8} && {(insideBuilding _x) < 0.2}} count _piyade;
                            if (_kn >= 2) then { _tur = "KUME"; _deger = 2 + (_kn / 10); };
                        };
                    };
                };
                if (_tur isEqualTo "") then { continue };
                if (_deger < _enDeger || {_deger isEqualTo _enDeger && {!isNull _en} && {_d >= (_u distance _en)}}) then { continue };
                private _aim = aimPos _o;
                // hat: MG / kume = acik hat; bina = ilk vurus hedefe yakin bir yapi
                private _hatOk = false;
                if (_tur isEqualTo "BINA") then {
                    private _vr = lineIntersectsSurfaces [_eye, _aim, _u, _o, true, 1, "FIRE", "NONE"];
                    _hatOk = _vr isNotEqualTo [] && {(((_vr select 0) select 0) distance _aim) <= 30} && {!(terrainIntersectASL [_eye, (_vr select 0) select 0])};
                } else {
                    _hatOk = !(terrainIntersectASL [_eye, _aim]) && {!(lineIntersects [_eye, _aim, _u, _o])} && {([_u, "VIEW", _o] checkVisibility [_eye, eyePos _o]) >= 0.3};
                };
                if (!_hatOk) then { continue };
                private _guv = [_u, _ls, _u getDir _o, _aim, false, false] call FUNC(rpgGuvenli);
                if (_guv isNotEqualTo "") then {
                    private _k = format ["karar_ret_%1", _guv];
                    _say set [_k, (_say getOrDefault [_k, 0]) + 1];
                    continue
                };
                _en = _o; _enTur = _tur; _enDeger = _deger;
            } forEach _gor;
            if (isNull _en) then { continue };

            _verilen = _verilen + 1;
            _u setVariable [QGVAR(rpgBekleT), time + _bekle];
            _u setVariable [QGVAR(rpgKararT), time];
            _g setVariable [QGVAR(rpgGrupT), time];
            _g reveal [_en, 2.5];
            if !(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false]) then { [_u, _ls] call CBA_fnc_selectWeapon; };
            _u doTarget _en;
            private _a0 = _u ammo _ls;
            [{ params ["_uu", "_tt"]; if (alive _uu && {alive _tt} && {isNull objectParent _uu}) then { _uu doFire _tt; }; }, [_u, _en], 1.5 + (random 1)] call CBA_fnc_waitAndExecute;
            private _k2 = format ["karar_%1", _enTur];
            _say set [_k2, (_say getOrDefault [_k2, 0]) + 1];
            if (_logN < 60) then {
                _logN = _logN + 1;
                diag_log format ["[RPG-KARAR] %1 | %2 | %3 -> %4 %5 m | %6 | mermi %7 (%8) | aiAmmoUsageFlags %9", groupId _g, name _u, _enTur, typeOf _en, round (_u distance _en), _ls, _mag, _a0, getNumber (configFile >> "CfgAmmo" >> _ammo >> "aiAmmoUsageFlags")];
            };
            // sonuc (7 sn sonra): atildi mi
            [{
                params ["_uu", "_ll", "_aa0", "_tr"];
                if (!alive _uu) exitWith {};
                private _s = missionNamespace getVariable ["lambs_danger_rpgSay", createHashMap];
                private _atildi = ((_uu ammo _ll) < _aa0) || {(time - (_uu getVariable [QGVAR(sonAtisT), -999])) < 9};
                private _kk = ["sonuc_atilmadi", "sonuc_atildi"] select _atildi;
                _s set [_kk, (_s getOrDefault [_kk, 0]) + 1];
                private _n = missionNamespace getVariable ["lambs_danger_rpgSonucLogN", 0];
                if (_n < 40) then {
                    missionNamespace setVariable ["lambs_danger_rpgSonucLogN", _n + 1];
                    diag_log format ["[RPG-KARAR-SONUC] %1 | %2 | atildi: %3 | mermi %4 -> %5 | elde: %6 | komut: %7", groupId group _uu, name _uu, _atildi, _aa0, _uu ammo _ll, currentWeapon _uu, currentCommand _uu];
                };
            }, [_u, _ls, _a0, _enTur], 7] call CBA_fnc_waitAndExecute;
        } forEach _adaylar;
    };
};
true
