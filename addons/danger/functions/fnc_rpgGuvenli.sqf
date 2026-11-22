#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RPG GUVENLIK KURALLARI (v8.746; kullanici: 'lambs rpg arastir' + 'rpg sistemi yapalim'): omuz roketatari atisinin kendine / dostuna zarar vermesini ve rezerv roketin israfini onleyen ORTAK kural seti.
 * fnc_rpgKapisi (Fired: motor / LAMBS RPG atisini iptal eder) ve fnc_rpgSistem (karar: emri vermeden once eler) ayni kurallari kullanir.
 *
 * KURALLAR (ilk ihlal edilen doner):
 *   "min"       : dusus / hedef noktasi atici >= rpgMinM (25 m) icinde (kendi patlamasi / sarapnel)
 *   "bina ici"  : atici bina ICINDE (arka alev kapali alanda oldurur)
 *   "dost hedefte" : dusus noktasinin rpgDostM (12 m) icinde dost (asker / kara araci)
 *   "geri duvar": atici gogsunden 3.5 m ARKADA nesne (duvar / arac / kaya) var (arka alev yansir)
 *   "dost arkada": 12 m icinde, atis yonunun TERSINDE (+-40 derece) dost var (arka alev konisi)
 *   "yedek"     : rpgYedek > 0 iken ZIRH BILINEN (1000 m, SEZILDI+) ve hedef zirh DEGIL ve bu roket son rpgYedek rokettense (kalan <= rpgYedek) -> piyadeye harcanmaz, zirh icin saklanir
 *
 * Arguments:
 * 0: Atici <OBJECT>
 * 1: Roketatar sinifi <STRING>
 * 2: Atis yonu (pusula derece) <NUMBER>
 * 3: Dusus / hedef noktasi ASL <ARRAY>
 * 4: Hedef zirh mi <BOOL> (varsayilan false)
 * 5: Atis yapildi mi (Fired: yuklu mermi dusulmus; kalan hesabi +1) <BOOL> (varsayilan false)
 *
 * Return Value: "" = guvenli, aksi halde ihlal edilen kural <STRING>
 *
 * Public: No
*/

params ["_unit", "_weapon", "_yon", "_imp", ["_zirhHedef", false], ["_atildi", false]];

private _minM = ((missionNamespace getVariable ["lambs_danger_rpgMinM", 25]) max 10) min 80;
private _dostM = ((missionNamespace getVariable ["lambs_danger_rpgDostM", 12]) max 4) min 40;
private _yedek = ((missionNamespace getVariable ["lambs_danger_rpgYedek", 1]) max 0) min 4;

if ((_unit distance _imp) < _minM) exitWith {"min"};
if ((insideBuilding _unit) > 0.5) exitWith {"bina ici"};

private _taraf = side group _unit;
private _dost = ((ASLToAGL _imp) nearEntities [["CAManBase", "LandVehicle"], _dostM]) findIf {
    alive _x && {_x isNotEqualTo _unit} && {(_taraf getFriend (side group _x)) >= 0.6}
};
if (_dost >= 0) exitWith {"dost hedefte"};

private _kok = (eyePos _unit) vectorAdd [0, 0, -0.2];
private _arka = _kok vectorAdd [-(sin _yon) * 3.5, -(cos _yon) * 3.5, 0];
if (lineIntersects [_kok, _arka, _unit]) exitWith {"geri duvar"};

private _arkaDost = (_unit nearEntities ["CAManBase", 12]) findIf {
    alive _x && {_x isNotEqualTo _unit} && {(_taraf getFriend (side group _x)) >= 0.6}
    && {(abs ((((_unit getDir _x) - _yon) + 540) mod 360 - 180)) >= 140}
};
if (_arkaDost >= 0) exitWith {"dost arkada"};

private _sonuc = "";
if (_yedek > 0 && {!_zirhHedef}) then {
    private _uyum = (compatibleMagazines _weapon) apply {toLower _x};
    private _kalan = _unit ammo _weapon;
    { if ((toLower (_x select 0)) in _uyum) then { _kalan = _kalan + (_x select 1); }; } forEach (magazinesAmmo _unit);
    if (_atildi) then { _kalan = _kalan + 1; };
    if (_kalan <= _yedek) then {
        private _esik = ["SEZILDI"] call FUNC(bilgiEsik);
        private _zirhVar = ((_unit nearTargets 1000) findIf {
            private _o = _x select 4;
            !isNull _o && {alive _o} && {(_taraf getFriend (side group _o)) < 0.6} && {(_o isKindOf "Tank") || {_o isKindOf "APC"} || {_o isKindOf "Wheeled_APC_F"}} && {(_unit knowsAbout _o) >= _esik}
        }) >= 0;
        if (_zirhVar) then { _sonuc = "yedek"; };   // (ic ice then: exitWith betigi sonlandirmaz -> degisken)
    };
};
_sonuc
