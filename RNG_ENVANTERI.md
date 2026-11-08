# RASTGELELIK ENVANTERI (v8.500x; Asama 7 adim 1 hazirligi)

Amac: egitimde tekrarlanabilirlik. MIKRO boyut (gorunum / zaman sapmasi) BIRAKILIR; KARAR boyutu kurala ya da tohumlu akisa baglanir. Bu belge `grep` + elle okuma ile cikarildi; **kod degismedi**. Satir numaralari v8.500x'e gore, kaymis olabilir. Etiketler benim yargim; "V" olanlarin varsayilanini sen onaylamalisin (egitim degiskenligi karari senin).

Kisaltmalar: **K** = karar: olasilik yerine KURAL / ESIK (ayni durum = ayni karar). **V** = egitim degiskenligi: tohumlu, birim / sistem bazli akis, tohum `[ONUCUS] RUN` satirinda, CBA ile ayarlanir. **M** = mikro: dokunma (gorunum / senkron kirma). **T** = teknik (kimlik / esitlik bozucu): dokunma.

## K — kurala cevrilecek (karar sonucunu degistirir)
| Yer | Ne | Neden K |
|---|---|---|
| `fireSupport:70` | UGL atici `selectRandom` | Kim atar sonucu belirler; en uygun (hedefe en yakin / mermisi en cok) deterministik secilsin |
| `fireSupport:91` | UGL salvo %60 (acikta tek hedef) | Atilip atilmayacagi; esik kurali |
| `tacticalUGL:137` | UGL sans 0.92 (CBA `uglSans`) | Ayni; kurala ya da tohumlu V |
| `contact:105` | siper `selectRandom` | Siper puanla secilsin (kural), esitlikte tohumlu |
| `dronSakla:81` | saklanma hedefi `selectRandom` | Puanla |
| `devriyeAg:146` | rota skoru `+ random 15` | Rota karari; tohumlu tie-break |
| `tacticsAssault:143 / 145` | overwatch yolu / bina `selectRandom` | Konum karari; puanla |
| `atesHareket:244` | 'b' sikki olasiligi (CBA oran) | Hareket halinde ates karari; zor durum zaten kural, geri kalani V |

## V — egitim degiskenligi (tohumlu, birim bazli, CBA'dan ayarli)
| Yer | Ne | Not |
|---|---|---|
| `komutanZihin:45` | komutan kisiligi TEMKINLI / DENGELI / SALDIRGAN (taraf basina) | **Makro; en etkili.** Eğitmen secsin, "rastgele" ise tohumlu |
| `varsayilanSkill:121 / 146` | beceri araligi, acemi orani | Birim kimligine bagli tohumlu (ayni birim hep ayni beceri) |
| `panikFelc:174 / 184` | panik tetik olasiligi + tur | Egitim degiskeni; ayarli oran |
| `hqIstihbarat:116` | rapor kaybi (sis / menzil) | Gercekci istihbarat belirsizligi |
| `ihaSorti:565 / 566` | EW link kaybi, iska | Mevcut CBA `ihaEWOrani` |
| `dronTepki:277`, `tankDron:102`, `dronVurusOlasi` | dron vurus olasiligi | Mevcut CBA `dronIsabetOran` |
| `komutanZihin:84 / 85` | gozlem hatasi +-%6, +-8 derece | Sensor belirsizligi |
| `dronTepki:50`, `motorSes:101`, `patlayici:80 / 95` | yon / atis dagilimi hatasi | Gercekci dagilim; tohumlu |

## YAN SECIMI (sag / sol, `selectRandom [90, -90]` ve benzeri) — sonucu etkiler, birim bazli tohumlu
`moveAssist:205`, `fieldCraft:246`, `fireLine:140`, `rpgReaction:78`, `tankDron:134`, `istiksaf:46`, `sniperTeam:156`, `buildingClearRun:264`, `planZirh:403` (`[-50, 50, -25, 25]`), `reconArac:339 / 352` (`+-40`), `tacticsRetreat:685` (`+-55`), `gozcuRto:118`.
Oneri: ayni birim + ayni sistem = ayni yon (tohumlu), farkli birimler farkli yonu secer (dagilma korunur).

