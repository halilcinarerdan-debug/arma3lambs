#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DISIPLINLI PATLAYICI KULLANIMI (v8.310; kullanici: 'patlayici kullanimini arttir el bombasi roket ama disiplinli' + 've ugl'). Yeni taktik degil: mevcut temasta olan askerin elindeki patlayiciyi DAHA SIK ve DOGRU hedefe kullandirir.
 * Izleyici 2.5 sn'de bir, yerel oyuncusuz, TEMASTA (contact) olan gruplarda; tick basina en cok 4 atis. Hedef: bilinen (knowsAbout >= 1.0) dusman PIYADE. 'Deger' sartlari (bos yere atilmaz):
 *   KUME (hedefin 8 m icinde baska bilinen dusman) | BINADA | KAPALI HAT (tufege gorus hatti kesik: siper / duvar) | BASKI (grupta >= 2 asker baski > 0.4)
 *   EL BOMBASI (frag; duman / isik / sok haric): 15-36 m, hedef 12 m icinde dost YOK, birim basina 30 sn, grup 6 sn, 60 sn'de en cok 2; son bomba YEDEK (kume >= 3 degilse atilmaz)
 *   ROKET (omuz roketatari, yuklu): 60-280 m, hedef 20 m icinde dost YOK, arkasinda (8 m, 120-240 derece) dost YOK, BINADA / KUME >= 3 / KAPALI HAT (>= 60 m); 60 sn / birim, 20 sn / grup;
 *        dusman ZIRHLI (tank / APC) 900 m icinde biliniyorsa ATILMAZ (AT rezervi)
 *   UGL ek mermi: UGL'li askere CBA 'lambs_danger_uglEkMermi' (varsayilan 4) kadar HE 40mm eklenir (bir kez; envanter doluysa eklenmez) - UGL darbogazi 'mermi_yok' idi.
 * v8.311: el bombasi SCRIPT ile kontrollu balistik firlatilir (hedefe yon + hesaplanan hiz, yay temizligi, insani dagilim; fireAtTarget / forceWeaponFire hedefe nisan almiyordu: 'bodoslama kendi yonlerine'); roket silah yonu hedefe <= 4 derece olunca ates eder (hizalanmazsa vazgecer).
 * CBA 'ELITE patlayici': lambs_danger_patlayiciAktif, lambs_danger_elBombasiAktif, lambs_danger_roketAktif, lambs_danger_uglEkMermi.   Kapatma: lambs_danger_patlayiciOff = true.
 * Log: [PATLAYICI] / [PATLAYICI-OZET]
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_patlayiciStarted") exitWith {false};
lambs_danger_patlayiciStarted = true;
diag_log "[PATLAYICI] disiplinli el bombasi / roket / UGL ek mermi izleyicisi baslatildi (v8.310)";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _sayac = createHashMapFromArray [["bomba", 0], ["roket", 0], ["ugl_ek", 0], ["FAT", 0], ["FWF", 0], ["yok", 0]];
    private _sonOzet = time + 60;
    // el bombasi (frag) mi?
    private _fragMi = {
        params ["_m"];
        private _k = toLower _m;
        private _a = getText (configFile >> "CfgMagazines" >> _m >> "ammo");
        (toLower (getText (configFile >> "CfgAmmo" >> _a >> "simulation"))) isEqualTo "shotgrenade"
        && {(_k find "smoke") < 0} && {(_k find "flare") < 0} && {(_k find "chem") < 0} && {(_k find "illum") < 0} && {(_k find "flash") < 0} && {(_k find "stun") < 0} && {(_k find "m84") < 0}
    };
    // 'Throw' muzzle -> sarjor haritasi (frag icin muzzle bul)
    private _atMuzzle = {
        params ["_m"];
        private _mz = "";
        { if ((toLower _m) in ([ "Throw", _x ] call FUNC(uglMags))) exitWith { _mz = _x; }; } forEach (getArray (configFile >> "CfgWeapons" >> "Throw" >> "muzzles"));
        _mz
    };
    // ---- EL BOMBASI: KONTROLLU ATIS (v8.311; kullanici: 'el bombasini bodoslama atiyorlar, kendi yonlerine'; RPT 23-10 08:19: fireAtTarget false + forceWeaponFire yonu bilmeden atiyordu -> mermi sayaci degismedi ('ates YOK') ama bomba askerin baktigi yone gidiyordu) ----
    //   forceWeaponFire / fireAtTarget hedefe nisan almaz ve menzili ayarlamaz -> bomba SCRIPT ile balistik firlatilir: hedefe dogru yatay yon + 40-60 derece yay + hesaplanan hiz (<= 26 m/sn), insani dagilim (yan +-4 m + %4 mesafe, boy +-5 %),
    //   yay uzerinde 6 noktada duvar / nesne denetimi (firlatanin onunde engel varsa ATILMAZ), once hedefe doWatch (<= 1.5 sn; govde 35 dereceden fazla sapmissa vazgecilir; setDir ile isinlama YOK), 'ThrowGrenade' animasyonu, magazin dusulur.
    private _firlat = {
        params ["_u", "_t", "_mag"];
        [_u, _t, _mag] spawn {
            params ["_u", "_t", "_mag"];
            private _ammo = getText (configFile >> "CfgMagazines" >> _mag >> "ammo");
            private _bit = time + 1.5;
            _u doWatch _t;
            private _aci = 180;
            while {time < _bit && {alive _u} && {alive _t}} do {
                sleep 0.25;
                _aci = abs ((((_u getDir _t) - (getDir _u)) + 540) mod 360 - 180);
                if (_aci < 20) exitWith {};
            };
            private _sonuc = "";
            if (!alive _u || {!alive _t}) then { _sonuc = "hedef / atici oldu"; }
            else { if (_aci > 35) then { _sonuc = format ["donemedi (%1 derece)", round _aci]; }
            else { if (false) then {} else {
                _u playActionNow "ThrowGrenade";
                sleep 0.8;
                if (alive _u && {alive _t} && {(magazines _u) findIf {_x isEqualTo _mag} >= 0}) then {
                    private _rel = (eyePos _u) vectorAdd [0, 0, -0.1];
                    private _hp = getPosASL _t;
                    private _dag = random (1.5 + ((_u distance2D _t) * 0.04));
                    private _hedef = (AGLToASL ((ASLToAGL _hp) getPos [_dag, random 360]));
                    private _D = ((_rel select 0) - (_hedef select 0)) ^ 2;
                    _D = sqrt (_D + (((_rel select 1) - (_hedef select 1)) ^ 2));
                    private _dh = ((_hedef select 2) + 0.3) - (_rel select 2);
                    private _v = -1;
                    private _th = 0;
                    {
                        private _payda = (_D * (tan _x)) - _dh;
                        if (_v < 0 && {_payda > 0.5}) then {
                            private _vv = sqrt ((9.81 * _D * _D) / (2 * ((cos _x) ^ 2) * _payda));
                            if (_vv <= 26) then { _v = _vv; _th = _x; };
                        };
                    } forEach [40, 50, 60];
                    if (_v < 0) then { _sonuc = "menzil / yukseklik uygun degil"; } else {
                        _v = _v * (1 + ((random 0.1) - 0.05));
                        private _yon = _rel getDir _hedef;
                        private _vel = [(sin _yon) * (cos _th) * _v, (cos _yon) * (cos _th) * _v, (sin _th) * _v];
                        // yay temizligi: 6 noktada
                        private _tTop = _D / ((cos _th) * _v max 1);
                        private _onceki = _rel;
                        private _engel = false;
                        for "_i" from 1 to 6 do {
                            private _tt = _tTop * (_i / 6) * 0.9;
                            private _nokta = _rel vectorAdd [(_vel select 0) * _tt, (_vel select 1) * _tt, ((_vel select 2) * _tt) - (4.905 * _tt * _tt)];
                            if (lineIntersects [_onceki, _nokta, _u, _t]) exitWith { _engel = true; };
                            _onceki = _nokta;
                        };
                        if (_engel) then { _sonuc = "yay uzerinde engel (duvar / nesne) - atilmadi"; } else {
                            private _gr = createVehicle [_ammo, ASLToAGL _rel, [], 0, "CAN_COLLIDE"];
                            _gr setPosASL _rel;
                            _gr setVelocity _vel;
                            _gr setShotParents [_u, _u];
                            _u removeMagazine _mag;
                            _sonuc = format ["ATILDI (hedef %1 m, aci %2, hiz %3 m/sn, dagilma %4 m)", round _D, _th, _v toFixed 1, _dag toFixed 1];
                        };
                    };
                } else { _sonuc = "hedef / bomba kayboldu"; };
            }; }; };
            diag_log format ["[PATLAYICI] bomba | %1 | %2 -> hedef %3 (%4 m) | KONTROLLU ATIS: %5 | grup %6", name _u, _mag, typeOf _t, round (_u distance _t), _sonuc, groupId (group _u)];
            private _s = missionNamespace getVariable ["lambs_danger_patlayiciSayac", createHashMap];
            private _k = ["yok", "FAT"] select ((_sonuc select [0, 6]) isEqualTo "ATILDI");
            _s set [_k, (_s getOrDefault [_k, 0]) + 1];
            missionNamespace setVariable ["lambs_danger_patlayiciSayac", _s];
        };
    };
    // ---- ROKET: hizalama kapili atis (v8.311) ----
    //   Silah yonu hedefe <= 4 derece olunca forceWeaponFire (donuste / hizalanmadan atilmaz); 5 sn icinde hizalanmazsa VAZGECILIR (atis yok). Kosan (hiz >= 2 m/sn) asker atmaz.
    private _roketAt = {
        params ["_u", "_t", "_ls"];
        [_u, _t, _ls] spawn {
            params ["_u", "_t", "_ls"];
            private _say0 = _u ammo _ls;
            _u selectWeapon _ls;
            sleep 0.5;
            private _bit = time + 5;
            private _min = 180;
            private _atildi = false;
            while {time < _bit && {!_atildi} && {alive _u} && {alive _t} && {(_u ammo _ls) > 0} && {(speed _u) < 2}} do {
                _u doWatch (aimPos _t);
                _u doTarget _t;
                sleep 0.3;
                private _fark = (AGLToASL (aimPos _t)) vectorDiff (eyePos _u);
                private _wd = _u weaponDirection _ls;
                if ((vectorMagnitude _fark) > 1 && {(vectorMagnitude _wd) > 0.1}) then {
                    private _aci = acos ((((vectorNormalized _wd) vectorDotProduct (vectorNormalized _fark)) min 1) max -1);
                    if (_aci < _min) then { _min = _aci; };
                    if (_aci < 4) exitWith {
                        _u forceWeaponFire [_ls, ((getArray (configFile >> "CfgWeapons" >> _ls >> "modes")) param [0, "Single"])];
                        _atildi = true;
                    };
                };
            };
            sleep 1;
            private _sonuc = if (_atildi && {(_u ammo _ls) < _say0}) then {"ATILDI"} else { if (_atildi) then {"EMIR VERILDI (mermi sayaci degismedi)"} else {format ["VAZGECILDI (hizalanamadi, en kucuk aci %1 derece)", round _min]} };
            diag_log format ["[PATLAYICI] roket | %1 | %2 -> hedef %3 (%4 m) | HIZALAMA KAPILI ATIS: %5 | grup %6", name _u, _ls, typeOf _t, round (_u distance _t), _sonuc, groupId (group _u)];
            _u doWatch objNull;
            [{ params ["_uu"]; if (alive _uu && {!(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false])}) then { _uu selectWeapon (primaryWeapon _uu); }; }, [_u], 1.5] call CBA_fnc_waitAndExecute;
        };
    };
    private _hepsiHE = {
        params ["_w", "_mz"];
        ([_w, _mz] call FUNC(uglMags)) select {
            private _a = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
            private _k = toLower _x;
            (toLower (getText (configFile >> "CfgAmmo" >> _a >> "simulation"))) isEqualTo "shotgrenade" && {(_k find "smoke") < 0} && {(_k find "flare") < 0} && {(_k find "illum") < 0} && {(_k find "chem") < 0}
        }
    };

    while {true} do {
        sleep 2.5;
        if (missionNamespace getVariable ["lambs_danger_patlayiciOff", false] || {!(missionNamespace getVariable ["lambs_danger_patlayiciAktif", true])}) then { continue };
        private _butce = 4;

        // ---- UGL ek mermi (bir kez / asker) ----
        private _ek = missionNamespace getVariable ["lambs_danger_uglEkMermi", 4];
        if (_ek > 0) then {
            {
                private _u = _x;
                if (!(_u getVariable [QGVAR(uglEkVerildi), false])) then {
                    _u setVariable [QGVAR(uglEkVerildi), true];
                    private _mz = [_u] call FUNC(hasUGL);
                    if (_mz isNotEqualTo "") then {
                        private _he = ([primaryWeapon _u, _mz] call _hepsiHE);
                        if (_he isNotEqualTo []) then {
                            private _var = (magazines _u) select {(toLower _x) in _he};
                            private _sinif = if (_var isNotEqualTo []) then { _var select 0 } else { _he select 0 };
                            private _eksik = _ek - (count _var);
                            if (_eksik > 0) then {
                                private _once = count ((magazines _u) select {_x isEqualTo _sinif});
                                _u addMagazines [_sinif, _eksik];
                                private _eklenen = (count ((magazines _u) select {_x isEqualTo _sinif})) - _once;
                                if (_eklenen > 0) then { _sayac set ["ugl_ek", (_sayac get "ugl_ek") + _eklenen]; };
                            };
                        };
                    };
                };
            } forEach (allUnits select {local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side (group _x)) isNotEqualTo civilian}});
        };

        // ---- temasta gruplar ----
        {
            if (_butce <= 0) exitWith {};
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {(side _g) isEqualTo civilian}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then { continue };
            if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(teslimOldu), false]}) then { continue };
            private _uyeler = (units _g) select {alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable [QGVAR(forceMove), false])} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time} && {!(_x getVariable [QGVAR(teslim), false])} && {(insideBuilding _x) < 0.5}};
            if (_uyeler isEqualTo []) then { continue };
            private _baski = ({(getSuppression _x) > 0.4} count _uyeler) >= 2;
            private _taraf = side _g;
            private _tr = _l nearTargets 320;
            private _dusman = _tr select {
                private _o = _x select 4;
                !isNull _o && {alive _o} && {_o isKindOf "CAManBase"} && {(_taraf getFriend (side (group _o))) < 0.6} && {(_l knowsAbout _o) >= 1.0}
            };
            if (_dusman isEqualTo []) then { continue };
            private _zirhli = (_l nearTargets 900) findIf {
                private _o = _x select 4;
                !isNull _o && {alive _o} && {(_o isKindOf "Tank") || {_o isKindOf "Tracked_APC_F"} || {_o isKindOf "Wheeled_APC_F"}} && {(_taraf getFriend (side (group _o))) < 0.6} && {(_l knowsAbout _o) >= 0.8}
            } >= 0;

            {
                if (_butce <= 0) exitWith {};
                private _u = _x;
                private _uP = getPosASL _u;
                // en yakin deger tasiyan hedef
                private _enIyi = objNull;
                private _enM = 1e9;
                private _kumeN = 0;
                private _kapali = false;
                private _binada = false;
                {
                    private _o = _x select 4;
                    private _m = _u distance _o;
                    private _k = ({ (_x select 4) isNotEqualTo _o && {(_x select 4) distance _o < 8} } count _dusman) + 1;
                    private _kp = lineIntersects [eyePos _u, eyePos _o, _u, _o];
                    private _bn = (insideBuilding _o) > 0.5;
                    if (_m < _enM && {_k >= 2 || _kp || _bn || _baski}) then { _enIyi = _o; _enM = _m; _kumeN = _k; _kapali = _kp; _binada = _bn; };
                } forEach _dusman;
                if (isNull _enIyi) then { continue };

                // --- EL BOMBASI ---
                if (missionNamespace getVariable ["lambs_danger_elBombasiAktif", true]) then {
                    if (_enM >= 15 && {_enM <= 36} && {(time - (_u getVariable [QGVAR(bombaT), -999])) > 30} && {(time - (_g getVariable [QGVAR(bombaGT), -999])) > 6}) then {
                        private _fraglar = (magazines _u) select {[_x] call _fragMi};
                        private _gecmis = (_u getVariable [QGVAR(bombaListe), []]) select {(time - _x) < 60};
                        _u setVariable [QGVAR(bombaListe), _gecmis];
                        private _yedek = (count _fraglar) <= 1 && {_kumeN < 3};
                        if (_fraglar isNotEqualTo [] && {!_yedek} && {(count _gecmis) < 2}) then {
                            private _mag = _fraglar select 0;
                            private _dostYakin = (_enIyi nearEntities ["CAManBase", 12]) findIf {alive _x && {(_taraf getFriend (side (group _x))) >= 0.6}} >= 0;
                            if (!_dostYakin && {(speed _u) < 6}) then {
                                _u setVariable [QGVAR(bombaT), time];
                                _g setVariable [QGVAR(bombaGT), time];
                                _gecmis pushBack time;
                                _u setVariable [QGVAR(bombaListe), _gecmis];
                                [_u, _enIyi, _mag] call _firlat;
                                _sayac set ["bomba", (_sayac get "bomba") + 1];
                                _butce = _butce - 1;
                                continue
                            };
                        };
                    };
                };

                // --- ROKET (omuz roketatari) ---
                if (missionNamespace getVariable ["lambs_danger_roketAktif", true] && {!_zirhli}) then {
                    private _ls = secondaryWeapon _u;
                    if (_ls isNotEqualTo "" && {(getNumber (configFile >> "CfgWeapons" >> _ls >> "type")) == 4} && {(_u ammo _ls) > 0}
                        && {_enM >= 60} && {_enM <= 280} && {_binada || {_kumeN >= 3} || {_kapali}}
                        && {(speed _u) < 2} && {(time - (_u getVariable [QGVAR(roketT), -999])) > 60} && {(time - (_g getVariable [QGVAR(roketGT), -999])) > 20}) then {
                        private _dostYakin = (_enIyi nearEntities ["CAManBase", 20]) findIf {alive _x && {(_taraf getFriend (side (group _x))) >= 0.6}} >= 0;
                        private _arkada = ((_u nearEntities ["CAManBase", 8]) findIf {_x isNotEqualTo _u && {alive _x} && {(_taraf getFriend (side (group _x))) >= 0.6} && {((abs (((_u getRelDir _x) + 180) mod 360 - 180)) >= 60)}}) >= 0;
                        if (!_dostYakin && {!_arkada}) then {
                            _u setVariable [QGVAR(roketT), time];
                            _g setVariable [QGVAR(roketGT), time];
                            [_u, _enIyi, _ls] call _roketAt;
                            _sayac set ["roket", (_sayac get "roket") + 1];
                            _butce = _butce - 1;
                        };
                    };
                };
            } forEach _uyeler;
        } forEach allGroups;

        if (time > _sonOzet) then {
            _sonOzet = time + 60;
            private _ys = missionNamespace getVariable ["lambs_danger_patlayiciSayac", createHashMap];
            diag_log format ["[PATLAYICI-OZET] 60 sn: emir bomba %1 roket %2 | UGL ek mermi verilen %3 | bomba firlatma sonucu (toplam): atildi %4 | atilmadi %6", _sayac get "bomba", _sayac get "roket", _sayac get "ugl_ek", _ys getOrDefault ["FAT", 0], 0, _ys getOrDefault ["yok", 0]];
            { _sayac set [_x, 0]; } forEach ["bomba", "roket"];
        };
    };
};
true
