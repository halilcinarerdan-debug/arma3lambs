#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EYP TUZAKLAMA + CANLI BOMBA (OYUN DAVRANISI) (v8.775; kullanici: 'canli bomba tuzaklama ve defuse yaklasimlarini yap'; kaynak: ATP 3-34.20 'Countering Explosive Hazards' + JP 3-15.1 'C-IED Operations' (kullanici PDF'leri)).
 * KAPSAM (durust): PDF'ler KARSI-EYP dokulesidir (arama seviyeleri, olay kategorileri A-D, cember / emniyet, uzaktan once, bildirme, EOD); saldirgan tarafin NASIL yapildigini (yapim / tetik detayi) anlatmaz; JP 3-15.1 Ek D (cihaz yapisi) BILEREK kullanilmadi.
 *   Bu modul yalniz OYUN DAVRANISI uretir (hangi AI ne zaman ne yapar). Cihaz = vanilla mayin nesnesi (createMine) / senaryo patlayici nesnesi; gercek yapim / tetik bilgisi YOKTUR.
 *
 * 1) TUZAKLAMA (CBA eypKur, varsayilan KAPALI): geri cekilen / temas kesen DUSMAN grup (oyuncusuz, yerel, >= 3 canli), bilinen dusman >= 60 m: en geride kalan asker, dusmanin GELIS YONUNDE, kendi 8 m onune (yol varsa 10 m'de yola oturur)
 *   vanilla anti-personel mayin (APERSMine) birakir; kendi tarafina revealMine (kendi AI'si kacinir); taraf basina en cok eypButce canli tuzak, grup basina eypAralikS sn. Dost 12 m / bina ici / su yok.
 * 2) CANLI BOMBA (CBA canliBomba, varsayilan KAPALI): dusman grup AGIR KAYIPTA (canli <= 2 ya da kayip >= %60), temas taze, canliBombaMenzilM (150 m) icinde bilinen dusman (sivil / dost degil): grubun en son (ya da tek) askeri 'canli bomba' olur: hedef alma / siper / bastirma
 *   AI'si kapanir, tam hizla hedefin ANLIK konumuna kosar (1 sn'de bir doMove); hedefe canliBombaTetikM (5 m) kalinca senaryo patlayici nesnesi (DemoCharge_Remote_Ammo_Scripted) patlar, asker olur. 40 sn'de varamazsa AI'si geri acilir.
 *   Ust sinir: canliBombaMax (1) olay / 600 sn, taraf basina. Oyuncunun savunmasi: standart ates (kosan hedef; bilgi / reaksiyon ayarlari).
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
                if (_uyeler isEqualTo []) then { continue };
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
                    if ((count _liste) < _maks) then {
                        private _geri = ([_uyeler, [], {_x distance2D _en}, "DESCEND"] call BIS_fnc_sortBy) select 0;
                        private _yon = _geri getDir _en;
                        private _p = (getPosATL _geri) getPos [8, _yon];
                        private _yol = (_p nearRoads 10);
                        if (_yol isNotEqualTo []) then { _p = getPosATL (_yol select 0); };
                        _p set [2, 0];
                        private _dostYakin = (_p nearEntities [["CAManBase", "LandVehicle"], 12]) findIf {alive _x && {(_taraf getFriend (side group _x)) >= 0.6}} >= 0;
                        if (!surfaceIsWater _p && {!_dostYakin} && {(insideBuilding _geri) < 0.5}) then {
                            private _m = createMine ["APERSMine", _p, [], 0];
                            _taraf revealMine _m;
                            _liste pushBack _m;
                            _tuzaklar set [str _taraf, _liste];
                            _g setVariable [QGVAR(eypKurT), time + (((missionNamespace getVariable ["lambs_danger_eypAralikS", 180]) max 30) min 900)];
                            _say set ["tuzak", (_say get "tuzak") + 1];
                            if (_kurN < 30) then { _kurN = _kurN + 1; diag_log format ["[EYP-KUR] %1 (%2) | %3 | geri cekilirken dusman yonune (%4 m) tuzak | taraf tuzagi %5 / %6 | xy %7", groupId _g, str _taraf, name _geri, round _d, count _liste, _maks, _p select [0, 2] apply { round _x }]; };
                        };
                    };
                };

                // ---------------- 2) CANLI BOMBA ----------------
                if (_bomba && {_d <= (((missionNamespace getVariable ["lambs_danger_canliBombaMenzilM", 150]) max 50) min 300)}) then {
                    private _toplam = count (units _g);
                    private _kayip = 1 - ((count _uyeler) / (_toplam max 1));
                    if ((count _uyeler) <= 2 || {_kayip >= 0.6}) then {
                        private _olaylar = (_bombaOlaylar getOrDefault [str _taraf, []]) select {(time - _x) < 600};
                        if ((count _olaylar) < (((missionNamespace getVariable ["lambs_danger_canliBombaMax", 1]) max 1) min 5) && {isNil {_g getVariable QGVAR(canliBombaT)}}) then {
                            private _b = _uyeler select ((count _uyeler) - 1);
                            if (isNil {_b getVariable QGVAR(canliBomba)}) then {
                                _olaylar pushBack time;
                                _bombaOlaylar set [str _taraf, _olaylar];
                                _g setVariable [QGVAR(canliBombaT), time];
                                _b setVariable [QGVAR(canliBomba), true];
                                _say set ["bomba_secildi", (_say get "bomba_secildi") + 1];
                                if (_bombaN < 30) then { _bombaN = _bombaN + 1; diag_log format ["[CANLI-BOMBA] SECILDI | %1 | %2 | grup %3 / %4 canli | hedef %5 %6 m", groupId _g, name _b, count _uyeler, _toplam, typeOf _en, round _d]; };
                                [_b, _en, _say, _bombaN] spawn {
                                    params ["_u", "_hedef", "_sy", "_ln"];
                                    private _tetik = ((missionNamespace getVariable ["lambs_danger_canliBombaTetikM", 5]) max 3) min 12;
                                    { _u disableAI _x; } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT", "COVER", "SUPPRESSION", "FSM"];
                                    _u setBehaviour "CARELESS";
                                    _u setUnitPos "UP";
                                    _u forceSpeed (_u getSpeed "FAST");
                                    private _t0 = time;
                                    private _sonuc = "zaman asimi";
                                    while {alive _u && {time < (_t0 + 40)}} do {
                                        if (isNull _hedef || {!alive _hedef}) then { _hedef = _u findNearestEnemy _u; };
                                        if (isNull _hedef) exitWith { _sonuc = "hedef yok"; };
                                        _u doMove (getPosATL _hedef);
                                        if ((_u distance _hedef) <= _tetik) exitWith {
                                            _sonuc = "PATLADI";
                                            private _c = createVehicle ["DemoCharge_Remote_Ammo_Scripted", getPosATL _u, [], 0, "CAN_COLLIDE"];
                                            _c setDamage 1;
                                            _u setDamage 1;
                                        };
                                        sleep 1;
                                    };
                                    if (!alive _u && {_sonuc isNotEqualTo "PATLADI"}) then { _sonuc = "vuruldu / oldu"; };
                                    private _k = switch (_sonuc) do { case "PATLADI": {"bomba_patladi"}; case "vuruldu / oldu": {"bomba_oldu"}; default {"bomba_zamanasimi"} };
                                    _sy set [_k, (_sy getOrDefault [_k, 0]) + 1];
                                    if (alive _u) then {
                                        { _u enableAI _x; } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT", "COVER", "SUPPRESSION", "FSM"];
                                        _u forceSpeed -1;
                                        _u setVariable [QGVAR(canliBomba), nil];
                                    };
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
true
