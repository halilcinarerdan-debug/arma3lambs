#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE FACTION EKLE (v8.237, Dilim A0) — faction listesinden asker sayisi (Zeus'suz elle koymadan): verilen sayida asker, faction'in squad sablonlariyla SANAL profil olarak
 * merkez etrafindaki yaricapa dagitilir (kara uzerinde, egimi dusuk). Fiziksel hale gelme kurallari fnc_cepheDongu'de (oyuncu yakinligi / operasyon alani / temas / cephe seridi).
 * Personnel Replacement rezervi (yedek havuz) faction kaydina eklenir. 'varisYap' = bu konum bu tarafin takviye varis noktasi olur.
 * Mission maker API'si (sunucuda): [faction, adet, rezerv, merkez, yaricap, varisYap] call lambs_danger_fnc_cepheFaction;
 *   ornek: ["rhs_faction_usarmy_wd", 240, 120, getPosATL ornekNesne, 800, true] call lambs_danger_fnc_cepheFaction;
 * Squad sablonu yoksa (CfgGroups kaydi olmayan faction) yaya sinif havuzundan 8'lik rastgele squad kurulur (TASARIM DEGERI). Son squad kalan sayiya gore kucuk olabilir.
 * Log: [CEPHE-FACTION]
 *
 * Arguments:
 * 0: Faction sinifi <STRING>
 * 1: Eklenecek asker sayisi <NUMBER>
 * 2: Rezerv havuzuna eklenecek asker <NUMBER> (default: 0)
 * 3: Merkez <ARRAY> (default: [0,0,0])
 * 4: Yaricap <NUMBER> (default: 600)
 * 5: Merkez takviye varis noktasi olsun <BOOL> (default: false)
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

params [["_f", "", [""]], ["_adet", 0, [0]], ["_rezerv", 0, [0]], ["_merkez", [0, 0, 0], [[]]], ["_yaricap", 600, [0]], ["_varis", false, [false]]];

if (!isServer) exitWith {false};
call FUNC(cepheInit);

private _sideNum = getNumber (configFile >> "CfgFactionClasses" >> _f >> "side");
if !(_sideNum in [0, 1, 2]) exitWith {
    ["HATA", format ["faction '%1' taninmiyor ya da taraf BLUFOR / OPFOR / INDEP degil (side=%2)", _f, _sideNum]] call FUNC(cepheLog);
    false
};
private _taraf = [east, west, independent] select _sideNum;

[] call FUNC(cepheFactionListe);   // yaya sinif havuzunu doldurur (onbellek)
private _sablon = [_f] call FUNC(cepheSablon);
private _adamSinif = (lambs_danger_cepheAdamSinif getOrDefault [_f, []]);
if (_sablon isEqualTo [] && {_adamSinif isEqualTo []}) exitWith {
    ["HATA", format ["faction '%1' icin ne squad sablonu ne yaya sinifi bulundu", _f]] call FUNC(cepheLog);
    false
};

private _fh = lambs_danger_cepheFactionlar getOrDefault [_f, createHashMapFromArray [["hedef", 0], ["rezerv", 0], ["olu", 0], ["takviyeGelen", 0]]];
_fh set ["taraf", _taraf];
_fh set ["ad", getText (configFile >> "CfgFactionClasses" >> _f >> "displayName")];
_fh set ["merkez", +_merkez];
_fh set ["rezerv", (_fh getOrDefault ["rezerv", 0]) + (_rezerv max 0)];
lambs_danger_cepheFactionlar set [_f, _fh];
if (_varis) then { lambs_danger_cepheVaris set [str _taraf, +_merkez]; };

// panelde faction eklenmesi = kullanici sistemi acmak istiyor demektir (CBA 'aktif' ayari kapaliysa da)
if (!(missionNamespace getVariable ["lambs_danger_cepheAktif", false]) && {_adet > 0}) then {
    lambs_danger_cepheAktif = true;
    ["AYAR", "cephe sistemi faction paneli ile ACILDI (CBA 'ELITE Cephe Komutani > Aktif' kapaliydi)"] call FUNC(cepheLog);
};

["FACTION", format ["%1 (%2) | taraf %3 | +%4 asker, +%5 rezerv | merkez %6 yaricap %7 m | varis noktasi: %8 | sablon %9, yaya sinif %10", _f, _fh get "ad", _taraf, _adet, _rezerv, mapGridPosition _merkez, round _yaricap, _varis, count _sablon, count _adamSinif]] call FUNC(cepheLog);

if (_adet <= 0) exitWith {true};

[_f, _adet, _taraf, _sablon, _adamSinif, _merkez, _yaricap, _fh] spawn {
    params ["_f", "_adet", "_taraf", "_sablon", "_adamSinif", "_merkez", "_yaricap", "_fh"];
    private _kalan = round _adet;
    private _squadSay = 0;
    private _askerSay = 0;
    private _agirliklar = _sablon apply { count _x };
    while {_kalan > 0} do {
        private _sinifler = if (_sablon isNotEqualTo []) then {
            +(_sablon selectRandomWeighted _agirliklar)
        } else {
            private _s = [];
            for "_i" from 1 to 8 do { _s pushBack (selectRandom _adamSinif); };
            _s
        };
        if ((count _sinifler) > _kalan) then { _sinifler resize _kalan; };
        // kara + dusuk egim (en cok 15 deneme; olmazsa merkez)
        private _poz = +_merkez;
        for "_i" from 1 to 15 do {
            private _a = _merkez getPos [(sqrt random 1) * _yaricap, random 360];
            if (!surfaceIsWater _a && {((surfaceNormal _a) select 2) > 0.92}) exitWith { _poz = _a; };
        };
        _poz resize 3;
        _poz set [2, 0];
        [_f, _taraf, _sinifler, _poz] call FUNC(cepheProfilYap);
        _kalan = _kalan - (count _sinifler);
        _squadSay = _squadSay + 1;
        _askerSay = _askerSay + (count _sinifler);
        sleep 0.03;
    };
    _fh set ["hedef", (_fh getOrDefault ["hedef", 0]) + _askerSay];
    ["FACTION", format ["%1 | %2 sanal squad profili olusturuldu (%3 asker); fiziksel hale gelme fnc_cepheDongu kurallarina bagli", _f, _squadSay, _askerSay]] call FUNC(cepheLog);
};

true
