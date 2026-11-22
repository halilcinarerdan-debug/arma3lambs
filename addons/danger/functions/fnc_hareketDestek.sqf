#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HAREKET TIKANMA KURTARICISI (v8.726; kullanici: 'hareket optimizasyonu de yap, botlar movementte bireysel zaman kaybetmesin, daha smooth'):
 * KANIT (tum RPT'ler): [HIZ-TANI] 1613 kayit 'komut MOVE, hiz 0' (404 bina ici, 218 yerinde donus animasyonu, ~930 bekleme / kilit, 52 tedavi); [ANOMALI] YURUMUYOR 1900 kayit (cogu gorev '-' bayraksiz). fnc_saglik bunu yalniz LOGLAR, duzeltmez.
 *   Bayraksiz kayitlarin buyuk kismi YANLIS ALARM olabilir: formasyon takipcisi kendi yerine varmis, komutu hala 'MOVE' gorunuyor (hedef < 2 m). Bu yuzden GERCEK tikanma = hedef (expectedDestination) uzakta (> 6 m).
 * KURAL: yerel AI (oyuncu degil, oyuncu komutasinda degil, aracta degil, binada degil), grup LAMBS / TUTAN sahipli degil (senaryo / LAMBS kendi tutar), currentCommand 'MOVE', hiz < 0.8 km/s, hedef > 6 m, baski < 0.5, saglikli,
 *   tedavi / sarjor / bomba tepkisi / panik / kose temkini / yan guvenlik / siperTut / sniper-pusu degil, 'donus' animasyonunda degil -> sayac baslar (yerinde donus sayilmaz):
 *   1) hareketDestekS (6 sn): ayni hedefe YENIDEN emir (doMove), birim hiz siniri kaldirilir (forceSpeed -1), ayakta (UP) -> cogu 'komut takildi' vakasini cozer.
 *   2) 2 x S (12 sn): hedefe 45 derece sapmali 4 m yan nokta (zemine uygun) 2.5 sn sonra asil hedefe donus (yan adim; navmesh / nesne takilmasi). Kosucu (forceMove) askerlere uygulanmaz (baska katmanin durum makinesi).
 *   3) 4 x S (24 sn): lider degilse ve forceMove degilse gruba DON (doFollowGuvenli); 20 sn sogutma.
 *   Hareket baslayinca (hiz >= 1.5 km/s) sayac sifirlanir; kurtarilan sayilir. Isinlama YOK.
 * OLCUM: [HAREKET-DESTEK] (ilk 20) + 60 sn [HAREKET-DESTEK-OZET]: tespit / adim 1 / adim 2 / adim 3 / kurtarilan / muaf nedenleri. Karne: MOVE TIKANMA.
 * CBA: lambs_danger_hareketDestek (varsayilan ACIK), lambs_danger_hareketDestekS (6 sn).
 * SINIR: bina ici (CQB bekleme tasarim geregi), LAMBS / TUTAN sahipli gruplar ve kosucular adim 2-3'ten muaf / tamamen muaf; yeniden emir ayni hedefe verildigi icin yeni hedef secimi / ters donus uretmez.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_hareketDestekStarted") exitWith {false};
lambs_danger_hareketDestekStarted = true;

