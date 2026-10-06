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
            if (isNil "lambs_danger_planManuel") then { lambs_danger_planManuel = createHashMap; };
            private _ad = ["RP", "ORP", "SBF", "KANAT1", "KANAT2", "CCP"];
            if (_tip >= 6) then {
                private _n = 0;
                {
                    if ((_x find (format ["%1|", _taraf])) isEqualTo 0) then {
                        lambs_danger_planManuel deleteAt _x;
                        deleteMarker (format ["ELITE_MANUEL_%1_%2", _taraf, _x select [(count format ["%1|", _taraf]), 6]]);
                        _n = _n + 1;
                    };
                } forEach (keys lambs_danger_planManuel);
                diag_log format ["[PLAN-MANUEL] %1 | bekleyen manuel noktalar silindi (%2)", _taraf, _n];
            } else {
                private _anahtar = format ["%1|%2", _taraf, _ad select _tip];
                lambs_danger_planManuel set [_anahtar, _poz];
                private _mn = format ["ELITE_MANUEL_%1_%2", _taraf, _ad select _tip];
                deleteMarker _mn;
                createMarker [_mn, _poz];
                _mn setMarkerType "mil_destroy";
                _mn setMarkerColor (switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
                _mn setMarkerText format ["MANUEL %1", _ad select _tip];
                diag_log format ["[PLAN-MANUEL] %1 | %2 manuel nokta konuldu: %3 (sonraki Objektif planinda kullanilir)", _taraf, _ad select _tip, mapGridPosition _poz];
            };
        }, {}, {}, [_poz]
    ] call EFUNC(main,showDialog);
};
