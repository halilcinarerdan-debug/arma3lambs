#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ELITE C2 (OYUNCU KOMUTA KATMANI) BASLATICI (v8.391; kullanici: 'coop icin, komutan olarak topcu ates destegi, helikopter pilotu olarak lojistik, AI destegi de istiyorum; TC2 modunu ellemeden bunun uzerine yap').
 * Her makinede acilista bir kez calisir (XEH_PREP boot listesi).
 *
 * SUNUCU (20 sn dongu; CBA c2Aktif):
 *   - ILK YUKLEME KAYDI: sunucuda gorulen her bot askerin getUnitLoadout'u bir kez saklanir (QGVAR(c2Yukleme)) — fnc_c2IkmalVer pilotun ikmali bu yuklemeye geri doner.
 *   - IKMAL TALEBI (CBA c2IkmalTalep): oyuncu bulunan taraflarda, bot askerlerinin yarisi ya da fazlasinin ana silah sarjoru azsa (yedek < CBA c2IkmalEsik) o grup harita isareti alir
 *     'C2_IKMAL_*' (turuncu ucgen, 'IKMAL: grup (az/toplam)') ve havadaki ayni taraf oyunculara 120 sn'de bir sohbet bildirimi gider. Isaret global (coop varsayimi: oyuncular ayni tarafta).
 * v8.392: menuye ROTA (birden cok waypoint) ve OBJEKTIF (ele gecir / savun / secili grup / iptal / durum; fnc_c2Objektif -> komutanPlan) eklendi; waypoint / grup / objektif cakismasi kurallari fnc_c2Emir + fnc_c2PlanCakisma + fnc_komutanPlan.
 * ISTEMCI (hasInterface):
 *   - ACE self menusu 'ELITE C2' (ACE varsa; yoksa addAction yedegi): Topcu ates destegi (HE / Duman / Aydinlatma / Iptal), Bot gruplarina emir (Hareket / Saldir / Tut / Serbest), Ikmal dagit.
 *   - MapSingleClick olayi -> fnc_c2Tikla (harita tiklamasi ile hedef / grup secimi).
 * Yetki: fnc_c2Yetkili (CBA c2Yetki, ACRE2 telsiz sarti c2TelsizSart). Kapatma: CBA 'ELITE C2' c2Aktif = false.
 * TC2 (Tactical-C2-Network) modunun fonksiyonlarina / dosyalarina BAGIMLILIK YOK; ikisi birlikte yuklenebilir (ayri menuler).
 * Log: [C2-BOOT] [C2-TOPCU] [C2-EMIR] [C2-IKMAL].
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_c2Started") exitWith {false};
lambs_danger_c2Started = true;

diag_log format ["[C2-BOOT] ELITE C2 baslatildi (v8.391) | isServer=%1 hasInterface=%2 | ACE menu=%3 ACRE=%4", isServer, hasInterface, !isNil "ace_interact_menu_fnc_createAction", isClass (configFile >> "CfgPatches" >> "acre_api")];

