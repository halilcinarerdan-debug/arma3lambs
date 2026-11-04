#include "script_component.hpp"

// ELITE fork (v8.130): "ELITE Karakol Garnizon" Zeus modulu — bir KARAKOLUN (ELITE Karakol / HQ) icinde nobetci, devriye alt gruplari, ust kat pozisyonlari ve arac mevzileri.
// Modul karakolun yaricapi + CBA garnizonEk (v8.393: varsayilan 500 m, eskiden sabit 150) icine birakilir (en yakin karakol secilir; GARNIZON ALANI karakolun yaricapidir, modulun konumu degil); ayni modul tekrar calistirilirsa ayar ve pozisyonlar YENIDEN hesaplanir (birimler orijinal gruplarina doner, sonra yeniden dagitilir).
// v8.400 SADELESTIRME: yakinda karakol YOKSA karakol OTOMATIK kurulur (taraf: en yakin AI asker; yaricap 150 m) - ayri 'Karakol' modulu sart degil. Panel: fnc_garnizonPanel ('ELITE Karakol / Mevzi' modulunun 'Garnizon = Ozel' secimi de ayni paneli acar).
// Yeni birimler (karakol icine konan / gelen) bir sonraki 15 sn'lik turda havuza girer ve eksik nobet / devriyeyi tamamlar. Kaldir: garnizon bosaltilir.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    deleteVehicle _logic;
    [_poz] call FUNC(garnizonPanel);
};
