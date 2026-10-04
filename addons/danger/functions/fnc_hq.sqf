#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KUMANDA (HQ) CEKIRDEGI v1 — "tek catı altında karar beyni" (LAMBS'in eksigi) + GRUPLAR ARASI KOORDINASYON.
 * Fikir: Rydygier'in HETMAN Artificial Leader (NR6 HAL) mimarisi — tek CORE + takilabilir moduller + emir / rapor kanali (kaynak kodu okunmadi; yalniz kavram: kilavuz ozeti).
 *
 * KATMANLAR:
 *   GRUP BEYNI (var)   fnc_commanderAssess  : tek grubun taktik karari (BOUNDING / PEEL / WITHDRAW / PUSH ...)
 *   KUMANDA (bu dosya) fnc_hq               : taraf (west / east / independent) basina DURUM TAHTASI + moduller; gruplar arasi kararlar
 *   MODULLER (v8.32)   hqTakviye (dinamik takviye), hqFeint (v8.37: kanat manevrasina destek yanilticisi saldiri), hqMedevac (hekimi olmayan gruba baska gruptan hekim; TCCC ile entegre)
 *                      fnc_hq<Ad>           : lambs_danger_hqModuller listesi; her biri [taraf, tahta] alir; kapatma: lambs_danger_hq<Ad>V1 = false
 *   EMIR KANALI        fnc_hqEmir           : [grup, ad, veri] -> grup degiskeni hqEmir + olay "HQEmir" + yurutucu (ornek: TAKVIYE -> LAMBS tacticsReinforce)
 *   RAPOR KANALI       olay veriyolu (fnc_olayGonder): gruplar RetreatBitti / SonDirenis / InContact / AllClear gonderir; kumanda [HQ-RAPOR] olarak kaydeder
 *
 * DURUM TAHTASI girdisi (HashMap, YEREL gruplar icin; AI baska makinede yerelse o grubu bu makine goremez):
 *   g grup | poz lider konumu | n canli | kayip (cmdInitialCount'a gore) | temasta (bool) | temasSure (sn, temas bitti) | sit (commanderAssess cmdSit:
 *   [zaman, enYakin, dusmanN, MG, zirh, guc orani, kayip, dusman pozisyonu]) | mesgul (taktik bayragi) | musait (destek verebilir)
 * MODUL TASLAGI: lambs_danger_fnc_hqTakviye gibi [taraf, tahta] call; donus degeri yok; emirleri hqEmir ile verir.
 *
 * ACILIS (v8.33): kumanda YALNIZCA Zeus'ta "LAMBS Danger" kategorisindeki "ELITE Kumanda (HQ)" modulu yerlestirilince calisir (lambs_danger_hqAktif = true, herkese yayinlanir).
 *   Modul secenekleri: modul bazli anahtarlar lambs_danger_hq<Ad>V1 ve "LAMBS dynamic reinforcement'i kapat" (lambs_danger_hqUpstreamKapat: grup bayragi enableGroupReinforce her turda false'a cekilir,
 *   yoksa upstream telsiz olayi tum bayrakli gruplari kumandayi atlayip kosturur).  Acik degilken cekirdek hicbir sey yapmaz (grup bayragina bile dokunmaz).
 * Kapatma: lambs_danger_hqAktif = false ya da lambs_danger_hqV1 = false.   Log: [HQ] [HQ-TAHTA] [HQ-RAPOR] [HQ-TAKVIYE] [HQ-KANAT] [HQ-ISTIHBARAT] [HQ-EMIR] [HQ-MODUL]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_hqStarted") exitWith {false};
lambs_danger_hqStarted = true;

// MODUL LISTESI: [ad, aralik sn] — yeni modul eklemek = fnc_hq<Ad>.sqf + buraya satir
if (isNil "lambs_danger_hqModuller") then {
    lambs_danger_hqModuller = [["istihbarat", 5], ["takviye", 8], ["kanat", 7], ["feint", 9], ["medevac", 6]];
};

diag_log format ["[HQ] kumanda cekirdegi baslatildi | moduller: %1", lambs_danger_hqModuller apply {_x select 0}];

// --- RAPOR KANALI (gruplar -> kumanda) ---
if (!isNil "CBA_fnc_addEventHandler") then {
    ["lambs_danger_grupOlayi", {
        params ["_g", "_ad", "_veri"];
        if !(missionNamespace getVariable ["lambs_danger_hqAktif", false]) exitWith {};
        if !(_ad in ["RetreatBitti", "SonDirenis", "InContact", "AllClear"]) exitWith {};
        _g setVariable ["lambs_danger_hqSonRapor", [_ad, time, _veri]];
        if (_ad in ["RetreatBitti", "SonDirenis"]) then {
            if (isNil "lambs_danger_hqRaporN") then { lambs_danger_hqRaporN = 0; };
            if (lambs_danger_hqRaporN < 150) then {
                lambs_danger_hqRaporN = lambs_danger_hqRaporN + 1;
                diag_log format ["[HQ-RAPOR] %1 | %2 | %3 | kalan:%4", groupId _g, _ad, _veri, {alive _x} count (units _g)];
            };
        };
    }] call CBA_fnc_addEventHandler;
};

