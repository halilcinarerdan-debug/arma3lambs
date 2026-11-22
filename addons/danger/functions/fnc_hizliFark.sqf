#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HIZLI FARK ETME (v8.727; kullanici: 'elemanlarin reaksiyon suresi, hem farkinda olmasi hem ates etmesi cok dusuk'; 1v1 RPT bd19160c, v8.722):
 * TESHIS: bot becerileri zaten 1.00 (spotTime / spotDistance / aimingSpeed; [SKILL-VARSAYILAN]); ELITE algi katmanlari (bilgiArtis, bilgiTaban, yakinAlgi, ufukAlgi, adimSes) BILINEN / yakin / siluet dusmani guclendirir ama
 *   ILK fark etmeyi (bilinmeyen -> bilinen) hizlandirmaz: o motorun knowsAbout birikimidir (isik, mesafe, durus, kamuflaj; insanda ~0.3-0.5 sn). cqbReflex yalniz BILDIGI dusmana ates eder.
 * KURAL (hile yok: gorus hatti + onden bakis + isik sartlari): yerel AI, oyuncuya DUSMAN, canli, onunde (hizliFarkAci, 65 derece) ve hizliFarkM (120 m) icinde, bakis hatti (VIEW LOD) acik (checkVisibility >= 0.3) iken
 *   GORUNUR sure birikir (gorunmuyorsa yavasca azalir); birikim esigi: T = hizliFarkS (0.5 sn) x (0.5 + mesafe / hizliFarkM) / gorunurluk, oyuncu yatik + hareketsizse x2, gece + isiksiz ise yalniz 25 m icinde. Esik dolunca
 *   bot 'reveal [oyuncu, hizliFarkSeviye]' (1.5: konumu yaklasik bilir -> motor hedef alir / ates eder) ve (hizliFarkGrup) 60 m icindeki grup uyelerine seviye x 0.7 (telsiz / bakis cagrisi). Zaten TESPIT esiginin ustunde bilen bota dokunulmaz.
 *   Yalniz INSAN oyunculara karsi. captive / sivil / baygin / teslim olanlar atlanir.
 * OLCUM: [HIZLI-FARK] (ilk 25 olay: bot, mesafe, birikim sn, ilk gorunurden beri sn, onceki knowsAbout, yeni seviye) + 60 sn [HIZLI-FARK-OZET] (tetiklenen, ort. gorunur->fark suresi, MOTOR kendi fark etme sayisi ve ort. suresi = referans). Karne: HIZLI FARK.
 * CBA: lambs_danger_hizliFark (varsayilan ACIK), hizliFarkM, hizliFarkS, hizliFarkAci, hizliFarkSeviye, hizliFarkGrup.
 * SINIR: oyuncu kamuflaji / dumanla gorunurluk < 0.3 ise tetiklenmez; seviye 1.5 'yaklasik konum' (4 = tam konum DEGIL); bota bina duvari arkasindan fark ettirmez (VIEW LOD hatti kapali).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_hizliFarkStarted") exitWith {false};
lambs_danger_hizliFarkStarted = true;

