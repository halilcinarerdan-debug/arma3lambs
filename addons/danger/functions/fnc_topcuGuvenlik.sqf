#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPCU ATIS GUVENLIGI (v8.338) — bir nokta icin dolayli atisin yapilip yapilamayacagini soyler.
 *   - DOST MESAFESI: en yakin dost birim >= RED + 20 m olmali. [K] TC 3-21.76 'Risk estimate distance' (RED degerleri fnc_topcuRed).
 *   - DANGER CLOSE: en yakin dost < 600 m ise 'tehlikeli yakin' (dc = true). [K] TC 3-21.76: hedef dost birlige <= 600 m (havan / sahra) -> DANGER CLOSE; duzeltme 'creeping' <= 100 m, bracketing yok.
 *   - ATESE YASAK ALAN (NFA): haritada adi 'nfa' ile baslayan isaret (daire / elips / dikdortgen; ikon ise 100 m) icinde ya da yarica + 100 m yakininda atis YOK. [K] TC 3-21.76 (NFA: ates yasak alani kavrami);
 *     'nfa' isim kurali ve +100 m tampon [T] (tasarim).
 *   - SIVIL: hedefe < 120 m'de canli sivil varsa atis YOK. [T] (ayirt etme / orantililik ilkesi; sayi tasarim).
 *
 * Arguments:
 * 0: Taraf (ates eden) <SIDE>
 * 1: Hedef konumu <ARRAY>
 * 2: RED (m) <NUMBER>
 * 3: Yalniz NFA kontrolu (dost mesafesi ve sivil bakilmaz; plan atisi bu mesafeleri kendi denetler) <BOOL> (varsayilan false)
 *
 * Return Value: [uygun <BOOL>, neden <STRING>, en yakin dost mesafesi <NUMBER>, danger close <BOOL>, en yakin dost konumu <ARRAY>]
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_poz", [], [[]]], ["_red", 455, [0]], ["_nfaSadece", false, [false]]];
if (_poz isEqualTo []) exitWith {[false, "nokta yok", 0, false, []]};

private _dF = 99999;
private _fP = [];
{
    if (alive _x && {(side (group _x)) isEqualTo _taraf}) then {
        private _d = _x distance2D _poz;
        if (_d < _dF) then { _dF = _d; _fP = getPosATL _x; };
    };
} forEach allUnits;

private _nfa = "";
{
    private _m = _x;
    if (_nfa isEqualTo "" && {((toLower _m) select [0, 3]) isEqualTo "nfa"}) then {
        private _r = (selectMax (markerSize _m)) max 100;
        if ((_poz distance2D (markerPos _m)) < (_r + 100)) then { _nfa = _m; };
    };
} forEach allMapMarkers;

private _siv = -1;
if (!_nfaSadece) then { _siv = allUnits findIf {alive _x && {(side (group _x)) isEqualTo civilian} && {(_x distance2D _poz) < 120}}; };

private _neden = "";
if (_nfa isNotEqualTo "") then {
    _neden = format ["ATESE YASAK ALAN (NFA isareti %1)", _nfa];
} else {
    if (_siv >= 0) then {
        _neden = "sivil < 120 m (NFA)";
    } else {
        if (!_nfaSadece && {_dF < (_red + 20)}) then { _neden = format ["dost %1 m < RED %2 m + 20", round _dF, _red]; };
    };
};
[_neden isEqualTo "", _neden, _dF, _dF < 600, _fP]
