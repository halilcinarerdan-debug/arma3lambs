#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EYP TUZAKLAMA + CANLI BOMBA (OYUN DAVRANISI) (v8.775; kullanici: 'canli bomba tuzaklama ve defuse yaklasimlarini yap'; kaynak: ATP 3-34.20 'Countering Explosive Hazards' + JP 3-15.1 'C-IED Operations' (kullanici PDF'leri)).
 * KAPSAM (durust): PDF'ler KARSI-EYP dokulesidir (arama seviyeleri, olay kategorileri A-D, cember / emniyet, uzaktan once, bildirme, EOD); saldirgan tarafin NASIL yapildigini (yapim / tetik detayi) anlatmaz; JP 3-15.1 Ek D (cihaz yapisi) BILEREK kullanilmadi.
 *   Bu modul yalniz OYUN DAVRANISI uretir (hangi AI ne zaman ne yapar). Cihaz = vanilla mayin nesnesi (createMine) / senaryo patlayici nesnesi; gercek yapim / tetik bilgisi YOKTUR.
 *
 * 1) TUZAKLAMA (CBA eypKur, varsayilan KAPALI; v8.777: CBA eypKomutlu ACIKSA tuzak = KOMUTLA patlayan EYP pususu (fnc_eypKomut, referans eyp_deme.txt); KAPALIYSA eski mayin): geri cekilen / temas kesen DUSMAN grup (oyuncusuz, yerel, >= 3 canli), bilinen dusman >= 60 m: en geride kalan asker, dusmanin GELIS YONUNDE, kendi 8 m onune (yol varsa 10 m'de yola oturur)
 *   vanilla anti-personel mayin (APERSMine) birakir; kendi tarafina revealMine (kendi AI'si kacinir); taraf basina en cok eypButce canli tuzak, grup basina eypAralikS sn. Dost 12 m / bina ici / su yok.
 * 2) CANLI BOMBA (CBA canliBomba, varsayilan KAPALI; v8.777: ARACLARDA DA = arac bombasi, CATISARAK = zikzak + ates ederek, bkz fnc_eypKos): dusman grup AGIR KAYIPTA (canli <= 2 ya da kayip >= %60), temas taze, canliBombaMenzilM (150 m) icinde bilinen dusman (sivil / dost degil): grubun en son (ya da tek) askeri 'canli bomba' olur: hedef alma / siper / bastirma
 *   AI'si kapanir, tam hizla hedefin ANLIK konumuna kosar (1 sn'de bir doMove); hedefe canliBombaTetikM (5 m) kalinca senaryo patlayici nesnesi (DemoCharge_Remote_Ammo_Scripted) patlar, asker olur. 40 sn'de varamazsa AI'si geri acilir.
 *   Ust sinir: canliBombaMax (1) olay / 600 sn, taraf basina. Oyuncunun savunmasi: standart ates (kosan hedef; bilgi / reaksiyon ayarlari).
 * 2b) TESLIM OLAN + UZERINDE PATLAYICI (CBA teslimBomba, varsayilan KAPALI; v8.776 kullanici: 'teslim olan askerler son anda uzerimize kossunlar, eger ied varsa uzerlerinde'): teslim olmus (QGVAR(teslim)) DUSMAN asker, uzerinde patlayici esyasi varsa (TimeBombCore sinifli sarjor: sarj / mayin / EYP) ya da CBA teslimBombaSans (0-1) sansiyla gizli cihaz tasiyorsa
 *   dusman 6-12 m'ye (birim basina sabit rastgele) yaklasinca SON ANDA teslimden cikar (captive kapali, AI acik, ACE teslim iptal), tam hizla hedefe kosar, canliBombaTetikM'de patlar; 8 sn'de varamazsa tekrar teslim (AI kapali) olur.
 * 3) DEFUSE / EMNIYET (CBA eypStandoffCarpan): fnc_iedFarkindalik'in emniyet cemberi (IED menzili x 6, 30-80 m / buyuk 55 m) bu carpanla olceklenir (ATP 3-34.20: kategoriye gore cember). Mevcut sistem (algi, EOD defuse, PATLAT) korunur.
 * OLCUM: [EYP-KUR] (ilk 30), [CANLI-BOMBA] (ilk 30: secilen, hedef, mesafe, sonuc) + 60 sn [EYP-OZET]. Karne: EYP / CANLI BOMBA.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_eypSistemStarted") exitWith {false};
