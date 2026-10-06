#include "script_component.hpp"

// ELITE fork (v8.113): "ELITE Objektif" Zeus modulu (LAMBS Danger kategorisi).
// Modulun yerlestirildigi nokta OBJEKTIF'tir. Zeus bir taraf secer, gorev tipini ve duşman hakkinda BILDIKLERINI verir ("sunlar var / sunlar yok");
// en yetkili grup lideri (rutbe) KOMUTAN olur, planlayici (fnc_komutanPlan) arazi tanima + rally point + ORP + destek / manevra / yedek rolleri + waypoint uretir.
// Waypoint'ler gercek (addWaypoint) -> Zeus'ta gorunur ve elle degistirilebilir. Hile yok: plan yalniz burada verilen bilgiye ve gruplarin kendi bildiklerine dayanir.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _obj = getPosATL _logic;
    [
        "ELITE Objektif (komutan plani)",
        [
            ["Taraf", "SIDE", "Plani uygulayacak taraf.", [[west, "BLUFOR"], [east, "OPFOR"], [independent, "INDEP"]], west],
            ["Gorev tipi", "LIST", "ELE GECIR: toplan -> ORP -> kesif -> destek + manevra saldirisi -> toparlanma. SAVUN: toplan -> objektif cevresinde sektorlu mevzi + garrison. IPTAL: bu taraftaki aktif plani durdurur.", ["Ele gecir (saldiri)", "Savun (mevzilen)", "IPTAL (aktif plani durdur)"], 0],
            ["Katilacak grup sayisi", "SLIDER", "En yetkili (rutbe) ve en yakin gruplardan secilir; en yuksek rutbeli lider KOMUTAN olur.", [1, 8], [1, 1], 4, 0],
            ["Duşman: piyade var", "BOOLEAN", "Objektifte duşman piyadesi var.", true, ""],
            ["Duşman: zirh / arac var", "BOOLEAN", "Tank / APC / teknik var. Isaretli degilse: ZIRH YOK (AT esikligi gerekmez).", false, ""],
            ["Duşman: AT / RPG var", "BOOLEAN", "Roketatar / fuze tasiyan duşman var.", false, ""],
            ["Duşman: MG var", "BOOLEAN", "Makineli tufek var -> cepheden saldirma yerine kanat manevrasi (2+ grup varsa).", false, ""],
            ["Duşman: nisanci var", "BOOLEAN", "Keskin nisanci / nisanci var.", false, ""],
            ["Duşman: binalarda / mevzili", "BOOLEAN", "Binalarda veya hazir mevzilerde (CQB / bina temizleme beklenir).", false, ""],
            ["Duşman sayisi (tahmin)", "SLIDER", "0 = bilinmiyor.", [0, 60], [1, 5], 0, 0],
            ["Rally point mesafesi (m)", "SLIDER", "Toplanma noktasi objektiften bu kadar geride, ortulu.", [250, 900], [10, 50], 450, 0],
            ["ORP mesafesi (m)", "SLIDER", "Objektif toplanma noktasi (saldiri hatti oncesi).", [80, 400], [10, 25], 180, 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_logic", "_obj"];
            _data params ["_taraf", "_tip", "_grupN", "_piy", "_zrh", "_at", "_mg", "_nis", "_bina", "_say", "_rally", "_orp"];
            private _ayar = createHashMapFromArray [
                ["tip", _tip], ["grupN", round _grupN], ["piyade", _piy], ["zirh", _zrh], ["at", _at], ["mg", _mg], ["nisanci", _nis], ["bina", _bina],
                ["sayi", round _say], ["rallyM", round _rally], ["orpM", round _orp]
            ];
            [_taraf, _obj, _ayar] spawn (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {}]);
            deleteVehicle _logic;
        }, {
            params ["_logic"];
            deleteVehicle _logic;
        }, {
            params ["_logic"];
            deleteVehicle _logic;
        }, [_logic, _obj]
    ] call EFUNC(main,showDialog);
};
