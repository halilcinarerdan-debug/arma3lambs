#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TERMAL GORUSLU ARAC TESPITI (v8.536; kullanici: 'kamuflaj sistemi arac termallerinde aktif de olmasin').
 * Renk kamuflaji (fnc_palet / camouflageCoef) TERMAL goruntude anlamsizdir (isi izi renkten bagimsiz). Bu fonksiyon bir aracin termal (Ti) gorus modu olup olmadigini config'ten okur:
 * arac / taret sinifinda (Turrets, ic ice taretler dahil) OpticsIn / ViewOptics / ViewGunner / ViewPilot altinda visionMode[] dizisinde "Ti" var mi. Sonuc arac sinifina gore onbellekli.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 *
 * Return Value: Termal gorusu var mi <BOOL>
 *
 * Public: No
*/

params [["_v", objNull, [objNull]]];
if (isNull _v) exitWith {false};
private _tip = typeOf _v;
private _oc = missionNamespace getVariable ["lambs_danger_termalOnbellek", createHashMap];
missionNamespace setVariable ["lambs_danger_termalOnbellek", _oc];
private _o = _oc get _tip;
if (!isNil "_o") exitWith {_o};

// bir sinifin (arac / taret) gorus bloklarinda Ti var mi; ic ice taretlere iner
private _tara = {
    params ["_c"];
    private _bulundu = false;
    {
        private _blk = _c >> _x;
        if (isClass _blk) then {
            if (((getArray (_blk >> "visionMode")) apply { toLower _x }) find "ti" >= 0) exitWith { _bulundu = true; };
            { if (((getArray (_x >> "visionMode")) apply { toLower _x }) find "ti" >= 0) exitWith { _bulundu = true; }; } forEach (configProperties [_blk, "isClass _x", true]);
        };
        if (_bulundu) exitWith {};
    } forEach ["OpticsIn", "ViewOptics", "ViewGunner", "ViewPilot"];
    if (!_bulundu) then {
        { if ([_x] call _tara) exitWith { _bulundu = true; }; } forEach (configProperties [_c >> "Turrets", "isClass _x", true]);
    };
    _bulundu
};
private _r = [configFile >> "CfgVehicles" >> _tip] call _tara;
_oc set [_tip, _r];
_r
