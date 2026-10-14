#include "script_component.hpp"

// ELITE fork (v8.237, Dilim A0): "ELITE Cephe Paneli" Zeus modulu — CEPHE SIMULASYONU (sanal / fiziksel profil sistemi) paneli.
// Modul bir kez calisir (nesne hemen silinir); konumu panelde "yerlesim merkezi" / "takviye varis noktasi" olarak kullanilir.
// Panel sayfalari: fnc_cephePanel. Sistem OPSIYONELDIR: yalniz bu panelden faction eklenince (ya da CBA 'ELITE Cephe Komutani > Aktif') calisir.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    deleteVehicle _logic;
    [_poz] call FUNC(cephePanel);
};
