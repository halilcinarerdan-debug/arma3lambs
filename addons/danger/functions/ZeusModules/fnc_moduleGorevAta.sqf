#include "script_component.hpp"

// ELITE fork (v8.127): "ELITE Gorev Ata" Zeus modulu — bir birimin / grubun / aracin ustune birakilir; hangi squad / arac hangi gorevi yapacak Zeus secer.
// Atama grupta (ve aractaysa araca) 'lambs_danger_gorev' degiskeni olarak tutulur; ELITE Objektif plani, topcu atesi ve arac medevac bunu okur.
//   Otomatik        : atama silinir (sistem kendi secer)
//   HARIC           : ELITE bu gruba hareket / taktik katmani uygulamaz (waypoint / LAMBS gorevi sahibi gibi davranir; geri cekilme / tibbi / atis disiplini kalir)
//   MEDEVAC         : arac medevacinde bu atananlar oncelikli ve yalniz bunlar (en az bir atanmis arac varsa)
//   TOPCU / TOPCU_YOK : topcu / havan ateşi: en az bir arac TOPCU atandiysa yalniz atananlar atar; TOPCU_YOK atesi kapatir
//   LISTELE         : mevcut atamalari (systemChat)
//   OYUNCU          : (v8.151) grup oyuncu komutasinda: ELITE taktik katmani kapali (LAMBS FSM + tum karar izleyicileri), TCCC / cephane / IED / ezme / murettebat korumasi ACIK; oyunculu gruplar otomatik
//   ELITE_TAM       : oyuncu grubunda da ELITE tam acik (otomatik oyuncu modunu ezer)
// Hedef: modul bir nesnenin ustune birakildiysa o, degilse 25 m icindeki en yakin asker / kara-hava-deniz araci.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    private _bagli = attachedTo _logic;
    deleteVehicle _logic;
    [
        "ELITE Gorev Ata",
        [
            ["Gorev", "LIST", "Birimin / grubun gorevi. Otomatik: atama silinir. HARIC: ELITE hareket / taktik katmani bu gruba dokunmaz (waypoint'ini izler). MEDEVAC: yarali tasima gorevi. TOPCU: yalniz atananlar ates eder. TOPCU_YOK: bu arac ates etmez. OYUNCU: oyuncu komutasi. ELITE TAM: oyunculu grupta da ELITE acik. LISTELE: atamalari goster.",
                ["Otomatik (atamayi sil)", "HARIC (ELITE dokunmasin)", "MEDEVAC ekibi / araci", "TOPCU ates destegi", "Topcu DEGIL (ates etmesin)", "OYUNCU KOMUTASI (ELITE taktik kapali; tedavi / cephane / IED acik)", "ELITE TAM ACIK (oyunculu grupta da)", "LISTELE (atamalari goster)"], 0]
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
            if (_kod isEqualTo 7) exitWith {
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
            private _kodlar = ["", "HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "OYUNCU", "ELITE_TAM"];
            ["lambs_danger_gorevAta", [_hedef, _kodlar select (_kod max 0 min 6)]] call CBA_fnc_serverEvent;
            systemChat format ["[ELITE] Gorev Ata istegi gonderildi: %1 -> %2", getText (configOf _hedef >> "displayName"), _kodlar select (_kod max 0 min 6)];
        }, {}, {}, [_poz, _bagli]
    ] call EFUNC(main,showDialog);
};
