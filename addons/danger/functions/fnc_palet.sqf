#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RENK PALETI FARKINDALIGI (v8.528; kullanici: 'ustlerindeki rengin ortalamasi alinsin, sadece uniforma + vest hesaplansin, botlar renk paletinin farkinda olsun, ona gore texture secimi yapabilsinler').
 *
 * !! SINIR (dogru bilgi): SQF texture PIKSELLERINI okuyamaz; gercek 'renk ortalamasi' hesaplanamaz. Bu fonksiyon ortalamayi TAHMIN eder:
 *    uniforma + vest (YALNIZ ikisi; kask / sirt cantasi / yuz sayilmaz) icin sinif adi + esyanin config'indeki texture YOLLARI (hiddenSelectionsTextures) kucuk harfe cevrilip
 *    sozcuk jetonlariyla (snow / desert / arid / woodland / flecktarn / urban / black / multicam ...) taranir -> palet oyu. Uniforma agirligi 0.65, vest 0.35; en yuksek oy kazanir.
 *    Jeton bulunamazsa 'BELIRSIZ' (tarafsiz 0.5). Zemin paleti de ayni sekilde surfaceTexture / surfaceType YOLUNDAN tahmin edilir (agac yogunlugu yedegi).
 *    Mod yolu / adi bu jetonlari icermiyorsa tanima BASARISIZ olur; misyon degiskeni lambs_danger_paletJetonlari ile [[PALET, [jetonlar]], ...] listesi eklenebilir (ustune yazar).
 * PALETLER: FOREST (koyu yesil / flecktarn / woodland), DESERT (col / kum / tan), SNOW (kar), URBAN (gri / sehir), DARK (siyah / koyu), KARISIK (multicam / MTP / OCP tipi), TOPRAK (zemin: toprak / kaya / camur).
 *
 * Modlar:
 *   ["birim", unit]            -> palet adi <STRING>     (uniforma + vest oyu; sinif / esya degisince yeniden)
 *   ["zemin", pos]             -> palet adi <STRING>     (zemin: surfaceTexture / surfaceType, yedek agac yogunlugu)
 *   ["uyum", unit, pos]        -> 0..1 <NUMBER>         (birim paleti x zemin paleti uyum puani; 1 = iyi karisir, 0.1 = ceviriye gore cok belirgin, 0.5 = bilinmiyor)
 * Ek: lambs_danger_paletAlgi = false ise "uyum" daima 0.5 doner.
 *
 * Arguments:
 * 0: Mod <STRING>
 * 1: Birim <OBJECT> veya pozisyon <ARRAY>
 * 2: Pozisyon <ARRAY> (yalniz "uyum")
 *
 * Return Value:
 * Palet adi <STRING> veya uyum <NUMBER>
 *
 * Public: No
*/

params [["_mod", "uyum", [""]], ["_a", objNull, [objNull, []]], ["_poz", [], [[]]]];

if (_mod isEqualTo "uyum" && {!(missionNamespace getVariable ["lambs_danger_paletAlgi", true])}) exitWith {0.5};

// metni jetonlara ayir: harf / rakam disindaki her sey '_' olur, bastan sona '_' ile cevrilir -> "_jeton_" aramasi parca eslesmesini onler ('tan' != 'standard')
private _norm = {
    params ["_s"];
    private _d = (toArray (toLower _s)) apply { if (((_x >= 97) && {_x <= 122}) || {(_x >= 48) && {_x <= 57}}) then {_x} else {95} };
    "_" + (toString _d) + "_"
};

private _tab = [
    ["SNOW", ["snow", "winter", "arctic", "white", "wtr", "frost", "ice"]],
    ["DESERT", ["desert", "arid", "sand", "tan", "coyote", "khaki", "dst", "cbr", "aor1", "dune", "dry", "dust"]],
    ["FOREST", ["woodland", "wdl", "forest", "flecktarn", "fleck", "m81", "green", "olive", "oli", "grn", "jungle", "leaf", "vegetation", "dpm", "tiger", "tigerstripe", "grass", "needle", "moss", "swamp", "leaves", "tropic", "nva", "pavn", "tgr", "erdl", "m1967", "og107", "arvn"]],   // v8.530: S.O.G. NVA / ABD / ARVN zeytin-yesil tonlari TAHMINI
    ["URBAN", ["urban", "grey", "gray", "city", "asphalt", "concrete", "tarmac", "pavement", "cobble", "tile"]],
    ["DARK", ["black", "blk", "dark", "night", "vc"]],   // v8.530: S.O.G. VC (vn_o_uniform_vc_*) siyah / koyu pijama TAHMINI
    ["KARISIK", ["multicam", "mcam", "ocp", "scorpion", "mtp", "cadpat", "marpat", "ucp", "mixed"]],
    ["TOPRAK", ["rock", "stone", "gravel", "dirt", "mud", "earth", "soil", "clay", "cliff", "mountain"]]
];
{ _tab pushBack _x; } forEach (missionNamespace getVariable ["lambs_danger_paletJetonlari", []]);

// metin -> palet adi (en cok jeton eslesen; hic yoksa BELIRSIZ)
private _sinifla = {
    params ["_metin"];
    private _m = [_metin] call _norm;
    private _en = "BELIRSIZ";
    private _enN = 0;
    {
        private _n = 0;
        { if ((_m find ("_" + _x + "_")) >= 0) then { _n = _n + 1; }; } forEach (_x select 1);
        if (_n > _enN) then { _enN = _n; _en = _x select 0; };
    } forEach _tab;
    _en
};

