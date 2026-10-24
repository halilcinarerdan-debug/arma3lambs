#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TACIZ ATISI (HARASSING FIRE) — v8.338; kullanici: 'taciz atisi ... kitaba uygun'.
 * Kitaptaki tanim: taciz atesi dusmanin dinlenmesini bozmak, hareketini kisitlamak ve moralini dusurmek icin yapilan KUCUK, DUZENSIZ, genelde gozlemsiz dolayli atistir; planlanan etkilerden biridir
 *   (harassing, interdiction, suppressive, destruction, deception). [K] FM 3-34 (2014) 1-138 (etki turleri), MCWP 3-11.1 (taciz atesi ile dusman faaliyetini bozma), FM 3-34 7678 ('non-observed H&I').
 *   Kaynak setinde taciz atesi icin sayisal esik YOKTUR; asagidaki tum sayilar [T] tasarimdir.
 * ISLEYIS (fnc_dronTopcu her taraf icin 'taciz zamani' geldikce cagirir; zaman DUZENSIZ: CBA 'tacizAralik' (240 sn) ile 2x arasi rastgele, gece x0.6):
 *   - HEDEF: taraf temas BELLEGINDEKI (fnc_dronTopcu: gozlemlenmis dusman kumeleri) 'bayat' konum: son gorulmesi 60-900 sn once, deger >= 3, daha once <= 2 kez taciz edilmis, son tacizden >= 600 sn.
 *     Yani gercek istihbarata dayanir (rastgele nokta degil) ve su an GOZLENMIYOR (gozlemli olsa 'gozlemli atis' yapilir).
 *   - EMNIYET: gozlemsiz ates oldugu icin DANGER CLOSE alaninda (dost <= 600 m) taciz YOK; dost >= RED + 20, NFA isareti / sivil yok (fnc_topcuGuvenlik). [K: danger close, RED, NFA]
 *   - HACIM: tek top, 'tacizMermi' (2) mermi, 18-38 sn arayla, her mermi 40 m yaricapta dagitik. Taraf basina 600 sn'de 'dronTopcuButce' (30) mermi butcesi gozlemli atisla ORTAK.
 *   - Top mesgulse (son 20 sn'de ates etmis) atlanir; plan atisi / gozlemli atis onceliklidir.
 * Log: [TACIZ]. Kapatma: lambs_danger_tacizAktif (CBA) / lambs_danger_tacizOff = true.
 *
 * Arguments:
 * 0: Taraf <SIDE>
 *
 * Return Value: Atis emri verildi mi <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]]];
if (missionNamespace getVariable ["lambs_danger_tacizOff", false]) exitWith {false};

private _bk = format ["lambs_danger_dtBellek_%1", _taraf];
private _bel = missionNamespace getVariable [_bk, []];
private _bolge = (missionNamespace getVariable ["lambs_danger_dtBolge", []]) select {(_x select 1) > time};   // yakin zamanda gozlemli atis yapilan bolge taciz edilmez
private _aday = _bel select {
    private _e0 = _x;
    private _yas = time - (_e0 select 1);
    _yas >= 60 && {_yas <= 900} && {(_e0 select 2) >= 3} && {(_e0 select 3) < 3} && {(time - (_e0 select 4)) > 600} && {(_e0 param [5, 1]) >= 2} && {(_bolge findIf {((_x select 0) distance2D (_e0 select 0)) < 200}) < 0}
};
if (_aday isEqualTo []) exitWith {false};

private _butce = missionNamespace getVariable ["lambs_danger_dronTopcuButce", 30];
private _mN = (missionNamespace getVariable ["lambs_danger_tacizMermi", 2]) max 1 min 4;
if (([_taraf] call FUNC(topcuButce)) + _mN > _butce) exitWith {false};

private _topcular = ([_taraf] call FUNC(topcuListe)) select { (time - ((_x select 0) getVariable [QGVAR(dtSonAtis), -999])) > 20 };
if (_topcular isEqualTo []) exitWith {false};
{ [_x select 0] call FUNC(topcuIzle); } forEach _topcular;

// puan: deger x tazelik; en yuksekten dene
private _sirali = [_aday, [], { (_x select 2) * (1 - ((time - (_x select 1)) / 900)) }, "DESCEND"] call BIS_fnc_sortBy;
private _atildi = false;
{
    if (!_atildi) then {
        private _e = _x;
        private _aim = _e select 0;
        private _in = _topcular select { _aim inRangeOfArtillery [[_x select 0], _x select 1] };
        if (_in isNotEqualTo []) then {
            _in = [_in, [], {(_x select 0) distance2D _aim}, "ASCEND"] call BIS_fnc_sortBy;
            (_in select 0) params ["_v", "_mg"];
            private _red = [_v, _mg] call FUNC(topcuRed);
            ([_taraf, _aim, _red] call FUNC(topcuGuvenlik)) params ["_ok", "_neden", "_dF", "_dc"];
            if (_ok && {!_dc}) then {
                _atildi = true;
                [_v, _aim, _mg] call FUNC(topcuAtisHazirla);
                [_v, _aim, _mg, _mN] spawn {
                    params ["_tv", "_tn", "_tm", "_tk"];
                    for "_i" from 1 to _tk do {
                        if (!alive _tv || {!canFire _tv}) exitWith {};
                        _tv doArtilleryFire [_tn getPos [random 40, random 360], _tm, 1];
                        if (_i < _tk) then { sleep (18 + random 20); };
                    };
                };
                _e set [3, (_e select 3) + 1];
                _e set [4, time];
                private _kullanilan = [_taraf, _mN] call FUNC(topcuButce);
                diag_log format ["[TACIZ] %1 | TACIZ ATISI (harassing fire, gozlemsiz): hedef %2 (bayat temas: %3 sn once, deger %4, %5. taciz) | %6 -> %7 mermi dagitik (40 m) | en yakin dost %8 m (RED %9 m, danger close siniri 600 m) | butce %10/%11",
                    _taraf, mapGridPosition _aim, round (time - (_e select 1)), _e select 2, _e select 3, typeOf _v, _mN, round _dF, _red, _kullanilan, _butce];
            };
        };
    };
} forEach _sirali;
_atildi
