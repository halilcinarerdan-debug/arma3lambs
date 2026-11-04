#include "script_component.hpp"

// ELITE fork (v8.404): "ELITE Harekat Kontrol" Zeus modulu - 3DEN 'ELITE Harekat' ile kurulmus harekati yonetir: H-saatini ilan et (Elle modunda), mevcut fazi atla, harekati durdur, durum.
// Liste sunucudan (lambs_danger_harekatListe, herkese yayinlanir) okunur; islem sunucuya CBA olayiyla gider (fnc_harekatDongu). Modul bir kez calisir.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    deleteVehicle _logic;
    private _liste = missionNamespace getVariable ["lambs_danger_harekatListe", []];
    if (_liste isEqualTo []) exitWith { systemChat "[ELITE] Kayitli harekat yok (3DEN: 'ELITE Harekat' modulu + Objektif modullerini SYNC edin)"; };
    [
        "ELITE Harekat Kontrol",
        [
            ["Harekat", "LIST", "Kontrol edilecek harekat.", _liste apply { format ["%1 [%2]", _x select 1, _x select 2] }, 0],
            ["Islem", "LIST", "Basla: H-saatini simdi ilan et. Sonraki faz: mevcut fazi atla (planlar surer) ve siradaki fazi baslat. Durdur: harekati iptal et (plan gruplari serbest / HQ'ya doner). Durum: faz / objektif durumu Zeus sohbetine.", ["Basla (H-saati)", "Sonraki faza gec", "Durdur", "Durum"], 0]
        ],
        {
            params ["_d", "_args"];
            _d params ["_hi", "_ii"];
            _args params ["_liste"];
            private _id = (_liste select (_hi max 0)) select 0;
            private _islem = ["BASLAT", "SONRAKI", "DURDUR", "DURUM"] select ((_ii max 0) min 3);
            if (_islem isEqualTo "DURUM") then {
                ["lambs_danger_harekatDurumIstegi", [clientOwner, _id]] call CBA_fnc_serverEvent;
            } else {
                ["lambs_danger_harekatIstegi", [_islem, _id]] call CBA_fnc_serverEvent;
                systemChat format ["[ELITE] Harekat %1: %2 istendi", _id, _islem];
            };
        }, {}, {}, [_liste]
    ] call EFUNC(main,showDialog);
};
