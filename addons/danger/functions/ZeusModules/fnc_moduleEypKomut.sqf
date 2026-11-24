#include "script_component.hpp"

// ELITE fork (v8.777; kullanici: 'zeus destegi ve editor destegi olsun'): "ELITE EYP Kur (komutla patlayan pusu)" Zeus modulu - modulun KONULDUGU nokta EYP konumudur.
//   Kurucu = secilen tarafin modulun 60 m icindeki en yakin canli (oyuncu olmayan, arac disi) askeri. Kurucu EYP'yi kurar, gozetleme noktasina cekilir, dusman tetik mesafesine girince patlatir (fnc_eypKomut).
//   Dusman gelis yonu: sekiz yon ya da otomatik (kurucunun tersi). Log: [EYP-KOMUT]

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    deleteVehicle _logic;
    [
        "ELITE EYP Kur (komutla patlayan pusu)",
        [
            ["Kurucunun tarafi", "LIST", "Kurucu: bu tarafin modula en yakin (60 m) canli askeri. Dusman = bu tarafin dost saymadigi herkes.", ["BLUFOR", "OPFOR", "INDEP"], 1],
            ["Dusman gelis yonu", "LIST", "Dusmanin EYP'ye hangi yonden gelecegi: gozetleme noktasi bunun TERSINDE secilir. Otomatik: kurucunun tersi.", ["Otomatik", "Kuzeyden", "Kuzeydogudan", "Doudan", "Guneydogudan", "Guneyden", "Guneybatidan", "Batidan", "Kuzeybatidan"], 0],
            ["Gozetleme mesafesi (m, 0 = otomatik)", "SLIDER", "Kurucu EYP'den bu kadar uzaga cekilir (araziden EYP'yi goren nokta aranir). 0: patlama gucune gore 20 / 28 / 45 m.", [0, 100], [5, 10], 0, 0],
            ["Tetik mesafesi (m)", "SLIDER", "Dusman EYP'ye bu kadar yaklasinca (8 m icinde dost yoksa) patlatir.", [5, 40], [1, 5], 12, 0],
            ["Patlama gucu", "LIST", "CBA ayari: eypPatlamaGucu. 0 hafif. 1 orta. 2 referans (GBU-12; kurucu 45 m uzaga cekilir).", ["CBA ayari", "0 hafif", "1 orta", "2 referans"], 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz"];
            _data params ["_taraf", "_yon", "_hideM", "_tetik", "_guc"];
            private _ts = [west, east, independent] select (round _taraf);
            private _adaylar = (_poz nearEntities ["CAManBase", 60]) select {alive _x && {!isPlayer _x} && {isNull objectParent _x} && {(side group _x) isEqualTo _ts}};
            if (_adaylar isEqualTo []) exitWith { systemChat "[ELITE] EYP kur: modulun 60 m icinde secilen tarafin askeri yok"; };
            private _u = _adaylar select 0;
            private _ep = [];
            private _hide = [];
            if ((round _yon) > 0) then {
                private _d = ((round _yon) - 1) * 45;
                _ep = _poz getPos [100, _d];
                if (_hideM > 0) then { _hide = _poz getPos [_hideM, _d + 180]; };
            };
            ["lambs_danger_eypKomutIstegi", [netId _u, _poz, _hide, _ep, round _tetik, (round _guc) - 1]] call CBA_fnc_serverEvent;
            systemChat format ["[ELITE] EYP kurma emri gonderildi: %1 -> %2", name _u, mapGridPosition _poz];
        }, {}, [_poz]
    ] call EFUNC(main,showDialog);
};
