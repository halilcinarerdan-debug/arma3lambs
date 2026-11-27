#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DISIPLINLI PATLAYICI KULLANIMI (v8.310; kullanici: 'patlayici kullanimini arttir el bombasi roket ama disiplinli' + 've ugl'). Yeni taktik degil: mevcut temasta olan askerin elindeki patlayiciyi DAHA SIK ve DOGRU hedefe kullandirir.
 * Izleyici 2.5 sn'de bir, yerel oyuncusuz, TEMASTA (contact) olan gruplarda; tick basina en cok 4 atis. Hedef: bilinen (knowsAbout >= 1.0) dusman PIYADE. 'Deger' sartlari (bos yere atilmaz):
 *   KUME (hedefin 8 m icinde baska bilinen dusman) | BINADA | KAPALI HAT (tufege gorus hatti kesik: siper / duvar) | BASKI (grupta >= 2 asker baski > 0.4)
 *   EL BOMBASI (frag; duman / isik / sok haric): bombaMinM (8 m) - 40 m (v8.383; lambs_danger_elBombasiMaxMesafe), ESNEK deger sarti (v8.316: kume 12 m / binada / kapali hat / alcak durus / duragan >= 20 m / baski > 0.3 / pusu; v8.315 sarti kaldirmisti; v8.313: guvenli min = olum yaricapi x 1.8, >= 12 m), hedef 12 m icinde dost YOK, birim basina 30 sn, grup 6 sn, 60 sn'de en cok 2; son bomba YEDEK (kume >= 3 degilse atilmaz)
 *   ROKET: v8.706'da KALDIRILDI (kullanici: 'roketi kaldir, lambs rpg kullanacagim'). Omuz roketatari kararini artik LAMBS RPG / LAMBS Danger verir; bu modul roket atmaz, roket tepkisi (tehditIzle / atAtisIzle) ve havaAA (helikopter) ayri modullerdir.
 *   UGL ek mermi: UGL'li askere CBA 'lambs_danger_uglEkMermi' (varsayilan 4) kadar HE 40mm eklenir (bir kez; envanter doluysa eklenmez) - UGL darbogazi 'mermi_yok' idi.
 * v8.311: el bombasi SCRIPT ile kontrollu balistik firlatilir (hedefe yon + hesaplanan hiz, yay temizligi, insani dagilim; fireAtTarget / forceWeaponFire hedefe nisan almiyordu: 'bodoslama kendi yonlerine').
 * CBA 'ELITE patlayici': lambs_danger_patlayiciAktif, lambs_danger_elBombasiAktif, lambs_danger_uglEkMermi.   Kapatma: lambs_danger_patlayiciOff = true.
 * Log: [PATLAYICI] / [PATLAYICI-OZET]
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_patlayiciStarted") exitWith {false};
lambs_danger_patlayiciStarted = true;
diag_log "[PATLAYICI] disiplinli el bombasi / UGL ek mermi izleyicisi baslatildi (v8.310; roket v8.706 kaldirildi: LAMBS RPG kullanilir)";

// v8.313 YUMUSAK DONUS YARDIMCISI (spawn'lanan kod dis degiskenleri goremez -> global): govdeyi hedefe <= _tol derece kalana dek 8 derece / 0.04 sn adimlarla (~200 derece/sn) cevirir, isinlama yok. Zamanlanmis ortam (sleep).
lambs_danger_patlayiciDon = {
    params ["_u", "_poz", "_tol"];
    private _fark = (((_u getDir _poz) - (getDir _u)) + 540) mod 360 - 180;
    private _kalan = abs _fark;
    if (_kalan > _tol) then {
        private _is = [-1, 1] select (_fark > 0);
        for "_i" from 1 to (ceil (_kalan / 8)) do {
            if (!alive _u) exitWith {};
            private _adim = 8 min _kalan;
            _u setDir ((getDir _u) + (_adim * _is));
            _kalan = _kalan - _adim;
            sleep 0.04;
        };
    };
};