diag_log "[HAREKET-DESTEK] hareket tikanma kurtarici (MOVE + hiz 0 + hedef uzak -> yeniden emir / yan adim / gruba don) baslatildi (v8.726)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["tespit", 0], ["adim1", 0], ["adim2", 0], ["adim3", 0], ["kurtarilan", 0], ["muafSahip", 0], ["muafBina", 0], ["muafDiger", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep ([1, true, false, "hareketDestek"] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_hareketDestek", true]) then { continue };
        private _S = ((missionNamespace getVariable ["lambs_danger_hareketDestekS", 6]) max 3) min 30;
        {
            private _u = _x;
            if (!local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u}) then { continue };
            // hareket ediyor / MOVE yok: sayac sifir (kurtarildiysa say)
            if ((currentCommand _u) isNotEqualTo "MOVE" || {(speed _u) >= 0.8}) then {
                if (!isNil {_u getVariable QGVAR(hdT)}) then {
                    if ((speed _u) >= 1.5 && {(_u getVariable [QGVAR(hdAdim), 0]) > 0}) then { _say set ["kurtarilan", (_say get "kurtarilan") + 1]; };
                    _u setVariable [QGVAR(hdT), nil];
                    _u setVariable [QGVAR(hdAdim), nil];
                };
                continue
            };
            private _g = group _u;
            private _dest = (expectedDestination _u) param [0, []];
            if (_dest isEqualTo [] || {(_dest select [0, 2]) isEqualTo [0, 0]} || {(_u distance2D _dest) <= 6}) then { _u setVariable [QGVAR(hdT), nil]; continue };
            if ((insideBuilding _u) > 0.5) then { _say set ["muafBina", (_say get "muafBina") + 1]; _u setVariable [QGVAR(hdT), nil]; continue };
            if (([_g] call FUNC(wpSahip)) in ["LAMBS", "TUTAN"] || {[_u] call FUNC(oyuncuKomutaMi)}) then { _say set ["muafSahip", (_say get "muafSahip") + 1]; _u setVariable [QGVAR(hdT), nil]; continue };
            if (
                ((getSuppression _u) >= 0.5) || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {captive _u} || {_u getVariable [QGVAR(teslim), false]} || {_u getVariable ["ACE_isUnconscious", false]}
                || {time < (_u getVariable [QGVAR(tcccBusy), 0])} || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                || {time < (_u getVariable [QGVAR(panikBitis), 0])} || {!isNil {_u getVariable QGVAR(koseAktif)}} || {!isNil {_u getVariable QGVAR(yanGuv)}} || {_u getVariable [QGVAR(disableAI), false]}
                || {(_u getVariable [QGVAR(siperTutBit), 0]) > time} || {(_g getVariable [QGVAR(isAmbushing), false]) isEqualTo true} || {(_g getVariable [QGVAR(sniperTeam), false]) isEqualTo true}
                || {((animationState _u) find "turn") >= 0}
            ) then { _say set ["muafDiger", (_say get "muafDiger") + 1]; _u setVariable [QGVAR(hdT), nil]; continue };

            private _t0 = _u getVariable [QGVAR(hdT), -1];
            if (_t0 < 0) then { _u setVariable [QGVAR(hdT), time]; _u setVariable [QGVAR(hdAdim), 0]; _say set ["tespit", (_say get "tespit") + 1]; continue };
            private _gec = time - _t0;
            private _adim = _u getVariable [QGVAR(hdAdim), 0];
            private _fm = (_u getVariable [QGVAR(forceMove), false]) isEqualTo true;
            private _sebep = "";
            if (_adim < 1 && {_gec >= _S}) then {
                _u setVariable [QGVAR(hdAdim), 1];
                _u forceSpeed -1;   // birim duzeyi (setSpeedMode grup duzeyidir: tek askerin takilmasi tum grubun hizini degistirmesin)
                _u setUnitPosWeak "UP";
                _u doMove _dest;
                _say set ["adim1", (_say get "adim1") + 1];
                _sebep = "1 yeniden emir";
            } else {
                if (_adim < 2 && {_gec >= (2 * _S)} && {!_fm}) then {
                    _u setVariable [QGVAR(hdAdim), 2];
                    private _tk = time;
                    _u setVariable [QGVAR(hdTok), _tk];
                    private _yp = _u getPos [4, (_u getDir _dest) + (selectRandom [-45, 45])];
                    if (!surfaceIsWater _yp) then {
                        _u doMove _yp;
                        [{
                            params ["_a", "_tt", "_d"];
                            if (alive _a && {(_a getVariable [QGVAR(hdTok), -1]) isEqualTo _tt} && {(currentCommand _a) isEqualTo "MOVE"}) then {
                                _a setVariable [QGVAR(hdTok), nil];
                                _a doMove _d;
                            };
                        }, [_u, _tk, _dest], 2.5] call CBA_fnc_waitAndExecute;
                    };
                    _say set ["adim2", (_say get "adim2") + 1];
                    _sebep = "2 yan adim";
                } else {
                    if (_adim < 3 && {_gec >= (4 * _S)} && {!_fm} && {_u isNotEqualTo (leader _g)}) then {
                        _u setVariable [QGVAR(hdAdim), 3];
                        _u setVariable [QGVAR(hdT), time + 20];
                        [_u, leader _g] call FUNC(doFollowGuvenli);
                        _say set ["adim3", (_say get "adim3") + 1];
                        _sebep = "3 gruba don";
                    };
                };
            };
            if (_sebep isNotEqualTo "" && {_logN < 20}) then {
                _logN = _logN + 1;
                diag_log format ["[HAREKET-DESTEK] %1 | %2 | adim %3 | %4 sn tikali | hedef %5 m | stance %6 | anim %7 | fm %8 | bayrak isRet %9", groupId _g, name _u, _sebep, round _gec, round (_u distance2D _dest), stance _u, animationState _u, _fm, _g getVariable [QGVAR(isRetreating), false]];
            };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "tespit") + (_say get "adim1") + (_say get "kurtarilan")) > 0) then {
                diag_log format ["[HAREKET-DESTEK-OZET] 60 sn: tespit %1 | adim1 (yeniden emir) %2 | adim2 (yan adim) %3 | adim3 (gruba don) %4 | kurtarilan %5 | muaf: LAMBS-TUTAN-oyuncu %6, bina ici %7, diger %8", _say get "tespit", _say get "adim1", _say get "adim2", _say get "adim3", _say get "kurtarilan", _say get "muafSahip", _say get "muafBina", _say get "muafDiger"];
            };
            { _say set [_x, 0]; } forEach (keys _say);
        };
    };
};
true
