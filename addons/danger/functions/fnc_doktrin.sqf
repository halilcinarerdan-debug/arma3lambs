#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DOKTRIN CERCEVESI — her ordunun taktik degerleri KENDI profilinde, kod ortak (global temel).
 *
 * FELSEFE (VBS4 / egitim simulasyonu yonu): davranis kodu sabit sayi tasimaz; GRUBUN PROFILINI okur. Yeni ordu = yeni profil (veri),
 * kod degismez. Profiller KALITIM zinciriyle kurulur: GENEL (taban) -> ust profil -> ordu profili; alt profil yalniz FARKLI degerleri yazar.
 *
 * KULLANIM (her yerde):   [_grup, "anahtar", varsayilan] call lambs_danger_fnc_dk      -> tek deger
 *                          [_grup] call lambs_danger_fnc_doktrin                        -> tum profil (HASHMAP, grupta onbellekli)
 *
 * ANAHTARLAR (varsayilan = mevcut davranis):
 *   ad                 profil adi
 *   --- taarruz / hareket ---
 *   assaultM 45        komutan: bu mesafenin altinda duz hucum (ustunken); ustunde ates-manevra (BOUNDING)
 *   bndBitisM 40       bounding bu mesafede hucuma devreder
 *   bantlar            [[mesafe_ustu, atilimMax, kazancMin], ...] buyukten kucuge; bound atilim bantlari
 *   owKurulumS 5       overwatch kurulum tavani (sn)
 *   bndMaxCycle 10     bir bounding'de en fazla cycle
 *   --- geri cekilme / kayip ---
 *   retreatAdim [20,30,50]   sicrama boyu [dusman<100 m, 100-200 m, >200 m]
 *   cekilKayip 0.4     bu kayip orani ustunde WITHDRAW
 *   peelOran 1.6, peelKayip 0.1   guc dezavantaji + kayip -> PEEL
 *   kucukEkip 3        bu sayi ve alti VEYA dusman < yakinM: kosarak kacmak yerine DELAY (siper + sis)
 *   yakinM 60
 *   --- ates / silah ---
 *   uglUzakM 200, uglUzakAralik 25, uglRezerv 2 (v8.83: 3 -> 2), uglRezervM 120   40mm kullanim kurallari
 *   --- saha ---
 *   arkaGuvenlik true, arkaGuvenlikMinKisi 6    CQB / kent arka guvenlik askeri
 *   cekilGuvenM 450, cekilEkSicrama 9, cekilMaxS 300, cekilGozlemM 280     retreat: dusman bu mesafeye ulasana kadar (en fazla N ek sicrama) cekilmeye devam
 *   baskiKirmaEsik 0.5, baskiKirmaMaxS 14   retreat: ort. baski bu esikten yuksekse once siper + karsi ates (en fazla N sn), sonra sicrama
 *   pusu true, pusuAtesM 70, pusuMaxS 150, pusuMinKisi 4   pusu: kill-box mesafesi, azami bekleme, en az kisi
 *   DUZENSIZ (Taliban-tipi): vur-kac, erken temas kesme, pusu agirlikli (haritada taliban / lop_am / lop_ists / insurgent ...)
 *   sonDirenis true   <= 3 asker son care: yakin binaya yerlesip kale savunmasi;  konsolidasyonS 90   retreat sonrasi LAMBS grup taktigi kapali toparlanma suresi (sn)
 *   cekilTopluM 180   retreat: dusman bu mesafeden uzaksa kapsama takimi yok, herkes birlikte kosar (yakinda ates-manevra)
 *   yorgunlukEtki 1 (bound uzunlugunu yorgunluga gore kisaltma carpani; 0 = kapali)
 *   teslim true, teslimEsik 0.15   moral endeksi bu esigin altina duserse (+ umutsuz kosullar) teslim; DUZENSIZ: teslim yok
 *   kamuflaj true, kamuflajMin 0.6   kamuflaj bilinci (ufuk / hareket / isik; camouflageCoef alt siniri)
 *
 * YENI ORDU EKLEME (kod degistirmeden, misyon init'te):
 *   lambs_danger_doktrinTanimlari = [["ADIM", "UST_PROFIL", [["assaultM", 55], ["bantlar", [[200,60,12],[100,40,10],[0,30,8]]]]]];
 *   lambs_danger_doktrinHaritasi  = [["faction_veya_sinif_parcasi", "ADIM"], ...];   // kucuk harf parca, ilk eslesen kazanir
 *
 * !! Asagidaki ordu degerleri BASLANGIC TAHMINLERIDIR (genel bilgi, yaklasik). Gercek nizamnamelerle (FM 3-21.8 / MCWP, Rus ve Cin piyade
 *    nizamnameleri, Peshmerge uygulamalari) dogrulanip duzeltilmelidir. "GENEL" mevcut davranisla AYNIDIR (degisiklik yok).
 *
 * Arguments:
 * 0: Grup <GROUP> (veya birim)
 *
 * Return Value:
 * Profil <HASHMAP>
 *
 * Public: No
*/

params [["_g", grpNull, [grpNull, objNull]]];
if (_g isEqualType objNull) then { _g = group _g; };
if (isNull _g) exitWith { createHashMap };

private _onb = _g getVariable [QGVAR(doktrin), createHashMap];
private _lider = leader _g;
private _fak = if (isNull _lider) then {""} else {toLower (faction _lider)};
// v8.40: CBA ayari (taraf basina profil); "OTO" = fraksiyondan
private _ovr = switch (side _g) do {
    case west: { missionNamespace getVariable ["lambs_danger_doktrinWest", "OTO"] };
    case east: { missionNamespace getVariable ["lambs_danger_doktrinEast", "OTO"] };
    case independent: { missionNamespace getVariable ["lambs_danger_doktrinInd", "OTO"] };
    default { "OTO" };
};
if !(_ovr isEqualType "") then { _ovr = "OTO"; };
private _imza = _fak + "|" + _ovr;
if ((count _onb) > 0 && {(_onb getOrDefault ["imza", ""]) isEqualTo _imza}) exitWith { _onb };

// --- TABAN (GENEL) ---
private _p = createHashMapFromArray [
    ["ad", "GENEL"],
    ["assaultM", 45], ["bndBitisM", 40], ["bantlar", [[200, 70, 15], [100, 40, 12], [0, 25, 8]]], ["owKurulumS", 5], ["bndMaxCycle", 10],
    ["retreatAdim", [20, 30, 50]], ["cekilKayip", 0.4], ["peelOran", 1.6], ["peelKayip", 0.1], ["kucukEkip", 3], ["yakinM", 60],
    ["uglUzakM", 200], ["uglUzakAralik", 25], ["uglRezerv", 2], ["uglRezervM", 120],
    ["arkaGuvenlik", true], ["arkaGuvenlikMinKisi", 6],
    ["cekilGuvenM", 450], ["cekilEkSicrama", 9], ["cekilMaxS", 300], ["cekilGozlemM", 280], ["baskiKirmaEsik", 0.5], ["baskiKirmaMaxS", 14],
    ["pusu", true], ["pusuAtesM", 70], ["pusuMaxS", 150], ["pusuMinKisi", 4],
    ["kamuflaj", true], ["kamuflajMin", 0.6],
    ["yorgunlukEtki", 1], ["teslim", true], ["teslimEsik", 0.15], ["cekilTopluM", 180], ["sonDirenis", true], ["konsolidasyonS", 90], ["toparlan", true]
];

// --- ORDU TANIMLARI: [ad, ust, [[anahtar, deger], ...]] ---
private _tanim = [
    // USMC: ates takimi liderleri inisiyatif alir (merkezsiz), agresif ates-manevra, uzun bound, ates ustunlugu + sis
    ["USMC", "GENEL", [["assaultM", 40], ["bndBitisM", 35], ["bantlar", [[200, 80, 15], [100, 45, 12], [0, 25, 8]]], ["retreatAdim", [25, 35, 55]], ["cekilKayip", 0.45]]],
    // ABD ordusu / NATO tipi: USMC'ye yakin, biraz daha temkinli
    ["ABD", "USMC", [["assaultM", 42], ["bndBitisM", 38], ["bantlar", [[200, 75, 15], [100, 42, 12], [0, 25, 8]]], ["cekilKayip", 0.4]]],
    // Rus (motorlu piyade): merkezi kontrol, kisa ve kati bound, daha uzak hucum baslangici, daha direncli (yuksek cekilme esigi)
    ["RUS", "GENEL", [["assaultM", 50], ["bndBitisM", 45], ["bantlar", [[200, 60, 15], [100, 35, 12], [0, 20, 8]]], ["cekilKayip", 0.5], ["retreatAdim", [20, 30, 45]], ["arkaGuvenlik", false]]],
    // Cin (PLA): merkezi, siki duzen, uclu hucum hucreleri; kisa kontrollu atilimlar
    ["CHN", "GENEL", [["assaultM", 50], ["bndBitisM", 45], ["bantlar", [[200, 55, 15], [100, 32, 12], [0, 20, 8]]], ["cekilKayip", 0.5], ["retreatAdim", [20, 28, 45]], ["arkaGuvenlik", false]]],
    // Peshmerge: hafif / yari duzensiz, mevzi savunmasi + atik yerel hucum; gevsek bound, daha yakindan hucum
    ["PESHMERGA", "GENEL", [["assaultM", 55], ["bndBitisM", 50], ["bantlar", [[200, 60, 12], [100, 40, 10], [0, 30, 8]]], ["retreatAdim", [25, 35, 45]], ["cekilKayip", 0.35], ["uglRezerv", 2]]],
    // DUZENSIZ / TALIBAN-tipi isyanci (TAHMIN, kaynak dogrulanmadi): vur-kac, pusu agirlikli, kucuk dagitik takimlar, ates ustunlugu yoksa ERKEN temas keser,
    //   yakin mesafeden hucum, daha iyi gizlenme (camouflageCoef alt siniri 0.55), uzun dagilarak cekilme
    ["DUZENSIZ", "GENEL", [["assaultM", 30], ["bndBitisM", 30], ["bantlar", [[200, 60, 12], [100, 35, 10], [0, 20, 8]]], ["retreatAdim", [25, 40, 60]], ["cekilKayip", 0.30], ["peelOran", 1.3], ["peelKayip", 0.08], ["konsolidasyonS", 40], ["kucukEkip", 2], ["pusu", true], ["pusuAtesM", 55], ["pusuMaxS", 180], ["pusuMinKisi", 3], ["uglRezerv", 2], ["arkaGuvenlik", false], ["kamuflajMin", 0.55], ["teslim", false]]]
];
// misyon / kullanici tanimlari (ayni ad = ustune yazar)
{ _tanim pushBack _x; } forEach (missionNamespace getVariable ["lambs_danger_doktrinTanimlari", []]);

// --- FRAKSIYON ESLESMESI (editlenebilir) ---
private _harita = missionNamespace getVariable ["lambs_danger_doktrinHaritasi", [
    ["rhs_faction_usmc", "USMC"], ["usmc", "USMC"],
    ["rhs_faction_usarmy", "ABD"], ["blu_f", "ABD"], ["blu_g_f", "ABD"],
    ["rhs_faction_msv", "RUS"], ["rhs_faction_vdv", "RUS"], ["rhs_faction_rva", "RUS"], ["rhs_faction_tv", "RUS"],
    ["opf_t_f", "CHN"], ["_chn", "CHN"], ["_pla", "CHN"], ["china", "CHN"],
    ["peshmerga", "PESHMERGA"], ["kurd", "PESHMERGA"], ["_pesh", "PESHMERGA"],
    ["taliban", "DUZENSIZ"], ["lop_am", "DUZENSIZ"], ["lop_ists", "DUZENSIZ"], ["_ists", "DUZENSIZ"], ["insurgent", "DUZENSIZ"], ["irregular", "DUZENSIZ"], ["_isis", "DUZENSIZ"], ["opf_g_f", "DUZENSIZ"], ["ind_g_f", "DUZENSIZ"],
    ["cup_b_us", "ABD"], ["cup_o_ru", "RUS"], ["cup_i_tk_gue", "DUZENSIZ"], ["tk_gue", "DUZENSIZ"], ["cup_o_chdkz", "DUZENSIZ"], ["chdkz", "DUZENSIZ"], ["cup_i_napa", "DUZENSIZ"]
]];
private _ad = "GENEL";
{
    if ((_fak find (_x select 0)) >= 0) exitWith { _ad = _x select 1; };
} forEach _harita;
if (_ovr isNotEqualTo "OTO") then { _ad = _ovr; };

// --- KALITIM ZINCIRI: ad -> ust -> ... -> GENEL; en uzaktan uygula, en son kendi degerleri ---
private _zincir = [];
private _n = _ad;
private _guv = 0;
while {_n isNotEqualTo "" && {_n isNotEqualTo "GENEL"} && {_guv < 6}} do {
    private _ix = -1;
    { if ((_x select 0) isEqualTo _n) then { _ix = _forEachIndex; }; } forEach _tanim;   // SON tanim kazanir (misyon tanimi yerlesikin ustune yazar)
    if (_ix < 0) exitWith {};
    private _t = _tanim select _ix;
    _zincir pushBack _t;
    _n = _t select 1;
    _guv = _guv + 1;
};
reverse _zincir;
{
    { _p set [_x select 0, _x select 1]; } forEach (_x select 2);
} forEach _zincir;
_p set ["ad", _ad];
_p set ["imza", _imza];

_g setVariable [QGVAR(doktrin), _p];
if ((count _onb) isEqualTo 0 || {(_onb getOrDefault ["ad", ""]) isNotEqualTo _ad}) then {
    diag_log format ["[DOKTRIN-PROFIL] %1 | faction:%2 -> %3 | assaultM:%4 bndBitisM:%5 cekilKayip:%6", groupId _g, _imza, _ad, _p get "assaultM", _p get "bndBitisM", _p get "cekilKayip"];
};
_p
