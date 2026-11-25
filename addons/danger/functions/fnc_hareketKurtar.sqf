#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HAREKET KURTARMA MERDIVENI (v8.818; kullanici: 'MOVE kabul edilip yurunmemesinin nedeni hala yok, siper varisina ulasamama, az testte halledelim'). ORTAK cozum: siper varisi (fnc_acikSiper gozcusu) ve geri cekilme kosucusu
 *   (fnc_tacticsRetreat ezme / takili / bosta dallari) ayni merdiveni kullanir.
 * KANIT (RPT 7ba225b8 + a8638e70): 59 [RET-DOMOVE-TEST] kaydinin 48'inde (%81) komut KABUL / yok sayildi fark etmeksizin asker < 2 km/sa; 56'sinda saldiri hedefi (getAttackTarget) var (karsilastirma grubu 3 -> hedef hipotezi KANITLANMADI);
 *   FSM / TARGET / AUTOTARGET kapatmak (v8.807, v8.811) cozmedi. [SIPER-VARIS] ULASILAMADI 35 kayit: yolTara 30'unda 'yol acik', baski 0.00 (32 / 35), davranis 35 / 35 COMBAT, komut ATTACK 22 / MOVE 11, durus CROUCH 18 / STAND 10 / PRONE 7,
 *   siper noktasina medyan ~15 m kala (18 kaydi 5-15 m). Yani engel / arazi / baski DEGIL: asker emri aliyor ama harekete gecmiyor. KOK NEDEN HALA BILINMIYOR (T: asagidaki adimlar tek tek denenir, hangisinin ise yaradigi log'dan okunur).
 * MERDIVEN (AYNI birimde 20 sn icinde art arda cagrilarda adim artar; 20 sn sessizlikte sifirlanir; adimlar BIRIKIMLI: ust adim alttakileri de uygular):
 *   1) bu birimin saldiri / atanan hedefini unutur (forgetTarget; yalniz bu birim) + AI bayraklari acilir (PATH / MOVE / ANIM) + hiz kilidi kalkar + doStop (yalniz duruyorsa) + doMove;
 *   (v8.820: 2. adimda bakis gidilecek noktaya doWatch, 3. adimda SUPPRESSION + CHECKVISIBLE 8 sn kapali)
 *   2) + lider degilse formasyona don (doFollowGuvenli: komut kuyrugu sifirlanir; retreat / temas kesme / kacis grubunda atlanir) + duruş UP (zayif) + 4 sn CARELESS (yalniz dusman >= 150 m ve baski < 0.3; motorun 'dusman var, dur ve nisan al' davranisini baypas; sure sonunda GRUP davranisi eski haline doner; v8.822) + kosu patlamasi (TARGET + AUTOTARGET kapali) + doMove;
 *   3) + setDestination [hedef, 'LEADER DIRECT', true] (yol planlamasini atlayan dogrudan yuruyus) + hiz modu FULL;
 *   4) + calculatePath (asenkron 'PathCalculated') ile yol dugumleri hesaplanir, askerden >= 12 m ilerideki ilk dugume doMove (yalniz azami adim >= 4 ise; referans modun yol dugumu tekniginden ilhamla, kod kopyalanmadi).
 *   2.5 sn sonra sonuc olculur (hiz > 2 km/sa): [HAREKET-KURTAR] satiri (ilk 25, sonra 30 sn'de bir; oncesi / sonrasi hiz, durus, animasyon, komut, saldiri / atanan hedef) + adim basina sayac ve 60 sn [HAREKET-KURTAR-OZET].
 * Fonksiyon doMove'u KENDISI verir (kurtarma emirleri doMove'dan ONCE gelmek zorunda: doFollow / forgetTarget komutu sifirlar). Kapaliysa -1 doner; cagiran kendi doMove'una doner.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Hedef (AGL) <ARRAY>
 * 2: Kaynak <STRING> (varis / retreat-ezme / retreat-takili / retreat-idle)
 * 3: Azami adim (1-4) <NUMBER> (varsayilan 4)
 * 4: Baslangic adimi (1-4) <NUMBER> (varsayilan 1; ilk cagrida bu adimdan baslanir)
 *
 * Return Value: Uygulanan adim (1..4) ya da -1 (kapali / gecersiz) <NUMBER>
 * CBA: lambs_danger_hareketKurtar (acik / kapali), lambs_danger_hareketKurtarCare (CARELESS adimi acik / kapali)
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_hedef", [], [[]]], ["_kaynak", "?", [""]], ["_azami", 4, [0]], ["_baslangic", 1, [0]]];
if (isNull _u || {!alive _u} || {isPlayer _u} || {!local _u} || {!isNull objectParent _u} || {(count _hedef) < 2}) exitWith {-1};
if !(missionNamespace getVariable ["lambs_danger_hareketKurtar", true]) exitWith {-1};
// v8.818 (RPT a049faa1): ayni askerde ayni saniyede 3 cagri (birden fazla varis gozcusu) adimlari saniyede 1 artiriyordu -> 1.5 sn'den sik cagri mevcut adimi doner, eylem yapmaz
if ((time - (_u getVariable [QGVAR(hkT), -999])) < 1.5) exitWith { (_u getVariable [QGVAR(hkN), 1]) max 1 };
private _n = if ((time - (_u getVariable [QGVAR(hkT), -999])) > 20) then { 0 } else { _u getVariable [QGVAR(hkN), 0] };
_n = (((_n + 1) max ((_baslangic max 1) min 4)) min ((_azami max 1) min 4));   // v8.818: baslangic adimi (RPT a049faa1: retreat-idle adim 1 %37 / adim 3 %58 / adim 4 %69 -> bosta dali 3'ten baslar)
_u setVariable [QGVAR(hkN), _n];
_u setVariable [QGVAR(hkT), time];
private _h3 = [_hedef select 0, _hedef select 1, 0];

