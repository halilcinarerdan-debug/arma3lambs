#include "script_component.hpp"

// ELITE fork (v8.33): "ELITE Kumanda (HQ)" Zeus modulu (LAMBS Danger kategorisi).
// Yerlestirilince secenek penceresi acilir; Tamam = kumanda aktif (lambs_danger_hqAktif, herkese yayinlanir). Kumanda baska hicbir yolla acilmaz.
// Ayni modul tekrar yerlestirilip "Kumanda aktif" kapatilirsa kumanda durur.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _tip = {
        params ["_ad", "_varsayilan"];
        missionNamespace getVariable [_ad, _varsayilan]
    };

    [
        "ELITE Kumanda (HQ)",
        [
            ["Kumanda aktif", "BOOLEAN", "Kapali: kumanda hicbir sey yapmaz. Acik: gruplar arasi koordinasyon calisir (asagidaki secenekler).", true, ""],
            ["Istihbarat paylasimi (SPOTREP agi)", "BOOLEAN", "Bir grubun gordugu dusman telsiz menzilindeki (1500 m) diger gruplara 2-6 sn gecikmeyle bildirilir.", ["lambs_danger_hqIstihbaratV1", true] call _tip, ""],
            ["Takviye (zor durumdaki gruba yardim)", "BOOLEAN", "Zor durumdaki gruba musait 1-2 grup dusmanin kanadindan yaklasarak yardima gider.", ["lambs_danger_hqTakviyeV1", true] call _tip, ""],
            ["Kanat manevrasi (sabitle + kusat)", "BOOLEAN", "Temasta sabit bir gruba ikinci grup dusmanin kanadindan hucum eder; yeterli grup varsa cift kusatma.", ["lambs_danger_hqKanatV1", true] call _tip, ""],
            ["Medevac (hekimi olmayan gruba hekim)", "BOOLEAN", "Yalniz ACE saglik sisteminde baygin asker varsa anlamli. Kapali tutulabilir.", ["lambs_danger_hqMedevacV1", false] call _tip, ""],
            ["LAMBS dynamic reinforcement'i kapat", "BOOLEAN", "Acik: LAMBS'in kendi takviye sistemi (bayrakli tum gruplar ayni anda kosar) kapatilir; takviyeyi yalniz kumanda yapar.", ["lambs_danger_hqUpstreamKapat", true] call _tip, ""]
        ],
        {
            params ["_data", "_args"];
            _args params ["_logic"];
            _data params ["_aktif", "_ist", "_tak", "_kan", "_med", "_upKapat"];
            missionNamespace setVariable ["lambs_danger_hqAktif", _aktif, true];
            missionNamespace setVariable ["lambs_danger_hqIstihbaratV1", _ist, true];
            missionNamespace setVariable ["lambs_danger_hqTakviyeV1", _tak, true];
            missionNamespace setVariable ["lambs_danger_hqKanatV1", _kan, true];
            missionNamespace setVariable ["lambs_danger_hqMedevacV1", _med, true];
            missionNamespace setVariable ["lambs_danger_hqUpstreamKapat", _upKapat, true];
            diag_log format ["[HQ-MODUL] kumanda %1 | istihbarat:%2 takviye:%3 kanat:%4 medevac:%5 | LAMBS reinforcement kapat:%6", ["KAPALI", "AKTIF"] select _aktif, _ist, _tak, _kan, _med, _upKapat];
            deleteVehicle _logic;
        }, {
            params ["_logic"];
            deleteVehicle _logic;
        }, {
            params ["_logic"];
            deleteVehicle _logic;
        }, [_logic]
    ] call EFUNC(main,showDialog);
};
