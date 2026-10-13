#include "script_component.hpp"

// ELITE fork (v8.214): "ELITE Gozetleme Ata" Zeus modulu — bir squad'in (HQ birimi) HANGI karakol / mevzi / gozetleme noktasinda nobet (gozetleme) tutacagini Zeus belirler.
// Modulu bir askerin / squad'in / aracin ustune birak (ya da 25 m icine); hedef listesi haritadaki ELITE Karakol / Mevzi isaretlerinden gelir.
//   Hedef secilirse: grup oraya gider, yaricap icinde dagilip dis cevreye (360 derece sektor) bakar, temasta dovusur, temas bitince noktaya doner. Atanmis grup ELITE Objektif planlarina ALINMAZ (gorev 'HARIC').
//   "Atamayi kaldir": nobet biter, gorev eski haline doner.   Log: [GOZETLE]

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    private _bagli = attachedTo _logic;
    deleteVehicle _logic;
    private _isaretler = allMapMarkers select {(_x find "ELITE_KARAKOL_") isEqualTo 0};
    _isaretler = [_isaretler, [], {(markerPos _x) distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
    if (_isaretler isEqualTo []) exitWith { systemChat "[ELITE] Gozetleme Ata: haritada karakol / mevzi yok (once 'ELITE Karakol / Mevzi' modulu koyun)"; };
    private _adlar = ["Atamayi KALDIR (nobeti bitir)"] + (_isaretler apply { format ["%1 [%2] (%3 m)", markerText _x, mapGridPosition (markerPos _x), round ((markerPos _x) distance2D _poz)] });
    [
        "ELITE Gozetleme Ata",
        [
            ["Hedef (karakol / mevzi / gozetleme noktasi)", "LIST", "Squad bu noktada nobet tutar (yaricap icinde dagilir, dis cevreyi gozetler). Liste modul konumuna yakinliga gore siralidir.", _adlar, 1]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz", "_bagli", "_isaretler"];
            _data params ["_secim"];
            private _hedef = _bagli;
            if (isNull _hedef) then {
                private _y = nearestObjects [_poz, ["CAManBase", "LandVehicle"], 25];
                _hedef = if (_y isEqualTo []) then {objNull} else {_y select 0};
            };
            if (isNull _hedef) exitWith { systemChat "[ELITE] Gozetleme Ata: yakinda asker / arac yok (modulu bir squad'in ustune birak)"; };
            private _g = group (effectiveCommander _hedef);
            private _mn = if (_secim <= 0) then {""} else {_isaretler param [_secim - 1, ""]};
            ["lambs_danger_gozetleAta", [netId _g, _mn]] call CBA_fnc_serverEvent;
            systemChat format ["[ELITE] Gozetleme istegi gonderildi: %1 -> %2", groupId _g, [format ["%1", markerText _mn], "nobeti KALDIR"] select (_mn isEqualTo "")];
        }, {}, {}, [_poz, _bagli, _isaretler]
    ] call EFUNC(main,showDialog);
};
