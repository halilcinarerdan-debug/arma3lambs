#include "script_component.hpp"

// ELITE fork (v8.777; kullanici: 'zeus destegi ve editor destegi olsun'): "ELITE Canli Bomba (PBIED / VBIED)" Zeus modulu - bir askerin / aracin (20 m icinde en yakin) ustune birakilir.
//   Ayar: yaklasma tarzi (catisarak / gizli = referans), hedef taraf, tespit menzili, son an mesafesi, patlama gucu, olunce patlama sansi, arac ustu varil. Ayrintilar: fnc_eypBombaYap, fnc_eypKos. Log: [EYP-ISARET]

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    private _bagli = attachedTo _logic;
    deleteVehicle _logic;
    private _hedef = _bagli;
    if (isNull _hedef || {!alive _hedef} || {!((_hedef isKindOf "CAManBase") || {_hedef isKindOf "LandVehicle"})}) then {
        private _y = (nearestObjects [_poz, ["CAManBase", "LandVehicle"], 20]) select {alive _x && {!isPlayer _x}};
        _hedef = if (_y isEqualTo []) then {objNull} else {_y select 0};
    };
    if (!isNull _hedef && {_hedef isKindOf "CAManBase"} && {!isNull objectParent _hedef}) then { _hedef = vehicle _hedef; };
    if (isNull _hedef) exitWith { systemChat "[ELITE] Canli bomba: modulun 20 m icinde asker / arac yok (modulu birimin USTUNE birakin)"; };
    [
        "ELITE Canli Bomba (PBIED / VBIED)",
        [
            ["Yaklasma tarzi", "LIST", "Catisarak: zikzak yaparak ve ates ederek gelir. Gizli (referans): CARELESS + ates etmez, yuruyerek yaklasir, son an mesafesinde sprint (arac: 45 km/s sonra tam gaz).", ["Catisarak (zikzak + ates)", "Gizli yaklasim (referans)"], 0],
            ["Hedef taraf", "LIST", "Otomatik: bu birimin dost saymadigi herkes. Elle secersen yalniz o taraf hedeflenir.", ["Otomatik (dost olmayan)", "BLUFOR", "OPFOR", "INDEP"], 0],
            ["Tespit menzili (m)", "SLIDER", "Bu mesafede dusman gorunce hedefe gider.", [50, 1000], [50, 100], 400, 0],
            ["Son an mesafesi (m, 0 = CBA ayari)", "SLIDER", "Bu mesafede sprint / tam gaz. 0: CBA ayari (piyade 45 / arac 120).", [0, 300], [10, 50], 0, 0],
            ["Patlama mesafesi (m, 0 = CBA ayari)", "SLIDER", "Hedef ya da herhangi bir dusman bu mesafeye girdigi anda patlar. 0: CBA ayari canliBombaTetikM (5 m). Varsayilan 8 m (olum yaricapi ~5-10 m; daha yakinda patlarsa hedef zarar gormeyebilir).", [0, 25], [1, 5], 8, 0],
            ["Patlama gucu", "LIST", "CBA ayari: eypPatlamaGucu. 0 hafif (DemoCharge). 1 orta. 2 referans (arac: GBU-12; olum yaricapi cok buyuk).", ["CBA ayari", "0 hafif", "1 orta", "2 referans"], 0],
            ["Vurulunca patlama sansi", "LIST", "Hedefe varamadan vurulursa cihazin olunce patlama olasiligi.", ["CBA ayari", "Hic", "25 yuzde", "50 yuzde", "75 yuzde", "100 yuzde"], 0],
            ["Arac ustu gorsel varil", "LIST", "Yalniz arac: kasaya patlayici varil nesnesi baglar (gorsel).", ["Evet", "Hayir"], 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_hedef"];
            _data params ["_tarz", "_taraf", "_menzil", "_atilma", "_tetik", "_guc", "_olum", "_varil"];
            private _a = [round _menzil, round _tarz, [-1, round _atilma] select (_atilma > 0), (round _guc) - 1, [-1, 0, 0.25, 0.5, 0.75, 1] select (round _olum), round _taraf, [1, 0] select (round _varil), [-1, round _tetik] select (_tetik > 0)];
            ["lambs_danger_eypBombaIstegi", [netId _hedef, _a]] call CBA_fnc_serverEvent;
            systemChat format ["[ELITE] Canli bomba gorevi gonderildi: %1 (%2)", getText (configOf _hedef >> "displayName"), ["catisarak", "gizli yaklasim"] select (round _tarz)];
        }, {}, {}, [_hedef]
    ] call EFUNC(main,showDialog);
};
