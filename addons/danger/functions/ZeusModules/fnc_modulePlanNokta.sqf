#include "script_component.hpp"

// ELITE fork (v8.115): "ELITE Plan Noktasi (manuel)" Zeus modulu — komutanin hesapladigi rally point / ORP / destek noktasi / kanat / yarali toplama noktasi yerine
// ZEUS'UN SECTIGI noktayi kullanmasi icin (tarihsel senaryo canlandirma: 'komutan o hatayi yapsin, ne olurdu gorelim').
// Komutan emri uygular (itiraz etmez); sistem yalnizca [PLAN-UYARI] ile secimin sorunlarini (gorus, yakinlik, ates hatti) loglar ve plan bitince [PLAN-OZET] (ne oldu?) yazar.
// Nokta sonraki ELITE Objektif planinda kullanilir ve kullanilinca silinir. 'SIL' secenegi o tarafin tum bekleyen manuel noktalarini temizler.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    deleteVehicle _logic;
    [
        "ELITE Plan Noktasi (manuel)",
        [
            ["Taraf", "LIST", "Noktanin gececegi plan hangi tarafin.", ["BLUFOR", "OPFOR", "INDEP"], 0],
            ["Nokta tipi", "LIST", "Komutan hesaplamak yerine bu noktayi kullanir (hatali olsa bile). SIL: bu tarafin bekleyen tum manuel noktalarini temizler.", ["Rally point (RP)", "ORP", "Destek noktasi (SBF)", "Kanat noktasi 1", "Kanat noktasi 2", "CCP (yarali toplama)", "SIL (hepsini temizle)"], 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz"];
            _data params ["_tarafI", "_tip"];
            private _taraf = [west, east, independent] select (_tarafI max 0 min 2);
            private _ad = ["RP", "ORP", "SBF", "KANAT1", "KANAT2", "CCP"];
            if (_tip >= 6) then {
                // sunucudaki tum manuel noktalar bu taraf icin silinsin
                { ["lambs_danger_planNoktaIstegi", [_taraf, _x, []]] call CBA_fnc_serverEvent; } forEach _ad;
            } else {
                ["lambs_danger_planNoktaIstegi", [_taraf, _ad select _tip, _poz]] call CBA_fnc_serverEvent;
            };
        }, {}, {}, [_poz]
    ] call EFUNC(main,showDialog);
};
