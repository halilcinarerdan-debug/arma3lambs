#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IED FARKINDALIGI (v8.47, v8.50: ACE EOD entegrasyonu)
 *
 * Doktrin (MCWP 3-11.1 "IED or possible IED" drill): durma, bolgeyi tarama, supheli noktayi gozetleme, dagilma; molalarda IED taramasi.
 * Sayisal degerler yoktur (TASARIM):
 *   - TESPIT: lider grubun askerlerinden birinin <= 35 m'sinde (mayin dedektoru / explosiveSpecialist <= 50 m) ve gorus hatti acik supheli nesne
 *     (allMines + sinif adinda "ied" gecen nesneler, mod IED'leri dahil) -> taraf icin revealMine (AI yol planlamasi bunu otomatik atlar).
 *   - TEPKI: 50 m yaricapta askerler IED'den uzaklasir (55 m'ye), yatarak degil ortu / dagilma; grup 60 sn LIMITED hizda, AWARE.
 *   - IMHA: grupta explosiveSpecialist varsa ve temas YOKSA, vanilla mayinda (MineBase) 3 m'ye gidip "Deactivate" dener (45 sn zaman asimi).
 *     Uzaktan tetikli / mod IED'lerinde imha denenmez, yalnizca kacinilir.
 *   - Cooldown: ayni IED icin grup basina 5 dk. ATLANIR: oyuncu lider, arac, retreat / evade / breakContact.
 *   - v8.50: EOD = explosiveSpecialist ozelligi VEYA ACE_isEOD degiskeni (ACE: ace_common_fnc_isEOD ile ayni kosul). EOD / mayin dedektorlu asker
 *     erken tespit eder (90 m, gorus hatti kosulsuz 50 m'ye kadar); diger askerler 60 m (25 m icinde gorus hatti aranmaz).
 *     EOD varsa, imha kiti (ACE_DefusalKit veya ToolKit) tasiyorsa ve temas yoksa HER tur IED'e (vanilla mayin + mod / ACE IED) gidip diz coker, ~8 sn calisip etkisizlestirir (ACE yuklu ise ACE EOD sureci simule edilir).
 *     Digerleri 55 m'ye acilir; bounding / taktik kilidi olan askerler dahil (IED tehlikesi kilidi gecer), 60 sn boyunca 4 sn'de bir geri itilir.
 *     EOD yoksa ya da EOD'da imha kiti yoksa grup yalnizca kacinir (imha denenmez; EOD yine erken tespit eder).
 * Kapatma: lambs_danger_iedOff = true.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_iedFarkStarted") exitWith {false};
lambs_danger_iedFarkStarted = true;

diag_log "[IED-FARK] IED farkindaligi watchdog baslatildi";

private _calis = {
    missionNamespace setVariable ["lambs_danger_iedAdim", "basladi"];
    private _logN = 0;
    private _gozN = 0;
    private _atlaN = 0;
    private _tur = 0;
    private _nabizT = time + 60;
    private _turMs = 0;
    while {true} do {
        sleep 4;
        private _t0 = diag_tickTime;
        _tur = _tur + 1;
        if (missionNamespace getVariable ["lambs_danger_iedOff", false]) then { continue };
        // NABIZ: dongu yasiyor mu, haritada kac IED / mayin var, son turun suresi (60 sn'de bir)
        if (time > _nabizT) then {
            _nabizT = time + 60;
            diag_log format ["[IED-FARK-NABIZ] tur:%1 | allMines:%2 | yerel AI grup:%3 | son tur:%4 ms | adim:%5", _tur, count allMines, count (allGroups select {local _x && {!isNull leader _x} && {!isPlayer leader _x}}), round _turMs, missionNamespace getVariable ["lambs_danger_iedAdim", "?"]];
        };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_iedAdim", format ["tur %1: grup %2", _tur, groupId _g]];
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
            ) then {
                // neden atlandi: yakinda mayin / IED varsa 15 sn'de bir yaz
                if ((time - (_g getVariable [QGVAR(iedAtlaT), -99])) > 15 && {(allMines findIf {(_x distance2D _l) < 130}) >= 0} && {_atlaN < 80}) then {
                    _g setVariable [QGVAR(iedAtlaT), time];
                    _atlaN = _atlaN + 1;
                    diag_log format ["[IED-FARK-ATLA] %1 | grup atlandi (yakinda IED / mayin var), neden: retreat:%2 evade:%3 breakContact:%4", groupId _g, _g getVariable [QGVAR(isRetreating), false], _g getVariable [QGVAR(isEvading), false], _g getVariable [QGVAR(isBreakingContact), false]];
                };
                continue;
            };
            private _lp = getPosATL _l;
            // v8.50c: tarama merkezi yalniz lider degil, EOD / dedektorlu askerler de (EOD liderden uzaklasinca ikinci IED 4 m'de fark ediliyordu)
            private _merkezler = [_lp] + ((units _g) select {alive _x && {isNull objectParent _x} && {(_x getUnitTrait "explosiveSpecialist") || {_x getVariable ["ACE_isEOD", false]} || {"MineDetector" in (items _x)}}} apply {getPosATL _x});
            private _adaylar = [];
            {
                private _c = _x;
                {
                    _adaylar pushBackUnique _x;
                } forEach ((allMines select {(_x distance2D _c) < 130}) + ((_c nearObjects 130) select {(toLower (typeOf _x)) find "ied" >= 0 && {!(_x in allMines)}}));
            } forEach _merkezler;
            if (_adaylar isEqualTo []) then { continue };
            private _bilinen = _g getVariable [QGVAR(iedBilinen), []];
            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            {
                private _m = _x;
                private _mp = getPosATL _m;
                if ((_bilinen findIf {(_x select 0) distance2D _mp < 3 && {(time - (_x select 1)) < 300}}) >= 0) then { continue };
                private _tespit = objNull;
                {
                    private _u = _x;
                    private _eodU = (_u getUnitTrait "explosiveSpecialist") || {_u getVariable ["ACE_isEOD", false]};
                    private _menzil = [60, 90] select (_eodU || {"MineDetector" in (items _u)});
                    private _d = _u distance2D _m;
                    if (_d <= _menzil) then {
                        private _e = eyePos _u;
                        private _t = (getPosASL _m) vectorAdd [0, 0, 0.2];
                        // yakinda (25 m) herkes gorur; EOD 50 m'ye kadar gorus hatti aramaz; digerleri icin acik gorus sart
                        if (_d <= ([25, 50] select _eodU) || {!(lineIntersects [_e, _t, _u, _m]) && {!(terrainIntersectASL [_e, _t])}}) exitWith { _tespit = _u; };
                    };
                } forEach _us;
                if (isNull _tespit) then {
                    // tespit YOK: nedenini yaz (15 sn'de bir, grup basina)
                    if ((time - (_g getVariable [QGVAR(iedGozT), -99])) > 15 && {_gozN < 150}) then {
                        private _bd = 1e9;
                        private _bu = objNull;
                        { private _dd = _x distance2D _m; if (_dd < _bd) then { _bd = _dd; _bu = _x; }; } forEach _us;
                        if (!isNull _bu && {_bd < 130}) then {
                            _g setVariable [QGVAR(iedGozT), time];
                            _gozN = _gozN + 1;
                            private _ebu = (_bu getUnitTrait "explosiveSpecialist") || {_bu getVariable ["ACE_isEOD", false]};
                            private _mz = [60, 90] select (_ebu || {"MineDetector" in (items _bu)});
                            private _neden = if (_bd > _mz) then { format ["menzil disi (%1 m > %2 m)", round _bd, _mz] } else { "gorus hatti kapali (arazi / nesne)" };
                            diag_log format ["[IED-FARK-GOZLEM] %1 | %2 | en yakin asker %3 (%4 m, EOD:%5) | tespit YOK: %6", groupId _g, typeOf _m, name _bu, round _bd, _ebu, _neden];
                        };
                    };
                    continue;
                };

                _bilinen pushBack [_mp, time];
                _g setVariable [QGVAR(iedBilinen), _bilinen];
                (side _g) revealMine _m;

                // EOD secimi: explosiveSpecialist ozelligi veya ACE_isEOD (IED'e en yakin)
                private _eodlar = _us select {(_x getUnitTrait "explosiveSpecialist") || {_x getVariable ["ACE_isEOD", false]}};
                _eodlar = _eodlar apply {[_x distance2D _m, _x]};
                _eodlar sort true;
                private _eodU = if (_eodlar isEqualTo []) then {objNull} else {(_eodlar select 0) select 1};
                // imha icin imha kiti sart: ACE_DefusalKit (ACE) veya ToolKit (vanilla); kitli EOD'lar arasindan en yakini
                // v8.57: yalniz EOD teknisyeni (explosiveSpecialist / ACE_isEOD) imha edebilir; kit: ACE_DefusalKit veya ToolKit (lambs_danger_iedKitSiki = true -> ACE yuklu iken yalniz ACE_DefusalKit)
                private _kitSiki = (missionNamespace getVariable ["lambs_danger_iedKitSiki", false]) && {isClass (configFile >> "CfgPatches" >> "ace_explosives")};
                private _kitli = _eodlar select {private _it = items (_x select 1); ("ACE_DefusalKit" in _it) || {!_kitSiki && {"ToolKit" in _it}}};
                private _imhaU = if (_kitli isEqualTo []) then {objNull} else {(_kitli select 0) select 1};
                private _temas = (_g getVariable [QGVAR(contact), 0]) > time;
                private _sinif = toLower (typeOf _m);
                // tehlike yaricapi: oyunun kendi verisinden (CfgAmmo indirectHitRange; mod IED'leri dahil) x 6 guvenlik / parca payi (v8.52: x3 / 20 m cok kucuk kaldi), 30-80 m arasi;
                // veri yoksa sinif adina gore yedek (buyuk 55 m, digerleri 30 m)
                private _irange = getNumber (configFile >> "CfgAmmo" >> (typeOf _m) >> "indirectHitRange");
                private _yaricap = if (_irange > 0) then { ((_irange * 6) max 30) min 80 } else { [30, 55] select ((_sinif find "big") >= 0) };
                // ikincil cihaz suphesi: hedefin 40 m cevresinde baska IED adayi var mi (IED'ler kumelenir); yakinlik tetikli (range / pressure) tiplere EOD yurumez
                // v8.50e: yalniz hedefe / EOD yaklasma hattina YAKIN (12-20 m / 8-14 m) cihaz engeller; 40 m'de kumeleme artik imhayi engellemez (sirayla imha)
                private _digerleri = _adaylar select {_x isNotEqualTo _m};
                private _yakinTipi = { private _tt = toLower (typeOf _this); ((_tt find "range") >= 0) || {(_tt find "pressure") >= 0} || {(_tt find "tripwire") >= 0} };
                // v8.52: yalniz YAKINLIK TETIKLI (range / pressure / tripwire) komsu engeller; uzaktan tetikli komsular siraya girer
                private _ikincil = (_digerleri findIf {(_x call _yakinTipi) && {(_x distance2D _m) < 20}}) >= 0;
                if (!_ikincil && {!isNull _imhaU}) then {
                    private _bas = getPosATL _imhaU;
                    private _son = _mp getPos [5, _mp getDir _bas];
                    private _hat = _bas distance2D _son;
                    private _adim = ceil (_hat / 6);
                    for "_i" from 0 to _adim do {
                        private _nk = _bas vectorAdd ((_son vectorDiff _bas) vectorMultiply (_i / (_adim max 1)));
                        if ((_digerleri findIf {(_x call _yakinTipi) && {(_x distance2D _nk) < 14}}) >= 0) exitWith { _ikincil = true; };
                    };
                };
                private _yakinlik = ((_sinif find "range") >= 0) || {(_sinif find "pressure") >= 0} || {(_sinif find "tripwire") >= 0};
                // v8.55: yakinlik tetikli (range / pressure / tripwire) IED veya yakininda yakinlik tetikli komsu varsa EOD'nin cihaza YURUMESI olmaz; bunun yerine
                // KONTROLLU PATLATMA (BIP): kitli EOD guvenli uzakliktan (tehlike yaricapi + 5 m) imha eder, cevre emniyeti disarida, patlama cevreyi etkilemez.
                private _zorPat = ((_g getVariable [QGVAR(iedPatList), []]) findIf {_x distance2D _mp < 4}) >= 0;
                private _mod = ["DEFUSE", "PATLAT"] select (_ikincil || _yakinlik || _zorPat);
                private _imhaMi = !isNull _imhaU && {!_temas} && {(_imhaU distance2D _m) < 110} && {(_g getVariable [QGVAR(iedIs), []]) params [["_jm", objNull], ["_ju", objNull]]; isNull _jm || {!alive _ju}};
                if (_imhaMi) then { _eodU = _imhaU; };
                diag_log format ["[IED-FARK-KARAR] %1 | %2 | EOD sayisi:%3 kitli:%4 | temas:%5 | ikincil(yakinlik tetikli komsu):%6 | bu IED yakinlik tetikli:%7 | devam eden is:%8 | EOD-IED mesafe:%9 | imha karari:%10 | mod:%11 (zar iptali sonrasi PATLAT:%12) | kit kurali:%13", groupId _g, typeOf _m, count _eodlar, count _kitli, _temas, _ikincil, _yakinlik, ((_g getVariable [QGVAR(iedIs), []]) isNotEqualTo []), if (isNull _imhaU) then {"-"} else {str (round (_imhaU distance2D _m))}, _imhaMi, _mod, _zorPat, ["ACE_DefusalKit veya ToolKit", "yalniz ACE_DefusalKit"] select _kitSiki];
                // yeni IED bulundu: devam eden imhanin hedefine / EOD'ye 20 m'den yakinsa ikincil cihaz -> imha iptal, EOD geri cekilir; uzaksa imha surer
                private _abort = false;
                private _is = _g getVariable [QGVAR(iedIs), []];
                if (_is isNotEqualTo []) then {
                    _is params ["_im", "_ie"];
                    if (!isNull _im && {alive _ie} && {_im isNotEqualTo _m} && {((_m distance2D _im) < 20) || {(_m distance2D _ie) < 20}}) then { _abort = true; _g setVariable [QGVAR(iedAbort), time]; };
                };

                // uzaklasma (yaricap + 8 m); EOD imha edecekse kalir. Taktik kilidi (bounding vb.) IED tehlikesinde gecilir.
                // TEMASTA: yaricap icindekiler yere yatar, surunerek uzaklasir (parca etkisi azalir); disindakiler siperde ates etmeye devam eder, IED'e dogru yurumez
                private _uzaklasan = 0;
                private _kacanlar = [];
                {
                    if ((_x distance2D _m) < _yaricap && {!(_imhaMi && {_x isEqualTo _eodU})} && {_abort || {!(_x getVariable [QGVAR(iedIsci), false])}}) then {
                        _x setVariable [QGVAR(taktikKilit), nil];
                        if (_temas) then {
                            _x setUnitPos "DOWN";
                            [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; }; }, [_x], 14] call CBA_fnc_waitAndExecute;
                        };
                        private _yon = _mp getDir _x;
                        _x doMove (_mp getPos [_yaricap + 8 + (random 6), _yon + (random 40) - 20]);
                        _uzaklasan = _uzaklasan + 1;
                        _kacanlar pushBack _x;
                    };
                } forEach _us;
                if (!_temas) then {
                    _g setBehaviour "AWARE";
                    _g setSpeedMode "LIMITED";
                    [{ params ["_gg"]; if (!isNull _gg && {!(_gg getVariable [QGVAR(isExecutingTactic), false])}) then { _gg setSpeedMode "NORMAL"; }; }, [_g], 25] call CBA_fnc_waitAndExecute;
                };

                // v8.58: GRUBU FELC ETME. Yalniz EOD (imha) + en fazla 2 GUVENLIK ELEMANI (EOD'ye / IED'e en yakin, lider / saglikci disi) cihazda kalir;
                // grubun GERISI gorevine / yoluna DEVAM EDER (komutan yolu degistirir: tehlike yaricapindan 4 sn'de bir geri itilir, mayin tipi IED'ler yol planlamasindan kacinilir).
                // EOD yoksa / imha yoksa hic bekleme: yalniz yaricap icindekiler disari itilir (30 sn).
                [_g, _m, _mp, _eodU, _imhaMi, _yaricap, _temas, _kacanlar] spawn {
                    params ["_grp", "_mine", "_pos", "_eod", "_imhaVar", "_yar", "_tm", "_kac"];
                    private _it = 0;
                    private _t0 = time;
                    private _sure = [30, 130] select _imhaVar;
                    private _R2 = _yar + 10;
                    private _bitis = "sure doldu";
                    // guvenlik elemani secimi (yalniz imha varsa ve temas yoksa)
                    private _guv = [];
                    if (_imhaVar && {!_tm}) then {
                        private _adaylar2 = (units _grp) select {alive _x && {isNull objectParent _x} && {_x isNotEqualTo _eod} && {_x isNotEqualTo (leader _grp)} && {!(_x getUnitTrait "medic")} && {!(_x getUnitTrait "explosiveSpecialist")} && {(_x distance2D _pos) < 90}};
                        private _sirali2 = _adaylar2 apply {[_x distance2D _pos, _x]};
                        _sirali2 sort true;
                        _guv = (_sirali2 select [0, 2]) apply {_x select 1};
                        { _x setVariable [QGVAR(iedGuv), true]; } forEach _guv;
                    };
                    private _kip = if (!_imhaVar) then {2} else {[0, 1] select _tm};
                    private _guvAd = (_guv apply {name _x}) joinString ", ";
                    diag_log format ["[IED-FARK-CEVRE] %1 | BASLADI | %2 | guvenlik elemani:%3 (%4) | EOD:%5 | grubun gerisi DEVAM EDER (felc yok) | tehlike yaricap %6 m | sure tavani %7 sn", groupId _grp, ["EOD + guvenlik elemani", "TEMAS: yalniz yaricap ici geri itme", "imha yok: yalniz yaricap ici geri itme"] select _kip, count _guv, _guvAd, if (isNull _eod) then {"-"} else {name _eod}, round _yar, _sure];
                    while {(time - _t0) < _sure && {!isNull _grp} && {(_grp getVariable [QGVAR(iedPos), _pos]) isEqualTo _pos}} do {
                        sleep 1;
                        _it = _it + 1;
                        // v8.59: IED ARTIK YOK (imha edildi / patladi / silindi) -> kacis emirleri HEMEN iptal; yok olduktan sonra kacmanin anlami yok
                        if (isNull _mine) exitWith { _bitis = "IED yok (patladi / silindi / imha edildi) - kacis iptal"; };
                        if (_imhaVar && {(time - _t0) > 10} && {(_grp getVariable [QGVAR(iedIs), []]) isEqualTo []}) exitWith { _bitis = "imha bitti"; };
                        if ((_it mod 4) != 0) then { continue };
                        // tum askerler (EOD hariç) tehlike yaricapinin icindeyse disari itilir; yolu degistirme
                        {
                            if (alive _x && {isNull objectParent _x} && {!(_imhaVar && {_x isEqualTo _eod})} && {(_x distance2D _pos) < (_yar - 2)}) then {
                                _x doMove (_pos getPos [_yar + 8 + (random 6), _pos getDir _x]);
                            };
                        } forEach (units _grp);
                        // guvenlik elemani: kendi yonunde (radyal) cevre noktasi, disa bakar, diz coker
                        private _lst = _guv select {alive _x};
                        private _sir = _lst apply {[(_pos getDir _x) + (random 0.01), _x]};
                        _sir sort true;
                        private _minA = (9 / (_R2 max 20)) * 57.3;
                        private _onceki = -999;
                        {
                            _x params ["_ac", "_u"];
                            private _ac2 = if (_ac < (_onceki + _minA)) then { _onceki + _minA } else { _ac };
                            _onceki = _ac2;
                            private _cp = _pos getPos [_R2 + (4 * (_forEachIndex mod 2)), _ac2];
                            if ((_u distance2D _cp) > 5) then {
                                _u setVariable [QGVAR(taktikKilit), time + 6];
                                _u doMove _cp;
                            } else {
                                _u doWatch (_pos getPos [_R2 + 60, _ac2]);
                                _u setUnitPos "MIDDLE";
                            };
                        } forEach _sir;
                    };
                    if (!isNull _grp && {(_grp getVariable [QGVAR(iedPos), _pos]) isNotEqualTo _pos}) then { _bitis = "yeni IED bulundu (gorev devredildi)"; };
                    diag_log format ["[IED-FARK-CEVRE] %1 | BITTI | neden: %2 | gecen %3 sn | guvenlik elemani serbest birakildi", groupId _grp, _bitis, round (time - _t0)];
                    // kacis iptali: IED yok olduysa tum kacanlar (ve temasta yere yatirilanlar) hemen normale doner, gruba katilir
                    if ((_bitis find "kacis iptal") >= 0 || {_bitis isEqualTo "imha bitti"}) then {
                        private _serbest = (_kac + (units _grp)) select {!isNull _x && {alive _x} && {isNull objectParent _x}};
                        {
                            _x setUnitPos "AUTO";
                            _x doWatch objNull;
                            _x setVariable [QGVAR(taktikKilit), nil];
                        } forEach _serbest;
                        if (!_tm || {(_bitis find "kacis iptal") >= 0}) then {
                            ((_kac + _guv) select {!isNull _x && {alive _x} && {isNull objectParent _x}}) doFollow (leader _grp);
                        };
                    };
                    {
                        _x setVariable [QGVAR(iedGuv), nil];
                        if (!isNull _grp && {(_grp getVariable [QGVAR(iedPos), _pos]) isEqualTo _pos}) then {
                            _x doWatch objNull;
                            _x setUnitPos "AUTO";
                            _x setVariable [QGVAR(taktikKilit), nil];
                        };
                    } forEach _guv;
                    if (!isNull _grp && {(_grp getVariable [QGVAR(iedPos), _pos]) isEqualTo _pos} && {!_tm}) then {
                        private _rel = (_guv + [_eod]) select {!isNull _x && {alive _x}};
                        _rel doFollow (leader _grp);
                    };
                };
                _g setVariable [QGVAR(iedPos), _mp];

                // imha: EOD varsa ve temas yoksa (vanilla mayin + ACE / mod IED); EOD yoksa yalniz kacinilir
                private _imha = "yok(EOD yok)";
                if (_ikincil && {!isNull _imhaU}) then { _imha = "yok(ikincil cihaz suphesi)"; };
                if (!isNull _eodU && {isNull _imhaU}) then { _imha = "yok(imha kiti yok: ACE_DefusalKit / ToolKit)"; };
                if (_temas && {!isNull _imhaU}) then { _imha = "yok(temas var: yere yat + uzaklas)"; };
                if (_imhaMi) then {
                    _imha = ["deneniyor (DEFUSE: EOD yaklasir)", "deneniyor (PATLAT: kontrollu patlatma, EOD yurumez)"] select (_mod isEqualTo "PATLAT");
                    [_eodU, _m, _g, typeOf _m, _yaricap, _mod] spawn {
                        params ["_u", "_mine", "_grp", "_mineTip", "_yariC", "_mod"];
                        private _pat = _mod isEqualTo "PATLAT";
                        private _t0 = time;
                        private _ab = _grp getVariable [QGVAR(iedAbort), 0];
                        private _sebep = "";
                        _grp setVariable [QGVAR(iedIs), [_mine, _u]];
                        _u setVariable [QGVAR(iedIsci), true];
                        // v8.50d: bilinen mayina AI yol planlamasi yaklasmaz (revealMine) -> mayin noktasina doMove asla varmiyordu. Hedef: IED'in kendi tarafimizdaki 5 m onu;
                        // komut 8 sn'de bir (her sn tekrarlanan doMove yurumeyi sifirliyordu); diger sistemler (bounding / cqb / rearGuard) EOD'ye karismasin diye kilit
                        private _noktaF = { params ["_uu", "_mm", "_ofs"]; private _mp0 = getPosATL _mm; _mp0 getPos [_ofs, _mp0 getDir _uu] };
                        private _hedefP = [_u, _mine, [5, _yariC + 5] select _pat] call _noktaF;
                        private _enYakin = if (_pat) then { _u distance2D _hedefP } else { _u distance2D _mine };
                        private _enYakinT = time;
                        private _sonKomut = -99;
                        private _sonLog = time + 10;
                        diag_log format ["[IED-FARK-IMHA] %1 | BASLADI | mod:%6 | hedef nokta: %2 m uzakta | IED:%3 (%4 m) | kit:%5", name _u, round (_u distance2D _hedefP), _mineTip, round (_u distance2D _mine), "ACE_DefusalKit" in (items _u), _mod];
                        waitUntil {
                            sleep 1;
                            if (time > _sonLog) then {
                                _sonLog = time + 10;
                                diag_log format ["[IED-FARK-IMHA] %1 | yaklasiyor: IED'e %2 m | en yakin %3 m | ilerleme yok:%4 sn | gecen:%5 sn | komut: %6", name _u, round (_u distance2D _mine), round _enYakin, round (time - _enYakinT), round (time - _t0), unitReady _u];
                            };
                            if (alive _u && {!isNull _mine}) then {
                                _u setVariable [QGVAR(taktikKilit), time + 6];
                                _u setVariable [QGVAR(forceMove), true];
                                if ((time - _sonKomut) > 8) then { _u doMove _hedefP; _sonKomut = time; };
                                private _dm = if (_pat) then { _u distance2D _hedefP } else { _u distance2D _mine };
                                if (_dm < (_enYakin - 2)) then { _enYakin = _dm; _enYakinT = time; };
                            };
                            if !(alive _u) then { _sebep = "EOD oldu"; };
                            if (isNull _mine) then { _sebep = "IED yok (patladi / silindi)"; };
                            if ((_grp getVariable [QGVAR(iedAbort), 0]) > _ab) then { _sebep = "ikincil cihaz / yeni IED"; };
                            if ((_grp getVariable [QGVAR(contact), 0]) > time) then { _sebep = "temas basladi"; };
                            if ((time - _t0) > 120) then { _sebep = "sure doldu (yaklasamadi, kalan " + str (round (_u distance2D _mine)) + " m)"; };
                            // 20 sn ilerleme yok ve <= 15 m: engel / yol planlayici -> oldugu yerden calis
                            (_sebep != "") || {if (_pat) then {(_u distance2D _hedefP) <= 5} else {(_u distance2D _mine) <= 6}} || {((time - _enYakinT) > 20) && {if (_pat) then {(_u distance2D _hedefP) <= 20} else {(_u distance2D _mine) <= 15}}}
                        };
                        _u setVariable [QGVAR(forceMove), nil];
                        _u setVariable [QGVAR(taktikKilit), nil];
                        if (_sebep != "") exitWith {
                            _grp setVariable [QGVAR(iedIs), []];
                            _u setVariable [QGVAR(iedIsci), nil];
                            diag_log format ["[IED-FARK] %1 | imha YARIM KALDI (%3) | %2", name _u, _mineTip, _sebep];
                            if (alive _u && {!isNull _mine}) then { _u doMove ((getPosATL _mine) getPos [_yariC + 8, (getPosATL _mine) getDir _u]); };
                            if (alive _u && {isNull _mine}) then { _u doFollow (leader _grp); };
                        };
                        diag_log format ["[IED-FARK] %1 | IED'e vardi (%2 m, %3 sn) | %4: calisiyor", name _u, round (_u distance2D _mine), round (time - _t0), _mineTip];
                        // calisma: dur, diz coker, IED'e bak. DEFUSE: ~8 sn (ACE EOD sureci simule edilir). PATLAT: 10 sn hazirlik, cevre bosaltma kontrolu, kontrollu patlatma.
                        _u doWatch _mine;
                        _u setUnitPos "MIDDLE";
                        _u doMove (getPosATL _u);
                        private _bitti = false;
                        private _sebep2 = "";
                        private _t1 = time;
                        private _calSn = [8, 10] select _pat;
                        waitUntil {
                            sleep 1;
                            _u setVariable [QGVAR(taktikKilit), time + 4];
                            if !(alive _u) then { _sebep2 = "EOD oldu"; };
                            if (isNull _mine) then { _sebep2 = "IED calisma sirasinda yok oldu (patladi / baska sistem sildi)"; };
                            if ((_grp getVariable [QGVAR(contact), 0]) > time) then { _sebep2 = "temas basladi"; };
                            if ((_grp getVariable [QGVAR(iedAbort), 0]) > _ab) then { _sebep2 = "ikincil cihaz / yeni IED"; };
                            (time - _t1) > _calSn || {_sebep2 != ""}
                        };
                        _u setVariable [QGVAR(taktikKilit), nil];
                        if (_sebep2 isEqualTo "" && {alive _u} && {!isNull _mine}) then {
                            if (_pat) then {
                                // cevre emniyeti: hic kimse tehlike yaricapi icinde olmamali (en fazla 20 sn beklenir)
                                private _t2 = time;
                                waitUntil {
                                    sleep 1;
                                    private _ic = (units _grp) select {alive _x && {(_x distance2D _mine) < (_yariC - 3)} && {_x isNotEqualTo _u}};
                                    if (_ic isNotEqualTo [] && {(time - _t2) < 20}) then {
                                        { _x doMove ((getPosATL _mine) getPos [_yariC + 8, (getPosATL _mine) getDir _x]); } forEach _ic;
                                    };
                                    (_ic isEqualTo []) || {(time - _t2) >= 20} || {isNull _mine} || {(_grp getVariable [QGVAR(contact), 0]) > time}
                                };
                                if (!isNull _mine && {(_grp getVariable [QGVAR(contact), 0]) <= time}) then {
                                    triggerAmmo _mine;
                                    sleep 1.5;
                                    if (!isNull _mine) then { deleteVehicle _mine; };
                                    _bitti = true;
                                };
                            } else {
                                // v8.57: ZAR — imha basarisi sabit degil. P(basari) = beceri + kit - cihaz karmasikligi - baski. Basarisizlikta cogunlukla IPTAL (EOD geri cekilir, bu IED icin
                                // kontrollu patlatmaya gecilir), az olasilikla PATLAMA (EOD yakinda: ciddi risk). lambs_danger_iedZarOff = true -> hep basari.
                                private _basari = true;
                                if !(missionNamespace getVariable ["lambs_danger_iedZarOff", false]) then {
                                    private _sk = skill _u;
                                    private _sin = toLower _mineTip;
                                    private _kitB = [0, 0.05] select ("ACE_DefusalKit" in items _u);
                                    private _tipC = 0;
                                    if ((_sin find "iedd") >= 0) then { _tipC = _tipC + 0.10; };   // mod IED'leri daha karmasik varsayilir
                                    if ((_sin find "big") >= 0) then { _tipC = _tipC + 0.05; };
                                    if ((_sin find "urban") >= 0) then { _tipC = _tipC + 0.03; };
                                    private _bask = [0, 0.2] select (getSuppression _u > 0.3);
                                    private _pB = ((0.55 + (0.35 * _sk) + _kitB - _tipC - _bask) max 0.35) min 0.97;
                                    private _z1 = random 1;
                                    private _pD = 0.15;
                                    private _z2 = random 1;
                                    if (_z1 < _pB) then {
                                        diag_log format ["[IED-FARK-ZAR] %1 | beceri:%2 | P(basari):%3 (kit %4, cihaz -%5, baski -%6) | zar:%7 -> BASARI", name _u, _sk toFixed 2, _pB toFixed 2, _kitB, _tipC toFixed 2, _bask, _z1 toFixed 2];
                                    } else {
                                        _basari = false;
                                        if (_z2 < _pD) then {
                                            _sebep2 = "ZAR: PATLAMA (basarisiz, hata)";
                                            diag_log format ["[IED-FARK-ZAR] %1 | beceri:%2 | P(basari):%3 | zar:%4 -> BASARISIZ | ikinci zar:%5 < %6 -> PATLAMA (EOD yakinda)", name _u, _sk toFixed 2, _pB toFixed 2, _z1 toFixed 2, _z2 toFixed 2, _pD];
                                            if (!isNull _mine) then { triggerAmmo _mine; };
                                        } else {
                                            _sebep2 = "ZAR: IPTAL (EOD geri cekildi, bu IED icin kontrollu patlatmaya gecilir)";
                                            diag_log format ["[IED-FARK-ZAR] %1 | beceri:%2 | P(basari):%3 | zar:%4 -> BASARISIZ | ikinci zar:%5 >= %6 -> IPTAL (patlama yok)", name _u, _sk toFixed 2, _pB toFixed 2, _z1 toFixed 2, _z2 toFixed 2, _pD];
                                            private _pl = _grp getVariable [QGVAR(iedPatList), []];
                                            _pl pushBack (getPosATL _mine);
                                            _grp setVariable [QGVAR(iedPatList), _pl];
                                            _u doMove ((getPosATL _mine) getPos [_yariC + 5, (getPosATL _mine) getDir _u]);
                                        };
                                    };
                                };
                                if (_basari) then {
                                    if (_mine isKindOf "MineBase") then { _u action ["Deactivate", _u, _mine]; sleep 1; };
                                    if (!isNull _mine) then { deleteVehicle _mine; };
                                    _bitti = true;
                                };
                            };
                        } else {
                            if (_sebep2 isEqualTo "") then { _sebep2 = "?"; };
                        };
                        _u doWatch objNull;
                        _u setUnitPos "AUTO";
                        _grp setVariable [QGVAR(iedIs), []];
                        if (alive _u && {_bitti || {isNull _mine}}) then { _u doFollow (leader _grp); };
                        _u setVariable [QGVAR(iedIsci), nil];
                        // tamamlandiysa bilinen listeyi temizle: yakindaki diger IED yeniden degerlendirilip sirayla imha edilir
                        if (_bitti || {(_sebep2 find "IPTAL") >= 0}) then { _grp setVariable [QGVAR(iedBilinen), []]; };
                        diag_log format ["[IED-FARK] %1 | imha %2 | mod:%6 | %3 | ACE:%4 | kit:%5%7", name _u, ["BASARISIZ (calisma kesildi)", "TAMAM"] select _bitti, _mineTip, !isNil "ace_explosives_fnc_defuseExplosive", "ACE_DefusalKit" in (items _u), _mod, if (_bitti) then {""} else {format [" | neden: %1", _sebep2]}];
                    };
                };
                if (_logN < 100) then {
                    _logN = _logN + 1;
                    diag_log format ["[IED-FARK] %1 | %2 | lider %3 m | tespit:%4 (%7 m) | uzaklasan:%5 (yaricap %8 m [config:%10], temas:%9) | imha:%6", groupId _g, typeOf _m, round (_lp distance2D _m), name _tespit, _uzaklasan, _imha, round (_tespit distance2D _m), _yaricap, _temas, _irange];
                    if (!isNull _eodU) then { diag_log format ["[IED-FARK] %1 | EOD:%2 (explosiveSpecialist:%3 ACE_isEOD:%4)", groupId _g, name _eodU, _eodU getUnitTrait "explosiveSpecialist", _eodU getVariable ["ACE_isEOD", false]]; };
                };
            } forEach _adaylar;
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        _turMs = (diag_tickTime - _t0) * 1000;
        missionNamespace setVariable ["lambs_danger_iedAdim", format ["tur %1 bitti (%2 ms)", _tur, round _turMs]];
    };
};

// bekci: watchdog betigi bir hata ile olurse otomatik yeniden baslat (v8.51)
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] IED farkindaligi betigi sonlandi (hata?), son adim: %1 | RPT'de hemen ustteki 'Error' satirina bak", missionNamespace getVariable ["lambs_danger_iedAdim", "?"]];
        sleep 5;
    };
};

true