diag_log "[HIZLI-FARK] gorunur insan oyuncuyu hizli fark etme (reveal) katmani baslatildi (v8.727)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["tetik", 0], ["tetikSn", 0], ["motor", 0], ["motorSn", 0]];
    private _ozetT = time + 60;
    private _dt = 0.25;
    while {true} do {
        sleep _dt;
        if !(missionNamespace getVariable ["lambs_danger_hizliFark", true]) then { continue };
        private _R = ((missionNamespace getVariable ["lambs_danger_hizliFarkM", 120]) max 30) min 300;
        private _S = ((missionNamespace getVariable ["lambs_danger_hizliFarkS", 0.5]) max 0.2) min 3;
        private _aci = ((missionNamespace getVariable ["lambs_danger_hizliFarkAci", 65]) max 30) min 90;
        private _sev = ((missionNamespace getVariable ["lambs_danger_hizliFarkSeviye", 1.5]) max 0.5) min 4;
        private _grup = missionNamespace getVariable ["lambs_danger_hizliFarkGrup", true];
        private _esik = ["TESPIT"] call FUNC(bilgiEsik);
        private _gece = (sunOrMoon < 0.12);
        {
            private _p = _x;
            if (!alive _p || {captive _p} || {(side group _p) isEqualTo civilian}) then { continue };
            private _pp = getPosATL _p;
            private _pEye = eyePos _p;
            private _pYatik = ((stance _p) isEqualTo "PRONE") && {(speed _p) < 1.5};
            private _sd = side group _p;
            private _aday = (_pp nearEntities ["CAManBase", _R]) select {
                local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(_sd getFriend (side group _x)) < 0.6} && {!captive _x}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable ["ACE_isUnconscious", false])} && {!(_x getVariable [QGVAR(teslim), false])}
            };
            private _n = 0;
            {
                private _b = _x;
                if (_n >= 14) exitWith {};
                _n = _n + 1;
                private _d = _b distance2D _p;
                private _kn = _b knowsAbout _p;
                private _key = format ["hf_%1", netId _p];
                private _kay = _b getVariable [_key, [0, -1, false]];   // [birikim sn, ilk gorunur zamani, tetiklendi]
                _kay params ["_acc", "_ilk", "_tet"];
                if (_kn >= _esik) then {
                    // dogal fark etme (referans): ilk gorunurden TESPIT'e kadar gecen sure
                    if (_ilk >= 0 && {!_tet}) then { _say set ["motor", (_say get "motor") + 1]; _say set ["motorSn", (_say get "motorSn") + (time - _ilk)]; };
                    _b setVariable [_key, [0, -1, true]];
                    continue
                };
                if (_tet && {_kn < (_esik * 0.5)}) then { _kay = [0, -1, false]; _acc = 0; _ilk = -1; _tet = false; };   // unutuldu: yeniden fark ettirilebilir
                if (_tet) then { continue };
                // onden bakis
                private _bakis = eyeDirection _b;
                private _vp = _pEye vectorDiff (eyePos _b);
                private _vd = vectorMagnitude _vp;
                if (_vd < 1) then { continue };
                private _acA = acos ((((_bakis vectorDotProduct _vp) / (_vd max 0.1)) min 1) max -1);
                private _vis = 0;
                if (_acA <= _aci && {!(_gece && {_d > 25})}) then { _vis = [_b, "VIEW", _p] checkVisibility [eyePos _b, _pEye]; };
                if (_vis >= 0.3) then {
                    if (_ilk < 0) then { _ilk = time; };
                    _acc = _acc + _dt;
                    private _T = _S * (0.5 + (_d / _R)) / (_vis max 0.3);
                    if (_pYatik) then { _T = _T * 2; };
                    if (_acc >= _T) then {
                        _b reveal [_p, _sev];
                        if (_grup) then { { if (_x isNotEqualTo _b && {alive _x} && {(_x distance2D _b) <= 60}) then { _x reveal [_p, _sev * 0.7]; }; } forEach (units group _b); };
                        if (!((_b getVariable [QGVAR(forceMove), false]) isEqualTo true) && {!((group _b) getVariable [QGVAR(isRetreating), false])}) then { _b doTarget _p; };   // hedef al (ates karari motor / cqbReflex'te)
                        _tet = true;
                        _say set ["tetik", (_say get "tetik") + 1];
                        _say set ["tetikSn", (_say get "tetikSn") + (time - _ilk)];
                        if (_logN < 25) then {
                            _logN = _logN + 1;
                            diag_log format ["[HIZLI-FARK] %1 | %2 -> %3 | %4 m | gorunur birikim %5 sn (esik %6) | ilk gorunurden beri %7 sn | onceki knowsAbout %8 | gorunurluk %9 | seviye %10 | grup %11", groupId group _b, name _b, name _p, round _d, _acc toFixed 2, _T toFixed 2, (time - _ilk) toFixed 2, _kn toFixed 2, _vis toFixed 2, _sev, _grup];
                        };
                    };
                } else {
                    _acc = (_acc - (_dt * 0.5)) max 0;
                    if (_acc <= 0 && {!_tet}) then { _ilk = -1; };
                };
                _b setVariable [_key, [_acc, _ilk, _tet]];
            } forEach _aday;
        } forEach (allPlayers select {alive _x});
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "tetik") + (_say get "motor")) > 0) then {
                diag_log format ["[HIZLI-FARK-OZET] 60 sn: tetiklenen %1 (ort. gorunur->fark %2 sn) | motorun kendi fark ettigi %3 (ort. gorunur->fark %4 sn, referans)", _say get "tetik", ((_say get "tetikSn") / ((_say get "tetik") max 1)) toFixed 2, _say get "motor", ((_say get "motorSn") / ((_say get "motor") max 1)) toFixed 2];
            };
            { _say set [_x, 0]; } forEach (keys _say);
        };
    };
};
true