lambs_danger_eypSistemStarted = true;
diag_log "[EYP-SISTEM] eyp tuzaklama + canli bomba (oyun davranisi; CBA eypKur / canliBomba varsayilan KAPALI) baslatildi (v8.775)";

// v8.777 ZEUS / 3DEN: istek (sunucu) -> sahip makine (yerel) olaylari; modul / init satiri fnc_eypBombaYap / fnc_eypKomut cagirir
["lambs_danger_eypBombaIstegi", {
    params ["_nid", "_a"];
    private _o = objectFromNetId _nid;
    if (!isNull _o) then { ["lambs_danger_eypBombaYerel", [_o, _a], _o] call CBA_fnc_targetEvent; };
}] call CBA_fnc_addEventHandler;
["lambs_danger_eypBombaYerel", { _this call FUNC(eypBombaYap); }] call CBA_fnc_addEventHandler;
["lambs_danger_eypKomutIstegi", {
    params ["_nid", "_ip", "_hide", "_ep", "_tetikM", "_guc"];
    private _o = objectFromNetId _nid;
    if (!isNull _o) then { ["lambs_danger_eypKomutYerel", [_o, _ip, _hide, _ep, _tetikM, _guc], _o] call CBA_fnc_targetEvent; };
}] call CBA_fnc_addEventHandler;
["lambs_danger_eypKomutYerel", { _this spawn FUNC(eypKomut); }] call CBA_fnc_addEventHandler;