// durum (oncesi)
private _kOnce = currentCommand _u;
private _hiz0 = round (speed _u);
private _durus0 = stance _u;
private _anim0 = animationState _u;
private _hd = getAttackTarget _u;
private _at = assignedTarget _u;
private _care = false;

// 1) hedef birakma + hareket bayraklari + emir
{ if (!isNull _x) then { _u forgetTarget _x; }; } forEach [_hd, _at];
_u enableAI "PATH";
_u enableAI "MOVE";
_u enableAI "ANIM";
_u forceSpeed -1;

// 2) formasyon sifirlama + durus + CARELESS + kosu patlamasi
if (_n >= 2) then {
    [_u] call FUNC(doFollowGuvenli);   // korumali (retreat / temas kesme / kacis grubunda atlanir; o taktik emri zaten surekli yeniden verir)
    _u setUnitPosWeak "UP";
    [_u, 8, "kurtar"] call FUNC(kosuPatlamasi);
    // v8.820 (kullanici: 'vanilla'da eleman mermi yiyince / hedef bilince kipirdayamiyor'; RPT a049faa1: duran askerlerde cok sayida _turnl / _turnr donus animasyonu, getAttackTarget dolu, dusman 230-285 m, baski 0): bakis gidilecek noktaya cevrilir (hedefe donme dongusu kirilsin);
    //   8 sn sonra serbest birakilir (doWatch objNull; retreat zaten sicrama sonunda birakir)
    _u doWatch (AGLToASL [_hedef select 0, _hedef select 1, 1.5]);
    [{ params ["_uu"]; if (alive _uu && {!((group _uu) getVariable [QGVAR(isRetreating), false])} && {!(_uu getVariable [QGVAR(forceMove), false])}) then { _uu doWatch objNull; }; }, [_u], 8] call CBA_fnc_waitAndExecute;
    // v8.822 CARELESS GUVENLIGI (kullanici: 'elemanlar catismada careless kaliyor?'; RPT a049faa1: telemetride CARELESS 22 / 62 (dusman 200-400 m, temas yok), f4bf5df2: 5 / 64, bunlardan 2'si dusmana 122 m ve 39 m kala ASSAULT sirasinda):
    //   KOK NEDEN (T): setBehaviour tek askere verilse de grubu etkiliyor olabilir; her askerin cagrisi 8 sn'lik pencereyi uzatiyordu (zincirleme), onceki davranis askerin KENDI degiskeninde tutuldugundan baska askerin CARELESS'i 'onceki' sanilip AWARE'e donuluyordu.
    //   CARELESS ayrica algiyi dusurur (gizliAlgi isitme x0.5, hqIstihbarat CARELESS lideri alici saymaz). DUZELTME: (1) yalniz bilinen en yakin dusman >= 150 m VE baski < 0.3 iken; (2) 4 sn (eskiden 8); (3) onceki davranis GRUP duzeyinde saklanir, grup basina zincir yok
    //   (en cok 10 sn kesintisiz, sonra 20 sn bekleme); (4) sure sonunda GRUP davranisi eskisine doner. CBA hareketKurtarCare kapaliysa hic uygulanmaz.
    private _gc = group _u;
    private _enC = (leader _gc) findNearestEnemy (leader _gc);
    private _enUzak = isNull _enC || {((leader _gc) distance2D _enC) >= 150};
    if ((missionNamespace getVariable ["lambs_danger_hareketKurtarCare", true]) && {_enUzak} && {(getSuppression _u) < 0.3} && {time >= (_gc getVariable [QGVAR(hkGrpCareBekle), 0])} && {(_gc getVariable [QGVAR(contact), 0]) < (time - 20)}) then {   // v8.823: son 20 sn'de temas varsa CARELESS YOK (RPT 01a3fcd2: 5 kayit dusman 164-353 m ama temas 9-29 sn)
        private _tok = time + (random 0.001);
        if ((_gc getVariable [QGVAR(hkGrpCareTok), 0]) isEqualTo 0) then {
            _gc setVariable [QGVAR(hkGrpOncekiBeh), behaviour _u];
            _gc setVariable [QGVAR(hkGrpCareBas), time];
        };
        if ((time - (_gc getVariable [QGVAR(hkGrpCareBas), time])) > 10) then {
            _gc setVariable [QGVAR(hkGrpCareBekle), time + 20];   // kesintisiz CARELESS tavani: 20 sn bekle (zincirleme yok)
        } else {
            _gc setVariable [QGVAR(hkGrpCareTok), _tok];
            _u setBehaviour "CARELESS";
            _care = true;
            [{
                params ["_g", "_tk"];
                if (!isNull _g && {(_g getVariable [QGVAR(hkGrpCareTok), 0]) isEqualTo _tk}) then {
                    _g setVariable [QGVAR(hkGrpCareTok), 0];
                    _g setBehaviour (_g getVariable [QGVAR(hkGrpOncekiBeh), "AWARE"]);
                    { if (alive _x && {(behaviour _x) isEqualTo "CARELESS"}) then { _x setBehaviour (_g getVariable [QGVAR(hkGrpOncekiBeh), "AWARE"]); }; } forEach (units _g);
                };
            }, [_gc, _tok], 4] call CBA_fnc_waitAndExecute;
        };
    };
};

