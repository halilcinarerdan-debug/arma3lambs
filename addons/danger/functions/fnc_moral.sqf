#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MORAL + TESLIMIYET v1 (VBS4 "surrender / morale" fikri) — grup basina moral endeksi (0..1) ve umutsuz durumda teslim.
 *
 * MORAL ENDEKSI (5 sn'de bir; baslangic 1.0; hedefe dogru %20 / tick yaklasir = yumusak):
 *   hedef = 1 - 0.50 x kayip orani (baslangictan) - 0.25 x ort. baski - 0.15 x (cephane dusuk askerler orani) - 0.15 (lider olu) - 0.10 (en yakin dost > 100 m)
 *           + 0.10 (temas > 60 sn yok)    sinir 0..1
 *   (kayip orani: lambs_danger_cmdInitialCount ya da grubun ilk gorulen sayisi)
 *
 * TESLIM (hepsi saglanirsa): doktrin teslim = true; moral < teslimEsik (0.15); kalan <= 2 asker; >= %70 kayip; ort. baski >= 0.6;
 *   bilinen dusman <= 50 m; grup retreat / evade / temas kes / pusu degil; ayni grup daha once teslim olmadi.
 *   Etki: askerler LAMBS birim bayragi ile kapatilir, setCaptive true, silah birakilir, "Surrender" aksiyonu; olay "Teslim". Dusman menzilden
 *   cikinca (> 150 m, 60 sn) sadece moral toparlanir (teslim geri alinmaz).
 * DUZENSIZ (Taliban-tipi) profili teslim = false.
 *
 * v8.259 TESLIM ESIKLERI + CBA (kullanici: 'esigi gozden gecir, CBA'dan kapatilip acilabilsin, teslim olma faction bazli'; RPT f8ad6949: 64 olum, teslim 0 - eski kosullar (kalan <= 2, kayip >= %70, baski >= 0.6, dusman <= 50 m, moral < 0.15) neredeyse hic saglanmiyordu):
 *   yeni varsayilanlar (CBA 'LAMBS Danger > ELITE moral / teslim', sunucu ayari): moral < 0.30, kayip >= %60, kalan <= 4, ort. baski >= 0.40, bilinen dusman <= 120 m (hepsi TASARIM, slider).
 *   ACMA / KAPAMA: ana anahtar lambs_danger_teslimV1; taraf basina lambs_danger_teslimWest / East / Ind (CBA); FRAKSIYON bazli: 'teslimFraksiyonKapali' (virgullu liste, parca eslesme, kucuk / buyuk harf onemsiz; asla teslim olmaz) ve
 *   'teslimFraksiyonAcik' (doktrin DUZENSIZ olsa bile teslim olur); oncelik: Kapali liste > Acik liste > taraf onay kutusu + doktrin. Fraksiyon = liderin config fraksiyon adi (faction _lider). Teslim adayi olup olmayan gruplarda [TESLIM-ADAY] neden logu (ilk 40, grup basina 60 sn).
 * Kapatma: lambs_danger_moralV1 = false  (teslim yalniz: lambs_danger_teslimV1 = false).
 * Log: [MORAL] (grup basina moral degisince, en fazla 30 sn'de bir), [TESLIM], [MORAL-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_moralStarted") exitWith {false};
lambs_danger_moralStarted = true;

diag_log "[MORAL] moral + teslimiyet izleyicisi baslatildi";

[] spawn {
    private _gonder = missionNamespace getVariable ["lambs_danger_fnc_olayGonder", {false}];
    private _sonOzet = time;
    private _teslimSay = 0;
    while {true} do {
        sleep 5;
        if (!(missionNamespace getVariable ["lambs_danger_moralV1", true])) then { continue };
        private _gSay = 0;
        private _dusukSay = 0;
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!((lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"])} && {!(_x getVariable ["ACE_isUnconscious", false])} && {!(_x getVariable [QGVAR(teslim), false]) || {_g getVariable [QGVAR(teslimOldu), false]}}};   // v8.308: bireysel teslim olan etkin guc sayilmaz   // v8.91: bayilanlar etkin guc degil (kayip orani / moral)
            if (_us isEqualTo []) then { continue };
            if (_g getVariable [QGVAR(teslimOldu), false]) then {
                // v8.277 ESIR BAKIMI (kullanici RPT 21-10: 'captiveler hareket etmesin; bazi captiveler geri silah aldi'; [ROE-IHLAL] captive:true silahli:true = AT askeri roketatarini tutuyordu, DropWeapon yalniz ana silahi birakir):
                //   teslim olmus grup 5 sn'de bir kontrol edilir: kalan HER silah (ana / roketatar / tabanca) alinir, AI parcalari kapali tutulur (yurumez, silah toplamaz), durus sabit.
                if ((time - (_g getVariable [QGVAR(teslimBakimT), 0])) > 5) then {
                    _g setVariable [QGVAR(teslimBakimT), time];
                    {
                        private _eu = _x;
                        // v8.294 ACE CAPTIVES: oyuncu esiri kelepcelediyse (ace_captives_isHandcuffed) ya da serbest biraktiysa bakim BIRAKILIR (ACE yonetir; setCaptive / doStop / AI kapatma ACE ile catismaz)
                        if (_eu getVariable ["ace_captives_isHandcuffed", false]) then { _eu setVariable [QGVAR(aceEsir), true]; };
                        if (alive _eu && {isNull objectParent _eu} && {!(_eu getVariable [QGVAR(aceEsir), false])} && {(time - (_eu getVariable [QGVAR(teslimAnimT), -999])) > 6}) then {   // v8.358: teslim animasyonu suruyorsa (fnc_teslimOl) bakim bekler
                            if ((primaryWeapon _eu) isNotEqualTo "" || {(secondaryWeapon _eu) isNotEqualTo ""} || {(handgunWeapon _eu) isNotEqualTo ""}) then { removeAllWeapons _eu; };
                            { _eu disableAI _x; } forEach ["MOVE", "PATH", "TARGET", "AUTOTARGET", "FSM", "WEAPONAIM", "AUTOCOMBAT", "COVER", "SUPPRESSION"];
                            if (!captive _eu) then { _eu setCaptive true; };
                            doStop _eu;
                        };
                    } forEach (units _g);
                };
                continue
            };
            _gSay = _gSay + 1;

            private _ilk = _g getVariable [QGVAR(moralIlk), 0];
            if (_ilk < (count _us)) then { _ilk = count _us; _g setVariable [QGVAR(moralIlk), _ilk]; };
            private _init = _g getVariable [QGVAR(cmdInitialCount), _ilk];
            if (!(_init isEqualType 0) || {_init < (count _us)}) then { _init = _ilk max (count _us); };
            private _kayip = (1 - ((count _us) / (_init max 1))) max 0;

            private _l = leader _g;
            private _bsk = 0;
            private _dusukC = 0;
            { _bsk = _bsk + ((getSuppression _x) min 1); if ((count (magazines _x)) <= 1 && {(_x ammo (primaryWeapon _x)) < 10}) then { _dusukC = _dusukC + 1; }; } forEach _us;
            _bsk = _bsk / (count _us);
            private _komsu = 9999;
            if ((count _us) > 1 && {!isNull _l}) then {
                { if (_x isNotEqualTo _l) then { _komsu = _komsu min (_l distance2D _x); }; } forEach _us;
            } else { _komsu = 0; };
            private _temasYok = (_g getVariable [QGVAR(contact), 0]) < (time - 60);

            // v8.275 COKME TERIMI (RPT 04dfc9d7: hic [TESLIM-ADAY] yok, teslim hic tetiklenmedi): eski formulde kayip 0.6 + baski 0.4 ile moral en iyi ihtimalle 0.60'ta kaliyordu,
            //   0.30 esigi lider olu + cephane yok + dost uzak olmadan ULASILAMAZDI. Simdi grup yarisini kaybedince ek -0.25 (yuzde 40'ta -0.10): kayip 0.5 + baski 0.3 -> hedef 0.425 (< 0.45 yeni esik).
            private _cokme = if (_kayip >= 0.5) then {0.25} else { [0, 0.10] select (_kayip >= 0.4) };
            private _hedef = 1 - (0.50 * _kayip) - _cokme - (0.25 * _bsk) - (0.15 * (_dusukC / (count _us))) - ([0, 0.15] select (isNull _l || {!alive _l})) - ([0, 0.10] select (_komsu > 100)) + ([0, 0.10] select _temasYok);
            _hedef = (_hedef max 0) min 1;
            private _m0 = _g getVariable [QGVAR(moral), 1];
            private _m = _m0 + ((_hedef - _m0) * 0.2);
            _g setVariable [QGVAR(moral), _m];
            if (_m < 0.5) then { _dusukSay = _dusukSay + 1; };

            if ((abs (_m - (_g getVariable [QGVAR(moralLog), 1]))) >= 0.15 && {(time - (_g getVariable [QGVAR(moralLogT), -99])) > 30}) then {
                _g setVariable [QGVAR(moralLog), _m];
                _g setVariable [QGVAR(moralLogT), time];
                diag_log format ["[MORAL] %1 | moral:%2 (hedef %3, cokme -%4) | kalan:%5/%6 (kayip yuzde %7) | baski:%8 | cephane dusuk:%9 | komsu:%10 m | temas yok:%11", groupId _g, _m toFixed 2, _hedef toFixed 2, _cokme toFixed 2, count _us, _init, round (_kayip * 100), _bsk toFixed 2, _dusukC, if (_komsu > 9000) then {"-"} else {round _komsu}, _temasYok];
            };

            // --- TESLIM ---
            // izin: ana anahtar + fraksiyon listeleri + taraf onay kutusu + doktrin
            private _frk = toLower (if (isNull _l) then {""} else {faction _l});
            private _listeEslesme = {
                params ["_liste"];
                private _ok = false;
                { private _t = toLower ((_x splitString " ") joinString ""); if (_t isNotEqualTo "" && {(_frk find _t) >= 0}) exitWith { _ok = true; }; } forEach (_liste splitString ",;");
                _ok
            };
            private _izinVar = if !(missionNamespace getVariable ["lambs_danger_teslimV1", true]) then {false} else {
                if ([missionNamespace getVariable ["lambs_danger_teslimFraksiyonKapali", ""]] call _listeEslesme) then {false} else {
                    if ([missionNamespace getVariable ["lambs_danger_teslimFraksiyonAcik", ""]] call _listeEslesme) then {true} else {
                        private _tK = switch (side _g) do { case west: {"lambs_danger_teslimWest"}; case east: {"lambs_danger_teslimEast"}; default {"lambs_danger_teslimInd"} };
                        // v8.279 (kullanici: 'opfor teslim olmadi'; RPT 21-10 22:15-22:36: fraksiyon lop_ists_opf -> doktrin DUZENSIZ 'teslim yok' -> [TESLIM-ADAY] izin=false, moral 0.28-0.37 / kayip %75 / umutsuz=true olsa da hic teslim olmadi):
                        //   duzensiz profiller de teslim olabilir (CBA 'Teslim: duzensiz profiller', varsayilan ACIK) - yalniz kayip >= %60 ve en az 3 ardisik tur (15 sn) kosulu ile. Kapatma: lambs_danger_teslimDuzensiz = false.
                        (missionNamespace getVariable [_tK, true]) && {([_g, "teslim", true] call FUNC(dk)) || {missionNamespace getVariable ["lambs_danger_teslimDuzensiz", true]}}
                    };
                };
            };
            // v8.275: varsayilanlar gevsetildi (0.30 / 60 / 4 / 0.40 / 120 -> 0.45 / 50 / 5 / 0.30 / 150); CBA ayarlariyla ayni
            // v8.276 (RPT 21-10: sunucuda KAYITLI CBA degerleri eski varsayilanlardi - boot satiri 0.45 diyordu ama [TESLIM-ADAY] '(<0.3) ... (>=0.4) ... (<=120)' gosterdi, esige ulasilamadi):
            //   bes deger de eski varsayilanla BIREBIR ayniysa (kullanici elle degistirmemis, CBA eskisini saklamis) yeni varsayilanlar kullanilir; mesafe 150 -> 200 m. Elle degistirilen deger korunur.
            private _esikM = missionNamespace getVariable ["lambs_danger_teslimMoral", 0.45];
            private _esikKy = missionNamespace getVariable ["lambs_danger_teslimKayip", 50];
            private _esikN = missionNamespace getVariable ["lambs_danger_teslimKalan", 5];
            private _esikB = missionNamespace getVariable ["lambs_danger_teslimBaski", 0.30];
            private _esikD = missionNamespace getVariable ["lambs_danger_teslimMesafe", 200];
            if ((abs (_esikM - 0.30)) < 0.005 && {(abs (_esikKy - 60)) < 0.5} && {(abs (_esikN - 4)) < 0.5} && {(abs (_esikB - 0.40)) < 0.005} && {(abs (_esikD - 120)) < 0.5}) then {
                _esikM = 0.45; _esikKy = 50; _esikN = 5; _esikB = 0.30; _esikD = 200;
                if !(missionNamespace getVariable ["lambs_danger_teslimEskiLog", false]) then {
                    missionNamespace setVariable ["lambs_danger_teslimEskiLog", true];
                    diag_log "[TESLIM] kayitli CBA teslim esikleri eski varsayilanlarla ayni (0.30 / 60 / 4 / 0.40 / 120) -> v8.276 varsayilanlari kullaniliyor (0.45 / 50 / 5 / 0.30 / 200); elle degistirirsen korunur";
                };
            };
            private _esikK = _esikKy / 100;
            private _engel = (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isAmbushing), false]};
            // v8.275: aday logu artik moral < 0.60 iken (eski: esigin altinda) -> esige neden ulasilmadigi RPT'den okunur
            if (_m < (_esikM max 0.6) && {_kayip >= 0.3} && {(time - (_g getVariable [QGVAR(teslimAdayLogT), -99])) > 60} && {(missionNamespace getVariable ["lambs_danger_teslimAdayLogN", 0]) < 40}) then {
                _g setVariable [QGVAR(teslimAdayLogT), time];
                missionNamespace setVariable ["lambs_danger_teslimAdayLogN", (missionNamespace getVariable ["lambs_danger_teslimAdayLogN", 0]) + 1];
                private _enA = if (isNull _l) then {objNull} else {_l findNearestEnemy _l};
                diag_log format ["[TESLIM-ADAY] %1 | fraksiyon=%2 | izin=%3 | moral=%4 (<%5) | kayip=%6 (>=%7) | kalan=%8 (<=%9) | baski=%10 (>=%11) | dusman=%12 m (<=%13) | engel(retreat/evade/pusu)=%14 | umutsuz(baski/lider olu/dagilmis/kayip75/cephane)=%15",
                    groupId _g, _frk, _izinVar, _m toFixed 2, _esikM, round (_kayip * 100), round (_esikK * 100), count _us, _esikN, _bsk toFixed 2, _esikB, if (isNull _enA) then {"-"} else {round (_l distance2D _enA)}, _esikD, _engel, ((_bsk >= _esikB) || {isNull _l || {!alive _l}} || {_komsu > 100} || {_kayip >= 0.75} || {_dusukC >= (ceil ((count _us) / 2))})];
            };
            // v8.276 UMUTSUZLUK: baski artik ZORUNLU degil (RPT 21-10: 1-2 askeri kalan gruplar baski 0.00 ile 8 dk sonuna kadar savasti; moral hedefi baski olmadan ~0.33'un altina inmez).
            //   Su durumlardan BIRI yeterli: ort. baski >= esik | lider olu | grup dagilmis (lider en yakin dostdan > 100 m) | %75+ kayip | askerlerin yarisinin cephanesi bitik.
            private _umutsuz = (_bsk >= _esikB) || {isNull _l || {!alive _l}} || {_komsu > 100} || {_kayip >= 0.75} || {_dusukC >= (ceil ((count _us) / 2))};
            private _duzensizP = !([_g, "teslim", true] call FUNC(dk));
            private _teslimKosul = _izinVar && {_m < _esikM} && {(count _us) <= _esikN} && {_kayip >= (_esikK max ([0, 0.6] select _duzensizP))} && {_umutsuz} && {!_engel};
            private _teslimSay2 = if (_teslimKosul) then { (_g getVariable [QGVAR(teslimArdisik), 0]) + 1 } else { 0 };
            _g setVariable [QGVAR(teslimArdisik), _teslimSay2];
            // 2 ardisik tur (10 sn): tek tikluk kosul teslim ettirmez
            if (_teslimSay2 >= ([2, 3] select _duzensizP)) then {
                private _en = _l findNearestEnemy _l;
                // v8.307 (kullanici: 'askerler teslim olmadi'; RPT 23-10 05:29: [TESLIM-ADAY] umutsuz=true / kayip 71 / moral 0.41 ama 'dusman=- m (<=200)' -> yakinda bilinen piyade yoktu, dron 40 dk uzerlerindeydi):
                //   100 m'den yakin DUSMAN yoksa 450 m icindeki dusman IHA (dron uzerlerinde) teslim muhatabi sayilir. Kapatma: CBA lambs_danger_teslimDron = false.
                private _teslimEsik = _esikD;
                if (missionNamespace getVariable ["lambs_danger_teslimDron", true] && {isNull _en || {(_l distance2D _en) > _esikD}}) then {
                    private _drn = (_l nearEntities ["Air", 450]) select {unitIsUAV _x && {alive _x} && {((side _g) getFriend (side (group (effectiveCommander _x)))) < 0.6}};
                    if (_drn isNotEqualTo []) then { _en = _drn select 0; _teslimEsik = 450; };
                };
                if (!isNull _en && {alive _en} && {(_l distance2D _en) <= _teslimEsik}) then {
                    _g setVariable [QGVAR(teslimOldu), true];
                    _teslimSay = _teslimSay + 1;
                    // v8.358: silah birakma -> silahsiz durus -> ACE / vanilla teslim animasyonu SIRAYLA (fnc_teslimOl; eskiden hepsi ayni karede, animasyon takiliyordu); v8.294 ACE CAPTIVES uyumu orada
                    { [_x] call FUNC(teslimOl); } forEach _us;
                    _g setBehaviour "SAFE";
                    _g setCombatMode "BLUE";
                    diag_log format ["[TESLIM] %1 | %2 asker teslim oldu | moral:%3 kayip yuzde %4 baski:%5 | dusman:%6 m | taraf:%7", groupId _g, count _us, _m toFixed 2, round (_kayip * 100), _bsk toFixed 2, round (_l distance2D _en), side _g];
                    [_g, "Teslim", count _us] call _gonder;
                };
            };
        } forEach allGroups;

        if ((time - _sonOzet) >= 60) then {
            _sonOzet = time;
            diag_log format ["[MORAL-OZET] yerel AI grup:%1 | moral < 0.5: %2 | toplam teslim (oturum): %3", _gSay, _dusukSay, _teslimSay];
        };
    };
};

true
