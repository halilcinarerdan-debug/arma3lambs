#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 SUNUCU: OYUNCU KOMUTANIN TOPCU ATES DESTEGI ISTEGI (v8.391; kullanici: 'coop icin komutan olarak topcu ates destegi cagiralim, AI destegi de istiyorum').
 * Oyuncu (gozlemci) haritadan hedef secer; sunucu dogrular, AI topcu araclarini (taraf ayni, nisanci AI, sunucuda yerel, TOPCU_YOK degil) ates ettirir. Guvenlik fnc_topcuGuvenlik ile (v8.338):
 *   - HE: en yakin dost >= RED + 20 m (CBA c2RedUygula = false ise yalniz NFA isareti + sivil), NFA isareti, sivil < 120 m. GOZLEMLI atis oldugu icin danger close (600 m) yasagi YOK; danger close'ta yayilim 15 m'ye iner.
 *   - SMOKE (duman) / ILLUM (aydinlatma): yalniz NFA isareti (yaralayici degil).
 * Atis: topcuAtisHazirla (hareket emri / davranis / yabanci mermi onlemi) + top basina 2 sn kademeli doArtilleryFire, hedef etrafinda CBA c2TopcuYayilim m yayilim, top basina CBA c2TopcuMermi mermi,
 *   en fazla CBA c2TopcuMaksTop top (en yakin toplar). Gozlemci basina CBA c2TopcuBekleme sn bekleme. SHOT / SPLASH / COMPLETE bildirimi TAHMINIDIR (mermi dususu gozlemlenmez; ETA getArtilleryETA'dan).
 * Gonderen dogrulamasi: remoteExecutedOwner = gozlemci biriminin sahibi (baskasi adina istek yapilamaz). Log: [C2-TOPCU].
 *
 * Arguments:
 * 0: Tur <STRING> ("HE" / "SMOKE" / "ILLUM")
 * 1: Hedef konum <ARRAY>
 * 2: Gozlemci (komutan oyuncu) <OBJECT>
 *
 * Return Value: None
 * Public: No
*/

params [["_tur", "HE", [""]], ["_poz", [], [[]]], ["_obs", objNull, [objNull]]];
if (!isServer) exitWith {};

private _gon = remoteExecutedOwner;
if (_gon isEqualTo 0) then { _gon = clientOwner; };

private _bildir = {
    params ["_m"];
    [format ["[C2] TOPCU: %1", _m]] remoteExecCall ["systemChat", _gon];
    diag_log format ["[C2-TOPCU] %1 | %2", name _obs, _m];
};

if (isNull _obs || {!isPlayer _obs} || {(owner _obs) isNotEqualTo _gon}) exitWith {
    diag_log format ["[C2-TOPCU] RED: gonderen / gozlemci uyusmuyor (gonderen %1)", _gon];
};
if (!([_obs, false] call FUNC(c2Yetkili))) exitWith { ["Yetkin yok (grup lideri / komutan degiskeni)."] call _bildir; };
if !(_tur in ["HE", "SMOKE", "ILLUM"]) exitWith { [format ["Gecersiz tur: %1", _tur]] call _bildir; };
if (count _poz < 2 || {!((_poz select 0) isEqualType 0)} || {!((_poz select 1) isEqualType 0)}) exitWith { ["Gecersiz hedef konumu."] call _bildir; };
_poz = [_poz select 0, _poz select 1, 0];
if (surfaceIsWater _poz) exitWith { ["Hedef suda; konum gecersiz."] call _bildir; };

private _bekleme = missionNamespace getVariable ["lambs_danger_c2TopcuBekleme", 45];
private _kalan = _bekleme - (time - (_obs getVariable [QGVAR(c2TopcuT), -999]));
if (_kalan > 0) exitWith { [format ["Bekleme suresi: %1 sn (onceki gorevin ardindan)", ceil _kalan]] call _bildir; };

private _taraf = side (group _obs);
private _adayAll = vehicles select {
    alive _x && {(side (group _x)) isEqualTo _taraf} && {(getNumber (configOf _x >> "artilleryScanner")) > 0}
    && {!isNull (gunner _x)} && {!isPlayer (gunner _x)} && {canFire _x}
    && {!("TOPCU_YOK" in [_x getVariable ["lambs_danger_gorev", ""], (group (gunner _x)) getVariable ["lambs_danger_gorev", ""]])}
};
private _yerelDegil = {!local _x} count _adayAll;
private _adaylar = _adayAll select {local _x};
if (_adaylar isEqualTo []) exitWith {
    [format ["Kullanilabilir AI topcu yok (%1 top, %2 tanesi sunucuda yerel degil)", count _adayAll, _yerelDegil]] call _bildir;
};

private _red = missionNamespace getVariable ["lambs_danger_c2RedUygula", true];
private _kontrol = [];   // [top, mermi, mesafe, danger close, neden]
private _redler = [];
{
    private _v = _x;
    private _ammo = getArtilleryAmmo [_v];
    private _mg = switch (_tur) do {
        case "SMOKE": { (_ammo select {(toLower _x) find "smoke" >= 0}) param [0, ""] };
        case "ILLUM": { (_ammo select {((toLower _x) find "illum") >= 0 || {((toLower _x) find "flare") >= 0}}) param [0, ""] };
        default { (_ammo select {
            private _a = toLower _x;
            (_a find "smoke") < 0 && {(_a find "illum") < 0} && {(_a find "flare") < 0} && {(_a find "cluster") < 0} && {(_a find "mine") < 0}
        }) param [0, ""] };
    };
    if (_mg isEqualTo "") then {
        _redler pushBack format ["%1: %2 mermisi yok", getText (configOf _v >> "displayName"), _tur];
    } else {
        if !(_poz inRangeOfArtillery [[_v], _mg]) then {
            _redler pushBack format ["%1: hedef menzil disi", getText (configOf _v >> "displayName")];
        } else {
            private _g = [_taraf, _poz, [_v, _mg] call FUNC(topcuRed), (_tur isNotEqualTo "HE") || {!_red}] call FUNC(topcuGuvenlik);
            if (_g select 0) then {
                _kontrol pushBack [_v, _mg, _v distance2D _poz, _g select 3, ""];
            } else {
                _redler pushBack format ["%1: %2", getText (configOf _v >> "displayName"), _g select 1];
            };
        };
    };
} forEach _adaylar;

if (_kontrol isEqualTo []) exitWith {
    [format ["ATILAMAZ - %1", (_redler arrayIntersect _redler) joinString " | "]] call _bildir;
};

_kontrol = [_kontrol, [], {_x select 2}, "ASCEND"] call BIS_fnc_sortBy;
_kontrol = _kontrol select [0, (missionNamespace getVariable ["lambs_danger_c2TopcuMaksTop", 4]) max 1];

private _no = (missionNamespace getVariable ["lambs_danger_c2GorevNo", 0]) + 1;
missionNamespace setVariable ["lambs_danger_c2GorevNo", _no];
_obs setVariable [QGVAR(c2TopcuT), time];
_obs setVariable [QGVAR(c2Gorev), _no];

private _mermi = missionNamespace getVariable ["lambs_danger_c2TopcuMermi", 3];
private _yayBase = missionNamespace getVariable ["lambs_danger_c2TopcuYayilim", 25];
private _dcVar = (_kontrol findIf {_x select 3}) >= 0;
private _yay = if (_dcVar && {_tur isEqualTo "HE"}) then { _yayBase min 15 } else { _yayBase };
private _enEta = 0;
{
    _x params ["_v", "_mg", "_d", "_dc"];
    [_v, _poz, _mg] call FUNC(topcuAtisHazirla);
    private _eta = _v getArtilleryETA [_poz, _mg];
    _enEta = _enEta max _eta;
    [_v, _poz, _mg, _forEachIndex, _yay, _mermi, _obs, _no] spawn {
        params ["_tv", "_tn", "_tm", "_ti", "_ty", "_tr", "_to", "_tno"];
        sleep (2 * _ti);
        if (alive _tv && {canFire _tv} && {(_to getVariable [QGVAR(c2Gorev), -1]) isEqualTo _tno}) then {
            _tv doArtilleryFire [_tn getPos [random _ty, random 360], _tm, _tr];
        };
    };
} forEach _kontrol;

private _ad = getText (configFile >> "CfgMagazines" >> ((_kontrol select 0) select 1) >> "displayName");
if (_ad isEqualTo "") then { _ad = (_kontrol select 0) select 1; };
[format [
    "gorev #%1 %2: %3 top x %4 mermi (%5) | hedef GRID %6 | en yakin top %7 m | ETA ~%8 sn | yayilim %9 m%10",
    _no, _tur, count _kontrol, _mermi, _ad, mapGridPosition _poz, round ((_kontrol select 0) select 2), round _enEta, round _yay,
    if (_dcVar && {_tur isEqualTo "HE"}) then { " | DANGER CLOSE (dost <= 600 m)" } else { "" }
]] call _bildir;
if (_redler isNotEqualTo []) then { diag_log format ["[C2-TOPCU] gorev #%1 | atmayan toplar: %2", _no, (_redler arrayIntersect _redler) joinString " | "]; };

// tahmini SHOT / SPLASH / COMPLETE (mermi dususu gozlemlenmez)
[{ params ["_o", "_m"]; [_m] remoteExecCall ["systemChat", _o]; }, [_gon, format ["[C2] TOPCU #%1: SHOT (tahmini) - mermiler yolda", _no]], 3] call CBA_fnc_waitAndExecute;
if (_enEta > 6) then {
    [{ params ["_o", "_m"]; [_m] remoteExecCall ["systemChat", _o]; }, [_gon, format ["[C2] TOPCU #%1: SPLASH (tahmini ~5 sn)", _no]], _enEta - 3] call CBA_fnc_waitAndExecute;
};
[{ params ["_o", "_m"]; [_m] remoteExecCall ["systemChat", _o]; }, [_gon, format ["[C2] TOPCU #%1: ROUNDS COMPLETE (tahmini) - gorev bitti, duzeltme icin yeni istek ver", _no]], _enEta + (_mermi * 5) + (count _kontrol) * 2] call CBA_fnc_waitAndExecute;
