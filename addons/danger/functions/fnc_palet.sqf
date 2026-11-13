#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RENK PALETI FARKINDALIGI (v8.528; kullanici: 'ustlerindeki rengin ortalamasi alinsin, sadece uniforma + vest hesaplansin, botlar renk paletinin farkinda olsun, ona gore texture secimi yapabilsinler').
 *
 * YONTEM 1 (ASIL, v8.532): GERCEK ORTALAMA RENK. SQF'te getTextureInfo komutu texture'un ortalama rengini ([r,g,b,a]) verir (kaynak fikir: rekterakathom/DynamicCamoSystem, ayni komut). v8.528'de 'SQF pikseli okuyamaz'
 *    dedim; YANLISTI: ortalama renk okunabiliyor.  Birim = getObjectTextures'in ilk texture'u (uniforma govdesi; yoksa uniformClass config'inin ilk texture'u) agirlik 0.65 + vest (config hiddenSelectionsTextures'in ilk dolu
 *    texture'u) agirlik 0.35 (vest texture'i config'te yoksa yalniz uniforma). YALNIZ uniforma + vest (kask / canta / yuz yok). Zemin = surfaceTexture'in ortalama rengi (gece x0.75).
 *    Fark x = max(|zemin - birim| / buyuk) 3 kanalda, uyum = 0.5 + 0.5 x cos(180 x): 1 = ayni renk, 0 = tam zit. Texture ortalamalari onbellekli.
 * YONTEM 2 (YEDEK): getTextureInfo yoksa / texture bulunamazsa sinif adi + texture YOLU sozcuk jetonlariyla (snow / desert / woodland / flecktarn / urban / black / multicam ...) palet TAHMINI; jeton yoksa BELIRSIZ (0.5).
 *    misyon degiskeni lambs_danger_paletJetonlari ile [[PALET, [jetonlar]], ...] eklenir.
 * PALETLER: FOREST (koyu yesil / flecktarn / woodland), DESERT (col / kum / tan), SNOW (kar), URBAN (gri / sehir), DARK (siyah / koyu), KARISIK (multicam / MTP / OCP tipi), TOPRAK (zemin: toprak / kaya / camur).
 *
 * Modlar:
 *   ["renk", unit]             -> [r,g,b] <ARRAY>        (uniforma + vest ortalama rengi; [] = bulunamadi)
 *   ["zeminRenk", pos]         -> [r,g,b] <ARRAY>        (zemin ortalama rengi; [] = bulunamadi)
 *   ["birim", unit]            -> palet adi <STRING>     (YEDEK jeton yontemi: uniforma + vest oyu)
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

// ---------- YONTEM 1: GERCEK ORTALAMA RENK (getTextureInfo) ----------
private _sonucRenk = nil;
private _renkVar = (supportInfo "u:gettextureinfo*") isNotEqualTo [];
private _renkAl = {
    params ["_yol"];
    if (_yol isEqualTo "") exitWith {[]};
    private _oc = missionNamespace getVariable ["lambs_danger_texOnbellek", createHashMap];
    missionNamespace setVariable ["lambs_danger_texOnbellek", _oc];
    private _r = _oc get _yol;
    if (isNil "_r") then {
        private _i = getTextureInfo _yol;
        _r = [];
        if (!isNil "_i") then {
            private _c = _i param [2, []];
            if (_c isEqualType [] && {(count _c) >= 3}) then { _r = [_c select 0, _c select 1, _c select 2]; };
        };
        _oc set [_yol, _r];
    };
    _r
};
if (_renkVar && {_mod in ["renk", "zeminRenk", "uyum"]}) then {
    private _zeminRenk = {
        params ["_pz"];
        private _pp = +_pz;
        _pp resize 2;
        private _g = [surfaceTexture _pp] call _renkAl;
        if (_g isNotEqualTo [] && {sunOrMoon < 0.2}) then { _g = _g apply { _x * 0.75 }; };
        _g
    };
    private _birimRenk = {
        params ["_bu"];
        private _tex = (getObjectTextures _bu) param [0, ""];
        private _uc = getText (configFile >> "CfgWeapons" >> (uniform _bu) >> "ItemInfo" >> "uniformClass");
        if (_tex isEqualTo "" && {_uc isNotEqualTo ""}) then {
            { if (_tex isEqualTo "" && {_x isNotEqualTo ""}) then { _tex = _x; }; } forEach (getArray (configFile >> "CfgVehicles" >> _uc >> "hiddenSelectionsTextures"));
        };
        private _vc = vest _bu;
        private _vtex = "";
        if (_vc isNotEqualTo "") then {
            private _vcfg = configFile >> "CfgWeapons" >> _vc;
            { if (_vtex isEqualTo "" && {_x isNotEqualTo ""}) then { _vtex = _x; }; } forEach ((getArray (_vcfg >> "ItemInfo" >> "hiddenSelectionsTextures")) + (getArray (_vcfg >> "hiddenSelectionsTextures")));
        };
        private _u = [_tex] call _renkAl;
        private _v = [_vtex] call _renkAl;
        private _sonuc = [];
        if (_u isNotEqualTo [] && {_v isNotEqualTo []}) then {
            _sonuc = [0, 1, 2] apply { ((_u select _x) * 0.65) + ((_v select _x) * 0.35) };
        } else {
            _sonuc = [_u, _v] select (_u isEqualTo []);
        };
        // ilk 20 farkli uniforma / vest icin log
        private _lk = (uniform _bu) + "|" + _vc;
        private _gor = missionNamespace getVariable ["lambs_danger_paletRenkGor", createHashMap];
        missionNamespace setVariable ["lambs_danger_paletRenkGor", _gor];
        if (!(_lk in _gor) && {(count _gor) < 20}) then {
            _gor set [_lk, true];
            diag_log format ["[PALET-RENK] uniforma:%1 tex:%2 | vest:%3 tex:%4 | ortalama renk (agirlikli): %5 | getTextureInfo ile GERCEK ortalama", uniform _bu, _tex, _vc, _vtex, _sonuc apply { _x toFixed 2 }];
        };
        _sonuc
    };
    if (_mod isEqualTo "renk" && {_a isEqualType objNull} && {!isNull _a}) then { _sonucRenk = [_a] call _birimRenk; };
    if (_mod isEqualTo "zeminRenk" && {_a isEqualType []}) then { _sonucRenk = [_a] call _zeminRenk; };
    if (_mod isEqualTo "uyum" && {_a isEqualType objNull} && {!isNull _a} && {_poz isNotEqualTo []}) then {
        private _pc = [_a] call _birimRenk;
        private _gc = [_poz] call _zeminRenk;
        if (_pc isNotEqualTo [] && {_gc isNotEqualTo []}) then {
            private _x1 = 0;
            for "_k" from 0 to 2 do {
                private _pv = _pc select _k;
                private _gv = _gc select _k;
                _x1 = _x1 max ((abs (_gv - _pv)) / ((_pv max _gv) max 0.0001));
            };
            _sonucRenk = 0.5 + (0.5 * (cos (180 * (_x1 min 1))));
        };
    };
};
if (!isNil "_sonucRenk") exitWith {_sonucRenk};

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
    ["DARK", ["black", "blk", "dark", "night"]],   // v8.531: S.O.G. VC uniformalari renk cesitli (kullanici) -> jeton yok, BELIRSIZ (tarafsiz) kalir
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
        diag_log format ["[PALET] uniforma:%1 | vest:%2 | palet:%3 | oylar:%4 (YEDEK jeton tahmini; getTextureInfo yoksa / texture bulunamadiysa)", _uniforma, _yelek, _pal, _oy];
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
