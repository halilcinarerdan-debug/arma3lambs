#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * OBJEKTIF GRUP SECIMI (v8.150) — kullanici: "operasyon emri verirken istedigimiz squadlari secebilelim, kimler katilacak".
 * Zeus makinesinde "ELITE Objektif" 4/4 panelinden sonra (Grup secimi = Elle) acilan squad listesi: o tarafin AI gruplari (objektife <= 6000 m, lider canli, oyuncusuz,
 * >= 3 saglam asker, HARIC / MEDEVAC / TOPCU / TASIMA / KARAKOL_ARAC / RECON gorevli ve garnizon alt grubu OLMAYAN) yakindan uzaga, en fazla 12 piyade + 8 arac (v8.163); her panel 8 onay kutusu (otomatik 4 en yakin isaretli).
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
// v8.178 HQ: ayar "hqId" doluysa YALNIZ o HQ / US kategorisine atanmis squadlar listelenir (tum taraf yerine); ayar "mod" = "HQ_ATAMA": HQ'ya squad atama paneli (sonunda hqAtama olayi)
private _hqId = _ayar getOrDefault ["hqId", ""];
private _atamaModu = (_ayar getOrDefault ["mod", ""]) isEqualTo "HQ_ATAMA";
private _hqSuz = {
    params ["_g"];
    (_atamaModu) || {_hqId isEqualTo ""} || {(_g getVariable ["lambs_danger_hqId", ""]) isEqualTo _hqId}
};

