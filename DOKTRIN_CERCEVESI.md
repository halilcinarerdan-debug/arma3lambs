# Doktrin cercevesi (global temel)

Amac: her ordunun taktik degerleri KENDI profilinde yasar; kod ortaktir. Yeni ordu eklemek = veri eklemek.

## Mimari
```
fnc_doktrin  -> grubun fraksiyonundan profili cozer (GENEL -> ust profil -> ordu), grupta onbellekler, [DOKTRIN-PROFIL] loglar
fnc_dk       -> tek anahtar okur:  [_grup, "anahtar", varsayilan] call lambs_danger_fnc_dk
```
Davranis kodu (commanderAssess, tacticsBounding, tacticsRetreat, tacticalUGL, rearGuard) sabit sayi yerine `fnc_dk` okur.
Varsayilan deger = eski sabit => profil yoksa / "GENEL" ise davranis degismez.

## Anahtarlar (varsayilan)
| Anahtar | Varsayilan | Anlami |
|---|---|---|
| assaultM | 45 | Ustunken bu mesafenin altinda duz hucum, ustunde bounding |
| bndBitisM | 40 | Bounding bu mesafede hucuma devreder |
| bantlar | [[200,70,15],[100,40,12],[0,25,8]] | Bound bantlari: [dusman mesafesi >, atilim max m, kazanc min m] |
| owKurulumS | 5 | Overwatch kurulum tavani (sn) |
| bndMaxCycle | 10 | Bir bounding'de en fazla cycle |
| retreatAdim | [20,30,50] | Cekilme sicrama boyu [<100 m, 100-200 m, >200 m] |
| cekilKayip | 0.4 | Bu kayip oraninda WITHDRAW |
| peelOran / peelKayip | 1.6 / 0.1 | Guc dezavantaji + kayip -> PEEL |
| kucukEkip / yakinM | 3 / 60 | Kucuk ekip veya yakin dusman: kosarak kacma yerine DELAY |
| uglUzakM / uglUzakAralik | 200 / 25 | Uzak 40mm atis araligi |
| uglRezerv / uglRezervM | 3 / 120 | Mermi rezervi ve uzak atis siniri |
| arkaGuvenlik / arkaGuvenlikMinKisi | true / 6 | CQB arka guvenlik askeri |

## Profil kalitimi
`GENEL` (taban) -> ust profil -> ordu. Alt profil yalnizca farkli degerleri yazar. Ornek: `ABD` ust profili `USMC`.

Yerlesik profiller: GENEL, USMC, ABD, RUS, CHN, PESHMERGA.
**Degerler baslangic tahminleridir** (genel bilgi, yaklasik); nizamnamelerle (FM 3-21.8 / MCWP, Rus ve Cin piyade nizamnameleri,
Peshmerge uygulamalari) dogrulanip duzeltilmelidir.

## Yeni ordu ekleme (kod degistirmeden, misyon init)
```sqf
lambs_danger_doktrinTanimlari = [
    ["ORDUM", "GENEL", [["assaultM", 55], ["bantlar", [[200,60,12],[100,40,10],[0,30,8]]], ["cekilKayip", 0.35]]]
];
lambs_danger_doktrinHaritasi = [
    ["rhs_faction_xyz", "ORDUM"]      // faction (kucuk harf) veya sinif adi parcasi, ilk eslesen kazanir
];
```
Ayni adli misyon tanimi yerlesik profilin USTUNE yazar (son tanim kazanir).

## Sirada (ayni mekanizmayla)
Formasyon tercihleri, komuta stili (merkezi / merkezsiz, lider konumu), ates disiplini, RPG/UGL politikasi, kayip psikolojisi,
takim yapisi (4'lu ekip, 3'lu hucum hucresi), arac-piyade is birligi.
