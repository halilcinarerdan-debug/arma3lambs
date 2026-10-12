#include "script_component.hpp"

// ELITE fork (v8.196): "ELITE Topcu TEST" Zeus modulu - modulun KONULDUGU noktaya, planin zamanlamasini / dogrulama kosullarini beklemeden AI topculara 3 mermilik atis emri verir.
// Amac: topcunun atis MEKANIGINI (menzil, yer degistirme, doArtilleryFire) plan mantigindan ayirarak sinamak. Sonuc Zeus'a systemChat ve sunucu RPT'de [TOPCU-TEST] olarak yazilir.
// Modul bir kez calisir (modul nesnesi hemen silinir).

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    deleteVehicle _logic;
    ["lambs_danger_topcuTestIstegi", [_poz, clientOwner]] call CBA_fnc_serverEvent;
    systemChat format ["[ELITE] Topcu TEST istegi gonderildi: %1", mapGridPosition _poz];
};