## M — mikro, dokunma
- Konum sapmasi (`getPos [random r, random 360]`): **106** kullanim (`agacGizlen`, `aracAtTepki` ...).
- Zaman / bekleme sapmasi (`contact:33 / 71 / 74 / 83`, `aracUzak:72`, `dronTopcu:193 / 199`, `tacticsFlank:135`, `tacticsHold:*`, `tacticsHide:116`, `tacticsGarrison:104`, `tacticsSuppress:113`, `hqIstihbarat:122 / 125`, `havaAA:95`, `devriyeAg:112`, `tacticsAssault:62`, `rpgReaction:77`, `baskiTufekci:60 (+random 2 tie-break)`).
- `tacticsBounding:1206` (`_BND_CYCLE_RAND`) bound suresi sapmasi: mikro-orta, bir sonraki turda gozlemle karar ver.
- Kozmetik: `tacticsHold:58` callout metni.

## T — teknik, dokunma
`buildingClearRun:40`, `tacticsBounding:84`, `koseTemkin:274` (benzersiz kimlik), `iedFarkindalik:229 / 381 / 383`, `rotaPlan:56` (esitlik bozucu).

## Siradaki adim (onay bekler)
1. `fnc_rastgele`: sayi = f(tohum, birim / grup kimligi, sistem etiketi, sayac) (global akis DEGIL: betik sirasi farkli olsa da ayni sonuc).
2. K grubunu kurala cevir (8 satir), V ve YAN SECIMI grubunu `fnc_rastgele`'ye bagla (~30 satir).
3. Tohum + egitim degiskenligi ayarlari CBA'ya; tohum `[ONUCUS] RUN` satirina.
4. Her degisiklikte `RPT` kabul olcutu + bayrak (`lambs_danger_rastgeleEskiOff`: eski davranisa donus).

## UYGULAMA DURUMU (v8.501)
- Altyapi: `fnc_tohumBaslat` (oncelik: senaryo degiskeni > CBA `lambs_danger_tohumAyar` > otomatik), `fnc_rastgele` (durumsuz / sayacli, 24-bit hash), `fnc_rastgeleSec` (tohumlu `selectRandom`), `fnc_birimId` (kosular arasi kararli kimlik). Tohum `[TOHUM]` ve `[ONUCUS] RUN` satirinda.
- Tasinan K: `fireSupport` UGL atici (KURAL: en uzun suredir atmayan), UGL salvo %60 (tohumlu), `tacticalUGL` sans (tohumlu), `contact` siper, `dronSakla` bina, `devriyeAg` rota skoru, `tacticsAssault` overwatch yolu / bina, `atesHareket` 'b' kapisi.
- Tasinan V: komutan kisiligi (CBA taraf basina RASTGELE / TEMKINLI / DENGELI / SALDIRGAN), beceri (durumsuz: ayni birim + ayni beceri = ayni deger) + acemi, panik tetik / tur, istihbarat rapor kaybi, EW / iska, dron vurus (`dronTepki`, `tankDron`).
- Tasinan yan secimleri (12): `moveAssist`, `fieldCraft`, `fireLine`, `rpgReaction`, `tankDron`, `istiksaf`, `sniperTeam`, `buildingClearRun`, `planZirh`, `reconArac` (x2), `tacticsRetreat`, `gozcuRto` bakis ofseti.
- KALAN: `komutanZihin:84 / 85` (gozlem hatasi), `dronTepki:50`, `motorSes:101`, `patlayici:80 / 95` (sensor / atis dagilimi, V), `cqbCevik` darbe olasiligi (mikro), `ihaGozlem:72`. Mikro (konum / zaman sapmasi) dokunulmadi.
- DOGRULANMADI (T): oyunda hic calistirilmadi. Hash Python'da simule edildi (20 000 ornek duzgun dagilim, tekrarlanabilir); SQF tarafi ilk calistirmada hata verebilir. Geri alma: `lambs_danger_rastgeleEskiOff = true` (motorun random'una doner; kisilik CBA'si ayri).