if (_adaylar isEqualTo []) then {
    _adaylar = allGroups select {
        private _l = leader _x;
        !isNull _l && {alive _l} && {!isPlayer _l} && {(side _x) isEqualTo _taraf}
        && {({isPlayer _x} count (units _x)) isEqualTo 0}
        && {({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x)) >= 3}
        && {!((_x getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "TASIMA", "KARAKOL_ARAC", "RECON"])}
        && {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""} && {(_atamaModu || {!(_x getVariable ["lambs_danger_planAktif", false])})}
        && {isNull objectParent _l} && {[_x] call _hqSuz} && {_atamaModu || {_hqId isNotEqualTo ""} || {(_l distance2D _obj) <= 6000}}
    };
    _adaylar = [_adaylar, [], {(leader _x) distance2D _obj}, "ASCEND"] call BIS_fnc_sortBy;
    _adaylar = _adaylar select [0, [12, 16] select (_hqId isNotEqualTo "" || _atamaModu)];
    // v8.163: ARAC gruplari da listelenir (tank -> ZIRH DESTEK, kargo >= 3 arac -> TASIMA); onceden yalniz piyade vardi ("hangi apc katilacak yok")
    private _aracA = allGroups select {
        private _l = leader _x;
        private _v = if (isNull _l) then {objNull} else {objectParent _l};
        !isNull _l && {alive _l} && {!isPlayer _l} && {(side _x) isEqualTo _taraf}
        && {!isNull _v} && {_v isKindOf "LandVehicle"} && {alive _v} && {canMove _v}
        && {({isPlayer _x} count (units _x)) isEqualTo 0} && {!isNull (driver _v)} && {!isPlayer (driver _v)}
        && {!((_x getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC", "RECON"])}
        && {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""} && {_atamaModu || {!(_x getVariable ["lambs_danger_planAktif", false])}} && {[_x] call _hqSuz} && {_atamaModu || {_hqId isNotEqualTo ""} || {(_l distance2D _obj) <= 6000}}
    };
    _aracA = [_aracA, [], {(leader _x) distance2D _obj}, "ASCEND"] call BIS_fnc_sortBy;
    _aracA = _aracA select [0, [8, 12] select (_hqId isNotEqualTo "" || _atamaModu)];
    _adaylar = _adaylar + _aracA;
    if (_adaylar isEqualTo [] && {_hqId isNotEqualTo ""}) exitWith {
        systemChat format ["[ELITE] %1 kategorisine atanmis uygun squad yok - once 'ELITE HQ / US Kur' modulu ile squad atayin (>= 3 saglam asker, AI, planda olmayan)", _hqId];
        diag_log format ["[PLAN-ISTEK] elle secim: %1 icin atanmis uygun squad yok", _hqId];
    };
    if (_adaylar isEqualTo []) exitWith {
        // v8.161 TANI: hangi tarafta kac grup var / neden elendi (secilen taraf yanlis olabilir)
        private _say = {
            params ["_t"];
            private _hepsi = allGroups select {(side _x) isEqualTo _t && {!isNull (leader _x)} && {!isPlayer (leader _x)}};
            private _saglam = _hepsi select {({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x)) >= 3};
            private _yakin = _saglam select {((leader _x) distance2D _obj) <= 6000};
            [count _hepsi, count _saglam, count _yakin]
        };
        private _ad = switch (_taraf) do { case west: {"BLUFOR"}; case east: {"OPFOR"}; case independent: {"INDEP"}; default {str _taraf} };
        private _bw = [west] call _say; private _be = [east] call _say; private _bi = [independent] call _say;
        systemChat format ["[ELITE] Secilebilir grup yok | secilen taraf: %1 | AI grup / >=3 saglam asker / objektife <= 6000 m -> BLUFOR %2, OPFOR %3, INDEP %4 | HARIC / MEDEVAC / TOPCU / TASIMA / RECON ve garnizon alt grubu elenir", _ad, _bw, _be, _bi];
        diag_log format ["[PLAN-ISTEK] elle secim: aday yok | taraf %1 | BLUFOR %2 OPFOR %3 INDEP %4", _ad, _bw, _be, _bi];
    };
};
if (_adaylar isEqualTo []) exitWith {};

private _parca = _adaylar select [_bas, 8];
if (_parca isEqualTo []) exitWith {
    if (_atamaModu) exitWith {
        ["lambs_danger_hqAtama", [_hqId, _secili]] call CBA_fnc_serverEvent;
        diag_log format ["[HQ-ISTEK] atama sunucuya gonderildi: %1 | %2 squad", _hqId, count _secili];
        systemChat format ["[ELITE] %1: %2 squad atandi (secilmeyen eski atamalar kaldirildi)", _hqId, count _secili];
    };
    if (_secili isEqualTo []) exitWith { systemChat "[ELITE] Hic grup secilmedi - plan istegi gonderilmedi"; };
    // v8.167 KAPASITE UYARISI: secilen tasima araclarinin kargo koltugu ile secilen piyade sayisi esit degilse uyar
    private _asker = 0;
    private _koltuk = 0;
    private _aracSay = 0;
    {
        private _sg = groupFromNetId _x;
        if (isNull _sg) then { continue };
        private _sv = objectParent (leader _sg);
        if (!isNull _sv && {_sv isKindOf "LandVehicle"}) then {
            private _sn = ([_sv] call (missionNamespace getVariable ["lambs_danger_fnc_aracSinif", {["DIGER"]}])) select 0;
            if (_sn in ["IFV", "APC", "KAMYON"]) then {
                _aracSay = _aracSay + 1;
                _koltuk = _koltuk + ((_sv emptyPositions "cargo") min (missionNamespace getVariable [format ["lambs_danger_tasimaKap_%1", typeOf _sv], 99]));
            };
        } else {
            _asker = _asker + ({alive _x && {isNull objectParent _x}} count (units _sg));
        };
    } forEach _secili;
    if (_aracSay > 0 && {_asker isNotEqualTo _koltuk}) then {
        private _msg = if (_asker > _koltuk) then {
            format ["[ELITE] UYARI: %1 piyade secildi ama %2 tasima aracinin toplam %3 kargo koltugu var -> %4 asker ilk seferde sigmaz (ek sefer / yuruyus)", _asker, _aracSay, _koltuk, _asker - _koltuk]
        } else {
            format ["[ELITE] UYARI: %1 piyade secildi, %2 tasima aracinin %3 kargo koltugu var -> %4 koltuk bos kalir (bazi araclar bos olabilir)", _asker, _aracSay, _koltuk, _koltuk - _asker]
        };
        systemChat _msg;
        diag_log _msg;
    };
    // v8.176 KULLANICI HATASI KORUMASI: en az bir PIYADE grubu sart (yalniz arac secilirse plan kurulamaz); savunmada 1200 m'den uzak piyade uyarisi
    private _piyadeSec = _secili select {private _g = groupFromNetId _x; !isNull _g && {isNull objectParent (leader _g)}};
    if (_piyadeSec isEqualTo []) exitWith {
        systemChat "[ELITE] HATA: hic PIYADE grubu secilmedi (yalniz arac secildi) - istek gonderilmedi; yeniden deneyin";
        diag_log "[PLAN-ISTEK] elle secim reddedildi: piyade grubu yok";
    };
    if ((_ayar getOrDefault ["tip", 0]) isEqualTo 1) then {
        private _uzak = _piyadeSec select {private _g = groupFromNetId _x; !isNull _g && {((leader _g) distance2D _obj) > 1200}};
        if (_uzak isNotEqualTo []) then {
            private _m = format ["[ELITE] UYARI: %1 secili grup mevziye 1200 m'den uzak (%2) - yuruyerek gelecek", count _uzak, _uzak apply {groupId (groupFromNetId _x)}];
            systemChat _m;
            diag_log _m;
        };
    };
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
    private _av = objectParent _l;
    if (!isNull _av) then {
        private _sa = [_av] call FUNC(aracSinif);
        private _etiket = switch (_sa select 0) do {
            case "TANK": {"TANK: ZIRH DESTEK"};
            case "IFV": {format ["IFV: tasir + ates destegi (%1 koltuk)", _sa select 1]};
            case "APC": {format ["APC: savas taksisi (%1 koltuk)", _sa select 1]};
            case "KAMYON": {format ["KAMYON: tasir (%1 koltuk)", _sa select 1]};
            default {"ARAC: ZIRH DESTEK"};
        };
        [
            format ["[%1] %2 | %3 m | %4%5", _etiket, getText (configOf _av >> "displayName"), round (_l distance2D _obj), groupId _g, ["", " | " + _rol] select (_rol isNotEqualTo "")],
            "BOOLEAN",
            format ["Arac grubu (surucu %1). Isaretlenirse: TANK / diger -> ates pozisyonuna cikip objektife ates destegi; IFV -> piyadeyi tasir, indirince ates destegine gecer; APC / KAMYON -> piyadeyi tasir, indirince atesten uzak geride bekler (savas taksisi).", name (driver _av)],
            false,
            ""
        ]
    } else {
        [
            format ["%1 | %2 asker | %3 m | %4%5", groupId _g, _n, round (_l distance2D _obj), rank _l, ["", " | " + _rol] select (_rol isNotEqualTo "")],
            "BOOLEAN",
            format ["Lider %1 (%2). Isaretli grup plana katilir; en yuksek rutbeli secili grup lideri KOMUTAN olur.", name _l, rank _l],
            (_adaylar find _g) < 4,
            ""
        ]
    }
};

[
    format ["%1 (%2-%3 / %4)", _ayar getOrDefault ["baslik", "ELITE Objektif: katilacak squadlar"], _bas + 1, _bas + count _parca, count _adaylar],
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
    {},   // onLoad (v8.160: eksikti -> arguman dizisi onLoad sanilip "call [..]" hatasi verdi, OK calismadi; RPT bf897b86)
    [_taraf, _obj, _ayar, _adaylar, _bas, _secili, _parca]
] call EFUNC(main,showDialog);
