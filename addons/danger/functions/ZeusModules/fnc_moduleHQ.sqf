#include "script_component.hpp"

// ELITE fork (v8.178): "ELITE HQ / US Kur" Zeus modulu — modulun birakildigi nokta bir KOMUTA NOKTASI (HQ1 / HQ2 / HQ3 / US) olur; squadlar bu kategoriye ATANIR.
// Objektif planlari bir HQ / US'ten baslar (ELITE Objektif 1/4: "Komuta noktasi"); katilacak squadlar YALNIZ o kategoriye atananlar arasindan secilir.
// Plan iptal edilince / basarisiz olunca (rally point sonrasi dahil) atanmis gruplar ve araclar bu noktaya geri doner.
// Ayni kategori + taraf tekrar kurulursa kayit tasinir / guncellenir (atamalar korunur). Kaldirma: "ELITE Karakol / Plan KALDIR" listesi.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    deleteVehicle _logic;
    [
        "ELITE HQ / US Kur",
        [
            ["Taraf", "LIST", "Bu komuta noktasinin tarafi.", ["BLUFOR", "OPFOR", "INDEP"], 0],
            ["Kategori", "LIST", "HQ1 / HQ2 / HQ3 / US. Ayni kategori + taraf tekrar kurulursa tasinir.", ["HQ1", "HQ2", "HQ3", "US (ana ussu)"], 0],
            ["Yaricap (m)", "SLIDER", "Donuste 'ulasti' sayilma mesafesi ve harita isareti.", [30, 300], [10, 50], 100, 0],
            ["Squad atama", "LIST", "Elle: kurulunca squad listesi acilir; bu kategoriye atanacak squadlari isaretlersiniz (onceki atamalar listeye gore guncellenir). Sonra: yalniz nokta kurulur, atamayi tekrar bu modulle yaparsiniz.", ["Elle sec (liste)", "Sonra"], 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz"];
            _data params ["_tarafI", "_katI", "_yar", "_atama"];
            private _taraf = [west, east, independent] select (_tarafI max 0 min 2);
            private _kat = ["HQ1", "HQ2", "HQ3", "US"] select (_katI max 0 min 3);
            ["lambs_danger_hqIstegi", [_taraf, _poz, _katI, round _yar]] call CBA_fnc_serverEvent;
            diag_log format ["[HQ-ISTEK] sunucuya gonderildi: %1 %2 | %3 | yaricap %4 m | atama %5", _kat, _taraf, mapGridPosition _poz, round _yar, ["ELLE", "SONRA"] select (_atama isEqualTo 1)];
            systemChat format ["[ELITE] %1 (%2) istegi sunucuya gonderildi", _kat, _taraf];
            if (_atama isEqualTo 0) then {
                [{
                    params ["_taraf", "_poz", "_hqId"];
                    [_taraf, _poz, createHashMapFromArray [["mod", "HQ_ATAMA"], ["hqId", _hqId], ["tip", 1], ["baslik", format ["ELITE %1: bu kategoriye atanacak squadlar", _hqId]]]] call (missionNamespace getVariable ["lambs_danger_fnc_objektifGrupSec", {systemChat "[ELITE] objektifGrupSec yuklu degil"}]);
                }, [_taraf, _poz, format ["%1_%2", _kat, _taraf]]] call CBA_fnc_execNextFrame;
            };
        }, {}, {}, [_poz]
    ] call EFUNC(main,showDialog);
};
