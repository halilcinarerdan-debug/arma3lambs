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
    // v8.249: yakinda dron yoksa modul KENDISI yaratir (kullanici: 'Crocus dronlari sirtcantasi (Bag) olarak yere koymak zaman kaybi'): mod, Bag nesnesinin yani sira dogrudan arac sinifi da tanimliyor (B_/O_/I_Crocus_AT / AP)
    private _yaratSiniflar = ["B_Crocus_AT", "B_Crocus_AP", "O_Crocus_AT", "O_Crocus_AP", "I_Crocus_AT", "I_Crocus_AP"] select {isClass (configFile >> "CfgVehicles" >> _x)};
    private _yaratEtiket = ["Yok (yakindaki / ustundeki dronu kullan)"] + (_yaratSiniflar apply { format ["%1 (%2)", getText (configFile >> "CfgVehicles" >> _x >> "displayName"), _x] });
    [
        "ELITE IHA Gorevi",
        [
            ["Gorev", "LIST", "Sorti: IHA kendi basina hedef secer ve saldirir (FPV: kamikaze; BOMBA: 3 bomba). Gozlem: modul konumu etrafinda devriye, gordugu dusman ortak resme verilir. Kaldir: gorevi iptal eder.", ["Sorti (otomatik hedef)", "Gozlem devriyesi", "Gorevi KALDIR"], 0],
            ["Tur", "LIST", "Otomatik: sinif adindan tahmin (crocus / fpv -> FPV, mavic -> BOMBA, digerleri GOZLEM). Yanlissa elle sec.", ["Otomatik", "FPV-AT (zirh avcisi)", "FPV-AP (personel / termobarik)", "BOMBA (Mavic: el bombasi)", "GOZLEM"], 0],
            ["Taraf (muretttebat yoksa)", "LIST", "IHA'nin AI muretttebati yoksa bu tarafta yaratilir.", ["BLUFOR", "OPFOR", "INDEP"], 1],
            ["Menzil (m)", "SLIDER", "Kalkis noktasindan hedefe en fazla bu kadar (FPV Crocus: 4 km, 10 dk pil).", [500, 4000], [100, 500], 3000, 0],
            ["Gozlem yaricapi (m)", "SLIDER", "Gozlem devriyesinde modul konumu etrafinda.", [100, 800], [50, 100], 300, 0],
            ["Firlatma tetik mesafesi (m)", "SLIDER", "'Dron yarat' seciliyse: dron HEMEN degil, bu noktanin bu kadar yakininda IHA tarafinin BILDIGI dusman gorulunce yaratilir (hile yok). 0 = hemen yarat. Emir 30 dk gecerli; iptal: Gorevi KALDIR (modulu bu noktaya birak).", [0, 3000], [100, 200], 1200, 0],
            ["Operator bagi", "LIST", "Operator = modul konumuna en yakin (40 m) secilen taraftan canli dost asker. Bagsiz: eski davranis. Operator olunce: dron kontrolu kaybeder ve duser (firlatma emri varsa iptal olur) / dron o an bir hedefe kilitliyse (dalis) vurmaya devam eder, yeni hedef secmez, hedefsizse duser.", ["Bagsiz (operator yok)", "Operator olunce dron DUSER", "Operator olunce hedefe kilitliyse DALAR"], 1],
            ["Dron yarat (40 m icinde dron yoksa)", "LIST", "Sirtcantasini yere koyup kurmaya gerek yok: secilen arac sinifi modul konumunda dogrudan yaratilir ve gorev verilir. Yakinda zaten dron varsa o kullanilir (yaratilmaz).", _yaratEtiket, 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz", "_bagli", "_yaratSiniflar"];
            _data params ["_gorev", "_tur", "_tarafI", "_men", "_yar", "_tetikM", "_opI", "_yaratI"];
            private _u = _bagli;
            if (isNull _u || {!(unitIsUAV _u)}) then {
                private _y = (nearestObjects [_poz, ["Air", "LandVehicle"], 40]) select {unitIsUAV _x};
                _u = if (_y isEqualTo []) then {objNull} else {_y select 0};
            };
            // v8.260: dron istemcide degil SUNUCUDA, 40 m irtifada ucarak yaratilir (istemcide yaratilinca setOwner gerekiyordu; yerde 2 m'den dusen / carpan dron mod tarafindan patliyor olabilirdi)
            private _yaratSn = "";
            if (isNull _u && {(round _yaratI) >= 1} && {_gorev < 2}) then {
                _yaratSn = _yaratSiniflar param [(round _yaratI) - 1, ""];
            };
            if (isNull _u && {_yaratSn isEqualTo ""} && {_gorev < 2}) exitWith { systemChat "[ELITE] IHA Gorevi: yakinda (40 m) insansiz hava araci yok - modulu IHA'nin ustune birak ya da 'Dron yarat' sec"; };
            // v8.268 OPERATOR: modul konumuna (ya da dron varsa dronun yanina) en yakin, IHA tarafindan canli dost asker (40 m)
            private _opMod = round _opI;
            private _op = objNull;
            if (_opMod > 0 && {_gorev < 2}) then {
                private _tfS = [west, east, independent] select (_tarafI max 0 min 2);
                private _opAdaylar = (_poz nearEntities [["CAManBase"], 40]) select {alive _x && {isNull objectParent _x} && {(side (group _x)) isEqualTo _tfS}};
                if (_opAdaylar isEqualTo []) then {
                    _opMod = 0;
                    systemChat "[ELITE] IHA Gorevi: 40 m icinde dost operator asker yok -> operator BAGSIZ";
                } else {
                    _op = ([_opAdaylar, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy) select 0;
                    systemChat format ["[ELITE] IHA operatoru: %1 (olunce: %2)", name _op, ["", "dron duser", "hedefe kilitliyse dalar"] select _opMod];
                };
            };
            private _mod = ["SORTI", "GOZLEM", "KALDIR"] select (_gorev max 0 min 2);
            private _turKod = ["", "FPV-AT", "FPV-AP", "BOMBA", "GOZLEM"] select (_tur max 0 min 4);
            ["lambs_danger_ihaGorev", [["", netId _u] select (!isNull _u), _mod, _turKod, _tarafI, _poz, round _yar, round _men, _yaratSn, round _tetikM, ["", netId _op] select (!isNull _op), _opMod]] call CBA_fnc_serverEvent;
            systemChat format ["[ELITE] IHA gorevi gonderildi: %1 -> %2 (%3)", [_yaratSn + ([" - dusman " + str (round _tetikM) + " m'ye girince firlatilacak", " - hemen"] select (_tetikM <= 0)), getText (configOf _u >> "displayName")] select (!isNull _u), _mod, [_turKod, "otomatik tur"] select (_turKod isEqualTo "")];
        }, {}, {}, [_poz, _bagli, _yaratSiniflar]
    ] call EFUNC(main,showDialog);
};
