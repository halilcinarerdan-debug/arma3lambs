#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CQB KOSE / ARALIK TEMKINI — 'acilari hesaplasin, bodoslama koseden donmesin' (v8.351). Meskun mahalde, temas varken yuruyen AI piyadenin yolunda gorusu kapali bir KOSE (bina ucu, sokak agzi, kapi pervazi) varsa
 * kosenin onunde durur, kosenin ardindaki bilinmeyen sektoru dilimler (pie), sonra yavas gecer; arkadaki askerler sirada bekler. Hile yok: yalniz geometri (isin) ve bilinen dusman.
 *
 * KITAP (kaynaklar_doktrin/):
 *   - TC 3-21.76 (Ranger) A-7..A-8: koridor kavsaklari ve T kavsagi TEHLIKE ALANIDIR, dikkatle yaklasilir; kose sirasinda #1 ALCAK (diz), #2 YUKSEK (ayakta), atis sektorleri birbirine kenetlenir; isaret ettigi namlu kose disina
 *     cikarilmaz ('flagging' yasak, 11-24 not); kose temizlenince ekip dizilisine doner, temizlik ekip gidince gecerliligini yitirir. [K]
 *   - TC 3-21.76 A-9: merdiven / kapi 'fatal funnel' (olumcul huni); 11-26: girise / gecise kapali-ortulu yaklas. [K]
 *   - MCWP 3-11.2 (Marine squad) 9107d: sokak ve gecitlerde siperi onceden sec, duvara yapis, ortadan gitme, kalabaliklasma; sokagi mecbur kalmadikca gecme, gecisi ortu ekibiyle koordine et; birimler birlikte
 *     gecip karsida hemen dagilir. [K]
 *   - TC 3-21.76 11-12 (arazi analizi): girislerde / huni agizlarinda yigilma yok, takimlar arasi guvenli mesafe (tek bomba hepsini almasin). [K]
 *   Sayilar (isin yelpazesi, esikler, bekleme sureleri, 8 sn / 60 sn) TASARIM degeridir [T]; kitapta sayi YOKTUR.
 *
 * ALGILAMA (birim basina 0.8 sn'de bir, tick butcesi 6 birim):
 *   - Yuruyus yonu = hiz vektoru. 11 isin (-75..+75 derece, 24 m; bina ici 14 m), goz yuksekliginde 'VIEW' geometrisi; kucuk nesneler (< 2.5 m) engel sayilmaz.
 *   - Komsu iki isin arasi mesafe farki >= 4 m ise o aralik 3 kez ikiye bolunur (ayni yuzeye siyirma acisiyla devam eden duvarin sahte siçramasini eler); kalan fark >= 5 m (bina ici 4 m), yakin taraf <= 14 m (ici 8 m)
 *     ve kose ileride 1.8-12 m (ici 7 m), +-52 derece icindeyse KOSE sayilir. Kosenin ardindaki bilinmeyen sektor = yakin isin tarafina 9 ve 20 derece sapma.
 * DAVRANIS (yalniz AKTIF temas (QGVAR(contact) damgasi > time) ya da liderin 250 m icinde bilinen dusmani varken - v8.352: davranis COMBAT tek basina yetmez; bina icinde yalniz aktif temasta; teslim / esir (captive) atlanir; oyuncu iceren grup, arac, tactic / retreat / evade / bounding calisan grup, keskin nisanci ekibi, forceMove atlanir):
 *   NOKTA (kosede ilk gelen): forceSpeed 0 + comel + 0.8 sn uzak sektore, 0.6 sn yakin sektore doWatch (dilim 1 / 2); sonra forceSpeed 1.3 (agir adim) ile kosenin 2 m yakinina / (mesafe + 1.5 m) ilerleyene kadar (en cok 2.5 sn) gecer ve 'kose temiz' hafizasi (60 sn, 8 m) yazilir (v8.352: toplam ~3 sn, eskiden 5.5).
 *   ISTIF (ayni kosede ikinci / ucuncu asker): ayakta (#2 yuksek) durur, uzak sektore bakar, NOKTA bitene kadar (en cok 6 sn) bekler -> yigilmadan, birer birer gecer.
 *   Iptal: dusman <= 35 m bilinirse (knowsAbout >= 1) / baski > 0.6 / yarali dustu / baska sistem forceMove verdi / 12 sn sigorta -> hemen serbest (normal savas: fnc_cqbReflex, fnc_coverHug).
 * Birim basina 8 sn bekleme; ayni kose icin grup basina 60 sn temiz hafizasi (pesindeki birlikler durmaz).
 * Kapatma: CBA 'ELITE CQB' (lambs_danger_cqbV2 = false) ya da lambs_danger_koseTemkinOff = true. Log: [CQB-KOSE] (ilk 40) + [CQB-KOSE-OZET] (60 sn).
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_koseTemkinStarted") exitWith {false};
lambs_danger_koseTemkinStarted = true;

diag_log "[CQB-KOSE] kose / aralik temkini (acilari dilimleme) watchdog baslatildi (v8.351)";

[] spawn {
    private _acilar = [-75, -60, -45, -30, -15, 0, 15, 30, 45, 60, 75];

    // tek isin: yuruyus yonune gore _x derece sapmada goz hizasinda serbest mesafe (kucuk nesneler engel degil)
    private _isin = {
        params ["_u", "_eye", "_h", "_sapma", "_L"];
        private _a = _h + _sapma;
        private _hh = lineIntersectsSurfaces [_eye, _eye vectorAdd [(sin _a) * _L, (cos _a) * _L, 0], _u, objNull, true, 2, "VIEW", "NONE"];
        private _m = _L;
        {
            private _nesne = _x select 2;
            private _poz = _x select 0;
            if (isNull _nesne) exitWith { _m = _eye distance _poz; };
            private _bb = boundingBoxReal _nesne;
            if (((_bb select 0) distance (_bb select 1)) >= 2.5) exitWith { _m = _eye distance _poz; };
        } forEach _hh;
        _m
    };

    // yurunen yonde en yakin kor kose: [] ya da [kose AGL, uzak sektor, yakin sektor, ileri mesafe, aci, taraf(-1 sol / +1 sag), fark]
    private _koseBul = {
        params ["_u", "_h", "_icerde"];
        private _eye = eyePos _u;
        private _L = [24, 14] select _icerde;
        private _esikFark = [4, 3] select _icerde;
        private _d = [];
        { _d pushBack ([_u, _eye, _h, _x, _L] call _isin); } forEach _acilar;
        private _sonuc = [];
        private _enIleri = 1e9;
        for "_i" from 0 to ((count _acilar) - 2) do {
            private _dA = _d select _i;
            private _dB = _d select (_i + 1);
            if ((abs (_dA - _dB)) >= _esikFark && {(_dA min _dB) <= ([14, 8] select _icerde)}) then {
                // kisa / uzun isin; 3 kez ikiye bol (sahte siçrama eleme)
                private _aK = _acilar select ([_i, _i + 1] select (_dB < _dA));
                private _aU = _acilar select ([_i + 1, _i] select (_dB < _dA));
                private _dK = _dA min _dB;
                private _dU = _dA max _dB;
                for "_j" from 1 to 3 do {
                    private _aM = (_aK + _aU) / 2;
                    private _dM = [_u, _eye, _h, _aM, _L] call _isin;
                    if ((abs (_dM - _dK)) >= (abs (_dU - _dM))) then { _aU = _aM; _dU = _dM; } else { _aK = _aM; _dK = _dM; };
                    if (_dK > _dU) then {   // kisa / uzun rolu mesafeye gore
                        private _tA = _aK; private _tD = _dK;
                        _aK = _aU; _dK = _dU; _aU = _tA; _dU = _tD;
                    };
                };
                private _aci = (_aK + _aU) / 2;
                private _ileri = _dK * (cos _aci);
                if (
                    (_dU - _dK) >= ([5, 4] select _icerde)
                    && {_dU >= ([12, 8] select _icerde)} && {_dK <= ([14, 8] select _icerde)}
                    && {_ileri >= 1.8} && {_ileri <= ([12, 7] select _icerde)} && {(abs _aci) <= 52}
                    && {_ileri < _enIleri}
                ) then {
                    _enIleri = _ileri;
                    private _sgn = [1, -1] select (_aK < _aU);   // kisa isin solda (kucuk aci) ise bilinmeyen sektor solda
                    private _pozU = _u getPos [_dK + 12, _h + _aci + (_sgn * 20)];
                    private _pozY = _u getPos [_dK + 4, _h + _aci + (_sgn * 9)];
                    private _kosePoz = _u getPos [_dK, _h + _aci];
                    _pozU set [2, 1.2]; _pozY set [2, 1.2];
                    _sonuc = [_kosePoz, _pozU, _pozY, _ileri, _aci, _sgn, _dU - _dK];
                };
            };
        };
        _sonuc
    };

    // kose sekansi (birim basina spawn): ROL "NOKTA" = dilimler ve gecer; "ISTIF" = sirada bekler
    private _sekans = {
        params ["_u", "_g", "_kose", "_rol", "_kimlik", "_sayac"];
        _kose params ["_kPoz", "_pozU", "_pozY", "_ileri", "_aci", "_sgn", "_fark"];
        private _t0 = time;
        private _iptal = {
            params ["_uu"];
            !alive _uu || {!((lifeState _uu) in ["HEALTHY", "INJURED"])} || {(getSuppression _uu) > 0.6}
            || {_uu getVariable [QGVAR(forceMove), false]}
            || {
                private _e = _uu findNearestEnemy _uu;
                !isNull _e && {alive _e} && {(_uu distance2D _e) < 35} && {(_uu knowsAbout _e) >= 1.0}
            }
        };
        private _birak = {
            params ["_uu", "_kim"];
            if (alive _uu && {(_uu getVariable [QGVAR(koseAktif), -1]) isEqualTo _kim}) then {
                _uu forceSpeed -1;
                _uu doWatch objNull;
                _uu setUnitPosWeak "AUTO";
                _uu setVariable [QGVAR(koseAktif), nil];
                _uu setVariable [QGVAR(koseT), time];
            };
        };
        private _bitis = "temizlendi";
        if (_rol isEqualTo "ISTIF") then {
            _u forceSpeed 0;
            _u setUnitPosWeak "UP";
            _u doWatch _pozU;
            waitUntil {
                sleep 0.2;
                ([_u] call _iptal) || {(_g getVariable [QGVAR(koseKilit), []]) isEqualTo []} || {(time - _t0) > 6}
            };
            _bitis = ["istif bitti", "iptal"] select ([_u] call _iptal);
            if ((time - _t0) > 6) then { _bitis = "istif zaman asimi"; };
            [_u, _kimlik] call _birak;
            _sayac set ["istif", (_sayac get "istif") + 1];
        } else {
            _u forceSpeed 0;
            _u setUnitPosWeak "MIDDLE";
            _u doWatch _pozU;
            private _faz = 0;
            private _fazT = time;
            private _bitti = false;
            private _p0 = getPosATL _u;
            waitUntil {
                sleep 0.2;
                if ([_u] call _iptal) then {
                    _bitis = "iptal";
                    _bitti = true;
                } else {
                    switch (_faz) do {
                        case 0: { if ((time - _fazT) >= 0.8) then { _faz = 1; _fazT = time; _u doWatch _pozY; }; };
                        case 1: { if ((time - _fazT) >= 0.6) then { _faz = 2; _fazT = time; _p0 = getPosATL _u; _u forceSpeed 1.3; }; };
                        case 2: {
                            // v8.352: RPT'de her kose 5.5 sn surdu (yavas gecis 3.5 sn tavana dayaniyordu): kosenin 2 m yakinina varinca ya da baslangictan (kose mesafesi + 1.5 m, en cok 5 m) ilerleyince biter; tavan 2.5 sn
                            if ((_u distance2D _kPoz) < 2.0 || {(_u distance2D _p0) >= (((_ileri + 1.5) min 5) max 2)}) then { _bitti = true; };
                            if ((time - _fazT) >= 2.5) then { _bitti = true; };
                        };
                    };
                };
                _bitti || {(time - _t0) > 9}
            };
            [_u, _kimlik] call _birak;
            if (_bitis isEqualTo "temizlendi") then {
                private _temiz = _g getVariable [QGVAR(koseTemiz), []];
                _temiz pushBack [_kPoz, time];
                _g setVariable [QGVAR(koseTemiz), _temiz];
                _sayac set ["temizlendi", (_sayac get "temizlendi") + 1];
            } else {
                _sayac set ["iptal", (_sayac get "iptal") + 1];
            };
            _g setVariable [QGVAR(koseKilit), []];
        };
        if ((missionNamespace getVariable ["lambs_danger_koseLogN", 0]) < 40) then {
            missionNamespace setVariable ["lambs_danger_koseLogN", (missionNamespace getVariable ["lambs_danger_koseLogN", 0]) + 1];
            diag_log format ["[CQB-KOSE] %1 | %2 | %3 | kose %4 m ileride (aci %5, mesafe farki %6 m, bilinmeyen sektor %7) | sonuc: %8 (%9 sn)",
                groupId _g, name _u, _rol, _ileri toFixed 1, round _aci, _fark toFixed 1, ["SOL", "SAG"] select (_sgn > 0), _bitis, (time - _t0) toFixed 1];
        };
    };

    private _sayac = createHashMapFromArray [["tespit", 0], ["temizlendi", 0], ["istif", 0], ["iptal", 0]];
    private _sonOzet = time;

    while {true} do {
        sleep 0.4;
        if ((time - _sonOzet) >= 60) then {
            _sonOzet = time;
            if (((_sayac get "tespit") + (_sayac get "istif")) > 0) then {
                diag_log format ["[CQB-KOSE-OZET] 60 sn: kose tespit %1 | temizlendi %2 | istif (sirada bekleyen) %3 | iptal %4", _sayac get "tespit", _sayac get "temizlendi", _sayac get "istif", _sayac get "iptal"];
            };
            { _sayac set [_x, 0]; } forEach (keys _sayac);
        };
        if (missionNamespace getVariable ["lambs_danger_koseTemkinOff", false] || {!(missionNamespace getVariable ["lambs_danger_cqbV2", true])}) then { continue };
        private _butce = 6;

        {
            private _g = _x;
            if (_butce <= 0) exitWith {};
            if (isNull _g || {!local _g}) then { continue };
            // v8.352 TEHDIT KAPISI (RPT 30-10 17:58: 'TEMAS-YOK-COMBAT' - temas bitmis, dusman 140 m uzakta, lider yalniz COMBAT davranisinda iken 4 asker avluda 5.5 sn'lik kose beklemesi yapti): davranis COMBAT'i
            //   tek basina yetmez. QGVAR(contact) = temas BITIS damgasi (gelecek zaman, ~10 dk): temas aktif ya da liderin 250 m icinde taze bilinen (knowsAbout >= 0.3) dusmani var.
            private _temasT = _g getVariable [QGVAR(contact), 0];
            if (_temasT <= time) then {
                private _ld = leader _g;
                private _ed = if (isNull _ld || {!alive _ld}) then {objNull} else {_ld findNearestEnemy _ld};
                if (isNull _ed || {!alive _ed} || {(_ld distance2D _ed) > 250} || {(_ld knowsAbout _ed) < 0.3}) then { continue };
            };
            if (_g getVariable [QGVAR(sniperTeam), false]) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isATEngage), false]}
                || {_g getVariable [QGVAR(isSweeping), false]} || {_g getVariable [QGVAR(isSonDirenis), false]} || {_g getVariable [QGVAR(isAmbushing), false]}
            ) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };

            {
                private _u = _x;
                if (_butce <= 0) exitWith {};
                if (
                    !alive _u || {!local _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                    || {captive _u} || {_u getVariable [QGVAR(teslim), false]}
                    || {(speed _u) < 3.5} || {(stance _u) isEqualTo "PRONE"}
                    || {!isNil {_u getVariable QGVAR(koseAktif)}}
                    || {(time - (_u getVariable [QGVAR(koseT), -999])) < 8} || {(time - (_u getVariable [QGVAR(koseChk), -999])) < 0.8}
                    || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time}
                    || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []}
                    || {(_u getVariable [QGVAR(stationPos), []]) isNotEqualTo []}
                ) then { continue };
                _u setVariable [QGVAR(koseChk), time];

                private _icerde = (insideBuilding _u) > 0.5;
                if (_icerde && {_temasT <= time}) then { continue };   // bina icinde yalniz AKTIF temasta (damga > time)
                if (!_icerde && {(count (nearestTerrainObjects [_u, ["BUILDING", "HOUSE", "WALL"], 25, false, true])) isEqualTo 0}) then { continue };

                // bilinen yakin dusman: kose temkini degil, normal savas (cqbReflex / coverHug)
                private _en = _u findNearestEnemy _u;
                if (!isNull _en && {alive _en} && {(_u distance2D _en) < 35} && {(_u knowsAbout _en) >= 1.0}) then { continue };

                _butce = _butce - 1;
                private _vel = velocity _u;
                private _h = (_vel select 0) atan2 (_vel select 1);
                if (_h < 0) then { _h = _h + 360; };
                private _kose = [_u, _h, _icerde] call _koseBul;
                if (_kose isEqualTo []) then { continue };

                private _kPoz = _kose select 0;
                private _temiz = (_g getVariable [QGVAR(koseTemiz), []]) select {(time - (_x select 1)) < 60};
                _g setVariable [QGVAR(koseTemiz), _temiz];
                if ((_temiz findIf {((_x select 0) distance2D _kPoz) < 8}) >= 0) then { continue };

                private _kilit = _g getVariable [QGVAR(koseKilit), []];
                private _rol = "NOKTA";
                if (_kilit isNotEqualTo [] && {time < (_kilit select 1)} && {((_kilit select 0) distance2D _kPoz) < 8}) then {
                    _rol = "ISTIF";
                } else {
                    _g setVariable [QGVAR(koseKilit), [_kPoz, time + 9]];
                    _sayac set ["tespit", (_sayac get "tespit") + 1];
                };
                private _kimlik = diag_tickTime + (random 0.001);
                _u setVariable [QGVAR(koseAktif), _kimlik];
                [{
                    params ["_uu", "_kim"];
                    if (alive _uu && {(_uu getVariable [QGVAR(koseAktif), -1]) isEqualTo _kim}) then {   // 12 sn sigorta: sekans herhangi bir nedenle olurse birim donup kalmasin
                        _uu forceSpeed -1; _uu doWatch objNull; _uu setUnitPosWeak "AUTO";
                        _uu setVariable [QGVAR(koseAktif), nil];
                        _uu setVariable [QGVAR(koseT), time];
                    };
                }, [_u, _kimlik], 12] call CBA_fnc_waitAndExecute;
                [_u, _g, _kose, _rol, _kimlik, _sayac] spawn _sekans;
            } forEach (units _g);
        } forEach allGroups;
    };
};

true