[] spawn {
    private _kurN = 0;
    private _bombaN = 0;
    private _say = createHashMapFromArray [["tuzak", 0], ["bomba_secildi", 0], ["bomba_patladi", 0], ["bomba_zamanasimi", 0], ["bomba_oldu", 0]];
    private _ozetT = time + 60;
    private _bombaOlaylar = createHashMap;   // taraf -> [zaman]
    private _tuzaklar = createHashMap;       // taraf -> [mayin]
    while {true} do {
        sleep 3;
        private _kur = missionNamespace getVariable ["lambs_danger_eypKur", false];
        private _bomba = missionNamespace getVariable ["lambs_danger_canliBomba", false];
        if (_kur || _bomba) then {
            {
                private _g = _x;
                if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian} || {(side _g) isEqualTo sideLogic}) then { continue };
                private _l = leader _g;
                if (isNull _l || {isPlayer _l} || {((units _g) findIf {isPlayer _x}) > -1}) then { continue };
                private _uyeler = (units _g) select {alive _x && {local _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
                private _hepsi = (units _g) select {alive _x && {local _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};   // v8.777: araca binmis olanlar da (arac bombasi)
                if (_uyeler isEqualTo [] && {_hepsi isEqualTo []}) then { continue };
                private _taraf = side _g;
                private _temas = (_g getVariable [QGVAR(contact), 0]) > (time - 15);
                if (!_temas) then { continue };
                private _en = _l findNearestEnemy _l;
                if (isNull _en || {!alive _en} || {(_taraf getFriend (side group _en)) >= 0.6} || {(side group _en) isEqualTo civilian}) then { continue };
                private _d = _l distance2D _en;

                // ---------------- 1) TUZAKLAMA ----------------
                if (_kur && {(count _uyeler) >= 3} && {_d >= 60} && {_d <= 400}
                    && {((_g getVariable [QGVAR(isRetreating), false]) isEqualTo true) || {(_g getVariable [QGVAR(isBreakingContact), false]) isEqualTo true}}
                    && {time >= (_g getVariable [QGVAR(eypKurT), 0])}) then {
                    private _liste = (_tuzaklar getOrDefault [str _taraf, []]) select {!isNull _x && {alive _x}};
                    _tuzaklar set [str _taraf, _liste];
                    private _maks = ((missionNamespace getVariable ["lambs_danger_eypButce", 3]) max 1) min 10;
                    private _komutAktif = missionNamespace getVariable [format ["lambs_danger_eypKomutAktif_%1", str _taraf], 0];
                    if (((count _liste) + _komutAktif) < _maks) then {
                        private _geri = ([_uyeler, [], {_x distance2D _en}, "DESCEND"] call BIS_fnc_sortBy) select 0;
                        private _yon = _geri getDir _en;
                        private _p = (getPosATL _geri) getPos [8, _yon];
                        private _yol = (_p nearRoads 10);
                        if (_yol isNotEqualTo []) then { _p = getPosATL (_yol select 0); };
                        _p set [2, 0];
                        private _dostYakin = (_p nearEntities [["CAManBase", "LandVehicle"], 12]) findIf {alive _x && {(_taraf getFriend (side group _x)) >= 0.6}} >= 0;
                        if (!surfaceIsWater _p && {!_dostYakin} && {(insideBuilding _geri) < 0.5}) then {
                            _g setVariable [QGVAR(eypKurT), time + (((missionNamespace getVariable ["lambs_danger_eypAralikS", 180]) max 30) min 900)];
                            if (missionNamespace getVariable ["lambs_danger_eypKomutlu", true]) then {
                                // v8.777 (kullanici referansi eyp_deme.txt): KOMUTLA patlayan EYP pususu (kur, gozetle, 12 m'de patlat)
                                _say set ["komut", (_say getOrDefault ["komut", 0]) + 1];
                                if (_kurN < 30) then { _kurN = _kurN + 1; diag_log format ["[EYP-KUR] %1 (%2) | %3 | geri cekilirken dusman yonune (%4 m) KOMUTLA patlayan EYP kuruyor | taraf aktif %5 + komut %6 / %7", groupId _g, str _taraf, name _geri, round _d, count _liste, _komutAktif, _maks]; };
                                [_geri, _p, getPosATL _en] spawn { params ["_u", "_pp", "_ep"]; [_u, _pp, [], _ep] call FUNC(eypKomut); };
                            } else {
                                private _m = createMine ["APERSMine", _p, [], 0];
                                _taraf revealMine _m;
                                _liste pushBack _m;
                                _tuzaklar set [str _taraf, _liste];
                                _say set ["tuzak", (_say get "tuzak") + 1];
                                if (_kurN < 30) then { _kurN = _kurN + 1; diag_log format ["[EYP-KUR] %1 (%2) | %3 | geri cekilirken dusman yonune (%4 m) tuzak | taraf tuzagi %5 / %6 | xy %7", groupId _g, str _taraf, name _geri, round _d, count _liste, _maks, _p select [0, 2] apply { round _x }]; };
                            };
                        };
                    };
                };

                // ---------------- 2) CANLI BOMBA (piyade ya da ARAC bombasi; catisarak) ----------------
                if (_bomba && {_d <= (((missionNamespace getVariable ["lambs_danger_canliBombaMenzilM", 150]) max 50) min 300)}) then {
                    private _toplam = count (units _g);
                    private _kayip = 1 - ((count _hepsi) / (_toplam max 1));
                    if ((count _hepsi) <= 2 || {_kayip >= 0.6}) then {
                        private _olaylar = (_bombaOlaylar getOrDefault [str _taraf, []]) select {(time - _x) < 600};
                        if ((count _olaylar) < (((missionNamespace getVariable ["lambs_danger_canliBombaMax", 1]) max 1) min 5) && {isNil {_g getVariable QGVAR(canliBombaT)}}) then {
                            // v8.777 (kullanici: 'araclardada olsun'): gruptaki araba / kamyon / MRAP (Tank degil) ve surucusu bu grubun yerel AI'si ise ARAC bombasi; yoksa piyadenin en son askeri
                            private _araclar = [];
                            { private _vv = vehicle _x; if (_vv isNotEqualTo _x && {_vv isKindOf "Car"} && {!(_vv in _araclar)} && {canMove _vv} && {((crew _vv) findIf {isPlayer _x}) < 0}) then { _araclar pushBack _vv; }; } forEach _hepsi;
                            private _surucu = objNull;
                            { private _dd = driver _x; if (!isNull _dd && {alive _dd} && {_dd in _hepsi} && {!isPlayer _dd}) exitWith { _surucu = _dd; }; } forEach _araclar;
                            // v8.786 (RPT 1f3a00f8: secilen 'en son' asker hedeften 235 m uzaktaydi (lider-dusman 98 m), 40 sn'de 54 m gidebildi -> zaman asimi x2): bomba = HEDEFE EN YAKIN asker (arac yoksa)
                            private _b = if (!isNull _surucu) then {_surucu} else {if (_uyeler isEqualTo []) then {objNull} else {([_uyeler, [], {_x distance _en}, "ASCEND"] call BIS_fnc_sortBy) select 0}};
                            if (!isNull _b && {isNil {_b getVariable QGVAR(canliBomba)}}) then {
                                _olaylar pushBack time;
                                _bombaOlaylar set [str _taraf, _olaylar];
                                _g setVariable [QGVAR(canliBombaT), time];
                                _b setVariable [QGVAR(canliBomba), true];
                                _say set ["bomba_secildi", (_say get "bomba_secildi") + 1];
                                private _aracMi = !isNull objectParent _b;
                                if (_aracMi) then { _say set ["bomba_arac", (_say getOrDefault ["bomba_arac", 0]) + 1]; };
                                if (_bombaN < 30) then { _bombaN = _bombaN + 1; diag_log format ["[CANLI-BOMBA] SECILDI | %1 | %2 | %3 | grup %4 / %5 canli | hedef %6 %7 m (lider-dusman) | bomba-hedef %8 m", groupId _g, name _b, ["piyade", "ARAC (" + typeOf vehicle _b + ")"] select _aracMi, count _hepsi, _toplam, typeOf _en, round _d, round (_b distance _en)]; };
                                [_b, _en, _say, _bombaN] spawn {
                                    params ["_u", "_hedef", "_sy", "_ln"];
                                    private _t0 = time;
                                    // sure: mesafeye gore (4 m/s varsayim; en az 40, en cok 120 sn)
                                    private _sure = ((20 + ((_u distance _hedef) / 4)) max 40) min 120;
                                    private _sonuc = [_u, _hedef, _sure] call FUNC(eypKos);
                                    private _k = switch (_sonuc) do { case "PATLADI": {"bomba_patladi"}; case "vuruldu / oldu": {"bomba_oldu"}; default {"bomba_zamanasimi"} };
                                    _sy set [_k, (_sy getOrDefault [_k, 0]) + 1];
                                    if (alive _u) then { _u setVariable [QGVAR(canliBomba), nil]; };
                                    diag_log format ["[CANLI-BOMBA] SONUC | %1 | %2 | %3 sn", name _u, _sonuc, (time - _t0) toFixed 1];
                                };
                            };
                        };
                    };
                };
            } forEach allGroups;
        };
        if (time > _ozetT) then {
            _ozetT = time + 60;
            private _nz = (keys _say) select {(_say get _x) > 0};
            if (_nz isNotEqualTo []) then { diag_log format ["[EYP-OZET] 60 sn (kumulatif): %1", (_nz apply { format ["%1=%2", _x, _say get _x] }) joinString " "]; };
        };
    };
};
// ---------------- 2b) TESLIM OLAN + UZERINDE PATLAYICI: son anda kosar ----------------
[] spawn {
    private _logN = 0;
    private _say = missionNamespace getVariable ["lambs_danger_teslimBombaSay", createHashMap];
    missionNamespace setVariable ["lambs_danger_teslimBombaSay", _say];
    while {true} do {
        sleep 0.5;
        if !(missionNamespace getVariable ["lambs_danger_teslimBomba", false]) then { continue };
        {
            private _u = _x;
            if (!local _u || {isPlayer _u} || {!alive _u} || {(_u getVariable [QGVAR(teslim), false]) isNotEqualTo true} || {!isNull objectParent _u}) then { continue };
            private _k = _u getVariable [QGVAR(teslimBombaK), -1];
            if (_k < 0) then {
                private _esya = (magazines _u) findIf { private _a = getText (configFile >> "CfgMagazines" >> _x >> "ammo"); _a isNotEqualTo "" && {_a isKindOf ["TimeBombCore", configFile >> "CfgAmmo"]} };
                private _tasiyor = (_esya >= 0) || {(random 1) < (((missionNamespace getVariable ["lambs_danger_teslimBombaSans", 0]) max 0) min 1)};
                _k = [0, 1] select _tasiyor;
                _u setVariable [QGVAR(teslimBombaK), _k];
                _u setVariable [QGVAR(teslimBombaM), 6 + (random 6)];
                if (_k isEqualTo 1) then {
                    _say set ["isaretli", (_say getOrDefault ["isaretli", 0]) + 1];
                    if (_logN < 20) then { _logN = _logN + 1; diag_log format ["[TESLIM-BOMBA] ISARETLI | %1 (%2) | teslim oldu, uzerinde patlayici: %3 | son an mesafesi %4 m", name _u, groupId group _u, ["gizli cihaz (sans)", "esya var"] select (_esya >= 0), round (_u getVariable QGVAR(teslimBombaM))]; };
                };
            };
            if (_k isNotEqualTo 1) then { continue };
            private _taraf = side group _u;
            private _M = _u getVariable [QGVAR(teslimBombaM), 8];
            private _hedefler = (_u nearEntities ["CAManBase", _M]) select {alive _x && {_x isNotEqualTo _u} && {!captive _x} && {(_taraf getFriend (side group _x)) < 0.6} && {(side group _x) isNotEqualTo civilian} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            if (_hedefler isEqualTo []) then { continue };
            private _hedef = ([_hedefler, [], {_x distance _u}, "ASCEND"] call BIS_fnc_sortBy) select 0;
            // SON AN: teslimden cik
            _u setVariable [QGVAR(teslimBombaK), 2];
            _u setVariable [QGVAR(teslim), false, true];
            _u setVariable [QGVAR(disableAI), false];
            _u setCaptive false;
            { _u enableAI _x; } forEach ["MOVE", "PATH", "ANIM", "TARGET", "AUTOTARGET", "FSM", "WEAPONAIM", "AUTOCOMBAT", "COVER", "SUPPRESSION"];
            if (!isNil "ace_captives_fnc_setSurrendered") then { [_u, false] call ace_captives_fnc_setSurrendered; } else { _u playMoveNow "AmovPercMstpSnonWnonDnon"; };
            // v8.777 (kullanici: 'catisarak'): teslimde silahlar silindi; CBA teslimBombaTabanca ACIKSA gizli tabanca (P07 + 3 sarjor) ile catisir
            private _tabanca = false;
            if ((weapons _u) isEqualTo [] && {missionNamespace getVariable ["lambs_danger_teslimBombaTabanca", true]}) then {
                _u addMagazine "16Rnd_9x21_Mag"; _u addMagazine "16Rnd_9x21_Mag"; _u addMagazine "16Rnd_9x21_Mag";
                _u addWeapon "hgun_P07_F";
                _u selectWeapon (handgunWeapon _u);
                _tabanca = (handgunWeapon _u) isNotEqualTo "";
            };
            _say set ["kosu", (_say getOrDefault ["kosu", 0]) + 1];
            diag_log format ["[TESLIM-BOMBA] SON AN KOSU | %1 (%2) | hedef %3 %4 m | gizli tabanca %5", name _u, groupId group _u, typeOf _hedef, round (_u distance _hedef), _tabanca];
            [_u, _hedef, _say] spawn {
                params ["_b", "_h", "_sy"];
                private _t0 = time;
                private _sonuc = [_b, _h, 8] call FUNC(eypKos);
                _sy set [_sonuc, (_sy getOrDefault [_sonuc, 0]) + 1];
                if (alive _b) then {
                    // varamadi: silahlari birak, tekrar teslim (AI kapali)
                    _b setVariable [QGVAR(teslim), true, true];
                    _b setVariable [QGVAR(disableAI), true];
                    _b setCaptive true;
                    { _b disableAI _x; } forEach ["MOVE", "PATH", "TARGET", "AUTOTARGET", "FSM", "WEAPONAIM", "AUTOCOMBAT", "COVER", "SUPPRESSION"];
                    _b forceSpeed -1;
                    doStop _b;
                    removeAllWeapons _b;
                    if (!isNil "ace_captives_fnc_setSurrendered") then { [_b, true] call ace_captives_fnc_setSurrendered; } else { _b action ["Surrender", _b]; };
                };
                diag_log format ["[TESLIM-BOMBA] SONUC | %1 | %2 | %3 sn", name _b, _sonuc, (time - _t0) toFixed 1];
            };
        } forEach allUnits;
    };
};
true
