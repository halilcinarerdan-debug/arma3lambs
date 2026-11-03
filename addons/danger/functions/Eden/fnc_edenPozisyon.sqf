#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Catisma Pozisyonu modulu (v8.385). Modul konumu = pozisyon, modul YONU (rotasyon) = ates / ilerleme yonu. Pozisyonun NE ISE YARADIGI (tip), ONEM PUANI (1-10),
 * durusu, kapasitesi, sektoru, rol tercihi ve tarafi niteliklerden okunur ve 'lambs_danger_cpListe' kaydina yazilir (publicVariable: AI hangi makinede yerelse orada okunur).
 * Kayit kullanicilari: lambs_main_fnc_findCover (fnc_cpAday: cover / bounding / geri cekilme adayi), fnc_karakolGarnizon (nobet pozisyonu), fnc_mevziKur (SAVUN plani).
 * Grup / birim baglamak GEREKMEZ (SYNC yok): konum + nitelik yeterli. ELITE'in hazir olmasi beklenmez (kayit hemen yazilir; findCover ELITE'ten bagimsiz okur).
 * Kayit: [pos(ATL), yon, tip, puan, taraf, durus, kapasite, sektor, rol, garnizon, ad]   (bicim: fnc_cpAday basligi)
 * Log: [EDEN-POZISYON]. Hata ayiklama: 'Oyunda harita isareti' niteligi.
 *
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

private _tip = ((round (["SAYI", [_logic, "lambs_danger_edPozTip", 0]] call FUNC(edenOrtak))) max 0) min 4;
private _puan = ((round (["SAYI", [_logic, "lambs_danger_edPozPuan", 5]] call FUNC(edenOrtak))) max 1) min 10;
private _taraf = ((round (["SAYI", [_logic, "lambs_danger_edPozTaraf", 0]] call FUNC(edenOrtak))) max 0) min 3;
private _durus = ((round (["SAYI", [_logic, "lambs_danger_edPozDurus", 0]] call FUNC(edenOrtak))) max 0) min 3;
private _kap = ((round (["SAYI", [_logic, "lambs_danger_edPozKap", 2]] call FUNC(edenOrtak))) max 1) min 8;
private _sektor = ((round (["SAYI", [_logic, "lambs_danger_edPozSektor", 360]] call FUNC(edenOrtak))) max 20) min 360;
private _rol = ((round (["SAYI", [_logic, "lambs_danger_edPozRol", 0]] call FUNC(edenOrtak))) max 0) min 4;
private _garn = ["BOOL", [_logic, "lambs_danger_edPozGarnizon", true]] call FUNC(edenOrtak);
private _isaret = ["BOOL", [_logic, "lambs_danger_edPozIsaret", false]] call FUNC(edenOrtak);

private _poz = getPosATL _logic;
private _dir = getDir _logic;
private _tipAd = ["SIPER", "BINA-ICI", "CATI-UST-KAT", "ATES-MEVZII", "GECIS"] select _tip;
if (isNil "lambs_danger_cpListe") then { lambs_danger_cpListe = []; };
private _ad = format ["POZ%1-%2-%3", (count lambs_danger_cpListe) + 1, _tipAd, mapGridPosition _poz];
lambs_danger_cpListe pushBack [_poz, _dir, _tip, _puan, _taraf, _durus, _kap, _sektor, _rol, _garn, _ad];
publicVariable "lambs_danger_cpListe";

if (_isaret) then {
    private _mn = createMarker [format ["ELITE_POZ_%1", count lambs_danger_cpListe], _poz];
    _mn setMarkerShape "ICON";
    _mn setMarkerType (["mil_dot", "mil_box", "mil_triangle", "mil_arrow2", "mil_end"] select _tip);
    _mn setMarkerDir _dir;
    _mn setMarkerColor (["ColorBlack", "ColorOrange", "ColorBlue", "ColorRed", "ColorGreen"] select _tip);
    _mn setMarkerSize [0.7 + (_puan * 0.05), 0.7 + (_puan * 0.05)];
    _mn setMarkerText format ["%1 p%2", _tipAd, _puan];
};

diag_log format ["[EDEN-POZISYON] %1 | tip %2 | puan %3 | taraf %4 | durus %5 | kapasite %6 | sektor %7 | rol %8 | karakol / mevzi %9 | yon %10 | toplam kayit %11",
    _ad, _tipAd, _puan, ["hepsi", "BLUFOR", "OPFOR", "INDEP"] select _taraf, ["otomatik", "yatarak", "comelerek", "ayakta"] select _durus, _kap, _sektor,
    ["herkes", "MARKSMAN", "MG", "AT", "RIFLE"] select _rol, ["evet", "hayir"] select (!_garn), round _dir, count lambs_danger_cpListe];
