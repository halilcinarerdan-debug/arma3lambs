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
            ["Taraf (muretttebat yoksa)", "LIST", "IHA'nin AI muretttebati yoksa bu tarafta yaratilir. OTOMATIK (varsayilan, v8.339): arac sinifinin tarafi (B_ = BLUFOR, O_ = OPFOR, I_ = INDEP), cantali asker varsa onun tarafi, yoksa yakindaki en yakin askerin tarafi. Elle secersen o gecer (sinifla celisirse uyari verilir).", ["Otomatik (sinif / asker)", "BLUFOR", "OPFOR", "INDEP"], 0],
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
            private _tarafSecim = round _tarafI;   // v8.339: 0 = otomatik, 1 BLUFOR, 2 OPFOR, 3 INDEP
            private _tarafOto = _tarafSecim <= 0;
            _tarafI = (_tarafSecim - 1) max 0 min 2;
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
            // v8.272 CROCUS CANTASI: yakinda (40 m) Crocus cantasi tasiyan dost asker ya da yerde Crocus cantasi varsa ve dron yoksa, 'Dron yarat = Yok' secilmis olsa bile canta tespit edilir:
            //   arac sinifi cantadan bulunur (fnc_ihaCantaSinif), operator = cantali asker (operator bagi acikken), canta firlatmada tuketilir (asker: removeBackpackGlobal; yerde: cantadan 1 adet).
            private _cantaObj = objNull;
            private _cantaSn = "";
            if (isNull _u && {_gorev < 2}) then {
                private _tfC = [west, east, independent] select (_tarafI max 0 min 2);
                private _askC = (_poz nearEntities [["CAManBase"], 40]) select {alive _x && {_tarafOto || {(side (group _x)) isEqualTo _tfC}} && {(side (group _x)) in [west, east, independent]} && {[backpack _x, true] call FUNC(ihaCantaSinif)}};
                if (_askC isNotEqualTo []) then {
                    _cantaObj = ([_askC, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy) select 0;
                    _cantaSn = [backpack _cantaObj] call FUNC(ihaCantaSinif);
                } else {
                    private _hC = (nearestObjects [_poz, ["WeaponHolder", "WeaponHolderSimulated", "GroundWeaponHolder"], 40]) select {(((getBackpackCargo _x) select 0) findIf {[_x, true] call FUNC(ihaCantaSinif)}) >= 0};
                    if (_hC isNotEqualTo []) then {
                        _cantaObj = _hC select 0;
                        private _bc = ((getBackpackCargo _cantaObj) select 0) select (((getBackpackCargo _cantaObj) select 0) findIf {[_x, true] call FUNC(ihaCantaSinif)});
                        _cantaSn = [_bc] call FUNC(ihaCantaSinif);
                    };
                };
                if (_cantaSn isNotEqualTo "" && {_yaratSn isEqualTo ""}) then {
                    _yaratSn = _cantaSn;
                    systemChat format ["[ELITE] IHA: Crocus cantasi bulundu (%1) -> %2%3", ["yerde", name _cantaObj] select (_cantaObj isKindOf "CAManBase"), _cantaSn, ""];
                } else {
                    _cantaObj = objNull;   // kullanici sinifi elle sectiyse canta tuketilmez
                };
            };
            if (isNull _u && {_yaratSn isEqualTo ""} && {_gorev < 2}) exitWith { systemChat "[ELITE] IHA Gorevi: yakinda (40 m) insansiz hava araci yok - modulu IHA'nin / Crocus cantali askerin ustune birak ya da 'Dron yarat' sec"; };
            // v8.339 TARAF: otomatik secimde (1) cantali asker (2) dron / yaratilacak sinifin config tarafi (3) yakindaki en yakin AI askerin tarafi (4) eski varsayilan OPFOR.
            //   Elle secim sinifin tarafiyla celisirse UYARI (kullanici RPT 21-43: B_Crocus_AP gozlem dronlari varsayilan OPFOR ile DOGU olarak dogdu, BATI mevzisinin icinde vuruldu).
            private _dusmanDron = false;
            private _snTaraf = [typeOf _u, _yaratSn] select (isNull _u);
            private _cfgYon = -1;
            if (_snTaraf isNotEqualTo "") then {
                private _cs = getNumber (configFile >> "CfgVehicles" >> _snTaraf >> "side");
                if (_cs in [0, 1, 2]) then { _cfgYon = [1, 0, 2] select _cs; };
            };
            if (_tarafOto) then {
                private _idx = -1;
                if (!isNull _cantaObj && {_cantaObj isKindOf "CAManBase"}) then { _idx = [west, east, independent] find (side (group _cantaObj)); };
                if (_idx < 0) then { _idx = _cfgYon; };
                if (_idx < 0) then {
                    private _yk = (_poz nearEntities [["CAManBase"], 60]) select {alive _x && {(side (group _x)) in [west, east, independent]}};
                    if (_yk isNotEqualTo []) then { _idx = [west, east, independent] find (side (group (([_yk, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy) select 0))); };
                };
                if (_idx < 0) then { _idx = 1; };
                _tarafI = _idx;
                systemChat format ["[ELITE] IHA tarafi OTOMATIK: %1", ["BLUFOR", "OPFOR", "INDEP"] select _tarafI];
            } else {
                // v8.339: sinifin tarafi secilen tarafin DUSMANI ise gorev IPTAL (kullanici: 'eger dron dusmansa iptal etsin, sistem yazi ciksin')
                if (_cfgYon >= 0 && {_cfgYon isNotEqualTo _tarafI} && {(([west, east, independent] select _tarafI) getFriend ([west, east, independent] select _cfgYon)) < 0.6}) then {
                    _dusmanDron = true;
                    systemChat format ["[ELITE] IHA gorevi IPTAL: %1 sinifi %2 (secilen taraf %3 icin DUSMAN dron). Tarafi 'Otomatik' yap ya da dogru tarafi sec.", _snTaraf, ["BLUFOR", "OPFOR", "INDEP"] select _cfgYon, ["BLUFOR", "OPFOR", "INDEP"] select _tarafI];
                    diag_log format ["[IHA-GOREV] IPTAL: %1 sinifi %2, secilen taraf %3 (dusman dron)", _snTaraf, ["BLUFOR", "OPFOR", "INDEP"] select _cfgYon, ["BLUFOR", "OPFOR", "INDEP"] select _tarafI];
                };
            };
            if (_dusmanDron && {_gorev < 2}) exitWith {};
            // v8.268 OPERATOR: modul konumuna (ya da dron varsa dronun yanina) en yakin, IHA tarafindan canli dost asker (40 m)
            private _opMod = round _opI;
            private _op = objNull;
            if (_opMod > 0 && {_gorev < 2}) then {
                private _tfS = [west, east, independent] select (_tarafI max 0 min 2);
                private _opAdaylar = (_poz nearEntities [["CAManBase"], 40]) select {alive _x && {isNull objectParent _x} && {(side (group _x)) isEqualTo _tfS}};
                if (!isNull _cantaObj && {_cantaObj isKindOf "CAManBase"}) then { _opAdaylar = [_cantaObj]; };   // v8.272: cantali asker operatordur
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
            ["lambs_danger_ihaGorev", [["", netId _u] select (!isNull _u), _mod, _turKod, _tarafI, _poz, round _yar, round _men, _yaratSn, round _tetikM, ["", netId _op] select (!isNull _op), _opMod, ["", netId _cantaObj] select (!isNull _cantaObj)]] call CBA_fnc_serverEvent;
            systemChat format ["[ELITE] IHA gorevi gonderildi: %1 -> %2 (%3)", [_yaratSn + ([" - dusman " + str (round _tetikM) + " m'ye girince firlatilacak", " - hemen"] select (_tetikM <= 0)), getText (configOf _u >> "displayName")] select (!isNull _u), _mod, [_turKod, "otomatik tur"] select (_turKod isEqualTo "")];
        }, {}, {}, [_poz, _bagli, _yaratSiniflar]
    ] call EFUNC(main,showDialog);
};
