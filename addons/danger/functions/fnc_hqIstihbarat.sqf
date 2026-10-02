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
 * Kapatma: lambs_danger_hqIstihbaratV1 = false; menzil: lambs_danger_hqIstihbaratM.   Log: [HQ-ISTIHBARAT] (ilk 200 satir)
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

// 1) muhbir verisi: nesne -> [nesne, en iyi seviye, son gorus, muhbir grup]
private _temaslar = createHashMap;
{
    private _g = _x get "g";
    private _l = leader _g;
    if ((behaviour _l) isEqualTo "CARELESS") then { continue };
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

    {
        if (_yapilan >= 8) exitWith {};
        private _a = _x get "g";
        if (_a isEqualTo _muhbir) then { continue };
        private _aL = leader _a;
        if ((_aL distance2D _muhbirL) > _menzil || {(behaviour _aL) isEqualTo "CARELESS"}) then { continue };
        if ((_a knowsAbout _o) >= 0.8) then { continue };
        private _gk = format ["%1|%2", groupId _a, netId _o];
        if ((time - (lambs_danger_hqIstGecmis getOrDefault [_gk, -999])) < 25) then { continue };
        lambs_danger_hqIstGecmis set [_gk, time];
        _yapilan = _yapilan + 1;

        [{
            params ["_ag", "_hedef", "_sev"];
            if (!isNull _ag && {alive _hedef} && {alive (leader _ag)}) then { _ag reveal [_hedef, _sev]; };
        }, [_a, _o, _seviye], 2 + (random 4)] call CBA_fnc_waitAndExecute;

        if (isNil "lambs_danger_hqIstN") then { lambs_danger_hqIstN = 0; };
        if (lambs_danger_hqIstN < 200) then {
            lambs_danger_hqIstN = lambs_danger_hqIstN + 1;
            diag_log format [
                "[HQ-ISTIHBARAT] %1 | muhbir %2 -> alici %3 | hedef %4 (%5) | muhbirden %6 m, alicidan %7 m | seviye %8 (yas %9 sn)",
                _taraf, groupId _muhbir, groupId _a, typeOf _o, ["AI", "OYUNCU"] select (isPlayer _o),
                round (_muhbirL distance2D _o), round (_aL distance2D _o), _seviye toFixed 2, round _yas
            ];
        };
    } forEach _tahta;
} forEach (keys _temaslar);

// eski kayitlari temizle
if (count lambs_danger_hqIstGecmis > 400) then {
    private _sil = [];
    { if ((time - _y) > 60) then { _sil pushBack _x; }; } forEach lambs_danger_hqIstGecmis;
    { lambs_danger_hqIstGecmis deleteAt _x; } forEach _sil;
};

_yapilan > 0