// --- DURUM TAHTASI ---
private _tahtaKur = {
    params ["_taraf"];
    private _tahta = [];
    {
        private _g = _x;
        private _l = leader _g;
        if (isNull _l || {!alive _l} || {isPlayer _l} || {!local _g}) then { continue };
        if ((side _g) isNotEqualTo _taraf) then { continue };
        if ((units _g) findIf {isPlayer _x} > -1) then { continue };
        private _n = {alive _x} count (units _g);
        if (_n < 1) then { continue };

        private _init = _g getVariable ["lambs_danger_cmdInitialCount", _n];
        if (!(_init isEqualType 0) || {_init < _n}) then { _init = _n; };
        private _kayip = if (_init > 0) then {(_init - _n) / _init} else {0};
        private _contact = _g getVariable ["lambs_danger_contact", 0];
        private _temasta = _contact > time;

        private _mesgul = false;
        {
            if (_g getVariable [_x, false]) exitWith { _mesgul = true; };
        } forEach [
            "lambs_danger_isRetreating", "lambs_danger_isEvading", "lambs_danger_isBreakingContact", "lambs_danger_isSonDirenis",
            "lambs_danger_isAmbushing", "lambs_danger_isExecutingTactic", "lambs_danger_isBounding", "lambs_danger_sniperTeam",
            "lambs_danger_disableGroupAI"
        ];

        private _musait = !_mesgul
            && {!_temasta}
            && {(time - _contact) > 20}
            && {_n >= 3}
            && {isNull objectParent _l}
            && {(time - (_g getVariable ["lambs_danger_hqGorevT", -999])) > 180}
            && {_g getVariable ["lambs_danger_hqTakviyeKatilim", true]};

        _tahta pushBack (createHashMapFromArray [
            ["g", _g], ["poz", getPosATL _l], ["n", _n], ["kayip", _kayip],
            ["temasta", _temasta], ["temasSure", time - _contact],
            ["sit", _g getVariable ["lambs_danger_cmdSit", []]],
            ["mesgul", _mesgul], ["musait", _musait]
        ]);
    } forEach allGroups;
    _tahta
};

[_tahtaKur] spawn {
    params ["_tahtaKur"];
    private _sonTahtaLog = 0;
    private _modSon = createHashMap;
    while {true} do {
        sleep 4;
        // v8.60: lambs_danger_hqOtomatik = true -> Zeus modulu gerekmeden kumanda (istihbarat paylasimi, takviye, kanat, feint) otomatik acilir
        if ((missionNamespace getVariable ["lambs_danger_hqOtomatik", false]) && {!(missionNamespace getVariable ["lambs_danger_hqAktif", false])}) then {
            missionNamespace setVariable ["lambs_danger_hqAktif", true];
            diag_log "[HQ-MODUL] kumanda OTOMATIK acildi (lambs_danger_hqOtomatik = true)";
        };
        if (!(missionNamespace getVariable ["lambs_danger_hqV1", true]) || {!(missionNamespace getVariable ["lambs_danger_hqAktif", false])}) then { continue };
        {
            private _taraf = _x;
            private _tahta = [_taraf] call _tahtaKur;
            if (_tahta isEqualTo []) then { continue };

            // upstream (LAMBS) dynamic reinforcement ile cakisma: bayrak kapali tutulur (secenek: modul)
            if (missionNamespace getVariable ["lambs_danger_hqUpstreamKapat", true]) then {
                {
                    private _gg = _x get "g";
                    if (_gg getVariable ["lambs_danger_enableGroupReinforce", false]) then {
                        _gg setVariable ["lambs_danger_enableGroupReinforce", false, true];
                    };
                } forEach _tahta;
            };

            // moduller
            {
                _x params ["_ad", "_aralik"];
                if !(missionNamespace getVariable [format ["lambs_danger_hq%1V1", _ad], true]) then { continue };
                private _anahtar = format ["%1_%2", _taraf, _ad];
                if ((time - (_modSon getOrDefault [_anahtar, -999])) < _aralik) then { continue };
                _modSon set [_anahtar, time];
                private _fn = missionNamespace getVariable [format ["lambs_danger_fnc_hq%1", toUpper (_ad select [0, 1]) + (_ad select [1])], {}];
                [_taraf, _tahta] call _fn;
            } forEach lambs_danger_hqModuller;

            // tahta ozeti (90 sn'de bir, ilk 40 satir)
            if ((time - _sonTahtaLog) > 90 && {(missionNamespace getVariable ["lambs_danger_hqTahtaN", 0]) < 40}) then {
                _sonTahtaLog = time;
                missionNamespace setVariable ["lambs_danger_hqTahtaN", (missionNamespace getVariable ["lambs_danger_hqTahtaN", 0]) + 1];
                private _toplamN = 0;
                { _toplamN = _toplamN + (_x get "n"); } forEach _tahta;
                diag_log format [
                    "[HQ-TAHTA] %1 | grup:%2 | temasta:%3 | mesgul:%4 | musait:%5 | toplam asker:%6",
                    _taraf, count _tahta,
                    {_x get "temasta"} count _tahta, {_x get "mesgul"} count _tahta, {_x get "musait"} count _tahta,
                    _toplamN
                ];
            };
        } forEach [west, east, independent];
    };
};

true
