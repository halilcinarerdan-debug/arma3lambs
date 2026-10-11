#include "script_component.hpp"

// ELITE fork (v8.176): "ELITE Karakol / Plan KALDIR" Zeus modulu — kayitli karakol / HQ / mevzileri ve AKTIF planlari listeler; hangilerinin kaldirilacagini siz isaretlersiniz.
// Kaldirilan karakol: kayit + harita isareti silinir, yaninda aktif SAVUN plani varsa iptal edilir. Kaldirilan plan: IPTAL fazina alinir (gruplar serbest).
// Modul bir kez calisir (modul nesnesi hemen silinir); liste sunucudan istenir.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    deleteVehicle _logic;
    ["lambs_danger_kaldirListeIstegi", [clientOwner]] call CBA_fnc_serverEvent;
    systemChat "[ELITE] Karakol / plan listesi sunucudan isteniyor...";
};
