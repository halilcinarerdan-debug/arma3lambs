#include "script_component.hpp"

// ELITE fork (v8.127): "ELITE Gorev Ata" Zeus modulu — bir birimin / grubun / aracin ustune birakilir; hangi squad / arac hangi gorevi yapacak Zeus secer.
// Atama grupta (ve aractaysa araca) 'lambs_danger_gorev' degiskeni olarak tutulur; ELITE Objektif plani, topcu atesi ve arac medevac bunu okur.
//   Otomatik        : atama silinir (sistem kendi secer)
//   MANEVRA / DESTEK / YEDEK : plana KATILIR ve rolu bu olur (grup sayisi sinirina bakilmaksizin)
//   HARIC           : hicbir plana alinmaz (kendi basina davranir)
//   MEDEVAC         : plana girmez; arac medevacinde bu atananlar oncelikli ve yalniz bunlar (en az bir atanmis arac varsa)
//   TOPCU / TOPCU_YOK : topcu / havan ateşi: en az bir arac TOPCU atandiysa yalniz atananlar atar; TOPCU_YOK atesi kapatir
//   LISTELE         : bu tarafin mevcut atamalari (systemChat)
//   RECON           : plana KESIF unsuru (>= 2 asker): gozlem noktasina STEALTH + GREEN (ates gelene kadar ates yok) gidip bilgi toplar, plan gruplarina rapor verir
//   TASIMA          : arac nakli / taksi (APC, kamyon): once bu araclar kullanilir (atanmis yoksa uygun araclar otomatik)
// Hedef: modul bir nesnenin ustune birakildiysa o, degilse 25 m icindeki en yakin asker / kara-hava-deniz araci.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    private _bagli = attachedTo _logic;
    deleteVehicle _logic;
    [
        "ELITE Gorev Ata",
        [
            ["Gorev", "LIST", "Birimin / grubun gorevi. Otomatik: atama silinir. MANEVRA / DESTEK / YEDEK: ELITE Objektif planina bu rolle katilir (grup sayisi sinirina bakilmaksizin). HARIC: hicbir plana girmez. MEDEVAC: yarali tasima gorevi, plana girmez. TOPCU: yalniz atananlar ates eder. TOPCU_YOK: bu arac ates etmez. LISTELE: atamalari goster.",
                ["Otomatik (atamayi sil)", "Plan: MANEVRA", "Plan: DESTEK (baski / SBF)", "Plan: YEDEK", "Plan disi (HARIC)", "MEDEVAC ekibi / araci", "TOPCU ates destegi", "Topcu DEGIL (ates etmesin)", "LISTELE (atamalari goster)", "TASIMA araci (APC / kamyon taksi)", "RECON (gozlem: gizli, ates gelene kadar ates yok)"], 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz", "_bagli"];
            _data params ["_kod"];
            private _hedef = _bagli;
            if (isNull _hedef) then {
                private _y = nearestObjects [_poz, ["CAManBase", "LandVehicle", "Air", "Ship"], 25];
                _hedef = if (_y isEqualTo []) then {objNull} else {_y select 0};
            };
            if (_kod isEqualTo 8) exitWith {
                private _l = [];
                {
                    private _g = _x;
                    private _v = _g getVariable ["lambs_danger_gorev", ""];
                    if (_v isNotEqualTo "") then { _l pushBack format ["%1 [%2]: %3", groupId _g, str (side _g), _v]; };
                } forEach allGroups;
                {
                    private _v = _x getVariable ["lambs_danger_gorev", ""];
                    if (_v isNotEqualTo "") then { _l pushBack format ["%1 (arac): %2", getText (configOf _x >> "displayName"), _v]; };
                } forEach vehicles;
                if (_l isEqualTo []) then { systemChat "[ELITE] Atama yok (hepsi Otomatik)"; } else { { systemChat format ["[ELITE] %1", _x]; } forEach _l; };
            };
            if (isNull _hedef) exitWith { systemChat "[ELITE] Gorev Ata: yakinda asker / arac yok (modulu bir birimin ustune birak)"; };
            private _kodlar = ["", "MANEVRA", "DESTEK", "YEDEK", "HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "", "TASIMA", "RECON"];
            ["lambs_danger_gorevAta", [_hedef, _kodlar select (_kod max 0 min 10)]] call CBA_fnc_serverEvent;
            systemChat format ["[ELITE] Gorev Ata istegi gonderildi: %1 -> %2", getText (configOf _hedef >> "displayName"), _kodlar select (_kod max 0 min 10)];
        }, {}, {}, [_poz, _bagli]
    ] call EFUNC(main,showDialog);
};
