#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ELITE YURUNEBILIR ALAN (v8.331; v8.333 Zeus uyumlu) — Eden (3D editor) VE Zeus modulu; yogun objeli hendeklerde AI'nin nesneler USTUNDEN yurumesi icin alan tanimlar. Ad yazmaya gerek yok.
 *   EDEN  : Systems > Modules > 'ELITE Yurunebilir Alan'; dikdortgen / elips alan boyutu ve yonu modulun kendi tutamaclariyla ayarlanir (yari boyutlar: a = yan, b = boy). Modul sunucuda kaydi loglar.
 *   ZEUS  : Zeus modul listesinde ayni modul (LAMBS Danger kategorisi); birakilinca bir ayar paneli acilir: sekil, yari genislik (a), yari boy (b), yon. Panel kapatilsa bile 12 x 4 m varsayilan alan gecerlidir;
 *           alani degistirmek icin modulu silip yeniden birak (ya da Zeus'ta modulu tasi / dondur: merkez ve yon modulun konumu / yonundan okunmaz, panelde girilen degerler gecerlidir).
 * Alan degeri modul nesnesinde 'objectArea' = [a, b, yon, dikdortgenMi, -1] olarak (Zeus'ta public) tutulur; alan listesi fnc_yuruyusAlani ile okunur, yurutme fnc_yuruyusIzle, GORSEL (harita isareti + Zeus 3D cizgi) fnc_yuruyusGorsel.
 *
 * Arguments:
 * 0: Modul <OBJECT>
 * 1: Birimler <ARRAY> (kullanilmaz)
 * 2: Etkin mi <BOOL>
 *
 * Return Value: Yok
 * Public: No
*/

params [["_logic", objNull, [objNull]], ["_units", [], [[]]], ["_activated", true, [true]]];
if (isNull _logic || {!_activated}) exitWith {};

private _alan = _logic getVariable ["objectArea", []];

// ---- ZEUS: calisma zamaninda curator'un makinesinde birakildi (alan degeri henuz yok) ----
if (_alan isEqualTo [] && {hasInterface} && {time > 10} && {local _logic} && {!isNull (getAssignedCuratorLogic player)}) exitWith {
    _logic setVariable ["objectArea", [12, 4, round (getDir _logic), true, -1], true];
    [
        "ELITE Yurunebilir Alan (yogun objeli hendek)",
        [
            ["Sekil", "LIST", "Dikdortgen: hendek / siper hatti. Elips: yuvarlak siper alani.", ["Dikdortgen", "Elips"], 0],
            ["Yari genislik a (m)", "SLIDER", "Alanin yan yari boyutu (toplam genislik = 2 x a).", [2, 80], [1, 1], 12, 0],
            ["Yari boy b (m)", "SLIDER", "Alanin boy yari boyutu (hendegin uzun ekseni genelde bu yondedir; toplam boy = 2 x b).", [2, 80], [1, 1], 4, 0],
            ["Yon (derece)", "SLIDER", "Alanin yonu; b ekseni bu yone bakar (0 = kuzey).", [0, 359], [1, 1], round (getDir _logic), 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_l"];
            _data params ["_sekil", "_a", "_b", "_yon"];
            if (isNull _l) exitWith {};
            _l setVariable ["objectArea", [round _a, round _b, round _yon, _sekil isEqualTo 0, -1], true];
            diag_log format ["[YURUYUS-ALANI] Zeus alani ayarladi: %1 | %2 x %3 m | yon %4 | %5", mapGridPosition _l, round _a, round _b, round _yon, ["dikdortgen", "elips"] select (_sekil isNotEqualTo 0)];
            systemChat format ["[ELITE] Yurunebilir alan: %1 x %2 m, yon %3 (turuncu isaret birkac sn icinde gorunur)", round _a, round _b, round _yon];
        }, {}, {}, [_logic]
    ] call EFUNC(main,showDialog);
};

// ---- EDEN / sunucu: kayit logu ----
if (!isServer) exitWith {};
if (_alan isEqualTo []) then { _alan = [10, 4, 0, true, -1]; };
diag_log format ["[YURUYUS-ALANI] modul kaydedildi: %1 | yari boyut %2 x %3 m | yon %4 | sekil %5", mapGridPosition _logic, _alan param [0, 10], _alan param [1, 4], round (_alan param [2, 0]), ["elips", "dikdortgen"] select (_alan param [3, true])];
