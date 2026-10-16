#include "script_component.hpp"

// ELITE fork (v8.115): "ELITE Plan Noktasi (manuel)" Zeus modulu — komutanin hesapladigi rally point / ORP / destek noktasi / kanat / yarali toplama noktasi yerine
// ZEUS'UN SECTIGI noktayi kullanmasi icin (tarihsel senaryo canlandirma: 'komutan o hatayi yapsin, ne olurdu gorelim').
// Komutan emri uygular (itiraz etmez); sistem yalnizca [PLAN-UYARI] ile secimin sorunlarini (gorus, yakinlik, ates hatti) loglar ve plan bitince [PLAN-OZET] (ne oldu?) yazar.
// Nokta sonraki ELITE Objektif planinda kullanilir ve kullanilinca silinir. 'SIL' secenegi o tarafin tum bekleyen manuel noktalarini temizler.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    private _modYon = getDir _logic;
    deleteVehicle _logic;
    [
        "ELITE Plan Noktasi (manuel)",
        [
            ["Taraf", "LIST", "Noktanin gececegi plan hangi tarafin.", ["BLUFOR", "OPFOR", "INDEP"], 0],
            ["Nokta tipi", "LIST", "Komutan hesaplamak yerine bu noktayi kullanir (hatali olsa bile). SIL: bu tarafin bekleyen tum manuel noktalarini temizler.", ["Rally point (RP)", "ORP", "Destek noktasi (SBF)", "Kanat noktasi 1", "Kanat noktasi 2", "CCP (yarali toplama)", "SIL (hepsini temizle)", "MEVZI ekle (savunma, BIRDEN COK konabilir)", "MEVZI sil (en yakin, 150 m)", "MEVZI hepsini sil"], 0],
            ["Mevzi yonu = modul yonu", "BOOLEAN", "Yalniz MEVZI ekle icin: isaretliyse ates yonu modulun Zeus'ta dondurulen yonudur; degilse mevzi objektiften DISARI bakar. Birden cok MEVZI ekleyebilirsiniz; SAVUN plani objektife <= 700 m olanlari kullanir, gruplari mevzilere dagitir.", false, ""]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz", "_modYon"];
            _data params ["_tarafI", "_tip", ["_yonKullan", false]];
            private _taraf = [west, east, independent] select (_tarafI max 0 min 2);
            // v8.239 COKLU MEVZI: tip 7 ekle, 8 en yakini sil, 9 hepsini sil (SIL=6 yalniz RP / ORP / SBF / kanat / CCP noktalarini temizler)
            if (_tip >= 7) exitWith {
                ["lambs_danger_savunmaMevziIstegi", [_taraf, ["EKLE", "SIL-YAKIN", "SIL-HEPSI"] select ((_tip - 7) min 2), _poz, [-1, _modYon] select _yonKullan]] call CBA_fnc_serverEvent;
                systemChat format ["[ELITE] Mevzi istegi gonderildi: %1", ["MEVZI EKLE", "EN YAKIN MEVZI SIL", "TUM MEVZILERI SIL"] select ((_tip - 7) min 2)];
            };
            private _ad = ["RP", "ORP", "SBF", "KANAT1", "KANAT2", "CCP"];
            if (_tip == 6) then {
                // sunucudaki tum manuel noktalar bu taraf icin silinsin
                { ["lambs_danger_planNoktaIstegi", [_taraf, _x, []]] call CBA_fnc_serverEvent; } forEach _ad;
            } else {
                ["lambs_danger_planNoktaIstegi", [_taraf, _ad select _tip, _poz]] call CBA_fnc_serverEvent;
            };
        }, {}, {}, [_poz, _modYon]
    ] call EFUNC(main,showDialog);
};
