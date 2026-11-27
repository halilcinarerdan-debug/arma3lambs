#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIPER ON TARAMA (v8.732; kullanici: 'botlar ne yap ne et yuzde 50 daha iyi cover alsinlar, muazzam duzeyde cover'; 'on tarama calisiyor mu cover falan'):
 * KANIT (COVER-OLCUM, 16713 ornek / tum RPT): temasli askerin yalniz ~%1'i GERCEK siperde (dusman hatti <= 4 m'deki nesneye carpiyor), ~%95'i 'UZAK ENGEL' (arazi / uzak nesne ile gizli = cover degil), ~%4 acikta.
 *   coverHug / acikSiper yalniz ACIKTA kalani (hat acik) kurtariyordu; 'gizli ama siper degil' asker ayni yerde bekliyordu.
 * KURAL: temasli (contact), bosta (hiz < 1.5), binada degil, bilinen dusman 25-300 m (>= SUPHE) olan, 'uzak engel' sinifindaki asker (dusman gozunden hat ASKERDEN > 4 m uzakta kesiliyor ya da arazi) icin
 *   fnc_acikSiper en cok siperOnTaramaM (8 m) icindeki nesne / binaya on-tarama yaptirir (3. arguman); bulursa oraya gider (gercek siper), bulamazsa yerinde kalir. Asker basina siperOnTaramaS (45 sn) bekleme; tarama basina en cok 3 asker.
 *   Zaten gercek siperde (<= 4 m) / acikta (coverHug kurtarir) / baskida (>= 0.5) / kosucu / kilitli / geri cekilen / bounding / LAMBS-TUTAN / oyuncu komutasi / tedavi / sarjor degistiren atlanir. Yakin dovus (< 25 m) atlanir.
 * OLCUM: [SIPER-ON-TARAMA] (ilk 25) + 60 sn [SIPER-ON-TARAMA-OZET]; karne SIPER KALITESI (COVER-OLCUM SIPER % ve ACIKTA %: hedef = SIPER % belirgin artar).
 * CBA: siperOnTarama (varsayilan ACIK), siperOnTaramaM (8), siperOnTaramaS (45).
 * SINIR: ek hareket uretir (kisa, <= 8 m); fazla gelirse siperOnTaramaS'yi artir ya da kapat. Siper bulundugunda mevcut acikSiper kurallari (dolu defter, penetrasyon, ongoru, yakin dovus) aynen gecerlidir.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_siperOnTaramaStarted") exitWith {false};
lambs_danger_siperOnTaramaStarted = true;
diag_log "[SIPER-ON-TARAMA] siper on tarama (gizli ama sert siperi olmayan askere yakin gercek siper) baslatildi (v8.732)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["tarama", 0], ["uzak", 0], ["gonder", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep ([2, true, false, "siperOnTarama"] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_siperOnTarama", true]) then { continue };
        private _Mb = (missionNamespace getVariable ["lambs_danger_siperOnTaramaM", 14]) max 3;   // taban; asker basina profile gore (asagida)
        private _cd = ((missionNamespace getVariable ["lambs_danger_siperOnTaramaS", 30]) max 15) min 300;
        private _esik = ["SUPHE"] call FUNC(bilgiEsik);
        private _n = 0;
        {
            private _u = _x;
            if (_n >= 5) exitWith {};   // v8.737: tarama basina 3 -> 5
            if (!local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u}) then { continue };
            private _g = group _u;
            if ((_g getVariable [QGVAR(contact), 0]) <= time || {time < (_u getVariable [QGVAR(onTaramaT), 0])}) then { continue };
            if ((speed _u) >= 1.5 || {(insideBuilding _u) > 0.5}) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(sniperTeam), false]}   // v8.737 (kullanici: 'botlari sipere yapistir'): bounding / taktik yurutenlerin bosta (kapsama) askerleri de taranir (kosucu = forceMove asagida elenir)
                || {([_g] call FUNC(wpSahip)) in ["LAMBS", "TUTAN"]} || {[_u] call FUNC(oyuncuKomutaMi)}
                || {(_u getVariable [QGVAR(forceMove), false]) isEqualTo true} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {(_u getVariable [QGVAR(siperTutBit), 0]) > time}
                || {time < (_u getVariable [QGVAR(tcccBusy), 0])} || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                || {!isNil {_u getVariable QGVAR(koseAktif)}} || {!isNil {_u getVariable QGVAR(yanGuv)}} || {([_u] call FUNC(baskiSeviye)) >= 3} || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {captive _u}
            ) then { continue };
            private _en = _u findNearestEnemy _u;
            if (isNull _en || {!alive _en} || {!(_en isKindOf "CAManBase")} || {captive _en} || {(_u knowsAbout _en) < _esik}) then { continue };
            private _M = (([_u, "siperOnTaramaM", _Mb] call FUNC(profilDeger)) max 3) min 40;   // v8.738: ACIK arazide 2x, ORMAN / KENTSEL'de 0.6x
            private _d = _u distance2D _en;
            if (_d < 25 || {_d > 300}) then { continue };
            // sinif (COVER-OLCUM ile ayni): siper (<= 4 m) / acik / uzak engel
            private _pa = (getPosASL _u) vectorAdd [0, 0, 0.9];
            private _ht = lineIntersectsSurfaces [eyePos _en, _pa, _en, _u, true, 1, "VIEW", "NONE"];
            _say set ["tarama", (_say get "tarama") + 1];
            if (_ht isNotEqualTo [] && {(((_ht select 0) select 0) distance _pa) < 4}) then { _u setVariable [QGVAR(onTaramaT), time + _cd]; continue };   // zaten gercek siperde
            if (_ht isEqualTo [] && {!(terrainIntersectASL [eyePos _en, _pa])}) then { continue };   // acikta: coverHug / acikSiper kurtarir
            _say set ["uzak", (_say get "uzak") + 1];
            _u setVariable [QGVAR(onTaramaT), time + _cd];
            if ([_u, _en, _M] call FUNC(acikSiper)) then {
                _say set ["gonder", (_say get "gonder") + 1];
                _n = _n + 1;
                if (_logN < 25) then {
                    _logN = _logN + 1;
                    diag_log format ["[SIPER-ON-TARAMA] %1 | %2 | dusman %3 m, gizli ama sert siper yok (uzak engel) -> yakin siper (<= %4 m) bulundu ve gonderildi", groupId _g, name _u, round _d, _M];
                };
            };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say get "tarama") > 0) then {
                diag_log format ["[SIPER-ON-TARAMA-OZET] 60 sn: taranan %1 | uzak engel (siper degil) %2 | yakin siper bulunup gonderilen %3", _say get "tarama", _say get "uzak", _say get "gonder"];
            };
            { _say set [_x, 0]; } forEach ["tarama", "uzak", "gonder"];
        };
    };
};
true