if (isServer) then {
    [] spawn {
        private _mrk = createHashMap;   // grup netId -> [isaret, son bildirim zamani]
        private _mrkY = createHashMap;  // arac netId -> [isaret, son bildirim zamani] (v8.396 yakit talebi)
        while {true} do {
            sleep 20;
            if (!(missionNamespace getVariable ["lambs_danger_c2Aktif", true])) then { continue };

            // 1) ilk yukleme kaydi (tikta en fazla 40 asker)
            private _n = 0;
            {
                if (_n < 40 && {alive _x} && {!isPlayer _x} && {(_x getVariable [QGVAR(c2Yukleme), []]) isEqualTo []}) then {
                    _x setVariable [QGVAR(c2Yukleme), getUnitLoadout _x];
                    _n = _n + 1;
                };
            } forEach (allUnits select {(side (group _x)) in [west, east, independent]});

            // 2) ikmal talebi isaretleri
            private _taraflar = [];
            { _taraflar pushBackUnique (side (group _x)); } forEach allPlayers;
            private _esik = missionNamespace getVariable ["lambs_danger_c2IkmalEsik", 2];
            private _aktif = [];
            if (_taraflar isNotEqualTo [] && {missionNamespace getVariable ["lambs_danger_c2IkmalTalep", true]}) then {
                {
                    private _g = _x;
                    if ((side _g) in _taraflar && {!isNull (leader _g)} && {!isPlayer (leader _g)}) then {
                        private _ai = (units _g) select {alive _x && {!isPlayer _x}};
                        if ((count _ai) >= 2) then {
                            private _az = {
                                private _mg = (primaryWeaponMagazine _x) param [0, ""];
                                _mg isNotEqualTo "" && {({_x isEqualTo _mg} count (magazines _x)) < (_esik + 1)}
                            } count _ai;
                            if (_az > 0 && {(_az * 2) >= (count _ai)}) then {
                                private _id = netId _g;
                                _aktif pushBack _id;
                                private _kayit = _mrk getOrDefault [_id, []];
                                private _m = "";
                                private _son = -999;
                                if (_kayit isEqualTo []) then {
                                    _m = createMarker [format ["C2_IKMAL_%1", (_id splitString ":") joinString "_"], getPosATL (leader _g)];
                                    _m setMarkerType "mil_triangle";
                                    _m setMarkerColor "ColorOrange";
                                } else {
                                    _m = _kayit select 0;
                                    _son = _kayit select 1;
                                };
                                _m setMarkerPos (getPosATL (leader _g));
                                _m setMarkerText format ["IKMAL: %1 (%2/%3)", groupId _g, _az, count _ai];
                                if ((time - _son) > 120) then {
                                    _son = time;
                                    private _pilotlar = allPlayers select {(side (group _x)) isEqualTo (side _g) && {(vehicle _x) isKindOf "Air"}};
                                    if (_pilotlar isNotEqualTo []) then {
                                        [format ["[C2] IKMAL TALEBI: %1 (%2/%3 bot az cephane) | GRID %4", groupId _g, _az, count _ai, mapGridPosition (leader _g)]] remoteExecCall ["systemChat", _pilotlar];
                                    };
                                    diag_log format ["[C2-IKMAL] talep | %1 | %2/%3 bot az cephane | GRID %4", groupId _g, _az, count _ai, mapGridPosition (leader _g)];
                                };
                                _mrk set [_id, [_m, _son]];
                            };
                        };
                    };
                } forEach allGroups;
            };
            // v8.396 YAKIT TALEBI: AI surucu kara araci yakiti < CBA c2YakitEsik (varsayilan 0.25) ise 'C2_YAKIT_*' isareti + havadaki oyunculara bildirim (180 sn'de bir)
            private _yakitAktif = [];
            if (_taraflar isNotEqualTo [] && {missionNamespace getVariable ["lambs_danger_c2IkmalTalep", true]}) then {
                private _yEsik = missionNamespace getVariable ["lambs_danger_c2YakitEsik", 0.25];
                {
                    private _av = _x;
                    private _dr = driver _av;
                    if (_av isKindOf "LandVehicle" && {alive _av} && {(fuel _av) < _yEsik} && {!isNull _dr} && {alive _dr} && {!isPlayer _dr} && {(side (group _dr)) in _taraflar}) then {
                        private _vid = netId _av;
                        _yakitAktif pushBack _vid;
                        private _ky = _mrkY getOrDefault [_vid, []];
                        private _ym = "";
                        private _yson = -999;
                        if (_ky isEqualTo []) then {
                            _ym = createMarker [format ["C2_YAKIT_%1", (_vid splitString ":") joinString "_"], getPosATL _av];
                            _ym setMarkerType "mil_box";
                            _ym setMarkerColor "ColorYellow";
                        } else {
                            _ym = _ky select 0;
                            _yson = _ky select 1;
                        };
                        _ym setMarkerPos (getPosATL _av);
                        _ym setMarkerText format ["YAKIT %1%%: %2", round ((fuel _av) * 100), getText (configOf _av >> "displayName")];
                        if ((time - _yson) > 180) then {
                            _yson = time;
                            private _yp = allPlayers select {(side (group _x)) isEqualTo (side (group _dr)) && {(vehicle _x) isKindOf "Air"}};
                            if (_yp isNotEqualTo []) then {
                                [format ["[C2] YAKIT TALEBI: %1 (%2%%) | GRID %3", getText (configOf _av >> "displayName"), round ((fuel _av) * 100), mapGridPosition _av]] remoteExecCall ["systemChat", _yp];
                            };
                            diag_log format ["[C2-IKMAL] yakit talebi | %1 | %2%% | GRID %3", getText (configOf _av >> "displayName"), round ((fuel _av) * 100), mapGridPosition _av];
                        };
                        _mrkY set [_vid, [_ym, _yson]];
                    };
                } forEach vehicles;
            };
            {
                if !(_x in _yakitAktif) then {
                    deleteMarker ((_mrkY get _x) select 0);
                    _mrkY deleteAt _x;
                };
            } forEach (keys _mrkY);
            // artik talep etmeyen gruplarin isareti silinir
            {
                if !(_x in _aktif) then {
                    deleteMarker ((_mrk get _x) select 0);
                    _mrk deleteAt _x;
                };
            } forEach (keys _mrk);
        };
    };
};

