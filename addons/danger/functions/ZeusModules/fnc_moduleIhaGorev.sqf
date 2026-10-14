#include "script_component.hpp"

// ELITE fork (v8.233): "ELITE IHA Gorevi" Zeus modulu — bir insansiz hava aracinin (FPV Drone Crocus, Mavic 3, RHS IHA'lari ...) ustune birakilir (ya da 40 m icinde en yakin IHA).
//   Gorev: Sorti (otomatik hedef: FPV-AT zirh, FPV-AP / BOMBA personel kumesi) / Gozlem devriyesi (modul konumu etrafinda) / Gorevi kaldir.
//   Tur: Otomatik (sinif adindan tahmin; bkz. RPT [IHA-ENVANTER]) ya da elle. Taraf: IHA'nin muretttebati yoksa kullanilir.
//   Ayrintilar: fnc_ihaSorti. Log: [IHA-SORTI]

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    private _bagli = attachedTo _logic;
    deleteVehicle _logic;
    [
        "ELITE IHA Gorevi",
        [
            ["Gorev", "LIST", "Sorti: IHA kendi basina hedef secer ve saldirir (FPV: kamikaze; BOMBA: 3 bomba). Gozlem: modul konumu etrafinda devriye, gordugu dusman ortak resme verilir. Kaldir: gorevi iptal eder.", ["Sorti (otomatik hedef)", "Gozlem devriyesi", "Gorevi KALDIR"], 0],
            ["Tur", "LIST", "Otomatik: sinif adindan tahmin (crocus / fpv -> FPV, mavic -> BOMBA, digerleri GOZLEM). Yanlissa elle sec.", ["Otomatik", "FPV-AT (zirh avcisi)", "FPV-AP (personel / termobarik)", "BOMBA (Mavic: el bombasi)", "GOZLEM"], 0],
            ["Taraf (muretttebat yoksa)", "LIST", "IHA'nin AI muretttebati yoksa bu tarafta yaratilir.", ["BLUFOR", "OPFOR", "INDEP"], 1],
            ["Menzil (m)", "SLIDER", "Kalkis noktasindan hedefe en fazla bu kadar (FPV Crocus: 4 km, 10 dk pil).", [500, 4000], [100, 500], 3000, 0],
            ["Gozlem yaricapi (m)", "SLIDER", "Gozlem devriyesinde modul konumu etrafinda.", [100, 800], [50, 100], 300, 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz", "_bagli"];
            _data params ["_gorev", "_tur", "_tarafI", "_men", "_yar"];
            private _u = _bagli;
            if (isNull _u || {!(unitIsUAV _u)}) then {
                private _y = (nearestObjects [_poz, ["Air", "LandVehicle"], 40]) select {unitIsUAV _x};
                _u = if (_y isEqualTo []) then {objNull} else {_y select 0};
            };
            if (isNull _u) exitWith { systemChat "[ELITE] IHA Gorevi: yakinda (40 m) insansiz hava araci yok - modulu IHA'nin ustune birak"; };
            private _mod = ["SORTI", "GOZLEM", "KALDIR"] select (_gorev max 0 min 2);
            private _turKod = ["", "FPV-AT", "FPV-AP", "BOMBA", "GOZLEM"] select (_tur max 0 min 4);
            ["lambs_danger_ihaGorev", [netId _u, _mod, _turKod, _tarafI, _poz, round _yar, round _men]] call CBA_fnc_serverEvent;
            systemChat format ["[ELITE] IHA gorevi gonderildi: %1 -> %2 (%3)", getText (configOf _u >> "displayName"), _mod, [_turKod, "otomatik tur"] select (_turKod isEqualTo "")];
        }, {}, {}, [_poz, _bagli]
    ] call EFUNC(main,showDialog);
};
