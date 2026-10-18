#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HENDEKTE YERLESME (v8.229) — SAVUN planinda bir grubun askerleri secilen hendek alaninin UZUN ekseni boyunca dagilir (her asker ayri nokta), vardiginda comelir (MIDDLE: 1.4 m hendekte siperde)
 * ve dis cevreye (tehdit yonu / objektife ters degil, objektife DOGRU degil: merkezden disa) bakar. doStop + comelme; plan bitince fnc_komutanPlanDongu cleanup'i birakir.
 * Kaynak ilkesi: ATP 3-21.8 / FM 3-21.10 mevzi: askerler hendege aralikli yerlesir, ates sektorlerine bakar (kitapta mesafe / sayi YOK; aralik = hendek uzunlugu / asker sayisi).
 * v8.252 COKLU ALAN + KAPASITE (RPT f39a5919: 8-9 kisilik gruplar kisa hendege sigmadi, bir kismi hendegin yaninda bekledi; hepsi topcu atesinde oldu): grup degiskeni lambs_danger_hendekEk = [[alan indeksi, asker sayisi], ...] varsa
 *   askerler ONCE birincil alana (kapasite kadar) sonra ek alanlara dagitilir (her alana en yakin kalan askerler); degisken yoksa eski davranis (hepsi birincil alan). Kapasite asimi [HENDEK-YERLES] satirinda yazilir.
 *   Yolda takilan asker 20 sn'de bir noktaya yeniden gonderilir (en cok 90 sn); sonuc [HENDEK-VARIS] (vardi / zaman asimi, en uzak kalan mesafe).
 * v8.243: grup 'mevziIlk' sayisini yazar; hendekteki grup LAMBS komutan beyni / buddy / dagilma / rol istasyonundan muaf (fnc_mevziDeMi); plan sonunda fnc_komutanPlanDongu 'hendekte' bayragini siler.
 * Log: [HENDEK-YERLES]
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hendek indeksi (fnc_hendekAlani LISTE) <NUMBER>
 * 2: Bakis yonu (derece; tehdit / sektor) <NUMBER>
 *
 * Return Value: Yerlestirilen asker sayisi <NUMBER>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_idx", -1, [0]], ["_dirB", 0, [0]]];
if (isNull _g || {!local _g}) exitWith {0};
private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
if (_us isEqualTo []) exitWith {0};

// ---- alan / asker dagitimi: [[alanIdx, [askerler]], ...]
private _ek = (_g getVariable [QGVAR(hendekEk), []]) select {(_x select 0) isNotEqualTo _idx};
private _dagit = [];
private _kalanU = +_us;
private _ekToplam = 0;
{ _ekToplam = _ekToplam + (_x select 1); } forEach _ek;
private _birSay = ((count _us) - _ekToplam) max 1;
private _merkez0 = (["LISTE"] call FUNC(hendekAlani)) param [_idx, []];
if (_merkez0 isNotEqualTo []) then {
    private _c0 = _merkez0 select 0;
    _kalanU = [_kalanU, [], {_x distance2D _c0}, "ASCEND"] call BIS_fnc_sortBy;
};
private _birU = _kalanU select [0, _birSay min (count _kalanU)];
_kalanU = _kalanU - _birU;
_dagit pushBack [_idx, _birU];
{
    _x params ["_eIdx", "_eSay"];
    if (_kalanU isEqualTo []) exitWith {};
    private _eAl = (["LISTE"] call FUNC(hendekAlani)) param [_eIdx, []];
    if (_eAl isNotEqualTo []) then {
        private _ec = _eAl select 0;
        _kalanU = [_kalanU, [], {_x distance2D _ec}, "ASCEND"] call BIS_fnc_sortBy;
    };
    private _eU = _kalanU select [0, _eSay min (count _kalanU)];
    _kalanU = _kalanU - _eU;
    if (_eU isNotEqualTo []) then { _dagit pushBack [_eIdx, _eU]; };
} forEach _ek;
// artakalan (sayim farki) birincil alana
if (_kalanU isNotEqualTo []) then { (_dagit select 0) set [1, (_dagit select 0 select 1) + _kalanU]; };

private _kap0 = ["KAPASITE", _idx] call FUNC(hendekAlani);
private _plan0 = _dagit select 0;
private _sayilan = 0;
private _asim = (count (_plan0 select 1)) > _kap0;
{
    _x params ["_aIdx", "_aU"];
    private _pts = ["NOKTALAR", _aIdx, count _aU] call FUNC(hendekAlani);
    if (_pts isEqualTo []) then { continue };
    _sayilan = _sayilan + (count _aU);
    diag_log format ["[HENDEK-YERLES] %1 | %2 asker hendege (alan %3, %4 nokta, kapasite %5%6) | bakis %7", groupId _g, count _aU, _aIdx, count _pts, ["KAPASITE", _aIdx] call FUNC(hendekAlani), if (_aIdx isEqualTo _idx && {_asim}) then {" - KAPASITE ASILDI: ek alan yok, sikisik"} else {""}, round _dirB];
    {
        private _u = _x;
        private _pt = _pts select (_forEachIndex min ((count _pts) - 1));
        _u setVariable [QGVAR(hendekSonuc), nil];
        _u enableAI "PATH"; _u enableAI "MOVE";
        _u doMove _pt;
        [_u, _pt, _dirB] spawn {
            params ["_u", "_pt", "_dirB"];
            private _bas = time;
            private _bit = _bas + 90;
            private _sonDM = _bas;
            waitUntil {
                sleep 1;
                if (alive _u && {(_u distance2D _pt) >= 2.5} && {(time - _sonDM) >= 20}) then { _sonDM = time; _u doMove _pt; };
                !alive _u || {(_u distance2D _pt) < 2.5} || {time > _bit}
            };
            if (alive _u) then {
                _u setVariable [QGVAR(hendekSonuc), [(_u distance2D _pt) < 2.5, _u distance2D _pt]];
                doStop _u;
                _u setUnitPos "MIDDLE";
                _u doWatch (_pt getPos [120, _dirB]);
            };
        };
    } forEach _aU;
} forEach _dagit;

// varis ozeti (92 sn sonra)
[{
    params ["_gr", "_unlar"];
    private _s = _unlar select {alive _x && {!isNil {_x getVariable QGVAR(hendekSonuc)}}};
    private _vardi = _s select {(_x getVariable QGVAR(hendekSonuc)) select 0};
    private _enUzak = 0;
    { _enUzak = _enUzak max ((_x getVariable QGVAR(hendekSonuc)) select 1); } forEach _s;
    diag_log format ["[HENDEK-VARIS] %1 | %2 asker: %3 noktada (2.5 m), %4 zaman asimi (en uzak kalan %5 m)", groupId _gr, count _s, count _vardi, (count _s) - (count _vardi), round _enUzak];
}, [_g, +_us], 92] call CBA_fnc_waitAndExecute;

_g setVariable [QGVAR(hendekte), true];
_g setVariable [QGVAR(mevziIlk), (_g getVariable [QGVAR(mevziIlk), 0]) max (count _us)];   // v8.243: fnc_tactics mevzi tutma kayip esigi (>= %60 kayipta serbest) bu sayiya gore
count _us
