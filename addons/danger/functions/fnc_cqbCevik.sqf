#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CQB CEVIK (v8.368; kullanici: 'hareket ve atis ozellikle yakin mesafede calismiyor gibi, 4 v 1 alabiliyorum, rambo dalinca CQB'de oldurmesi kolay ... yere civilenmesinler, daha kivrak olsunlar').
 *
 * NEDEN (RPT 21:44-21:46, 3 asker / 1 oyuncu, mesafe 14-60 m): ates-hareket (fnc_atesHareket) ve atis ustunlugu (fnc_atisUstunlugu) dusman < 30 m iken HIC calismiyor (esikleri 30-220 m / >= 30 m);
 *   yakin dovuste yalniz cqbReflex (hedef al + ates) ve siper secimi var. Sonuc: askerler 'Dodge!' / bomba tepkisi / hasar sonrasi YERDE ya da cömelmis DURUYOR ([ANOMALI] YURUMUYOR: MOVE komutu ama 15 sn duruyor,
 *   stance CROUCH, gorev Dodge!), tek tek oyuncunun on hattina giriyor ve oyuncu ateş-hareket yapan tek taraf oluyor.
 *
 * ISLEYIS (1.2 sn'de bir; grup temasta, oyuncusuz; asker basina en yakin bilinen dusman piyade 3 .. 32 m [CBA]):
 *   CIVILENMIS tespiti: yatik / comelmis, ~yerinde (< 1.5 m) >= 3.5 sn, baski < 0.6, onunde 1.8 m icinde mermi durduran SIPER YOK (sert siperdeki asker civilenmis sayilmaz, orada ates eder).
 *   KURAL (CQB ates-hareket; TC 3-21.76 / MCWP 3-11.2: bir ekip ates eder, digeri hareket eder; yakin dovuste yerinde yatmak olum bolgesinde kalmaktir -> ya dovus ya cik):
 *     - dusmani GOREN asker = ATES unsuru: yatik ise bir kademe kalkar (MIDDLE), doTarget + doFire (3 sn'de bir; mermi disiplini: yuklu sarjor >= 6 mermi ya da yedek sarjor var).
 *     - dusmani GOREMEYEN ya da CIVILENMIS asker = HAREKET unsuru (grupta en az bir ATES unsuru varsa): dusmana gore 60-120 derece YANAL 5-11 m bos noktaya kisa atilim:
 *       dostlardan >= 2.5 m, dostun ates hattinin onunde degil (6 derece koridor), yol duvara carpmaz, dusmana 6 m'den fazla yaklasmaz; puan: hedefi goren +6, siperli +4, yanal aciklik +3.
 *       FULL hiz, AI KAPATILMAZ (CQB'de kosarken de ates edebilir), varista doTarget + doFire. Hareket eden grup basina en fazla (n / 2).
 *     - ATES unsuru yoksa civilenmis asker yerinde ates unsuru olur (kalkar + ates) - tek basina kosmaz.
 *   MUAF: forceMove / taktikKilit / hekim tedavisi / bomba tepkisi / panik / yeniden doldurma / teslim / aracta / oyuncu; grup: retreat / evade / temas kes / peel / bina temizleme / hendek / keskin nisanci / AT taarruzu.
 *   Asker basina 5 sn bekleme, tikte en fazla 6 emir. Kapatma: CBA 'ELITE siper' > CQB cevik (lambs_danger_cqbCevikAktif). Log: [CQB-CEVIK] (ilk 60) + 60 sn ozeti.
 *
 * v8.370: tek basina >= 6 sn civilenmis asker de yanal atilim yapar; dusmani goremeyen civilenmis asker kalkar + dusmana doner (RPT: tespit 7 / hareket 0).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_cqbCevikStarted") exitWith {false};
lambs_danger_cqbCevikStarted = true;

diag_log "[CQB-CEVIK] CQB cevik hareket + ates (civilenme onleyici) watchdog'u baslatildi (v8.368): dusman 3-32 m, ates unsuru / yanal hareket unsuru";

[] spawn {
    // v8.369: LAMBS Suppression baskiyi uzun tutar (beceri 0 icin 25 sn): 'civilenmis' baski kapisi courage ile yukselir (0.6 -> en cok 0.9) - baskili ama cesur asker yine de yer degistirebilsin
    private _lSup = isClass (configFile >> "CfgPatches" >> "lambs_suppression");
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _sayac = createHashMapFromArray [["civilenmis", 0], ["yanal", 0], ["ates", 0], ["kalk", 0], ["yerYok", 0]];
    private _ozetT = time + 60;
    private _logN = 0;
    while {true} do {
        sleep 1.2;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_sayac get "yanal") + (_sayac get "ates") + (_sayac get "kalk")) > 0) then {
                diag_log format ["[CQB-CEVIK-OZET] 60 sn: civilenmis tespit %1 | yanal hareket %2 | ates emri %3 | yatiktan kalkis %4 | hareket icin yer bulunamadi %5", _sayac get "civilenmis", _sayac get "yanal", _sayac get "ates", _sayac get "kalk", _sayac get "yerYok"];
            };
            { _sayac set [_x, 0]; } forEach (keys _sayac);
        };
        if (!(missionNamespace getVariable ["lambs_danger_cqbCevikAktif", true])) then { continue };
        private _menzil = missionNamespace getVariable ["lambs_danger_cqbCevikMenzil", 32];
        private _butce = 6;

        {
            private _g = _x;
            if (_butce <= 0) exitWith {};
            if (isNull _g || {!local _g}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isPeeling), false]} || {_g getVariable [QGVAR(isSweeping), false]} || {_g getVariable [QGVAR(isATEngage), false]}
                || {_g getVariable [QGVAR(disableGroupAI), false]} || {_g getVariable ["lambs_danger_disableGroupAI", false]}
                || {_g getVariable [QGVAR(sniperTeam), false]} || {[_g] call FUNC(mevziDeMi)}
            ) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };
            private _us = (units _g) select {alive _x && {local _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!captive _x} && {!(_x getVariable [QGVAR(teslim), false])}};
            if ((count _us) < 1) then { continue };

            // ---- her askerin en yakin bilinen dusmani + gorus durumu ----
            private _bilgi = [];     // [asker, dusman, mesafe, goruyor, civili]
            {
                private _u = _x;
                private _en = _u findNearestEnemy _u;
                if (isNull _en || {!alive _en} || {!(_en isKindOf "CAManBase")}) then { continue };
                private _d = _u distance2D _en;
                if (_d < 3 || {_d > _menzil}) then { continue };
                if ((_u knowsAbout _en) < (["SUPHE"] call FUNC(bilgiEsik))) then { continue };
                private _goruyor = !(terrainIntersectASL [eyePos _u, eyePos _en]) && {!(lineIntersects [eyePos _u, eyePos _en, _u, _en])};
                // yerinde ne kadar suredir
                private _pp = _u getVariable [QGVAR(cevikPos), []];
                if (_pp isEqualTo [] || {(_u distance2D _pp) > 1.5}) then {
                    _u setVariable [QGVAR(cevikPos), getPosATL _u];
                    _u setVariable [QGVAR(cevikPosT), time];
                };
                private _yerde = time - (_u getVariable [QGVAR(cevikPosT), time]);
                private _durus = stance _u;
                private _siperde = (count (lineIntersectsSurfaces [eyePos _u, (eyePos _u) vectorAdd (((eyePos _u) vectorFromTo (eyePos _en)) vectorMultiply 1.8), _u, objNull, true, 1, "FIRE", "NONE"])) > 0;
                private _civili = (_durus in ["PRONE", "CROUCH"]) && {_yerde >= 3.5} && {(getSuppression _u) < (0.6 + ([0, 0.3 * (_u skill "courage")] select _lSup))} && {!_siperde} && {(speed _u) < 1.5};
                _bilgi pushBack [_u, _en, _d, _goruyor, _civili];
            } forEach _us;
            if (_bilgi isEqualTo []) then { continue };

            // ---- ates unsurlari: dusmani goren (ve civilenmemis / ya da tek goren) ----
            private _atesU = _bilgi select {(_x select 3)};
            private _hareketEdebilir = floor ((count _us) / 2);
            private _hareketSay = 0;

            {
                _x params ["_u", "_en", "_d", "_goruyor", "_civili"];
                if (_butce <= 0) exitWith {};
                if (
                    (time - (_u getVariable [QGVAR(cevikT), -999])) < 5
                    || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                    || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                    || {time < (_u getVariable [QGVAR(panikBitis), 0])} || {(primaryWeapon _u) isEqualTo ""}
                ) then { continue };

                if (_civili) then { _sayac set ["civilenmis", (_sayac get "civilenmis") + 1]; };
                private _rol = [_u] call _rolFn;
                private _hareketMi = (!_goruyor || {_civili}) && {_hareketSay < (_hareketEdebilir max 1)} && {(insideBuilding _u) < 0.5} && {_rol isNotEqualTo "MG"};
                // ates unsuru yoksa civilenmis asker kendisi ates unsuru olur (tek basina kosmaz)
                if (_hareketMi && {(_atesU findIf {(_x select 0) isNotEqualTo _u}) < 0} && {!(_civili && {(time - (_u getVariable [QGVAR(cevikPosT), time])) >= 6})}) then { _hareketMi = false; };

                if (_hareketMi) then {
                    // ---- HAREKET unsuru: yanal bos nokta ----
                    private _p = getPosATL _u;
                    private _enP = getPosATL _en;
                    private _bak = _p getDir _enP;
                    private _dostlar = ((_p nearEntities ["CAManBase", 25]) select {_x isNotEqualTo _u && {alive _x} && {(side group _x) isEqualTo (side group _u)}}) apply {getPosATL _x};
                    private _talep = ((((group _u) getVariable [QEGVAR(main,coverClaims), []]) select {(time - (_x select 1)) < 8 && {(_x select 2) isNotEqualTo _u}}) apply {_x select 0});
                    private _atesciPoz = (_atesU select {(_x select 0) isNotEqualTo _u}) apply {getPosATL (_x select 0)};
                    private _eH = getTerrainHeightASL _p;
                    private _enIyi = [];
                    private _enS = -1e9;
                    {
                        private _ang = _x;
                        {
                            private _r = _x;
                            private _c = _p getPos [_r, _bak + _ang];
                            if (!surfaceIsWater _c && {(abs ((getTerrainHeightASL _c) - _eH)) <= 1.5}) then {
                                private _cd = _c distance2D _enP;
                                private _min = 99;
                                { _min = _min min (_x distance2D _c); } forEach (_dostlar + _talep);
                                if (_cd >= 6 && {_cd <= (_d + 2)} && {_min >= 2.5} && {!(lineIntersects [AGLToASL (_p vectorAdd [0, 0, 0.9]), AGLToASL (_c vectorAdd [0, 0, 0.9]), _u, objNull])}) then {
                                    // dostun ates hattinin onunde olma
                                    private _hat = false;
                                    {
                                        private _f = _x;
                                        private _aci = abs ((((_f getDir _enP) - (_f getDir _c)) + 540) mod 360 - 180);
                                        if (_aci < 6 && {(_f distance2D _c) < (_f distance2D _enP)}) exitWith { _hat = true; };
                                    } forEach _atesciPoz;
                                    if (!_hat) then {
                                        private _s = 0 - (_r * 0.4);
                                        if (!(lineIntersects [AGLToASL (_c vectorAdd [0, 0, 1.5]), eyePos _en, _u, _en])) then { _s = _s + 6; };
                                        private _on = _c getPos [2, _c getDir _enP];
                                        if (lineIntersects [AGLToASL (_c vectorAdd [0, 0, 1]), AGLToASL (_on vectorAdd [0, 0, 1]), _u, objNull]) then { _s = _s + 4; };
                                        if ((abs _ang) >= 80) then { _s = _s + 3; };
                                        if (_s > _enS) then { _enS = _s; _enIyi = _c; };
                                    };
                                };
                            };
                        } forEach [5, 8, 11];
                    } forEach [90, -90, 60, -60, 120, -120];

                    if (_enIyi isEqualTo []) then {
                        _sayac set ["yerYok", (_sayac get "yerYok") + 1];
                        _u setVariable [QGVAR(cevikT), time - 2];   // 3 sn sonra yeniden dene
                        // yer yok: yerinde ates unsuru ol
                        if (_civili) then { _u setUnitPosWeak "MIDDLE"; };
                    } else {
                        _butce = _butce - 1;
                        _hareketSay = _hareketSay + 1;
                        _u setVariable [QGVAR(cevikT), time];
                        _u setVariable [QGVAR(taktikKilit), time + 4];
                        _u setUnitPosWeak "AUTO";
                        _u forceSpeed -1;
                        _u setSpeedMode "FULL";
                        _u doTarget _en;
                        _u doMove _enIyi;
                        // v8.500x CQB HAREKET HALINDE ATES (kullanici: 'cqb de hareket halinde ates baya artabilir'): atilim suresince (en fazla 6 sn) her ~0.9 sn'de lambs_danger_cqbHareketAtesOran olasiligiyla
                        //   dusmana doFire (gorus hatti aciksa, mermi varsa). Eskiden yalniz varista ates ediliyordu.
                        private _hOran = missionNamespace getVariable ["lambs_danger_cqbHareketAtesOran", 0.7];
                        if (_hOran > 0) then {
                            [_u, _en, _hOran] spawn {
                                params ["_uu", "_ee", "_o"];
                                private _tb = time + 6;
                                while {alive _uu && {alive _ee} && {time < _tb}} do {
                                    if ((random 1) < _o && {(_uu ammo (primaryWeapon _uu)) > 0} && {!(lineIntersects [eyePos _uu, eyePos _ee, _uu, _ee])}) then { _uu doTarget _ee; _uu doFire _ee; };
                                    sleep 0.9;
                                };
                            };
                            _sayac set ["ates", (_sayac get "ates") + 1];
                        };
                        private _cl = ((group _u) getVariable [QEGVAR(main,coverClaims), []]) select {(time - (_x select 1)) < 8};
                        _cl pushBack [_enIyi, time, _u];
                        (group _u) setVariable [QEGVAR(main,coverClaims), _cl];
                        _sayac set ["yanal", (_sayac get "yanal") + 1];
                        [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.6} }, { params ["_uu", "_hp", "_ee"]; if (alive _uu && {!isNull _ee} && {alive _ee}) then { _uu setUnitPosWeak "MIDDLE"; _uu doTarget _ee; _uu doFire _ee; }; }, [_u, _enIyi, _en], 6, { params ["_uu", "_hp", "_ee"]; if (alive _uu && {!isNull _ee} && {alive _ee}) then { _uu doTarget _ee; _uu doFire _ee; }; }] call CBA_fnc_waitUntilAndExecute;
                        if (_logN < 60) then {
                            _logN = _logN + 1;
                            diag_log format ["[CQB-CEVIK] %1 | %2 (%3) | dusman %4 m | %5 | -> YANAL ATILIM %6 m (ates unsuru %7 kisi) | stance %8", groupId _g, name _u, _rol, round _d, ["dusmani goremiyor", format ["CIVILENMIS %1 sn (%2, siper yok)", (time - (_u getVariable [QGVAR(cevikPosT), time])) toFixed 1, stance _u]] select _civili, round (_u distance2D _enIyi), count _atesU, stance _u];
                        };
                    };
                } else {
                    // ---- ATES unsuru: kalk (yatiksa) + hedefe ates ----
                    if (!_goruyor) then {
                        if (_civili) then { _u setUnitPosWeak "MIDDLE"; _u doWatch _en; _sayac set ["kalk", (_sayac get "kalk") + 1]; _u setVariable [QGVAR(cevikT), time - 2]; };
                        continue
                    };
                    private _st = stance _u;
                    if (_st isEqualTo "PRONE" && {_d < 22} && {(getSuppression _u) < 0.5}) then {
                        _u setUnitPosWeak "MIDDLE";
                        _sayac set ["kalk", (_sayac get "kalk") + 1];
                    };
                    // mermi disiplini: dolu mermi >= 6 ya da yedek sarjor var
                    private _w = primaryWeapon _u;
                    private _uyum = (compatibleMagazines _w) apply {toLower _x};
                    private _yedek = {(toLower _x) in _uyum} count (magazines _u);
                    if (((_u ammo _w) >= 6 || {_yedek > 0}) && {(time - (_u getVariable [QGVAR(cevikAtesT), -999])) > 3}) then {
                        _u setVariable [QGVAR(cevikAtesT), time];
                        _u setVariable [QGVAR(cevikT), time - 2];
                        _u doTarget _en;
                        _u doFire _en;
                        _butce = _butce - 1;
                        _sayac set ["ates", (_sayac get "ates") + 1];
                    };
                };
            } forEach _bilgi;
        } forEach allGroups;
    };
};

true
