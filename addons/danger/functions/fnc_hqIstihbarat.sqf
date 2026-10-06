#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KUMANDA MODULU: ISTIHBARAT / BILGI PAYLASIMI (SPOTREP agi).
 *
 * Doktrin (ozet duzeyinde bilinen genel ilke; orijinal kaynak okunmadi): bir birligin gordugu dusman, telsizle komuta ve komsu birliklere HEMEN raporlanir (SALUTE / SPOTREP);
 * komsular bilgiyi gecikmeli ve hata payli alir, telsiz menzili / yetenegi siniri belirler; eski bilgi (yaslanmis) guvenilmez.
 * Upstream LAMBS (doShareInformation): paylasim yalniz tek birimin "hedef buldugu" anda ve kisa menzilde (varsayilan 350 m) yapilir; telsiz agi yok.
 *
 * ISLEM (5 sn'de bir, taraf basina):
 *   MUHBIR: tahtadaki her grubun lideri nearTargets ile bildigi dusman nesneleri; kosul: knowsAbout >= 1.2 (gorulmus, yalniz duyulmamis), son gorus <= 20 sn, konum hatasi <= 40 m.
 *   ALICI: ayni taraftan baska grup, lider telsiz menzilinde (hqIstihbaratM, varsayilan 1500 m), CARELESS degil, bu dusmani henuz bilmiyor (knowsAbout < 0.8), son 25 sn'de ayni nesne ona bildirilmemis.
 *   BILDIRIM: 2-6 sn gecikmeyle (telsiz / aktarma) reveal; seviye = min(muhbirin bilgisi, maxRevealValue), yaslandikca duser (20 sn -> -%40), en az 0.9.  (Konum o anki gercek konum: bilgi en cok 20 sn yasinda oldugu icin sinirli "hile".)
 *   TUR SINIRI: 8 bildirim. Telsiz kapaliysa (lambs_main_radioDisabled) hic yapmaz.
 *
 * v8.72 SIS (fog of war) — rapor artik MUKEMMEL degil (hepsi TASARIM tahmini, doktrin sayisi degil; genel ilke: raporlar gec, eksik, belirsiz ve yaslanmis gelir):
 *   - telsiz sarti: muhbir lider VE alici lider telsiz tasimali (ItemRadio / ACRE / TFAR); yoksa rapor gitmez (SAYAC: telsiz yok)
 *   - muhbir ritmi: ayni muhbir grup 15 sn'de en fazla bir rapor turu, turda en fazla 3 dusman (en yakin 3: eksik / secici rapor)
 *   - gecikme: 6-16 sn + mesafe (+6 sn / 1500 m) + muhbir bastirilmis / temasta (+8-18 sn) + alici temasta (+3 sn)  (rapor hazirlama + aktarma + isleme)
 *   - teslim guvenilirligi: 600 m'e kadar %100, menzil sinirinda %35 (telsiz kalitesi / parazit); duserse rapor kaybolur ([HQ-ISTIHBARAT] DUSTU)
 *   - seviye (belirsizlik): muhbir bilgisi x yas faktoru x mesafe faktoru x bastirma faktoru; 0.5 - maxReveal. Dusuk seviye = alicinin konum hatasi buyuk (motor: reveal seviyesi -> targetKnowledge konum hatasi);
 *     gecikme sirasinda dusman hareket ettiyse alici ESKI bilgiyle karsilanir (teslim aninda olcum seviyesi yaslanma ile duser).
 *   - kapatma: lambs_danger_hqSisOff = true -> eski mukemmel paylasim (2-6 sn, seviye >= 0.9)
 * Kapatma: lambs_danger_hqIstihbaratV1 = false; menzil: lambs_danger_hqIstihbaratM.   Log: [HQ-ISTIHBARAT] (ilk 200 satir), [HQ-ISTIHBARAT-OZET] sayac (90 sn)
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Durum tahtasi <ARRAY of HASHMAP>
 *
 * Return Value: Bildirim yapildi mi <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_tahta", [], [[]]]];

if (missionNamespace getVariable ["lambs_main_radioDisabled", false]) exitWith {false};
if ((count _tahta) < 2) exitWith {false};

private _menzil = missionNamespace getVariable ["lambs_danger_hqIstihbaratM", 1500];
private _maxSeviye = missionNamespace getVariable ["lambs_main_maxRevealValue", 1.5];
private _sis = !(missionNamespace getVariable ["lambs_danger_hqSisOff", false]);
private _sd = (missionNamespace getVariable ["lambs_danger_hqSisSiddet", 0.4]) max 0 min 1;   // v8.74: sis siddeti (0 = eski mukemmel, 1 = tam sis); varsayilan 0.4: oyuncu karsisinda PvE zorlugu korunur
private _telsizMi = {
    params ["_u"];
    // v8.89: grup LIDERI (komutan) telsiz tasir kabul edilir — RPT e020cec6: IS (LOP_ISTS) askerlerinde ItemRadio yok -> 'muhbir / alici telsiz yok' 38 kez, EAST'te HIC istihbarat paylasimi olmadi,
    //   USMC'de oldu (asimetri: esya listesi yapayligi, doktrin degil). Lider = implicit kisa menzilli telsiz; esya aramasi diger birimler icin kalir.
    if (_u isEqualTo (leader (group _u))) exitWith {true};
    private _oge = (assignedItems _u) + (items _u);
    (_oge findIf {private _k = toLower _x; (_k find "radio") >= 0 || {(_k find "prc") >= 0} || {_k find "tf_" == 0}}) > -1
};
// v8.83 RTO: grubun telsiz gucu — 1 = RTO canli (uzun menzil), 0.4 = yalniz liderin kisa menzilli telsizi, 0 = telsiz yok
private _grupTelsiz = {
    params ["_g"];
    private _rto = _g getVariable ["lambs_danger_rto", objNull];
    if (!isNull _rto && {alive _rto} && {(group _rto) isEqualTo _g}) exitWith {1};
    private _lw = leader _g;
    if ([_lw] call _telsizMi) exitWith { [1, 0.4] select (_g getVariable ["lambs_danger_rtoAtandi", false]) };   // RTO atanmis ama olu -> yalniz liderin kisa menzilli telsizi
    0
};
if (isNil "lambs_danger_hqIstSay") then { lambs_danger_hqIstSay = createHashMap; lambs_danger_hqIstOzetT = time + 90; };
private _say = { params ["_k"]; lambs_danger_hqIstSay set [_k, (lambs_danger_hqIstSay getOrDefault [_k, 0]) + 1]; };

// 1) muhbir verisi: nesne -> [nesne, en iyi seviye, son gorus, muhbir grup]
private _temaslar = createHashMap;
{
    private _g = _x get "g";
    private _l = leader _g;
    if ((behaviour _l) isEqualTo "CARELESS") then { continue };
    if (_sis) then {
        private _rf = [_g] call _grupTelsiz;
        if (_rf <= 0) then { ["muhbir telsiz yok"] call _say; continue };
        _g setVariable ["lambs_danger_hqTelsizF", _rf];
        if ((time - (_g getVariable ["lambs_danger_hqIstMuhbirT", -999])) < 15) then { continue };
    };
    {
        _x params ["_pos", "_tip", "_ts", "_cost", "_obj"];
        if (isNull _obj || {!alive _obj} || {(side _obj) getFriend _taraf >= 0.6} || {(side _obj) isEqualTo civilian}) then { continue };
        private _k = _l knowsAbout _obj;
        if (_k < 1.2) then { continue };
        private _tk = _l targetKnowledge _obj;
        if ((time - (_tk select 2)) > 20 || {(_tk select 5) > 40}) then { continue };
        private _anahtar = netId _obj;
        private _eski = _temaslar getOrDefault [_anahtar, []];
        if (_eski isEqualTo [] || {_k > (_eski select 1)}) then {
            _temaslar set [_anahtar, [_obj, _k, _tk select 2, _g]];
        };
    } forEach (_l nearTargets 600);
} forEach _tahta;
if (count _temaslar isEqualTo 0) exitWith {false};

// 2) alicilar
if (isNil "lambs_danger_hqIstGecmis") then { lambs_danger_hqIstGecmis = createHashMap; };
private _yapilan = 0;
{
    if (_yapilan >= 8) exitWith {};
    private _bilgi = _temaslar get _x;
    _bilgi params ["_o", "_k", "_son", "_muhbir"];
    private _muhbirL = leader _muhbir;
    private _yas = time - _son;
    private _seviye = ((_k * (1 - ((_yas / 20) * 0.4))) min _maxSeviye) max 0.9;
    private _muhbirBask = if (_sis) then { (((units _muhbir) select {alive _x}) apply {getSuppression _x}) call BIS_fnc_arithmeticMean } else { 0 };
    private _muhbirMesgul = _sis && {(_muhbirBask > 0.4) || {_muhbir getVariable ["lambs_danger_isRetreating", false]}};

    {
        if (_yapilan >= 8) exitWith {};
        private _a = _x get "g";
        if (_a isEqualTo _muhbir) then { continue };
        private _aL = leader _a;
        private _mzr = _menzil * ((_muhbir getVariable ["lambs_danger_hqTelsizF", 1]) max 0.1);
        if ((_aL distance2D _muhbirL) > _mzr || {(behaviour _aL) isEqualTo "CARELESS"}) then { continue };
        if ((_a knowsAbout _o) >= 0.8) then { continue };
        if (_sis && {!([_aL] call _telsizMi)}) then { ["alici telsiz yok"] call _say; continue };
        private _mesafe = _aL distance2D _muhbirL;
        // teslim guvenilirligi: 600 m'e kadar %100, menzil sinirinda %35
        private _guv = 1 - (0.65 * _sd * (((_mesafe - 600) max 0) / ((_mzr - 600) max 1)));
        if (_sis && {(random 1) > _guv}) then { ["rapor kayboldu (parazit/menzil)"] call _say; continue };
        private _gk = format ["%1|%2", groupId _a, netId _o];
        if ((time - (lambs_danger_hqIstGecmis getOrDefault [_gk, -999])) < 25) then { continue };
        lambs_danger_hqIstGecmis set [_gk, time];
        _yapilan = _yapilan + 1;

        private _gecikme = 2 + (random 4);
        private _sevYeni = _seviye;
        if (_sis) then {
            _gecikme = (2 + (random 4)) + _sd * ((4 + (random 10)) + ((_mesafe / 1500) * 6) + ([0, 8 + (random 10)] select _muhbirMesgul) + ([0, 3] select ((_a getVariable ["lambs_danger_contact", 0]) > time)));
            // belirsizlik: seviye teslim ani yasina (gecikme dahil) + mesafe + bastirmaya gore dusurulur; alt sinir 0.5
            private _yasT = _yas + _gecikme;
            private _f0 = ((1 - ((_yasT / 40) * 0.5)) max 0.4) * ((1 - (_mesafe / ((_menzil * 2) max 1))) max 0.5) * (1 - (_muhbirBask * 0.3));
            private _f = 1 - ((1 - _f0) * _sd);
            _sevYeni = ((_k * _f) min _maxSeviye) max 0.5;
            ["rapor teslim"] call _say;
        };

        [{
            params ["_ag", "_hedef", "_sev"];
            if (!isNull _ag && {alive _hedef} && {alive (leader _ag)}) then { _ag reveal [_hedef, _sev]; };
        }, [_a, _o, _sevYeni], _gecikme] call CBA_fnc_waitAndExecute;
        _muhbir setVariable ["lambs_danger_hqIstMuhbirT", time];

        if (isNil "lambs_danger_hqIstN") then { lambs_danger_hqIstN = 0; };
        if (lambs_danger_hqIstN < 200) then {
            lambs_danger_hqIstN = lambs_danger_hqIstN + 1;
            diag_log format [
                "[HQ-ISTIHBARAT] %1 | muhbir %2 -> alici %3 | hedef %4 (%5) | muhbirden %6 m, alicidan %7 m | seviye %8 (yas %9 sn)",
                _taraf, groupId _muhbir, groupId _a, typeOf _o, ["AI", "OYUNCU"] select (isPlayer _o),
                round (_muhbirL distance2D _o), round (_aL distance2D _o), _sevYeni toFixed 2, round _yas
            ];
            diag_log format ["[HQ-ISTIHBARAT] ... SIS | gecikme %1 sn | mesafe %2 m | guvenilirlik %3 | muhbir bastirma %4 | sis:%5", _gecikme toFixed 1, round _mesafe, _guv toFixed 2, _muhbirBask toFixed 2, _sis];
        };
    } forEach _tahta;
} forEach (keys _temaslar);

// eski kayitlari temizle
if (count lambs_danger_hqIstGecmis > 400) then {
    private _sil = [];
    { if ((time - _y) > 60) then { _sil pushBack _x; }; } forEach lambs_danger_hqIstGecmis;
    { lambs_danger_hqIstGecmis deleteAt _x; } forEach _sil;
};

if (time > lambs_danger_hqIstOzetT) then {
    lambs_danger_hqIstOzetT = time + 90;
    if (count lambs_danger_hqIstSay > 0) then { diag_log format ["[HQ-ISTIHBARAT-OZET] son 90 sn: %1", (keys lambs_danger_hqIstSay) apply {format ["%1:%2", _x, lambs_danger_hqIstSay get _x]}]; };
    lambs_danger_hqIstSay = createHashMap;
};

_yapilan > 0
