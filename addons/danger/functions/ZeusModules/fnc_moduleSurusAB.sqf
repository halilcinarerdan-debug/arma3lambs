#include "script_component.hpp"

// ELITE fork (v8.239): "ELITE Arac SURUS A/B Testi" Zeus modulu — AI surucu neden suremiyor? Ayni arac sinifi, temiz murettebat, yan yana seritlerde ELITE kapali / acik, doMove / waypoint, yolcusuz / yolcuyla 300 m ileri gonderilir.
// ACIK, DUZ arazide birakin; modul yonu (Zeus'ta dondurun) = gidis yonu. Sonuc: [SURUS-AB] / [SURUS-AB-OZET] / [SURUS-AB-BISECT] (sunucu RPT) ve Zeus sohbeti. Ayrinti: fnc_surusAB.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    private _yon = getDir _logic;
    deleteVehicle _logic;
    private _liste = ["SINIFLAR"] call FUNC(surusAB);
    // yakindaki araclarin siniflari (30 m) = 2. secenek
    private _yakin = [];
    { if (_x isKindOf "LandVehicle" && {!(_x isKindOf "StaticWeapon")}) then { _yakin pushBackUnique (typeOf _x); }; } forEach (_poz nearEntities [["LandVehicle"], 30]);
    private _etiket = ["(yok)", format ["(30 m icindeki araclar: %1 sinif)", count _yakin]] + (_liste apply { _x select 1 });
    [
        "ELITE Arac SURUS A/B Testi",
        [
            ["Arac sinifi 1", "LIST", "Test edilecek arac sinifi (RHS APC / IFV / kamyon dahil, >= 6 yolcu). '(30 m icindeki araclar)' = modulun yanina koydugunuz araclarin siniflari.", _etiket, 0],
            ["Arac sinifi 2 (istege bagli)", "LIST", "Karsilastirma: ornegin tekerlekli ve paletli.", _etiket, 0],
            ["Arac sinifi 3 (istege bagli)", "LIST", "Ucuncu sinif.", _etiket, 0],
            ["Test seti", "LIST", "Temel (A-G): ELITE kapali/acik, doMove/waypoint, yolcu, RECON profili. Recon ayristirma (C,H-M): yolcusuz; hangi komut recon'u bozuyor (doStop / waypoint+doMove / SAFE-GREEN-isiksiz / forceSpeed 9). Yolcu ayristirma (C,N-R,T,U): kargo yolcusu (sayi, ayni grup, orderGetIn, ELITE kapali, RELOKE / JOIN). Koltuk / komut (C,K1-K7): yolcu FFV disi koltukta mi, etkin komutana da doMove, rutbe, yolcu AI kapali.", ["Temel (A-G)", "Recon ayristirma (H-M)", "Yolcu ayristirma (N-U)", "Koltuk / komut ayristirma (K1-K7)"], 3],
            ["ELITE acik varyantlari (yalniz Temel set)", "BOOLEAN", "Temel sette kapaliysa yalniz A / B calisir. Diger setlerde etkisiz.", true, ""],
            ["Test suresi (sn)", "SLIDER", "Her varyantin gidis suresi (olcum her saniye).", [10, 30], [1, 5], 15, 0],
            ["Otomatik bisect (suclu izleyici ara)", "BOOLEAN", "ELITE-acik varyant gitmiyor ama saf gidiyorsa, izleyici kapatma anahtarlari GECICI olarak global kapatilip ikili aramayla suclu aranir (~60 sn ek). Test oturumu icin.", false, ""]
        ],
        {
            params ["_d", "_args"];
            _args params ["_poz", "_yon", "_liste", "_yakin"];
            _d params ["_i1", "_i2", "_i3", "_set", "_elite", "_sure", "_bisect"];
            private _siniflar = [];
            {
                private _i = round _x;
                if (_i isEqualTo 1) then { { _siniflar pushBackUnique _x; } forEach _yakin; };
                if (_i >= 2) then { _siniflar pushBackUnique ((_liste select (_i - 2)) select 0); };
            } forEach [_i1, _i2, _i3];
            _siniflar = _siniflar select [0, 3];
            if (_siniflar isEqualTo []) exitWith { systemChat "[ELITE] Arac sinifi secilmedi - test baslatilmadi"; };
            ["lambs_danger_surusABIstegi", [_siniflar, _poz, _yon, _elite, round _set, round _sure, _bisect, clientOwner]] call CBA_fnc_serverEvent;
            diag_log format ["[SURUS-AB-ISTEK] sunucuya gonderildi: %1 | elite %2 set %3 sure %4 bisect %5", _siniflar, _elite, round _set, round _sure, _bisect];
            systemChat format ["[ELITE] Surus A/B testi baslatildi (%1 sinif); sonuc ~%2 sn icinde Zeus sohbetine", count _siniflar, 30 + round _sure];
        }, {}, {}, [_poz, _yon, _liste, _yakin]
    ] call EFUNC(main,showDialog);
};
