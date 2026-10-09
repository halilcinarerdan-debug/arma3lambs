#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * OBJEKTIF GRUP SECIMI (v8.150) — kullanici: "operasyon emri verirken istedigimiz squadlari secebilelim, kimler katilacak".
 * Zeus makinesinde "ELITE Objektif" 4/4 panelinden sonra (Grup secimi = Elle) acilan squad listesi: o tarafin AI gruplari (objektife <= 6000 m, lider canli, oyuncusuz,
 * >= 3 saglam asker, HARIC / MEDEVAC / TOPCU / TASIMA / KARAKOL_ARAC / RECON gorevli ve garnizon alt grubu OLMAYAN) yakindan uzaga, en fazla 16; her panel 8 onay kutusu (otomatik 4 en yakin isaretli).
 * Secilenlerin netId listesi plan ayarina "secili" olarak eklenir; plan (fnc_komutanPlan) YALNIZ bu gruplari kullanir (mesafe siniri yok, komutan en yuksek rutbeli secili grup lideri).
 * Hicbiri secilmezse plan istegi gonderilmez.
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Objektif <ARRAY>
 * 2: Ayar <HASHMAP>
 * 3: Adaylar (ilk cagrida bos birakilir: []) <ARRAY>
 * 4: Baslangic indeksi <NUMBER>
 * 5: Secilen netId'ler <ARRAY>
 *
 * Return Value: None
 * Public: No
*/

params ["_taraf", "_obj", "_ayar", ["_adaylar", []], ["_bas", 0], ["_secili", []]];

if (_adaylar isEqualTo []) then {
    _adaylar = allGroups select {
        private _l = leader _x;
        !isNull _l && {alive _l} && {!isPlayer _l} && {(side _x) isEqualTo _taraf}
        && {({isPlayer _x} count (units _x)) isEqualTo 0}
        && {({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x)) >= 3}
        && {!((_x getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "TASIMA", "KARAKOL_ARAC", "RECON"])}
        && {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}
        && {isNull objectParent _l} && {(_l distance2D _obj) <= 6000}
    };
    _adaylar = [_adaylar, [], {(leader _x) distance2D _obj}, "ASCEND"] call BIS_fnc_sortBy;
    _adaylar = _adaylar select [0, 16];
    if (_adaylar isEqualTo []) exitWith {
        systemChat "[ELITE] Secilebilir grup yok (en az 3 canli AI asker, oyuncusuz, objektife <= 6000 m, HARIC / MEDEVAC / TOPCU / TASIMA / RECON degil)";
    };
};
if (_adaylar isEqualTo []) exitWith {};

private _parca = _adaylar select [_bas, 8];
if (_parca isEqualTo []) exitWith {
    if (_secili isEqualTo []) exitWith { systemChat "[ELITE] Hic grup secilmedi - plan istegi gonderilmedi"; };
    _ayar set ["secili", _secili];
    _ayar set ["grupN", count _secili];
    ["lambs_danger_planIstegi", [_taraf, _obj, _ayar toArray false]] call CBA_fnc_serverEvent;
    diag_log format ["[PLAN-ISTEK] sunucuya gonderildi (elle grup secimi %1): %2", count _secili, _secili apply {groupId (groupFromNetId _x)}];
    systemChat format ["[ELITE] Plan istegi gonderildi: %1 grup secildi", count _secili];
};

private _alanlar = _parca apply {
    private _g = _x;
    private _l = leader _g;
    private _n = {alive _x} count (units _g);
    private _rol = _g getVariable ["lambs_danger_gorev", ""];
    [
        format ["%1 | %2 asker | %3 m | %4%5", groupId _g, _n, round (_l distance2D _obj), rank _l, ["", " | " + _rol] select (_rol isNotEqualTo "")],
        "BOOLEAN",
        format ["Lider %1 (%2). Isaretli grup plana katilir; en yuksek rutbeli secili grup lideri KOMUTAN olur.", name _l, rank _l],
        (_adaylar find _g) < 4,
        ""
    ]
};

[
    format ["ELITE Objektif: katilacak squadlar (%1-%2 / %3)", _bas + 1, _bas + count _parca, count _adaylar],
    _alanlar,
    {
        params ["_deger", "_args"];
        _args params ["_taraf", "_obj", "_ayar", "_adaylar", "_bas", "_secili", "_parca"];
        {
            if (_deger select _forEachIndex) then { _secili pushBackUnique (netId _x); };
        } forEach _parca;
        [{
            params ["_taraf", "_obj", "_ayar", "_adaylar", "_bas", "_secili"];
            [_taraf, _obj, _ayar, _adaylar, _bas + 8, _secili] call (missionNamespace getVariable ["lambs_danger_fnc_objektifGrupSec", {}]);
        }, [_taraf, _obj, _ayar, _adaylar, _bas, _secili]] call CBA_fnc_execNextFrame;
    },
    {},
    [_taraf, _obj, _ayar, _adaylar, _bas, _secili, _parca]
] call EFUNC(main,showDialog);