// esya sinifi -> metin (sinif adi + uniformClass + texture yollari); uniforma / vest ayni mantik
private _esyaMetni = {
    params ["_c"];
    private _cfg = configFile >> "CfgWeapons" >> _c;
    private _t = _c;
    private _uc = getText (_cfg >> "ItemInfo" >> "uniformClass");
    if (_uc isNotEqualTo "") then {
        _t = _t + " " + _uc;
        { _t = _t + " " + _x; } forEach (getArray (configFile >> "CfgVehicles" >> _uc >> "hiddenSelectionsTextures"));
    };
    { _t = _t + " " + _x; } forEach (getArray (_cfg >> "hiddenSelectionsTextures"));
    { _t = _t + " " + _x; } forEach (getArray (_cfg >> "ItemInfo" >> "hiddenSelectionsTextures"));
    _t
};

if (_mod isEqualTo "zemin") exitWith {
    if !(_a isEqualType []) exitWith {"BELIRSIZ"};
    private _p = +_a;
    _p resize 2;
    private _yol = (surfaceTexture _p) + " " + (surfaceType _p);
    private _r = [_yol] call _sinifla;
    if (_r isEqualTo "BELIRSIZ" && {(count (nearestTerrainObjects [_p, ["TREE", "BUSH"], 25, false, true])) >= 6}) then { _r = "FOREST"; };
    _r
};

if !(_a isEqualType objNull) exitWith {if (_mod isEqualTo "uyum") then {0.5} else {"BELIRSIZ"}};
if (isNull _a) exitWith {if (_mod isEqualTo "uyum") then {0.5} else {"BELIRSIZ"}};

// --- BIRIM PALETI (onbellekli: uniforma + vest sinifi) ---
private _on = missionNamespace getVariable ["lambs_danger_paletOnbellek", createHashMap];
missionNamespace setVariable ["lambs_danger_paletOnbellek", _on];
private _uniforma = uniform _a;
private _yelek = vest _a;
private _anahtar = _uniforma + "|" + _yelek;
private _pal = _on get _anahtar;
if (isNil "_pal") then {
    private _oy = createHashMap;
    {
        _x params ["_sinif", "_agirlik"];
        if (_sinif isNotEqualTo "") then {
            private _p = [([_sinif] call _esyaMetni)] call _sinifla;
            if (_p isNotEqualTo "BELIRSIZ") then { _oy set [_p, (_oy getOrDefault [_p, 0]) + _agirlik]; };
        };
    } forEach [[_uniforma, 0.65], [_yelek, 0.35]];
    _pal = "BELIRSIZ";
    private _enOy = 0;
    { if (_y > _enOy) then { _enOy = _y; _pal = _x; }; } forEach _oy;
    _on set [_anahtar, _pal];
    if (isNil "lambs_danger_paletLogN") then { lambs_danger_paletLogN = 0; };
    if (lambs_danger_paletLogN < 20) then {
        lambs_danger_paletLogN = lambs_danger_paletLogN + 1;
        diag_log format ["[PALET] uniforma:%1 | vest:%2 | palet:%3 | oylar:%4 (jeton tahmini, piksel ortalamasi DEGIL)", _uniforma, _yelek, _pal, _oy];
    };
};

if (_mod isEqualTo "birim") exitWith {_pal};

// --- UYUM: birim paleti x zemin paleti ---
if (_pal isEqualTo "BELIRSIZ" || {_poz isEqualTo []}) exitWith {0.5};
private _zemin = ["zemin", _poz] call FUNC(palet);
if (_zemin isEqualTo "BELIRSIZ") exitWith {0.5};
if (_pal isEqualTo _zemin) exitWith {1};
private _mat = createHashMapFromArray [
    ["KARISIK|FOREST", 0.7], ["KARISIK|DESERT", 0.7], ["KARISIK|TOPRAK", 0.75], ["KARISIK|SNOW", 0.2], ["KARISIK|URBAN", 0.5], ["KARISIK|DARK", 0.4],
    ["FOREST|TOPRAK", 0.6], ["FOREST|DESERT", 0.2], ["FOREST|SNOW", 0.1], ["FOREST|URBAN", 0.3], ["FOREST|DARK", 0.5], ["FOREST|KARISIK", 0.7],
    ["DESERT|TOPRAK", 0.75], ["DESERT|FOREST", 0.2], ["DESERT|SNOW", 0.15], ["DESERT|URBAN", 0.4], ["DESERT|DARK", 0.3], ["DESERT|KARISIK", 0.7],
    ["SNOW|FOREST", 0.1], ["SNOW|DESERT", 0.1], ["SNOW|TOPRAK", 0.15], ["SNOW|URBAN", 0.3], ["SNOW|DARK", 0.2], ["SNOW|KARISIK", 0.2],
    ["URBAN|TOPRAK", 0.5], ["URBAN|FOREST", 0.3], ["URBAN|DESERT", 0.4], ["URBAN|SNOW", 0.35], ["URBAN|DARK", 0.6], ["URBAN|KARISIK", 0.5],
    ["DARK|URBAN", 0.6], ["DARK|FOREST", 0.45], ["DARK|TOPRAK", 0.5], ["DARK|DESERT", 0.3], ["DARK|SNOW", 0.1], ["DARK|KARISIK", 0.4]
];
_mat getOrDefault [_pal + "|" + _zemin, 0.5]