[] spawn {
    private _sayac = createHashMapFromArray [["bomba", 0], ["ugl_ek", 0], ["FAT", 0], ["FWF", 0], ["yok", 0]];
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
    // ---- EL BOMBASI: KONTROLLU ATIS (v8.311; kullanici: 'el bombasini bodoslama atiyorlar, kendi yonlerine'; RPT 23-10 08:19: fireAtTarget false + forceWeaponFire yonu bilmeden atiyordu -> mermi sayaci degismedi ('ates YOK') ama bomba askerin baktigi yone gidiyordu) ----
    //   forceWeaponFire / fireAtTarget hedefe nisan almaz ve menzili ayarlamaz -> bomba SCRIPT ile balistik firlatilir: hedefe dogru yatay yon + 40-60 derece yay + hesaplanan hiz (<= 26 m/sn), insani dagilim (yan +-4 m + %4 mesafe, boy +-5 %),
    //   yay uzerinde 6 noktada duvar / nesne denetimi (firlatanin onunde engel varsa ATILMAZ), once hedefe doWatch (<= 1.5 sn; govde 35 dereceden fazla sapmissa vazgecilir; setDir ile isinlama YOK), 'ThrowGrenade' animasyonu, magazin dusulur.
    private _firlat = {
        params ["_u", "_t", "_mag"];
        [_u, _t, _mag] spawn {
            params ["_u", "_t", "_mag"];
            private _ammo = getText (configFile >> "CfgMagazines" >> _mag >> "ammo");
            _u doWatch _t;
            sleep 0.5;
            if (alive _u && {alive _t}) then { [_u, _t, 12] call lambs_danger_patlayiciDon; };
            private _aci = if (alive _u && {alive _t}) then { abs ((((_u getDir _t) - (getDir _u)) + 540) mod 360 - 180) } else { 180 };
            private _sonuc = "";
            if (!alive _u || {!alive _t}) then { _sonuc = "hedef / atici oldu"; }
            else { if (_aci > 130) then { _sonuc = format ["donemedi (%1 derece)", round _aci]; }   // v8.591: 35 -> 100 (RPT b3f29106 / aa5e787e: 44-65 derecede 3 atis iptal; bomba yonu script ile hesaplanir, govde yonu dogrulugu etkilemez)
            else { if (false) then {} else {
                // v8.611 ANIMASYON SONRA (kullanici: 'animasyonu var el bombasi yok'; RPT e120b9e9: 'yay uzerinde engel - atilmadi' satirlarinda asker ThrowGrenade animasyonuna girip bomba atmiyordu): animasyon yalniz TEMIZ yay bulunduktan sonra oynatilir
                if (alive _u && {alive _t} && {(magazines _u) findIf {_x isEqualTo _mag} >= 0}) then {
                    private _rel = (eyePos _u) vectorAdd [0, 0, -0.1];
                    private _hp = getPosASL _t;
                    private _dag = random (1.5 + ((_u distance2D _t) * 0.04));
                    private _hedef = (AGLToASL ((ASLToAGL _hp) getPos [_dag, random 360]));
                    private _D = ((_rel select 0) - (_hedef select 0)) ^ 2;
                    _D = sqrt (_D + (((_rel select 1) - (_hedef select 1)) ^ 2));
                    private _dh = ((_hedef select 2) + 0.3) - (_rel select 2);
                    // v8.595 YAY ACISI ARAMASI (RPT 38287827: 14 denemeden 12'si 'yay uzerinde engel'; engel Land_Radar_01_HQ_F yay noktasi 6-8/8 = hedefin binasi / pencere onu): eskiden yalniz 40 / 50 / 60 derece, ilk aci
                    //   secilip engel varsa vazgecilirdi. Simdi aci adaylari sirayla denenir (40, 50, 60, sonra DUZ yaylar 25 / 32 / 18 / 12 [pencere / kapidan iceri duz atis], 68); her aday icin hiz (<= 26 m/sn) + GEOM yay kontrolu;
                    //   ilk TEMIZ yay atilir; hicbiri temiz degilse ilk engelin adi loglanir. Bina duvari GEOM'da kapaliysa (pencere acik degilse) yine atilmaz (bomba geri seker).
                    // v8.597 UST KAT PENCERE + CAM DURUMU (kullanici: '2. ve 3. kat pencereye de atsinlar, fiziksel olarak girecekse camlarin kirik olup olmadigina dikkat et, birkac metre yukseye atilabilsin'):
                    //   yukseklik (dh) sinirsiz (aci 75 derece + hiz 28 m/sn); girip girmeyecegini GEOM yay denetimi belirler (cam gecirmezse yay kapali = atilmaz).
                    //   Cam gosterimi bilinmiyor: binanin 'glass' animasyonlari + hitpoint sayisi RPT'ye yazilir ([PATLAYICI-CAM], ilk 8) - sonraki surumde kirik / saglam cam ayrimi bu veriye gore yapilir.
                    if ((insideBuilding _t) > 0.2 && {(missionNamespace getVariable ["lambs_danger_camLogN", 0]) < 8}) then {
                        missionNamespace setVariable ["lambs_danger_camLogN", (missionNamespace getVariable ["lambs_danger_camLogN", 0]) + 1];
                        private _bn0 = nearestBuilding _t;
                        private _cam = (animationNames _bn0) select {((toLower _x) find "glass") >= 0};
                        diag_log format ["[PATLAYICI-CAM] %1 | hedef yuksekligi +%2 m | cam animasyonu %3 (kirik / gizli %4) | hitpoint %5 | ornek %6", typeOf _bn0, _dh toFixed 1, count _cam, {(_bn0 animationPhase _x) > 0.5} count _cam, count ((getAllHitPointsDamage _bn0) param [0, []]), _cam select [0, 4]];
                    };
                    private _v = -1;
                    private _th = 0;
                    private _vel = [];
                    private _engelAd = "";
                    private _engelI = 0;
                    private _denenen = 0;
                    private _yon = _rel getDir _hedef;
                    // v8.614 NISAN NOKTASI LISTESI (kullanici: 'el bombasi pencereye ve evin icine ama daha iyi tuttursunlar'; hile KALDIRILDI): hedef BINADAYSA yalniz hedef noktasi degil, hedefin <= 5 m'sindeki ayni kat (+-2.5 m) ic pozisyonlari
                    //   (pencere / kapidan gorulen noktalar dahil) da denenir (bomba olum yaricapi ~5 m: hedefin yakinina duserse yeter); ilk TEMIZ yay (aci x nisan noktasi) atilir.
                    private _aimList = [_hedef];
                    if ((insideBuilding _t) > 0.15) then {
                        private _tAGL = ASLToAGL _hp;
                        private _icP = ((nearestBuilding _t) buildingPos -1) select {((_x distance2D _tAGL) <= 5) && {(abs ((_x select 2) - (_tAGL select 2))) <= 2.5}};
                        _icP = [_icP, [], {_x distance2D _tAGL}, "ASCEND"] call BIS_fnc_sortBy;
                        { _aimList pushBack (AGLToASL (_x vectorAdd [0, 0, 0.3])); } forEach (_icP select [0, 6]);
                    };
                    {
                        if (_v >= 0) then { continue };
                        _hedef = _x;
                        _D = sqrt ((((_rel select 0) - (_hedef select 0)) ^ 2) + (((_rel select 1) - (_hedef select 1)) ^ 2));
                        _dh = ((_hedef select 2) + 0.3) - (_rel select 2);
                        _yon = _rel getDir _hedef;
                    {
                        if (_v >= 0) then { continue };
                        private _a = _x;
                        if (_a > 62 && {_dh < 2.5}) then { continue };   // v8.619: ayni kat hedefe dik (> 62 derece) lob YOK (RPT 39835e40: 80 derece, 10 m hedef -> bomba atici yaninda (0 m) dustu / geri tepti); dik yay yalniz ust kat (>= +2.5 m)
                        private _payda = (_D * (tan _a)) - _dh;
                        if (_payda > 0.5) then {
                            private _vv = sqrt ((9.81 * _D * _D) / (2 * ((cos _a) ^ 2) * _payda));
                            if (_vv <= (26 + (4 * (((_dh / 4) max 0) min 1)))) then {   // v8.597: ust kat (>= +4 m) hedefe hiz tavani 26 -> 28 m/sn
                                private _vk = _vv * (1 + ((random 0.1) - 0.05));
                                private _vl = [(sin _yon) * (cos _a) * _vk, (cos _yon) * (cos _a) * _vk, (sin _a) * _vk];
                                private _tTop = _D / ((cos _a) * _vk max 1);
                                private _onceki = _rel;
                                private _engel = false;
                                private _ad = "";
                                private _ni = 0;
                                // v8.624 DIK INIS YASAK (kullanici: 'el bombalarini pencereye tutturamiyorlar'; RPT 1a697d94: 76-80 derece lob, 14-17 m, bomba cati / duvara dusup geri teper; ayrica 49-57 m'ye atis): bina ici hedefte son inis acisi > 52 derece ya da mesafe > 40 m ise yay 'engelli' sayilir (pencere / kapidan girmek icin yatay inis gerekir)
                                private _inis = (-((_vl select 2) - (9.81 * _tTop))) atan2 ((cos _a) * _vk);
                                private _binaHedef = (insideBuilding _t) > 0.15;
                                if (_binaHedef && {(_inis > (missionNamespace getVariable ["lambs_danger_bombaInisMaks", 62])) || {_D > (missionNamespace getVariable ["lambs_danger_bombaMesafeMaks", 60])}}) then {   // v8.635: CBA bombaInisMaks / bombaMesafeMaks
                                    _engel = true;
                                    _ni = 0;
                                    _ad = format ["dik inis %1 derece / mesafe %2 m (pencereye girmez)", round _inis, round _D];
                                } else {
                                for "_i" from 1 to 8 do {
                                        private _tt = _tTop * (_i / 8);   // v8.596: 0.92 -> 1.0 (yayin SON %8'i de denetlenir: pencere / duvar onunde dusup geri sekme riski; RPT 38ac1efc: grup 10 -> 4 etkin)
                                        private _nokta = _rel vectorAdd [(_vl select 0) * _tt, (_vl select 1) * _tt, ((_vl select 2) * _tt) - (4.905 * _tt * _tt)];
                                        private _ht = if (_i >= 2) then { lineIntersectsSurfaces [_onceki, _nokta, _u, _t, true, 1, "GEOM", "NONE"] } else { [] };
                                        if (_ht isNotEqualTo []) exitWith {
                                            _engel = true;
                                            _ni = _i;
                                            private _eo = (_ht select 0) select 2;
                                            _ad = if (isNull _eo) then {"arazi / nesne"} else { [typeOf _eo, (getModelInfo _eo) select 0] select ((typeOf _eo) isEqualTo "") };
                                        };
                                        _onceki = _nokta;
                                    };
                                };
                                // v8.722 TUP DENETIMI (kullanici: 'botlar 2. kata el bombasini tutturamiyor, disari atiyorlar'; RPT: 74 izli atistan 48'i bina duvarina +2.5..+3.0 m'de carpti = 2. kat pencere denizligi hemen alti; cizgi yayi 'temiz' ama bomba
                //   gercekte ~6-10 cm kalinlikta, pencere kenarina / denizlige surtunuyor): bina ici hedefte yay, merkez cizgisinin ALTINA 0.55 m, USTUNE 0.25 m ve iki yanina 0.3 m kaydirilmis 4 paralel cizgiyle de denetlenir (pencere acikliginin ortasindan gecen yay secilir);
                //   hedef noktasina 2.5 m kala (ic zemin / duvar) denetim yapilmaz. Gecis dar ise yay 'engelli' sayilir, siradaki aci / nisan noktasi denenir.
                if (!_engel && {_binaHedef}) then {
                    private _sg = [cos _yon, -(sin _yon), 0];
                    private _tup = [[0, 0, -0.55], [0, 0, 0.25], _sg vectorMultiply 0.3, _sg vectorMultiply -0.3];
                    private _o2 = _rel;
                    for "_i" from 1 to 8 do {
                        private _tt2 = _tTop * (_i / 8);
                        private _nk2 = _rel vectorAdd [(_vl select 0) * _tt2, (_vl select 1) * _tt2, ((_vl select 2) * _tt2) - (4.905 * _tt2 * _tt2)];
                        if (_i >= 2 && {(_nk2 distance _hedef) > 2.5}) then {
                            {
                                if (!_engel && {(lineIntersectsSurfaces [_o2 vectorAdd _x, _nk2 vectorAdd _x, _u, _t, true, 1, "GEOM", "NONE"]) isNotEqualTo []}) then {
                                    _engel = true;
                                    _ni = _i;
                                    _ad = "dar gecis (pencere kenari / denizlik)";
                                };
                            } forEach _tup;
                        };
                        _o2 = _nk2;
                        if (_engel) exitWith {};
                    };
                };
                                _denenen = _denenen + 1;
                                if (_engel) then {
                                    if (_engelAd isEqualTo "") then { _engelAd = _ad; _engelI = _ni; };
                                } else { _v = _vk; _th = _a; _vel = _vl; };
                            };
                        };
                    } forEach [40, 50, 60, 45, 55, 35, 30, 25, 20, 15, 12, 68, 72, 76, 80];   // v8.614: 2. / 3. kat (kullanici: '2. kata falan atsinlar'): dik yaylar 72 / 76 / 80 derece, ust kat (>= +4 m) hiz tavani 30 m/sn
                    } forEach _aimList;   // v8.597: 75 derece (2. / 3. kat pencereye dik yay)
                    if (_v < 0) then {
                        _sonuc = if (_denenen isEqualTo 0) then {"menzil / yukseklik uygun degil"} else { format ["yay uzerinde engel (%1, yay noktasi %2/8; %3 aci denendi) - atilmadi", _engelAd, _engelI, _denenen] };
                    } else {
                        _u playActionNow "ThrowGrenade";
                        sleep 0.8;
                        if (!alive _u || {((magazines _u) findIf {_x isEqualTo _mag}) < 0}) then { _sonuc = "atici oldu / bomba kayboldu (animasyon sirasinda)"; } else {
                            private _gr = createVehicle [_ammo, ASLToAGL _rel, [], 0, "CAN_COLLIDE"];
                            _gr setPosASL _rel;
                            _gr setVelocity _vel;
                            _gr setShotParents [_u, _u];
                            // v8.619 PATLAMA ONCESI DOST GUVENLIGI (kullanici: 'kendilerini oldurduyorlar'; RPT 39835e40: el bombasi atici / giris takimi yaninda (0-6 m) patladi, Fu Hou / Zhen Jao baygin): fitilin son 0.3 sn'sinde bomba bombaDostM icinde dost (atici dahil) varsa bomba SILINIR (patlamaz)
                            [_gr, _u, _hedef, _dh, _th] spawn {
                                params ["_gr", "_u", "_hd", "_dhP", "_thP"];
                                private _fit = getNumber (configFile >> "CfgAmmo" >> (typeOf _gr) >> "explosionTime");
                                if (_fit <= 0) then { _fit = 5; };
                                private _bit = time + (_fit - 0.3);
                                // v8.624 BOMBA IZI (tani; kullanici: 'pencereye tutturamiyorlar'): ilk carpma (hiz > %45 duser) noktasi / nesnesi + fitil sonu konumu (hedefe uzaklik, bina altinda mi)
                                private _oncePos = getPosASL _gr;
                                private _onceHiz = vectorMagnitude (velocity _gr);
                                private _carpma = [];
                                waitUntil {
                                    sleep 0.05;
                                    if (!isNull _gr && {_carpma isEqualTo []}) then {
                                        private _h = vectorMagnitude (velocity _gr);
                                        if (_onceHiz > 6 && {_h < (_onceHiz * 0.55)}) then {
                                            private _ht = lineIntersectsSurfaces [_oncePos, (getPosASL _gr) vectorAdd ((vectorNormalized ((getPosASL _gr) vectorDiff _oncePos)) vectorMultiply 1.5), _gr, _u, true, 1, "GEOM", "NONE"];
                                            private _eo = if (_ht isEqualTo []) then {objNull} else {(_ht select 0) select 2};
                                            _carpma = [getPosASL _gr, if (isNull _eo) then {"arazi / bilinmeyen"} else {[typeOf _eo, (getModelInfo _eo) select 0] select ((typeOf _eo) isEqualTo "")}];
                                        };
                                        _oncePos = getPosASL _gr;
                                        _onceHiz = _h;
                                    };
                                    isNull _gr || {time >= _bit}
                                };
                                if (!isNull _gr) then {
                                    private _son = getPosASL _gr;
                                    private _ustte = lineIntersectsSurfaces [_son vectorAdd [0, 0, 25], _son vectorAdd [0, 0, 0.3], _gr, objNull, true, 1, "GEOM", "NONE"];
                                    private _bAltinda = _ustte isNotEqualTo [] && {((_ustte select 0) select 2) isKindOf "House"};
                                    // v8.722: mesafeler ASL-ASL (eskiden ASL dizi ile nesne 'distance' = arazi yuksekligi kadar sahte mesafe: yuksek arazide 205-248 m); plan = hedef noktasinin atici ayagina gore yuksekligi + atis acisi
                                    diag_log format ["[BOMBA-IZI] %1 | hedefe %2 m | atici %3 m | ilk carpma %4 | bina altinda %5 | plan: hedef (goze gore) +%6 m, aci %7", name _u, round (_son distance _hd), round (_son distance (getPosASL _u)), if (_carpma isEqualTo []) then {"yok (havada / son)"} else {format ["%1 m atici, nesne %2, yukseklik +%3 m", round ((_carpma select 0) distance (getPosASL _u)), _carpma select 1, (((_carpma select 0) select 2) - ((getPosASL _u) select 2)) toFixed 1]}, _bAltinda, _dhP toFixed 1, _thP];
                                    private _gp = getPosATL _gr;
                                    private _dm = missionNamespace getVariable ["lambs_danger_bombaDostM", 8];
                                    private _tr = side (group _u);
                                    private _yak = allUnits select {alive _x && {(_x distance _gr) < _dm} && {(_tr getFriend (side group _x)) >= 0.6}};
                                    if (_yak isNotEqualTo []) then {
                                        deleteVehicle _gr;
                                        diag_log format ["[PATLAYICI] bomba patlamadan SILINDI | %1 | yakin dost %2 (en yakin %3 m, atici %4 m) | grup %5", name _u, count _yak, round (((_yak apply {_x distance _gp}) call BIS_fnc_arithmeticMean) min 99), round (_u distance _gp), groupId (group _u)];
                                    };
                                };
                            };
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
    private _hepsiHE = {
        params ["_w", "_mz"];
        ([_w, _mz] call FUNC(uglMags)) select {
            private _a = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
            private _k = toLower _x;
            (toLower (getText (configFile >> "CfgAmmo" >> _a >> "simulation"))) isEqualTo "shotgrenade" && {(_k find "smoke") < 0} && {(_k find "flare") < 0} && {(_k find "illum") < 0} && {(_k find "chem") < 0}
        }
    };

    while {true} do {
        sleep ([2.5, true, false, "patlayici"] call FUNC(dusunSure));
        if (missionNamespace getVariable ["lambs_danger_patlayiciOff", false] || {!(missionNamespace getVariable ["lambs_danger_patlayiciAktif", true])}) then {
            // v8.590 TANI (RPT 8368382a: 52 dk oturumda [PATLAYICI-OZET] / [PATLAYICI-TANI] hic yok = izleyici calismadi): kapaliysa nedeni RPT'ye yaz (ilk 5, 60 sn'de bir)
            if (time > _sonOzet && {(missionNamespace getVariable ["lambs_danger_patKapaliN", 0]) < 5}) then {
                _sonOzet = time + 60;
                missionNamespace setVariable ["lambs_danger_patKapaliN", (missionNamespace getVariable ["lambs_danger_patKapaliN", 0]) + 1];
                diag_log format ["[PATLAYICI-OZET] KAPALI: patlayiciAktif %1 | patlayiciOff %2 (CBA 'ELITE patlayici' > ana anahtar)", missionNamespace getVariable ["lambs_danger_patlayiciAktif", true], missionNamespace getVariable ["lambs_danger_patlayiciOff", false]];
            };
            continue
        };
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

        // ---- SPAWN BOMBASI (v8.608; kullanici: 'her adama zeusta dahil spawnlandiginda envanterine 1 tane m67 ya da f1 tarzi bomba eklensin'): her yerel AI askere (Zeus dahil, her yeni asker) BIR KEZ CBA spawnBomba kadar frag bombasi eklenir; sinif: spawnBombaSinif
        //   (bos = taraf otomatik: BLUFOR rhs_mag_m67 / HandGrenade; OPFOR rhs_mag_f1 / rhs_mag_rgd5 / MiniGrenade; INDEPENDENT rhs_mag_f1 / HandGrenade; ilk bulunan, frag olan) ----
        private _sp = missionNamespace getVariable ["lambs_danger_spawnBomba", 1];
        if (_sp > 0) then {
            private _spSinif = missionNamespace getVariable ["lambs_danger_spawnBombaSinif", ""];
            {
                private _u = _x;
                if !(_u getVariable [QGVAR(bombaSpawn), false]) then {
                    _u setVariable [QGVAR(bombaSpawn), true];
                    private _adayL = if (_spSinif isNotEqualTo "") then { _spSinif splitString ", ;" } else {
                        switch (side (group _u)) do {
                            case west: { ["rhs_mag_m67", "HandGrenade"] };
                            case east: { ["rhs_mag_f1", "rhs_mag_rgd5", "MiniGrenade"] };
                            default { ["rhs_mag_f1", "HandGrenade"] };
                        }
                    };
                    private _cls = (_adayL select {isClass (configFile >> "CfgMagazines" >> _x) && {[_x] call _fragMi}}) param [0, ""];
                    if (_cls isNotEqualTo "") then {
                        private _once = {_x isEqualTo _cls} count (magazines _u);
                        _u addMagazines [_cls, _sp];
                        private _eklenen = ({_x isEqualTo _cls} count (magazines _u)) - _once;
                        if (_eklenen > 0 && {(missionNamespace getVariable ["lambs_danger_spawnBombaLogN", 0]) < 10}) then {
                            missionNamespace setVariable ["lambs_danger_spawnBombaLogN", (missionNamespace getVariable ["lambs_danger_spawnBombaLogN", 0]) + 1];
                            diag_log format ["[PATLAYICI] spawn bombasi | %1 | %2 | %3 x%4", name _u, side (group _u), _cls, _eklenen];
                        };
                    };
                };
            } forEach (allUnits select {local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side (group _x)) isNotEqualTo civilian}});
        };

        // ---- EL BOMBASI EK (v8.607; kullanici: 'el bombasi class name ekleme ayari ekle'): CBA elBombasiSinif (sarjor sinif adi, virgullu liste: HandGrenade, rhs_mag_rgd5) + elBombasiEk (asker basina en az bu kadar); ayar degisince yeniden uygulanir ----
        private _bSinif = missionNamespace getVariable ["lambs_danger_elBombasiSinif", ""];
        private _bAdet = missionNamespace getVariable ["lambs_danger_elBombasiEk", 0];
        if (_bSinif isNotEqualTo "" && {_bAdet > 0}) then {
            private _anahtar = format ["%1|%2", _bSinif, _bAdet];
            private _sinifListe = (_bSinif splitString ", ;") select {isClass (configFile >> "CfgMagazines" >> _x)};
            if (_sinifListe isEqualTo [] && {(missionNamespace getVariable ["lambs_danger_bombaEkUyari", ""]) isNotEqualTo _anahtar}) then {
                missionNamespace setVariable ["lambs_danger_bombaEkUyari", _anahtar];
                diag_log format ["[PATLAYICI] el bombasi ek: GECERLI SINIF YOK (CfgMagazines'te bulunamadi): '%1'", _bSinif];
            };
            {
                private _u = _x;
                if ((_u getVariable [QGVAR(bombaEkAnahtar), ""]) isNotEqualTo _anahtar) then {
                    _u setVariable [QGVAR(bombaEkAnahtar), _anahtar];
                    {
                        private _cls = _x;
                        if ([_cls] call _fragMi) then {
                            private _once = {_x isEqualTo _cls} count (magazines _u);
                            private _eksik = _bAdet - _once;
                            if (_eksik > 0) then {
                                _u addMagazines [_cls, _eksik];
                                private _eklenen = ({_x isEqualTo _cls} count (magazines _u)) - _once;
                                if (_eklenen > 0 && {(missionNamespace getVariable ["lambs_danger_bombaEkLogN", 0]) < 10}) then {
                                    missionNamespace setVariable ["lambs_danger_bombaEkLogN", (missionNamespace getVariable ["lambs_danger_bombaEkLogN", 0]) + 1];
                                    diag_log format ["[PATLAYICI] el bombasi eklendi | %1 | %2 x%3 (envanter dolu ise eksik kalabilir)", name _u, _cls, _eklenen];
                                };
                            };
                        };
                    } forEach _sinifListe;
                };
            } forEach (allUnits select {local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side (group _x)) isNotEqualTo civilian} && {!([_x] call FUNC(oyuncuKomutaMi))}});
        };

        // ---- temasta gruplar ----
        {
            if (_butce <= 0) exitWith {};
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {(side _g) isEqualTo civilian}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then { continue };
            if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(teslimOldu), false]}) then { continue };
            private _uyeler = (units _g) select {alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable [QGVAR(forceMove), false])} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time} && {!(_x getVariable [QGVAR(teslim), false])}};   // v8.314: bina ici de dahil (bomba atabilir; roket icin ayrica disarida sarti)
            if (_uyeler isEqualTo []) then { continue };
            private _baski = ({([_x] call FUNC(baskiSeviye)) >= 2} count _uyeler) >= 2;
            private _baskiGev = ({([_x] call FUNC(baskiSeviye)) >= 2} count _uyeler) >= 1;   // v8.316: esnek baski (bomba icin)
            private _pusu = (time - (_g getVariable [QGVAR(pusuT), -999])) < 30;   // v8.313: pusu alarmi (fnc_pusuTepki) son 30 sn -> bilinen atici icin bomba / roket 'deger tasir' sayilir
            private _taraf = side _g;
            private _tr = _l nearTargets 320;
            private _dusman = _tr select {
                private _o = _x select 4;
                !isNull _o && {alive _o} && {_o isKindOf "CAManBase"} && {!([_o] call FUNC(teslimMi))} && {(lifeState _o) in ["HEALTHY", "INJURED"]} && {!(_o getVariable ["ACE_isUnconscious", false])} && {(_taraf getFriend (side (group _o))) < 0.6} && {(_l knowsAbout _o) >= (["SUPHE"] call FUNC(bilgiEsik))}   // v8.384: baygin dusmana bomba atilmaz; v8.315: 1.0 -> 0.6 (kullanici: 'kosullari esnet')
            };
            // v8.314 TANI (kullanici: 'el bombasi kullanimi hala yok'; RPT 23-10 09:25: sayaclar 0 = hic aday bulunamadi; asker 'iceride' idi ve eski kod bina ici askeri eliyordu): grup basina 20 sn'de bir neden satiri (en cok 60)
            if ((time - (_g getVariable [QGVAR(patTaniT), -999])) > 20 && {(missionNamespace getVariable ["lambs_danger_patTaniN", 0]) < 60}) then {
                _g setVariable [QGVAR(patTaniT), time];
                missionNamespace setVariable ["lambs_danger_patTaniN", (missionNamespace getVariable ["lambs_danger_patTaniN", 0]) + 1];
                private _tumDus = _tr select { private _o = _x select 4; !isNull _o && {alive _o} && {_o isKindOf "CAManBase"} && {(_taraf getFriend (side (group _o))) < 0.6} };
                private _enY = if (_tumDus isEqualTo []) then {"-"} else { private _o = (([_tumDus, [], {(_x select 4) distance _l}, "ASCEND"] call BIS_fnc_sortBy) select 0) select 4; format ["%1 m knows %2", round (_l distance _o), (_l knowsAbout _o) toFixed 2] };
                diag_log format ["[PATLAYICI-TANI] %1 | temasta | asker %2 (binada %3) | frag tasiyan %4 | 320 m icinde dusman %5 (bilinen >= 1.0: %6) | en yakin %7 | baski:%8 pusu:%9", groupId _g, count _uyeler, ({(insideBuilding _x) > 0.5} count _uyeler), ({((magazines _x) findIf {[_x] call _fragMi}) >= 0} count _uyeler), count _tumDus, count _dusman, _enY, _baski, _pusu];
            };
            if (_dusman isEqualTo []) then { continue };

            {
                if (_butce <= 0) exitWith {};
                private _u = _x;
                // v8.566 CQB FRAG (kullanici: 'frag neredeyse hic kullanilmamis, cqb de frag kullanimini arttir'; RPT a3a55579: 60 dk'da el bombasi emri 0): CQB mesafesinde (CBA cqbBombaM, 25 m) bilinen dusmana DEGER SARTI aranmaz,
                //   birim bekleme 20 -> 10 sn, grup araligi 4 -> 2 sn, 60 sn'de en cok 3 -> 5 bomba. Dost 12 m / guvenli minimum mesafe / yay temizligi kurallari AYNEN. CBA cqbBomba.
                private _cqbBomba = missionNamespace getVariable ["lambs_danger_cqbBomba", true];
                private _cqbM = missionNamespace getVariable ["lambs_danger_cqbBombaM", 25];
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
                    private _bn = (insideBuilding _o) > 0.2;
                    if (_m < _enM && {_k >= 2 || _kp || _bn || _baski || _pusu || {_cqbBomba && {_m <= _cqbM}}}) then { _enIyi = _o; _enM = _m; _kumeN = _k; _kapali = _kp; _binada = _bn; };
                } forEach _dusman;
                // v8.316 DEGER SARTI VAR AMA ESNEK (kullanici: 'deger sarti olsun ama esnetilsin'; v8.315 sarti tamamen kaldirmisti): el bombasi hedefi 10-60 m, temasta bilinen dusman piyade ve ASAGIDAKILERDEN EN AZ BIRI:
    //   KUME (12 m icinde baska dusman) | BINADA | KAPALI HAT (bas ya da gogus hizasinda gorus hatti kesik) | ALCAK DURUS (CROUCH / PRONE) | DURAGAN (hiz < 1.5 m/sn, >= 20 m) | grupta EN AZ 1 askerde baski > 0.3 | pusu alarmi (son 30 sn).
    //   Yalniz acikta, ayakta KOSAN / yuruyen ve baski olmayan dusmana atilmaz (bos yere bomba harcanmaz). Diger disiplin: asker 20 sn, grup 4 sn, 60 sn'de <= 3, yay temizligi, dost 12 m, guvenli min mesafe.
                // v8.591 YAKINDA ACIMASIZ (kullanici: 'kullansinlar, rpg ve el bombasi yakinda acimasinlar'): en kisa atis mesafeleri CBA bombaMinM (8 m; eskiden 10 / guvenli yaricap x1.8 >= 12 m, binada 15 m)
                private _bombaMin = ((missionNamespace getVariable ["lambs_danger_bombaMinM", 8]) max 4) min 15;
                private _bombaMax = missionNamespace getVariable ["lambs_danger_elBombasiMaxMesafe", 40];   // v8.383: el bombasi azami atis mesafesi (kullanici: 'cok uzaga el bombasi atmaya calisti'); eskiden 60 m
                private _bH = objNull;
                private _bM = 1e9;
                private _bAday = false;
                {
                    private _o = _x select 4;
                    private _m = _u distance _o;
                    if (_m >= _bombaMin && {_m <= _bombaMax} && {_m < _bM}) then {
                        _bAday = true;
                        private _kk = ({ (_x select 4) isNotEqualTo _o && {((_x select 4) distance _o) < 12} } count _dusman) + 1;
                        private _deger = _kk >= 2 || {(insideBuilding _o) > 0.2} || {lineIntersects [eyePos _u, eyePos _o, _u, _o]} || {lineIntersects [eyePos _u, (getPosASL _o) vectorAdd [0, 0, 0.6], _u, _o]}
                            || {(stance _o) in ["CROUCH", "PRONE"]} || {(speed _o) < 1.5 && {_m >= 20}} || {_baskiGev} || {_pusu} || {_cqbBomba && {_m <= _cqbM}} || {missionNamespace getVariable ["lambs_danger_bombaAcik", true]};   // v8.609: acik arazi - deger sarti aranmaz (CBA bombaAcik)
                        if (_deger) then { _bH = _o; _bM = _m; };
                    };
                } forEach _dusman;
                if (_bAday && {isNull _bH}) then { _sayac set ["g_deger", (_sayac getOrDefault ["g_deger", 0]) + 1]; };
                if (isNull _enIyi && {isNull _bH}) then { continue };
                private _bT = if (!isNull _enIyi && {_enM <= _bombaMax}) then { _enIyi } else { _bH };
                private _bTM = if (isNull _bT) then { 1e9 } else { _u distance _bT };
                private _bKume = if (!isNull _enIyi && {_bT isEqualTo _enIyi}) then { _kumeN } else { 1 };
                private _cqbY = _cqbBomba && {_bTM <= _cqbM};

                // --- EL BOMBASI ---
                if (missionNamespace getVariable ["lambs_danger_elBombasiAktif", true]) then {
                    if (isNull _bT) then { _sayac set ["g_mesafe", (_sayac getOrDefault ["g_mesafe", 0]) + 1]; };
                    if (!isNull _bT && {_bTM >= _bombaMin} && {_bTM <= _bombaMax} && {(time - (_u getVariable [QGVAR(bombaT), -999])) > ([20, 10] select _cqbY)} && {(time - (_g getVariable [QGVAR(bombaGT), -999])) > ([4, 2] select _cqbY)}) then {
                        private _fraglar = (magazines _u) select {[_x] call _fragMi};
                        if (_fraglar isEqualTo []) then { _sayac set ["g_frag_yok", (_sayac getOrDefault ["g_frag_yok", 0]) + 1]; };
                        private _gecmis = (_u getVariable [QGVAR(bombaListe), []]) select {(time - _x) < 60};
                        _u setVariable [QGVAR(bombaListe), _gecmis];
                        private _yedek = (count _fraglar) <= 1 && {_bKume < 3} && {!_baski} && {!_pusu} && {_bTM > 25};   // v8.315: son bomba yedek - baski / pusu / 25 m icinde ise yedek bozulur
                        if (_fraglar isNotEqualTo [] && {_yedek}) then { _sayac set ["g_yedek", (_sayac getOrDefault ["g_yedek", 0]) + 1]; };
                        if (_fraglar isNotEqualTo [] && {!_yedek} && {(count _gecmis) < ([3, 5] select _cqbY)}) then {
                            private _mag = _fraglar select 0;
                            // v8.313: guvenli minimum mesafe = bombanin olum yaricapi (indirectHitRange) x 1.8, en az 12 m (eskiden sabit 15 m)
                            private _ihr = getNumber (configFile >> "CfgAmmo" >> (getText (configFile >> "CfgMagazines" >> _mag >> "ammo")) >> "indirectHitRange");
                            private _icerde = (insideBuilding _u) > 0.5;
                            if (_bTM < _bombaMin) then { _sayac set ["g_yakin", (_sayac getOrDefault ["g_yakin", 0]) + 1]; continue };
                            // v8.728 YUZ YUZE YASAGI (kullanici: 'face to face'de el bombasi atilmasin'): hedef bombaYuzYuzeM (20 m) icinde VE gorus hatti ACIK (duvar / siper arkasinda degil, gorunurluk >= 0.4) ise bomba atilmaz; asker ates eder (bomba 2-3 sn, olum yaricapi ~5-8 m, kendi canina da tehlike).
                            //   Duvar arkasi / kapali hat / ust kat hedefe ve bina girisi bombasina (girisBombasi) dokunulmaz.
                            private _yuzM = ((missionNamespace getVariable ["lambs_danger_bombaYuzYuzeM", 20]) max 0) min 60;
                            if (_yuzM > 0 && {_bTM < _yuzM} && {!(lineIntersects [eyePos _u, eyePos _bT, _u, _bT])} && {([_u, "VIEW", _bT] checkVisibility [eyePos _u, eyePos _bT]) >= 0.4}) then { _sayac set ["g_yuzyuze", (_sayac getOrDefault ["g_yuzyuze", 0]) + 1]; continue };
                            private _dostYakin = (_bT nearEntities ["CAManBase", ((missionNamespace getVariable ["lambs_danger_bombaDostM", 8]) max 8) min 30]) findIf {alive _x && {(_taraf getFriend (side (group _x))) >= 0.6}} >= 0;
                            if (_dostYakin) then { _sayac set ["g_dost", (_sayac getOrDefault ["g_dost", 0]) + 1]; };
                            if (!_dostYakin && {(speed _u) < 6}) then {
                                _u setVariable [QGVAR(bombaT), time];
                                _g setVariable [QGVAR(bombaGT), time];
                                _gecmis pushBack time;
                                _u setVariable [QGVAR(bombaListe), _gecmis];
                                [_u, _bT, _mag] call _firlat;
                                _sayac set ["bomba", (_sayac get "bomba") + 1];
                                _butce = _butce - 1;
                                continue
                            };
                        };
                    };
                };

            } forEach _uyeler;
        } forEach allGroups;

        if (time > _sonOzet) then {
            _sonOzet = time + 60;
            private _ys = missionNamespace getVariable ["lambs_danger_patlayiciSayac", createHashMap];
            diag_log format ["[PATLAYICI-OZET] 60 sn: emir bomba %1 | UGL ek mermi verilen %2 | bomba firlatma sonucu (toplam): atildi %3 | atilmadi %4 | bomba neden atilmadi: mesafe %5 frag_yok %6 yedek %7 yakin %8 dost %9 deger_yok %10 yuz_yuze %11", _sayac get "bomba", _sayac get "ugl_ek", _ys getOrDefault ["FAT", 0], _ys getOrDefault ["yok", 0], _sayac getOrDefault ["g_mesafe", 0], _sayac getOrDefault ["g_frag_yok", 0], _sayac getOrDefault ["g_yedek", 0], _sayac getOrDefault ["g_yakin", 0], _sayac getOrDefault ["g_dost", 0], _sayac getOrDefault ["g_deger", 0], _sayac getOrDefault ["g_yuzyuze", 0]];
            { _sayac set [_x, 0]; } forEach ["bomba", "g_mesafe", "g_frag_yok", "g_yedek", "g_yakin", "g_dost", "g_deger", "g_yuzyuze"];
        };
    };
};
true
