#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK AKILLI MUHIMMAT SECIMI (v8.359; kullanici: 'tanklar icin akilli muhimmat degistirme ekle'). Yerel, AI suruculu / nisancili (oyuncusuz) TANK ve IFV'lerin ana top mermisi, hedef turune gore degistirilir:
 *   hedef sinifi        tercih sirasi (varsa ilk mevcut)
 *   AGIR  (tank / zirh >= 300)        AP (kinetik, APFSDS)  >  HEAT  >  HE
 *   HAFIF (IFV / APC / zirh >= 100)   HEAT                 >  AP    >  HE
 *   YUMUSAK (kamyon / cip / topsuz)   HE                   >  HEAT  >  AP
 *   PIYADE_TOP (AT'li piyade, statik silah, binada, 2+ kume, > 450 m)  KUTU > HE > HEAT > AP (AP piyadeye en sona kalir); nisanci TOPU secer (v8.360)
 *   PIYADE (tek / dagnik)             top mermisi DEGISTIRILMEZ: koaksiyel MG yeter (v8.360)
 * Mermi turu CONFIG'den siniflanir (mod bagimsiz): once ad / warheadName anahtarlari (apfsds / sabot / heat / mp / he / frag / canister...), olmazsa hit / indirectHit orani (hit >= 150 ve splash <= 25 -> AP; hit >= 150 ve splash > 25 -> HEAT; splash >= 20 -> HE).
 *   Duman / isik / talim mermisi ve ATGM (fuze) secime GIRMEZ. Sinif onbellegi mermi basina.
 * HEDEF: nisancinin guncel hedefi (tankHedefSec secimi <= 12 sn, yoksa assignedTarget; nisanci son 6 sn ates ettiyse en yakin bilinen dusman); hedef yoksa ON YUKLEME: bilinen dusman tank <= 2000 m ya da zirhli <= 1500 m ise ona gore (AP / HEAT), yalniz piyade biliniyorsa dokunmaz.
 * KURALLAR: kategori 2 ardisik turda (1.5 sn) ayni kalmali (gidip gelme yok); degisiklik arasi en az 8 sn; yalniz tercih sirasinda MEVCUT mermiden DAHA UYGUN bir tur varsa degistirilir; stokta olmayan tur secilmez;
 *   degistirme `vehicle loadMagazine [taret, silah, mermi]` (namlu yeniden yuklenir = gercek zaman maliyeti). 6 sn sonra yuklu mermi degismediyse basarisiz sayilir; ayni arac tipinde 2 basarisizlikta o tip icin DESTEKSIZ (tekrar denenmez, RPT'ye yazilir).
 * v8.360 DOGRULAMA DUZELTMESI: currentMagazineTurret SECILI silahin mermisini verir; nisanci piyadeye MG secince top degisimi 'etkisiz' gorunup arac tipi kapaniyordu (RPT 02-11). Artik yalniz top seciliyken olculur.
 * Kapatma: CBA 'Zirh: akilli muhimmat' (lambs_danger_tankMuhimmat) ya da lambs_danger_tankMuhimmatOff = true.  Log: [TANK-MUHIMMAT] (ilk 80) + 90 sn ozeti.
 * Kaynak durumu: kaynak setinde mermi secim kurali YOK (yalniz ATP 7-100.1'de ornek ikmal karisimi: APFSDS + HE-FRAG + HEAT); tercih sirasi ve esikler TASARIM [T]. loadMagazine'in RHS otomatik yukleyicili toplarda etkisi DOGRULANMADI.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_tankMuhimmatStarted") exitWith {false};
lambs_danger_tankMuhimmatStarted = true;

diag_log "[TANK-MUHIMMAT] tank akilli muhimmat secimi baslatildi (v8.359): hedef turune gore AP / HEAT / HE / canister";

lambs_danger_muhimmatSinif = createHashMap;
lambs_danger_muhimmatSilah = createHashMap;
lambs_danger_muhimmatDesteksiz = createHashMap;

[] spawn {
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;

    // ---- mermi turu: AP / HEAT / HE / KUTU / OZEL / ? ----
    private _sinifla = {
        params ["_m"];
        private _k = toLower _m;
        private _c = lambs_danger_muhimmatSinif getOrDefault [_k, ""];
        if (_c isNotEqualTo "") exitWith {_c};
        private _ammo = getText (configFile >> "CfgMagazines" >> _m >> "ammo");
        private _ac = configFile >> "CfgAmmo" >> _ammo;
        private _ad = toLower (_m + "|" + _ammo);
        private _tok = _ad splitString "_|-. ";
        private _wh = toLower (getText (_ac >> "warheadName"));
        private _hit = getNumber (_ac >> "hit");
        private _ind = getNumber (_ac >> "indirectHit");
        private _sim = toLower (getText (_ac >> "simulation"));
        private _t = "?";
        if ((["smoke", "flare", "illum", "chemlight", "signal", "cir_", "practice", "training", "_tp_", "_tpt", "tracer_tp"] findIf {(_ad find _x) >= 0}) >= 0 || {(getNumber (_ac >> "intensity")) > 0} || {_sim in ["shotsmoke", "shotcm", "shotilluminating"]}) then { _t = "OZEL"; } else {
            if (_sim in ["shotmissile", "shotrocket"]) then { _t = "OZEL"; } else {
                if ((["canister", "cannister", "beehive", "flechette", "buckshot"] findIf {(_ad find _x) >= 0}) >= 0) then { _t = "KUTU"; } else {
                    if ((_ad find "heat") >= 0 || {(_wh find "heat") >= 0} || {"mp" in _tok} || {"mpat" in _tok} || {(_ad find "3bk") >= 0} || {(_ad find "3vbk") >= 0}) then { _t = "HEAT"; } else {
                        if ((["apfsds", "apds", "sabot", "fsds", "kinetic", "3bm", "m829", "dm63", "dm53", "dm33"] findIf {(_ad find _x) >= 0}) >= 0 || {"ap" in _tok} || {_wh isEqualTo "ap"}) then { _t = "AP"; } else {
                            if ((_ad find "frag") >= 0 || {"he" in _tok} || {"hesh" in _tok} || {(_ad find "3of") >= 0} || {_wh isEqualTo "he"}) then { _t = "HE"; } else {
                                if (_hit >= 150 && {_ind <= 25}) then { _t = "AP"; } else {
                                    if (_hit >= 150) then { _t = "HEAT"; } else {
                                        if (_ind >= 20) then { _t = "HE"; };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
        lambs_danger_muhimmatSinif set [_k, _t];
        _t
    };

    // ---- ana top: [taret yolu, silah] ya da [] (tip basina onbellek) ----
    private _topBul = {
        params ["_v"];
        private _tip = typeOf _v;
        private _c = lambs_danger_muhimmatSilah getOrDefault [_tip, 0];
        if !(_c isEqualType 0) exitWith {_c};
        private _en = [];
        private _enHit = 0;
        {
            private _p = _x;
            {
                private _w = _x;
                private _cm = compatibleMagazines _w;
                if (_cm isEqualTo []) then { continue };
                private _mh = 0;
                {
                    private _a = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
                    private _sim = toLower (getText (configFile >> "CfgAmmo" >> _a >> "simulation"));
                    if (_sim in ["shotshell", "shotbullet"]) then { _mh = _mh max (getNumber (configFile >> "CfgAmmo" >> _a >> "hit")); };
                } forEach _cm;
                if (_mh >= 40 && {_mh > _enHit}) then { _enHit = _mh; _en = [_p, _w]; };
            } forEach (_v weaponsTurret _p);
        } forEach ([[-1]] + (allTurrets _v));
        lambs_danger_muhimmatSilah set [_tip, _en];
        diag_log format ["[TANK-MUHIMMAT] %1 (%2) ana top: %3", getText (configOf _v >> "displayName"), _tip, if (_en isEqualTo []) then {"YOK (secim yapilmaz)"} else {format ["taret %1 silah %2 (en yuksek hit %3)", _en select 0, _en select 1, _enHit]}];
        _en
    };

    // ---- hedef sinifi ----
    // v8.360 (RPT 02-11: tank piyadeye HE yuklemeyi denedi ama nisanci koaksiyel MG sectigi icin currentMagazineTurret MG mermisini dondurdu -> 'etkisiz' sayilip arac tipi kapandi): piyade ikiye ayrilir:
    //   PIYADE     = tek / dagnik piyade: koaksiyel MG yeter, top mermisi DEGISTIRILMEZ
    //   PIYADE_TOP = top HE'ye deger hedef: AT silahli, statik silah, binada, 2+ kisilik kume (15 m), ya da koaks menzili disinda (> 450 m) -> HE (canister varsa once o) yuklenir ve TOP secilir
    private _hedefKat = {
        params ["_o", "_vv"];
        if (_o isKindOf "StaticWeapon") exitWith {"PIYADE_TOP"};
        if (_o isKindOf "CAManBase") exitWith {
            private _top = (((secondaryWeapon _o) isNotEqualTo "") && {[_o] call FUNC(isATUnit)}) || {(insideBuilding _o) > 0.5} || {(_vv distance2D _o) > 450};
            if (!_top) then {
                _top = ({alive _x && {(side (group _x)) isEqualTo (side (group _o))}} count (_o nearEntities ["CAManBase", 15])) >= 2;
            };
            ["PIYADE", "PIYADE_TOP"] select _top
        };
        if (_o isKindOf "Air") exitWith {""};
        private _sn = [_o] call FUNC(aracSinif);
        private _zirh = getNumber (configOf _o >> "armor");
        if ((_sn select 0) isEqualTo "TANK" || {_o isKindOf "Tank" && {_zirh >= 300}}) exitWith {"AGIR"};
        if ((_sn select 0) in ["IFV", "APC"] || {_zirh >= 100}) exitWith {"HAFIF"};
        "YUMUSAK"
    };

    private _tercih = createHashMapFromArray [
        ["AGIR", ["AP", "HEAT", "HE"]],
        ["HAFIF", ["HEAT", "AP", "HE"]],
        ["YUMUSAK", ["HE", "HEAT", "AP"]],
        ["PIYADE_TOP", ["KUTU", "HE", "HEAT", "AP"]]
    ];

    while {true} do {
        sleep 1.5;
        if (missionNamespace getVariable ["lambs_danger_tankMuhimmatOff", false] || {!(missionNamespace getVariable ["lambs_danger_tankMuhimmat", true])}) then { continue };
        if ((time - _ozetT) >= 0) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[TANK-MUHIMMAT-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        {
            private _v = _x;
            if (!local _v || {!alive _v} || {!(_v isKindOf "LandVehicle")}) then { continue };
            private _gn = gunner _v;
            private _d = driver _v;
            if (isNull _gn || {!alive _gn} || {isNull _d} || {isPlayer _gn} || {isPlayer _d} || {(crew _v) findIf {isPlayer _x} >= 0}) then { continue };
            if ((lambs_danger_muhimmatDesteksiz getOrDefault [typeOf _v, false])) then { continue };
            private _snf = ([_v] call FUNC(aracSinif)) select 0;
            if !(_snf in ["TANK", "IFV"]) then { continue };
            private _top = [_v] call _topBul;
            if (_top isEqualTo []) then { continue };
            _top params ["_yol", "_silah"];
            private _tf = side (group _gn);

            // onceki degisikligin dogrulamasi (6 sn)
            private _bek = _v getVariable [QGVAR(muhBekle), []];
            private _topSecili = (toLower (_v currentWeaponTurret _yol)) isEqualTo (toLower _silah);
            if (_topSecili) then { _v setVariable [QGVAR(muhYuklu), _v currentMagazineTurret _yol]; };   // top seciliyken yuklu mermi guvenilir; degilse son bilinen deger kullanilir
            // top secili degilse (nisanci koaksiyel MG kullaniyor) olcum gecersiz: ARAC TIPI KAPATILMAZ, 25 sn beklenir
            if (_bek isNotEqualTo [] && {_topSecili} && {(time - (_bek select 1)) >= 6}) then {
                _v setVariable [QGVAR(muhBekle), []];
                if ((toLower (_v currentMagazineTurret _yol)) isNotEqualTo (toLower (_bek select 0))) then {
                    private _bs = (_v getVariable [QGVAR(muhBasarisiz), 0]) + 1;
                    _v setVariable [QGVAR(muhBasarisiz), _bs];
                    _say set ["basarisiz", (_say getOrDefault ["basarisiz", 0]) + 1];
                    if (_bs >= 2) then {
                        lambs_danger_muhimmatDesteksiz set [typeOf _v, true];
                        diag_log format ["[TANK-MUHIMMAT] %1 (%2) | loadMagazine 2 kez etkisiz (yuklu: %3, istenen: %4) -> bu arac tipi icin DESTEKSIZ, secim yapilmayacak", getText (configOf _v >> "displayName"), typeOf _v, _v currentMagazineTurret _yol, _bek select 0];
                    };
                } else {
                    _v setVariable [QGVAR(muhBasarisiz), 0];
                    _say set ["dogrulandi", (_say getOrDefault ["dogrulandi", 0]) + 1];
                };
            };
            if (_bek isNotEqualTo [] && {(time - (_bek select 1)) >= 25}) then {
                _v setVariable [QGVAR(muhBekle), []];
                _say set ["dogrulanamadi", (_say getOrDefault ["dogrulanamadi", 0]) + 1];   // top hic secilmedi: ne basari ne basarisizlik
            };

            // taretteki uyumlu mermiler: tur -> [sinif, adet]
            private _uyum = (compatibleMagazines _silah) apply {toLower _x};
            private _tur = createHashMap;
            {
                _x params ["_mc", "_tp", "_adet"];
                if (_tp isEqualTo _yol && {_adet > 0} && {(toLower _mc) in _uyum}) then {
                    private _t = [_mc] call _sinifla;
                    if !(_t in ["OZEL", "?"]) then {
                        private _e = _tur getOrDefault [_t, ["", 0, 0]];
                        _e set [1, (_e select 1) + _adet];
                        if (_adet > (_e select 2)) then { _e set [0, _mc]; _e set [2, _adet]; };   // sinif = o turdeki en dolu sarjor
                        _tur set [_t, _e];
                    };
                };
            } forEach (magazinesAllTurrets _v);
            if (count _tur < 2) then { continue };

            // hedef
            private _hd = objNull;
            if ((time - (_v getVariable [QGVAR(tankHedefT), -999])) < 12) then { _hd = _v getVariable [QGVAR(tankHedefSon), objNull]; };
            if (isNull _hd || {!alive _hd}) then { _hd = assignedTarget _gn; };
            // nisanci son 6 sn icinde ates ettiyse en yakin bilinen dusman guncel hedef sayilir
            if ((isNull _hd || {!alive _hd}) && {(time - (_gn getVariable [QGVAR(sonAtisT), -999])) < 6}) then { _hd = _gn findNearestEnemy _gn; };
            private _kat = "";
            private _neden = "hedef";
            if (!isNull _hd && {alive _hd} && {(_tf getFriend (if (_hd isKindOf "CAManBase") then {side (group _hd)} else {side (group (effectiveCommander _hd))})) < 0.6}) then { _kat = [_hd, _v] call _hedefKat; };
            if (_kat isEqualTo "") then {
                // on yukleme: bilinen dusman zirh (hedef yokken)
                _neden = "on yukleme";
                private _en = (_gn nearTargets 2000) select {
                    private _o = _x select 4;
                    !isNull _o && {alive _o} && {!(_o isKindOf "CAManBase")} && {(_tf getFriend (_x select 2)) < 0.6} && {(_gn knowsAbout _o) >= 0.3}
                };
                private _ak = "";
                {
                    private _o = _x select 4;
                    private _dm = _v distance2D _o;
                    private _k2 = [_o, _v] call _hedefKat;
                    if (_k2 isEqualTo "AGIR" && {_dm <= 2000}) exitWith { _ak = "AGIR"; _hd = _o; };
                    if (_k2 isEqualTo "HAFIF" && {_dm <= 1500} && {_ak isEqualTo ""}) then { _ak = "HAFIF"; _hd = _o; };
                } forEach _en;
                _kat = _ak;
            };
            if (_kat isEqualTo "") then { _v setVariable [QGVAR(muhKat), ""]; continue };

            if (_kat isEqualTo "PIYADE") then { _v setVariable [QGVAR(muhKat), _kat]; continue };   // koaksiyel MG yeter: top mermisine dokunulmaz

            // 2 ardisik tur ayni kategori
            private _onceki = _v getVariable [QGVAR(muhKat), ""];
            _v setVariable [QGVAR(muhKat), _kat];
            if (_onceki isNotEqualTo _kat) then { continue };
            if ((time - (_v getVariable [QGVAR(muhSonT), -999])) < 8) then { continue };

            // piyade icin HE'ye deger hedef: nisanci koaksiyel MG yerine TOPU kullansin (10 sn'de bir)
            if (_kat isEqualTo "PIYADE_TOP" && {!_topSecili} && {(time - (_v getVariable [QGVAR(muhSecT), -999])) > 10} && {!isNull _hd}) then {
                _v setVariable [QGVAR(muhSecT), time];
                _v selectWeaponTurret [_silah, _yol];
                _gn doTarget _hd;
                _say set ["top_secildi", (_say getOrDefault ["top_secildi", 0]) + 1];
            };

            // tercih sirasi -> istenen tur (stokta olan ilk)
            private _sira = _tercih get _kat;
            private _istenen = "";
            { if (_x in _tur) exitWith { _istenen = _x; }; } forEach _sira;
            if (_istenen isEqualTo "") then { continue };
            private _yuklu = if (_topSecili) then {_v currentMagazineTurret _yol} else {_v getVariable [QGVAR(muhYuklu), ""]};
            private _yukluT = if (_yuklu isEqualTo "") then {""} else {[_yuklu] call _sinifla};
            private _rIst = _sira find _istenen;
            private _rYuk = if (_yukluT in _sira) then {_sira find _yukluT} else {99};
            if (_rIst >= _rYuk) then { continue };   // yuklu mermi zaten ayni ya da daha uygun
            private _mc = (_tur get _istenen) select 0;
            if ((toLower _mc) isEqualTo (toLower _yuklu)) then { continue };

            _v loadMagazine [_yol, _silah, _mc];
            if (_kat isEqualTo "PIYADE_TOP") then { _v selectWeaponTurret [_silah, _yol]; };
            _v setVariable [QGVAR(muhSonT), time];
            _v setVariable [QGVAR(muhBekle), [_mc, time]];
            _say set ["degisti", (_say getOrDefault ["degisti", 0]) + 1];
            _say set [format ["%1>%2", _yukluT, _istenen], (_say getOrDefault [format ["%1>%2", _yukluT, _istenen], 0]) + 1];
            if (_logN < 80) then {
                _logN = _logN + 1;
                diag_log format ["[TANK-MUHIMMAT] %1 (%2) | %3: %4 %5 (%6 m) | %7 (%8) -> %9 (%10) | stok: %11", getText (configOf _v >> "displayName"), groupId (group _gn), _neden, _kat, if (isNull _hd) then {"-"} else {typeOf _hd}, if (isNull _hd) then {"-"} else {round (_v distance2D _hd)}, _yuklu, _yukluT, _mc, _istenen, (keys _tur) apply {format ["%1=%2", _x, (_tur get _x) select 1]}];
            };
        } forEach vehicles;
    };
};

true
