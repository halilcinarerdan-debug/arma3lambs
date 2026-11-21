#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DUSUNME HIZI (v8.601; kullanici: 'ai kodlarda kabaca yuzde 20 daha hizli dusunur, sicak temas kisimlarini; cqb boyle kalsin'): karar / algi izleyicilerinin dongu bekleme suresini SICAK TEMASTA kisaltir.
 * Sicak temas = yerel, oyuncusuz bir AI grubu temasta (QGVAR(contact) > time); bayrak 1 sn'de bir yenilenir (allGroups taramasi ucuz). Temas yokken sure DEGISMEZ (bosta ek yuk yok).
 * Carpan: CBA lambs_danger_dusunHizi (0.5-3, varsayilan 1.25 = %25 daha hizli; 1 = eski); ONEMLI izleyiciler (ikinci parametre true: ates ustunlugu, ates-hareket, pusu tepkisi, patlayici, kacis, hedef siper, ufuk / sektor / gizli algi,
 *   yeniden doldurma siperi, lider senkronu, komutan karar onbellegi) CBA lambs_danger_dusunHiziOnemli (varsayilan 1.30 = %30). Sure = bekleme / carpan.
 * Kullanan izleyiciler (CQB izleyicileri KULLANMAZ): atisUstunlugu, atesHareket, hedefSiper, reloadCover, gizliAlgi, leaderSync, ozguven, pusuTepki, sektorBakis, ufukAlgi, acikBekleme, haltKur, kacis, kamuflaj,
 *   sinsiGeri, pusu, patlayici, buddyBond, dispersion, fireSupport, gelisYonu, noktaEleman, tehlikeAlani, rearGuard, mermiDisiplin, combatGevset, moral + fnc_tactics komutan karar onbellegi.
 *
 * Arguments:
 * 0: Taban bekleme suresi (sn) <NUMBER>
 * 1: Onemli izleyici mi (%30 carpani) <BOOL> (varsayilan false)
 * 2: CQB izleyicisi mi (v8.603: CBA lambs_danger_dusunHiziCqb, varsayilan 1.10 = %10; kullanici: 'cqbde islemci yuku artsin yuzde 10 daha hizli dusunsunler') <BOOL> (varsayilan false)
 * 3: Izleyici adi <STRING> (v8.681: yalniz OLCUM icin; bos = olcum yok; bekleme suresini DEGISTIRMEZ)
 *
 * Return Value: Bekleme suresi (sn) <NUMBER>
 * Public: No
*/

params [["_s", 1, [0]], ["_onemli", false, [false]], ["_cqb", false, [false]], ["_ad", "", [""]]];
private _h = ((missionNamespace getVariable [if (_cqb) then {"lambs_danger_dusunHiziCqb"} else {["lambs_danger_dusunHizi", "lambs_danger_dusunHiziOnemli"] select _onemli}, if (_cqb) then {1.1} else {[1.25, 1.3] select _onemli}]) max 0.5) min 3;   // v8.718: ust sinir 2 -> 3 (kullanici: 'dusunme hizlarini oyuncu seviyesine cikarabilmek icin limiti 2 yerine 3')
private _sonuc = _s;
if (_h isNotEqualTo 1) then {
    if (time > (missionNamespace getVariable ["lambs_danger_sicakT", -1])) then {
        missionNamespace setVariable ["lambs_danger_sicakT", time + 1];
        missionNamespace setVariable ["lambs_danger_sicakTemas", (allGroups findIf { local _x && {(_x getVariable [QGVAR(contact), 0]) > time} && {((units _x) findIf {isPlayer _x}) < 0} }) >= 0];
    };
    if (missionNamespace getVariable ["lambs_danger_sicakTemas", false]) then { _sonuc = _s / _h; };
};

// v8.681 DUSUNME HIZI OLCUMU (kullanici: '6 dusunme hizini etkiler mi'; YALNIZ OLCUM, bekleme suresi DEGISMEZ): izleyici adi (4. parametre) verilen her cagri icin ardisik iki cagri arasi GERCEKLESEN sure (bekleme + govde + zamanlayici gecikmesi)
//   ile ISTENEN bekleme (_sonuc) karsilastirilir; 60 sn'de bir [PERF-DUSUN] oranin en yuksek 12 izleyicisini yazar. Oran ~1.0-1.5 saglikli, >= 2 = izleyici istenen hizda donemiyor (yuk / agir govde). CBA perfOlcum (acik).
if (_ad isNotEqualTo "" && {missionNamespace getVariable ["lambs_danger_perfOlcum", true]}) then {
    private _pH = missionNamespace getVariable ["lambs_danger_perfDH", createHashMap];
    if (isNil {missionNamespace getVariable "lambs_danger_perfDH"}) then {
        missionNamespace setVariable ["lambs_danger_perfDH", _pH];
        missionNamespace setVariable ["lambs_danger_perfDT", diag_tickTime + 60];
    };
    private _now = diag_tickTime;
    private _scr = if (isNil "_thisScript") then {"u"} else {str _thisScript};
    private _k = _ad + "|" + _scr;
    private _e = _pH getOrDefault [_k, [-1, 0, 0, 0, 0, 0]];   // [sonT, sonIstenen, n, toplamIstenen, toplamGerceklesen, enUzun]
    if ((_e select 0) >= 0) then {
        private _act = _now - (_e select 0);
        _e set [2, (_e select 2) + 1];
        _e set [3, (_e select 3) + (_e select 1)];
        _e set [4, (_e select 4) + _act];
        _e set [5, (_e select 5) max _act];
    };
    _e set [0, _now];
    _e set [1, _sonuc];
    _pH set [_k, _e];
    if (_now > (missionNamespace getVariable ["lambs_danger_perfDT", _now + 60])) then {
        missionNamespace setVariable ["lambs_danger_perfDT", _now + 60];
        private _agg = createHashMap;
        {
            private _nm = (_x splitString "|") select 0;
            private _v = _pH get _x;
            private _a2 = _agg getOrDefault [_nm, [0, 0, 0, 0]];
            _a2 set [0, (_a2 select 0) + (_v select 2)];
            _a2 set [1, (_a2 select 1) + (_v select 3)];
            _a2 set [2, (_a2 select 2) + (_v select 4)];
            _a2 set [3, (_a2 select 3) max (_v select 5)];
            _agg set [_nm, _a2];
            _v set [2, 0]; _v set [3, 0]; _v set [4, 0]; _v set [5, 0];
        } forEach (keys _pH);
        private _satir = [];
        {
            private _v = _agg get _x;
            if ((_v select 0) >= 3 && {(_v select 1) > 0}) then { _satir pushBack [(_v select 2) / (_v select 1), _x, _v]; };
        } forEach (keys _agg);
        _satir sort false;
        if (_satir isNotEqualTo []) then {
            diag_log format ["[PERF-DUSUN] 60 sn: izleyici dongu hizi (gerceklesen / istenen bekleme; ~1-1.5 saglikli, >= 2 yavas) | izleyici sayisi %1 | %2", count _satir,
                ((_satir select [0, 12]) apply { _x params ["_o", "_nm", "_v"]; format ["%1 x%2 (n %3, istenen %4 s, gerceklesen %5 s, en uzun %6 s)", _nm, _o toFixed 2, _v select 0, ((_v select 1) / (_v select 0)) toFixed 2, ((_v select 2) / (_v select 0)) toFixed 2, (_v select 3) toFixed 1] }) joinString " | "];
        };
    };
};
_sonuc