// emir (doStop yalniz duruyorsa: hareket halindeki askerin yol hesabi / ayak ritmi kesilmesin)
if ((speed _u) < 3) then { doStop _u; };
_u setVariable [QGVAR(retEmirT), time];
_u setVariable [QGVAR(siperDoMoveT), time];
_u doMove _hedef;

// 3) dogrudan yuruyus hedefi + tam hiz
if (_n >= 3) then {
    _u setDestination [_h3, "LEADER DIRECT", true];
    _u setSpeedMode "FULL";
    // v8.820: baski / gorunurluk kontrolu kisa sure kapali (motorun 'bastirildim / hedef gorunur: dur' alt durumu); 8 sn sonra geri
    { _u disableAI _x; } forEach ["SUPPRESSION", "CHECKVISIBLE"];
    [{ params ["_uu"]; if (alive _uu) then { { _uu enableAI _x; } forEach ["SUPPRESSION", "CHECKVISIBLE"]; }; }, [_u], 8] call CBA_fnc_waitAndExecute;
};

// 4) yol dugumu
if (_n >= 4) then {
    private _ag = calculatePath ["man", "AWARE", getPosATL _u, _h3];
    _ag setVariable ["lambs_danger_hkU", _u];
    _ag setVariable ["lambs_danger_hkH", _h3];
    _ag addEventHandler ["PathCalculated", {
        params ["_agent", "_yol"];
        private _uu = _agent getVariable ["lambs_danger_hkU", objNull];
        private _hh = _agent getVariable ["lambs_danger_hkH", []];
        if (!isNull _uu && {alive _uu}) then {
            if ((count _yol) > 1) then {
                _uu doMove (_yol select (((_yol findIf { ((getPosATL _uu) distance2D _x) >= 12 }) max 1) min ((count _yol) - 1)));
            } else {
                if (_hh isNotEqualTo []) then { _uu setDestination [_hh, "LEADER DIRECT", true]; };
            };
        };
        deleteVehicle _agent;
    }];
};

// sayac + sonuc olcumu
private _say = missionNamespace getVariable ["lambs_danger_hkSay", createHashMap];
missionNamespace setVariable ["lambs_danger_hkSay", _say];
private _kk = format ["%1_adim%2", _kaynak, _n];
_say set [_kk, (_say getOrDefault [_kk, 0]) + 1];
if (isNil "lambs_danger_hkOzetT") then { lambs_danger_hkOzetT = time + 60; };
if (time > lambs_danger_hkOzetT) then {
    lambs_danger_hkOzetT = time + 60;
    diag_log format ["[HAREKET-KURTAR-OZET] 60 sn: %1", (_say toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }];
    _say = createHashMap;
    missionNamespace setVariable ["lambs_danger_hkSay", _say];
};
[_u, _n, _kaynak, _hiz0, _durus0, _anim0, _kOnce, !isNull _hd, !isNull _at, _hedef, _care] spawn {
    params ["_a", "_ad", "_ky", "_h0", "_d0", "_an0", "_ko", "_hv", "_av", "_hf", "_cr"];
    sleep 2.5;
    if (!alive _a) exitWith {};
    private _ok = (speed _a) > 2;
    private _s = missionNamespace getVariable ["lambs_danger_hkSay", createHashMap];
    private _kk = format ["%1_adim%2_ok", _ky, _ad];
    if (_ok) then { _s set [_kk, (_s getOrDefault [_kk, 0]) + 1]; };
    if (["hareketKurtar", 25, 30] call FUNC(logIzin)) then {
        diag_log format ["[HAREKET-KURTAR] %1 | %2 | %3 | adim %4 | hiz %5 -> %6 km/sa | durus %7 -> %8 | komut %9 -> %10 | anim %11 -> %12 | saldiri hedefi %13 atanan hedef %14 | hedefe %15 m | davranis %16 | careless uygulandi %18 | sonuc %17",
            _ky, groupId (group _a), name _a, _ad, _h0, round (speed _a), _d0, stance _a, _ko, currentCommand _a, _an0, animationState _a, _hv, _av, round ((getPosATL _a) distance2D _hf), behaviour _a, ["YURUMEDI", "YURUDU"] select _ok, _cr];
    };
};
_n
