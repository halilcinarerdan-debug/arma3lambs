#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK TARET BAKISI (v8.276; kullanici: 'tank turretleri olu noktalara bakmasin, duz duvara degil en tehlikeli bolgeye baksin').
 * Mevzideki (durmus) tankin murettebatinin nereye bakacagini secer. Eskiden sabit bir noktaya (savunmada tehdit yonunde 700 m, saldirida objektif) bakiyordu;
 * o nokta bina / duvar / tepe arkasindaysa taret fiilen duvara bakiyordu.
 *   1) BILINEN DUSMAN: grup liderinin bildigi, gercek, canli dusman (<= 1300 m, knowsAbout > 0.4) - zirh / AT'li en yuksek tehdit, yakin olan once -> o nesneye bakilir.
 *   2) SEKTOR TARAMASI: tehdit ekseni etrafinda +-70 derece (10 derecelik adimlarla) taret yuksekliginden (2.4 m) 800 m'ye ISIN atilir; ilk engel < 90 m ise "OLU NOKTA" sayilir (reddedilir),
 *      aksi halde puan = acik mesafe (800 m'ye kadar) x eksene yakinlik; en yuksek puanli bakis yonu secilir (en tehlikeli = dusmanin gelebilecegi en acik yaklasma kanali).
 *   3) Hicbiri uygun degilse (sikismis mevzi) tehdit noktasina bakilir (eski davranis).
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Tehdit noktasi / nesnesi (eksen) <OBJECT|ARRAY>
 * 2: Grup <GROUP> (opsiyonel; bilinen dusman icin lider kullanilir)
 * 3: Sektor kaydirma (derece) <NUMBER> (v8.280; opsiyonel)
 *
 * Return Value: [bakilacak nesne ya da pozisyon, tur ("DUSMAN" / "SEKTOR" / "EKSEN"), yon (derece), acik mesafe (m)]
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_tehdit", [], [objNull, []]], ["_g", grpNull, [grpNull]], ["_ofs", 0, [0]]];
if (isNull _v) exitWith { [[], "EKSEN", 0, 0] };

private _eksenP = if (_tehdit isEqualType objNull) then { getPosATL _tehdit } else { +_tehdit };
if (_eksenP isEqualTo []) then { _eksenP = _v getPos [500, getDir _v]; };
private _vP = getPosATL _v;
// v8.280 KOORDINASYON: ayni plandaki tanklar tehdit ekseninin farkli sektorlerine bakar (_ofs = tank basina +-40 derece kaydirma; hepsi ayni noktaya bakmaz, 360 derece guvenlik)
private _eksen = (_vP getDir _eksenP) + _ofs;

// ---- 1) bilinen dusman ----
private _sonuc = [];
if (!isNull _g) then {
    private _l = leader _g;
    if (!isNull _l && {local _l}) then {
        private _taraf = side _g;
        private _hd = (_l nearTargets 1300) select {
            (_taraf getFriend (_x select 2)) < 0.6
            && {alive (_x select 4)}
            && {(_l knowsAbout (_x select 4)) > 0.4}
            && {[_x select 4] call FUNC(gercekHedef)}
        };
        if (_hd isNotEqualTo []) then {
            private _en = objNull;
            private _enS = -1e9;
            {
                private _o = _x select 4;
                private _d = (_x select 0) distance2D _v;
                // zirhli / AT'li tehdit onceligi, yakin olan once
                private _agirlik = if (_o isKindOf "Tank" || {_o isKindOf "Wheeled_APC_F"} || {_o isKindOf "Tracked_APC_F"}) then {3} else { if (_o isKindOf "CAManBase" && {[_o] call FUNC(isATUnit)}) then {2.5} else {1} };
                private _s = (_agirlik * 100) - (_d / 10);
                if (_s > _enS) then { _enS = _s; _en = _o; };
            } forEach _hd;
            if (!isNull _en) then { _sonuc = [_en, "DUSMAN", round (_vP getDir _en), round (_v distance2D _en)]; };
        };
    };
};

// ---- 2) sektor taramasi ----
if (_sonuc isEqualTo []) then {
    private _gozASL = (AGLToASL _vP) vectorAdd [0, 0, 2.4];
    private _eniAci = -1000;
    private _eniS = -1;
    private _eniAcik = 0;
    for "_a" from -70 to 70 step 10 do {
        private _yon = _eksen + _a;
        private _son = (AGLToASL (_v getPos [800, _yon])) vectorAdd [0, 0, 1.5];
        private _hit = lineIntersectsSurfaces [_gozASL, _son, _v, objNull, true, 1, "VIEW", "FIRE"];
        private _acik = if (_hit isEqualTo []) then {800} else { _gozASL distance ((_hit select 0) select 0) };
        // 90 m'den kisa acik mesafe = olu nokta (duvar / bina / yamac)
        if (_acik >= 90) then {
            private _s = (_acik min 800) * (1 - ((abs _a) / 70) * 0.45);
            if (_s > _eniS) then { _eniS = _s; _eniAci = _yon; _eniAcik = _acik; };
        };
    };
    if (_eniAci > -999) then {
        _sonuc = [_v getPos [((_eniAcik min 500) max 150), _eniAci], "SEKTOR", round ((_eniAci + 360) mod 360), round _eniAcik];
    };
};

// ---- 3) eksen ----
if (_sonuc isEqualTo []) then { _sonuc = [_eksenP, "EKSEN", round ((_eksen + 360) mod 360), 0]; };
_sonuc