if (hasInterface) then {
    [] spawn {
        waitUntil { sleep 1; !isNull player };
        missionNamespace setVariable ["lambs_danger_c2Bekle", []];
        addMissionEventHandler ["MapSingleClick", { params ["_units", "_pos"]; [_pos] call lambs_danger_fnc_c2Tikla; }];

        // [ust menu, kimlik, baslik, amac, veri]
        private _yaprak = [
            ["top", "he", "HE etki atisi (haritadan hedef)", "TOPCU", ["HE"]],
            ["top", "smoke", "Duman perdesi (haritadan hedef)", "TOPCU", ["SMOKE"]],
            ["top", "illum", "Aydinlatma (haritadan hedef)", "TOPCU", ["ILLUM"]],
            ["top", "iptal", "Gorevi iptal et", "TOPCU_IPTAL", []],
            ["emir", "move", "Hareket (bot grubu + hedef nokta)", "EMIR", ["MOVE"]],
            ["emir", "sad", "Saldir / ara ve imha et (bot grubu + hedef)", "EMIR", ["SAD"]],
            ["emir", "rota", "Rota - birden cok waypoint (bot grubu + noktalar)", "EMIR", ["ROTA"]],
            ["emir", "rotabitir", "Rotayi bitir", "ROTA_BITIR", []],
            ["emir", "tut", "Yerinde tut (bot grubu)", "EMIR", ["TUT"]],
            ["emir", "serbest", "Serbest birak - ELITE komutan karar versin", "EMIR", ["SERBEST"]],
            ["obj", "ele", "Ele gecir (HQ'ya atanmis gruplar, haritadan objektif)", "OBJ", ["ELE"]],
            ["obj", "savun", "Savun / mevzilen (otomatik gruplar, haritadan objektif)", "OBJ", ["SAVUN"]],
            ["obj", "secili", "Secili bot grubu objektifi savunsun", "OBJ", ["SECILI_SAVUN"]],
            ["obj", "iptal", "Objektifleri iptal et (aktif planlar)", "OBJ", ["IPTAL"]],
            ["obj", "durum", "Aktif objektif durumu", "OBJ", ["DURUM"]],
            ["ikmal", "ver", "Yakindaki botlara ikmal dagit", "IKMAL", []]
        ];

        if (!isNil "ace_interact_menu_fnc_createAction" && {!isNil "ace_interact_menu_fnc_addActionToClass"}) then {
            private _kok = ["lambs_c2", "ELITE C2", "", {}, {missionNamespace getVariable ["lambs_danger_c2Aktif", true]}] call ace_interact_menu_fnc_createAction;
            ["CAManBase", 1, ["ACE_SelfActions"], _kok, true] call ace_interact_menu_fnc_addActionToClass;
            {
                _x params ["_pid", "_pbaslik"];
                private _a = [format ["lambs_c2_%1", _pid], _pbaslik, "", {}, {[player, false] call lambs_danger_fnc_c2Yetkili}] call ace_interact_menu_fnc_createAction;
                ["CAManBase", 1, ["ACE_SelfActions", "lambs_c2"], _a, true] call ace_interact_menu_fnc_addActionToClass;
            } forEach [["top", "Topcu ates destegi"], ["emir", "Bot gruplarina emir / waypoint"], ["obj", "Objektif"]];
            {
                _x params ["_pid", "_id", "_baslik", "_amac", "_veri"];
                private _yol = ["ACE_SelfActions", "lambs_c2"];
                private _kosul = {alive player};
                if (_pid isNotEqualTo "ikmal") then {
                    _yol pushBack format ["lambs_c2_%1", _pid];
                    _kosul = {[player, false] call lambs_danger_fnc_c2Yetkili};
                };
                private _a = [format ["lambs_c2_%1_%2", _pid, _id], _baslik, "", { params ["_t", "_p", "_prm"]; _prm call lambs_danger_fnc_c2Sec; }, _kosul, {}, [_amac, _veri]] call ace_interact_menu_fnc_createAction;
                ["CAManBase", 1, _yol, _a, true] call ace_interact_menu_fnc_addActionToClass;
            } forEach _yaprak;
            diag_log "[C2-BOOT] ACE self menusu 'ELITE C2' eklendi";
        } else {
            // ACE yok: addAction yedegi (respawn'da yeniden)
            missionNamespace setVariable ["lambs_danger_c2EkleFn", {
                params ["_u"];
                { _u removeAction _x; } forEach (_u getVariable [QGVAR(c2Aksiyonlar), []]);
                private _ids = [];
                {
                    _x params ["_pid", "_id", "_baslik", "_amac", "_veri"];
                    private _sart = if (_pid isEqualTo "ikmal") then { "alive _this && {_this isEqualTo player}" } else { "_this isEqualTo player && {[_this, false] call lambs_danger_fnc_c2Yetkili}" };
                    _ids pushBack (_u addAction [format ["[C2] %1", _baslik], { params ["_t", "_c", "_i", "_prm"]; _prm call lambs_danger_fnc_c2Sec; }, [_amac, _veri], 1.5, false, true, "", _sart]);
                } forEach (missionNamespace getVariable ["lambs_danger_c2Yaprak", []]);
                _u setVariable [QGVAR(c2Aksiyonlar), _ids];
            }];
            missionNamespace setVariable ["lambs_danger_c2Yaprak", _yaprak];
            [player] call (missionNamespace getVariable "lambs_danger_c2EkleFn");
            player addEventHandler ["Respawn", { params ["_u"]; [_u] call (missionNamespace getVariable "lambs_danger_c2EkleFn"); }];
            diag_log "[C2-BOOT] ACE menu yok: addAction yedegi eklendi";
        };
    };
};

true
