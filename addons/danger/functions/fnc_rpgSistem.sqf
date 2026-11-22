#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RPG KARAR KATMANI (v8.746; kullanici: 'lambs rpg arastir' + 'rpg sistemi yapalim'; v8.706'da ELITE script roketi KALDIRILMISTI: motor piyadeye roketatari secmiyordu, script atisi guvenilmezdi -> LAMBS RPG (config) kullaniliyor):
 * BU KATMAN roketi SCRIPT ILE FIRLATMAZ; yalniz uygun hedefi SECER ve motora emri verir (CBA_fnc_selectWeapon + doTarget + doFire); atisi motor / LAMBS RPG yapar. Atis guvenligi fnc_rpgKapisi'nda (Fired) ayrica denetlenir.
 * HEDEF TURLERI (zirh YOK: AT taarruzu fnc_tacticsATEngage; hava: fnc_havaAA):
 *   MG_YUVASI : bilinen dusman SABIT SILAH (StaticWeapon, mürettebatli)
 *   BINA      : bilinen dusman BINA ICINDE (insideBuilding > 0.5) ve atici hattinin ilk vurusu hedefe <= 30 m bir yapi (duvara roket: ic bolgeyi temizler)
 *   KUME      : acikta bilinen >= 3 dusman piyade 8 m cap icinde (gorunurluk >= 0.3, hat acik)
 * MUHIMMAT (v8.748): fnc_rpgMuhimmat roketatarliya piyadeye uygun (AP) roket tasitir (envanterde yer yoksa 1 AT sarjoru AP ile degisir); piyade / bina / kume emrinden once yuklu AT mermisi AP ile degistirilir (CBA rpgMuhimmatDegis);
 *   insan oyuncu hedefi (ozellikle binada pusuya yatan) once secilir (CBA rpgOyuncuOncelik).
 * REZERV (v8.747, kullanici: 'hepsini piyadeye harcamasinlar yedekte tutsunlar'): BINA / KUME emri yalniz kalan roket > rpgYedek (2) ise (fnc_rpgGuvenli 'yedek'); MG yuvasi muaf.
 * KOSULLAR: yerel AI, grup 25 sn icinde temasli, yuklu GUDUMSUZ roketatar (weaponLockSystem / maxControlRange = 0), bina disinda, kosucu / tedavi / geri cekilme degil, atis 6 sn'den eski, hedef rpgMinM + 10 .. rpgMaxM (250 m),
 *   bilgi >= SUPHE ve grup son 20 sn icinde gormus, fnc_rpgGuvenli (min / dost / geri duvar / arkada dost / zirh yedegi) temiz. Birim basina rpgBekleS (20 sn) bekleme, grup basina 8 sn, tur basina en cok 2 emir.
 * v8.752: TEK hedef (acikta gorunen tek piyade >= 60 m; CBA rpgTekHedef), KUME esigi 3 -> 2 kisi, [RPG-KARAR-OZET] (aday / filtre / hedef_bilinmiyor / izin_yok / sinif_* / hat_ret_* / emir).
 * OLCUM: [RPG-KARAR] (ilk 60: tur, mesafe, hedef) + [RPG-KARAR-SONUC] (7 sn sonra: mermi a -> b, atildi mi) + [RPG-OZET] (rpgKapisi ile ortak). Karne: RPG SISTEMI.
 * CBA: lambs_danger_rpgSistem, rpgKarar (varsayilan ACIK; kapali = yalniz kapi / olcum), rpgMinM, rpgMaxM, rpgDostM, rpgYedek, rpgBekleS.
 * LAMBS RPG BILGISI (v8.747; KULLANICI EKRAN GORUNTUSU, 3. taraf ozet, dogrulanmadi): mod CONFIG duzeyinde mermi tanimini degistirir: allowAgainstInfantry = 1 (roket piyadeye karsi kullanilabilir; varsayilan 0 = yalniz arac), aiAmmoUsageFlags'e piyade eklenir,
 *   airLock = 1 (havaya kilitlenir); RPG-7 (vanilla + RHS), RPG-32, MAAWS, SPG-9. v8.705'te motorun piyadeye roketatar secmemesinin nedeni buydu. Bu katman piyade hedefli (BINA / KUME) emri YALNIZ mermide allowAgainstInfantry > 0 ise verir
 *   (yamasiz mermiye emir motorda reddedilir); [RPG-TANI] boot'ta yamali roket siniflarini, [RPG-MERMI-TANI] her roketatar mermisinin degerlerini yazar.
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
    // v8.747 TANI: gudumsuz roket mermilerinden allowAgainstInfantry > 0 olanlar (LAMBS RPG yamasi ya da baska mod) - hangi roketatarlarin piyadeye atabilecegi
    private _tum = "(toLower (getText (_x >> 'simulation'))) isEqualTo 'shotrocket'" configClasses (configFile >> "CfgAmmo");
    private _yam = (_tum select {(getNumber (_x >> "allowAgainstInfantry")) > 0}) apply {configName _x};
    diag_log format ["[RPG-TANI] gudumsuz roket mermisi (shotRocket) %1 sinif, bunlardan allowAgainstInfantry > 0: %2 (LAMBS RPG yamasi ya da baska mod) | ilk 40: %3", count _tum, count _yam, _yam select [0, 40]];
    private _mermiTani = [];
    private _oz = createHashMap;   // v8.752 TESHIS: karar katmani neden emir vermiyor (60 sn ozet)
    private _ozT = time + 60;
    private _ar = { params ["_k"]; _oz set [_k, (_oz getOrDefault [_k, 0]) + 1]; };
    while {true} do {
        sleep (((missionNamespace getVariable ["lambs_danger_rpgTaramaS", 2]) max 0.3) min 5);   // v8.760: CBA rpgTaramaS (karar dongusu; eski sabit 2 sn)
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
        private _tekAcik = missionNamespace getVariable ["lambs_danger_rpgTekHedef", true];
        private _oyOnc = missionNamespace getVariable ["lambs_danger_rpgOyuncuOncelik", true];
        // v8.748 MUHIMMAT (kullanici: 'b yap'): roketatarli AI piyadeye uygun (AP) roket tasisin (envanterde yer yoksa 1 AT sarjoru AP ile yer degistirir); tick basina <= 6 birim, birim basina bir kez
        if (missionNamespace getVariable ["lambs_danger_rpgMuhimmat", true]) then {
            private _yk = 0;
            {
                if (_yk >= 6) exitWith {};
                _yk = _yk + 1;
                [_x, "yukle"] call FUNC(rpgMuhimmat);
            } forEach (allUnits select {
                local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {_x isKindOf "CAManBase"} && {(secondaryWeapon _x) isNotEqualTo ""} && {!(_x getVariable [QGVAR(rpgMuhOk), false])}
                && {(side group _x) in [west, east, resistance]} && {(!([_x] call FUNC(oyuncuKomutaMi))) || {_oyEsit}}
            });
        };
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
            ["aday"] call _ar;
            if (
                time < (_u getVariable [QGVAR(rpgBekleT), 0]) || {(time - (_g getVariable [QGVAR(rpgGrupT), -999])) < (((missionNamespace getVariable ["lambs_danger_rpgGrupBekleS", 8]) max 0) min 30)}
                || {(_u ammo _ls) <= 0} || {(insideBuilding _u) >= 0.5} || {_u getVariable [QGVAR(forceMove), false]} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                || {(_g getVariable [QGVAR(isRetreating), false]) isEqualTo true} || {(_g getVariable [QGVAR(isBreakingContact), false]) isEqualTo true}
                || {(time - (_u getVariable [QGVAR(hvAAT), -999])) < 12} || {(time - (_u getVariable [QGVAR(sonAtisT), -999])) < 6}
                || {(getSuppression _u) >= 0.7} || {_u getVariable [QGVAR(disableAI), false]} || {captive _u} || {_u getVariable ["ACE_isUnconscious", false]}
            ) then { ["filtre"] call _ar; continue };
            private _mag = (secondaryWeaponMagazine _u) param [0, ""];
            private _ammo = if (_mag isEqualTo "") then {""} else { getText (configFile >> "CfgMagazines" >> _mag >> "ammo") };
            if (_ammo isEqualTo "" || {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "weaponLockSystem")) > 0} || {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "maxControlRange")) > 0}) then { continue };
            private _ac = configFile >> "CfgAmmo" >> _ammo;
            private _bayrak = getNumber (_ac >> "aiAmmoUsageFlags");
            private _pizin = ((getNumber (_ac >> "allowAgainstInfantry")) > 0) || {((floor (_bayrak / 64)) mod 2) isEqualTo 1};   // v8.747: piyade izni = allowAgainstInfantry > 0 YA DA aiAmmoUsageFlags'te 64 (piyade) biti (BI forum: 64 = piyade, 128 = arac, 512 = zirh)
            private _apVar = false;
            if (!_pizin && {missionNamespace getVariable ["lambs_danger_rpgMuhimmat", true]}) then { _apVar = ([_u, "var"] call FUNC(rpgMuhimmat)) isNotEqualTo ""; };
            private _pEl = _pizin || {_apVar};   // v8.748: piyade emri uygun = yuklu mermi AP YA DA envanterde AP var (degistirme / LAMBS munisyon degisimi)
            if (!(_ammo in _mermiTani) && {(count _mermiTani) < 20}) then {
                _mermiTani pushBack _ammo;
                diag_log format ["[RPG-MERMI-TANI] %1 | sarjor %2 | mermi %3 | allowAgainstInfantry %4 | aiAmmoUsageFlags %5 | airLock %6 | hit %7 | indirectHit %8 (yaricap %9 m) | piyadeye emir: %10", _ls, _mag, _ammo, getNumber (_ac >> "allowAgainstInfantry"), _bayrak, getNumber (_ac >> "airLock"), getNumber (_ac >> "hit"), getNumber (_ac >> "indirectHit"), getNumber (_ac >> "indirectHitRange"), ["HAYIR (yamasiz: motor reddeder)", "evet"] select _pizin];
            };

            private _taraf = side _g;
            private _eye = eyePos _u;
            private _gor = (_u nearTargets _maxM) select {
                private _o = _x select 4;
                !isNull _o && {alive _o} && {(_taraf getFriend (side group _o)) < 0.6} && {(side group _o) isNotEqualTo civilian}
                && {(_u knowsAbout _o) >= _esit} && {((_u targetKnowledge _o) select 2) > (time - 20)}
            } apply {_x select 4};
            if (_gor isEqualTo []) then { ["hedef_bilinmiyor"] call _ar; continue };
            if (!_pEl && {(_gor findIf {_x isKindOf "StaticWeapon"}) < 0}) then { _say set ["karar_ret_izin_yok", (_say getOrDefault ["karar_ret_izin_yok", 0]) + 1]; ["izin_yok"] call _ar; continue };   // yamasiz mermi + sabit silah yok: piyade emri motorda reddedilir
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
                    if (_o isKindOf "CAManBase" && {_pEl}) then {
                        if ((insideBuilding _o) > 0.5) then {
                            if (_d >= 40 || {isPlayer _o}) then { _tur = "BINA"; _deger = 2; };
                        } else {
                            private _kn = {_x isNotEqualTo _o && {(_x distance2D _o) <= 8} && {(insideBuilding _x) < 0.2}} count _piyade;
                            if (_kn >= 1) then { _tur = "KUME"; _deger = 2 + (_kn / 10); } else {
                                // v8.752 TEK HEDEF (kullanici: 'roket kullanimi yok'): kume yoksa acikta gorunen tek piyade, >= 60 m (yalniz AP roket ya da yamali mermi; birim basina AP 1 adet = sinirli)
                                if (_tekAcik && {_d >= 60}) then { _tur = "TEK"; _deger = 1; };
                            };
                        };
                    };
                };
                if (_tur isEqualTo "") then { continue };
                ["sinif_" + _tur] call _ar;
                if (_oyOnc && {isPlayer _o}) then { _deger = _deger + 5; };   // v8.748 (kullanici: 'ilk oyunculara odaklansin, evde pusan oyunculara'): insan oyuncu hedefi once
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
                if (!_hatOk) then { ["hat_ret_" + _tur] call _ar; continue };
                private _guv = [_u, _ls, _u getDir _o, _aim, (_tur isEqualTo "MG_YUVASI") || _pEl, false] call FUNC(rpgGuvenli);   // AP (piyadeye uygun) roket rezervden muaf
                if (_guv isNotEqualTo "") then {
                    private _k = format ["karar_ret_%1", _guv];
                    _say set [_k, (_say getOrDefault [_k, 0]) + 1];
                    continue
                };
                _en = _o; _enTur = _tur; _enDeger = _deger;
            } forEach _gor;
            if (isNull _en) then { ["emir_yok"] call _ar; continue };
            ["emir"] call _ar;

            // v8.748 yuklu AT mermisi AP degilse ve piyade / bina / kume hedefi + AP tasiyorsa yuklu mermiyi AP ile degistir (CBA rpgMuhimmatDegis)
            if (!_pizin && {_apVar} && {_enTur in ["BINA", "KUME", "TEK"]} && {missionNamespace getVariable ["lambs_danger_rpgMuhimmatDegis", true]}) then {
                if ([_u, "degis"] call FUNC(rpgMuhimmat)) then {
                    _mag = (secondaryWeaponMagazine _u) param [0, ""];
                    _ammo = getText (configFile >> "CfgMagazines" >> _mag >> "ammo");
                };
            };
            _verilen = _verilen + 1;
            _u setVariable [QGVAR(rpgBekleT), time + _bekle];
            _u setVariable [QGVAR(rpgKararT), time];
            _u setVariable [QGVAR(rpgHedef), _en];   // v8.761: isabet duzeltmesi (fnc_rpgKapisi) icin hedef
            _g setVariable [QGVAR(rpgGrupT), time];
            _g reveal [_en, 2.5];
            if !(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false]) then { [_u, _ls] call CBA_fnc_selectWeapon; };
            _u doTarget _en;
            // v8.762 KOSMASIN, GORDUGU GIBI CAKSIN (kullanici): hareket eden roketatarli ates emrinde DURDURULUR (doStop); 5 sn sonra gruba doner (CBA rpgDurAt)
            if ((missionNamespace getVariable ["lambs_danger_rpgDurAt", true]) && {(speed _u) > 0.8} && {_u isNotEqualTo (leader _g)}) then {
                doStop _u;
                [{
                    params ["_uu"];
                    if (alive _uu && {(_uu getVariable [QGVAR(forceMove), false]) isNotEqualTo true} && {_uu isNotEqualTo (leader group _uu)}) then { [_uu, leader group _uu] call FUNC(doFollowGuvenli); };
                }, [_u], 5] call CBA_fnc_waitAndExecute;
            };
            private _a0 = _u ammo _ls;
            // v8.758 DIREK ATIS (kullanici: 'eleman direk atsin hic beklemesin, nisan aldigi gibi'): CBA rpgAtisGecikme (sn, 0 = hemen doFire; eski 1.5-2.5) + rpgZorlaAtis: 1.5 sn sonra hala atmadiysa fireAtTarget
            private _gec = ((missionNamespace getVariable ["lambs_danger_rpgAtisGecikme", 0]) max 0) min 3;
            private _atFn = { params ["_uu", "_tt"]; if (alive _uu && {alive _tt} && {isNull objectParent _uu}) then { _uu doFire _tt; }; };
            if (_gec <= 0) then { [_u, _en] call _atFn; } else { [_atFn, [_u, _en], _gec] call CBA_fnc_waitAndExecute; };
            if (missionNamespace getVariable ["lambs_danger_rpgZorlaAtis", true]) then {
                [{
                    params ["_uu", "_tt", "_ll", "_aa0"];
                    if (alive _uu && {alive _tt} && {isNull objectParent _uu} && {(_uu ammo _ll) >= _aa0} && {(currentWeapon _uu) isEqualTo _ll}) then { _uu fireAtTarget [_tt, currentMuzzle _uu]; };
                }, [_u, _en, _ls, _a0], _gec + 1.5] call CBA_fnc_waitAndExecute;
            };
            // v8.763 ZAMAN TESHISI (kullanici: 'eleman mal gibi bekliyo'): emirden silah secimine / atisa kadar gecen sure; 0.25 sn'de bir 12 sn izlenir -> [RPG-ZAMAN]
            [_u, _ls, time] spawn {
                params ["_uu", "_ll", "_t0"];
                private _tSec = -1;
                private _tAtis = -1;
                private _ts = time;
                while {time < (_t0 + 12) && {alive _uu}} do {
                    if (_tSec < 0 && {(currentWeapon _uu) isEqualTo _ll}) then { _tSec = time - _t0; };
                    if (_tAtis < 0 && {(_uu getVariable [QGVAR(rpgAtisT), -999]) >= _t0}) then { _tAtis = time - _t0; };
                    if (_tAtis >= 0) exitWith {};
                    sleep 0.25;
                };
                private _n = missionNamespace getVariable ["lambs_danger_rpgZamanLogN", 0];
                if (_n < 40) then {
                    missionNamespace setVariable ["lambs_danger_rpgZamanLogN", _n + 1];
                    diag_log format ["[RPG-ZAMAN] %1 | %2 | emirden roketatar elde: %3 sn | atisa: %4 sn | hiz %5 km/sa | komut %6 | durus %7 | baski %8", groupId group _uu, name _uu, if (_tSec < 0) then {"HIC (12 sn)"} else {_tSec toFixed 1}, if (_tAtis < 0) then {"ATILMADI (12 sn)"} else {_tAtis toFixed 1}, round (speed _uu), currentCommand _uu, stance _uu, (getSuppression _uu) toFixed 2];
                };
            };
            private _k2 = format ["karar_%1", _enTur];
            _say set [_k2, (_say getOrDefault [_k2, 0]) + 1];
            if (_logN < 60) then {
                _logN = _logN + 1;
                diag_log format ["[RPG-KARAR] %1 | %2 | %3 -> %4 %5 m | %6 | mermi %7 (%8) | aiAmmoUsageFlags %9 | oyuncu hedef: %10", groupId _g, name _u, _enTur, typeOf _en, round (_u distance _en), _ls, _mag, _a0, getNumber (configFile >> "CfgAmmo" >> _ammo >> "aiAmmoUsageFlags"), isPlayer _en];
            };
            // sonuc (7 sn sonra): atildi mi
            [{
                params ["_uu", "_ll", "_aa0", "_tr"];
                if (!alive _uu) exitWith {};
                private _s = missionNamespace getVariable ["lambs_danger_rpgSay", createHashMap];
                private _atildi = ((_uu ammo _ll) < _aa0) || {(time - (_uu getVariable [QGVAR(rpgAtisT), -999])) < 9};   // v8.754: yalniz ROKET atisi (eskiden sonAtisT = tufek atisi de sayiliyordu)
                private _kk = ["sonuc_atilmadi", "sonuc_atildi"] select _atildi;
                _s set [_kk, (_s getOrDefault [_kk, 0]) + 1];
                private _n = missionNamespace getVariable ["lambs_danger_rpgSonucLogN", 0];
                if (_n < 40) then {
                    missionNamespace setVariable ["lambs_danger_rpgSonucLogN", _n + 1];
                    diag_log format ["[RPG-KARAR-SONUC] %1 | %2 | atildi: %3 | mermi %4 -> %5 | elde: %6 | komut: %7", groupId group _uu, name _uu, _atildi, _aa0, _uu ammo _ll, currentWeapon _uu, currentCommand _uu];
                };
            }, [_u, _ls, _a0, _enTur], 7] call CBA_fnc_waitAndExecute;
        } forEach _adaylar;
        if (time > _ozT) then {
            _ozT = time + 60;
            if (_oz isNotEqualTo createHashMap) then {
                diag_log format ["[RPG-KARAR-OZET] 60 sn: %1", (([keys _oz, [], {_x}, "ASCEND"] call BIS_fnc_sortBy) apply { format ["%1=%2", _x, _oz get _x] }) joinString " "];
            };
            { _oz set [_x, 0]; } forEach (keys _oz);
        };
    };
};
true
