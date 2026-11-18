# Doktrin varsayılan tablosu (v8.602, genel bilgiye göre; sayfa kaynağı DOĞRULANMADI)

Amaç: CBA ayarlarının **varsayılanlarını** doktrine / gerçekçiliğe uygun hale getirmek için öneri tablosu. Bu belge **salt öneridir**: kodda hiçbir varsayılan değişmedi.

## Etiketler

- `[K]` kaynak setinde (TC 3-21.76, MCWP 3-11.1 / 3-11.2, ATP 3-21.8, FM 3-34 ...) var (dosya + satır, `KITABA_UYGUNLUK_DENETIMI.md` yöntemiyle doğrulanır).
- `[K~]` kavram kitapta var, sayı / ayrıntı tasarım.
- `[G]` **genel bilgi**: bu oturumda kitap sayfasıyla DOĞRULANMADI; sayı / ilke genel askeri bilgidir. PDF gelirse `[K]`'ye çevrilir ya da düzeltilir.
- `[T]` tasarım tahmini, kitapta karşılığı yok. `[U]` kullanıcı kararı (kitaptan bilerek sapar).

## İlke: iki profil

- **Doktrin (varsayılan):** hile yok (nişan hatası düzeltme, kusursuz algı, hız artışı yok), kitap sayıları, insani eşikler.
- **Zor (üstüne biner):** `isabetSeviye`, `isabetYardim`, `animHiz`, `dusunHizi`, düşük bilgi eşikleri, teslim kapalı... (mevcut 'acımasız' / 'en zor' dosyaları). Varsayılan ASLA zorluk düğmesi içermez.

## İncelenen ayarlar (21 / 215)

| Ayar | Şimdi | Öneri | Değişir mi | Etiket | Gerekçe |
|---|---|---|---|---|---|
| `bombaMinM` | 8 | 15 | **evet** | [G] | El bombasi (M67 sinifi) olum yaricapi ~5 m, yaralanma yaricapi ~15 m; ACE frag + yansima acikken atici / dost icin guvenli en kisa mesafe en az yaralanma yaricapi. Eski 8 m kendi grubunu vurma riski (RPT 38ac1efc). |
| `bombaDostM` | 18 | 20 | **evet** | [G] | Yaralanma yaricapi 15 m + 5 m pay: hedefin 20 m icinde dost varsa atma. |
| `elBombasiMaxMesafe` | 40 | 35 | **evet** | [G] | Egitimli askerin el bombasi etkili atis mesafesi ~35-40 m; 35 muhafazakar. |
| `animHiz` | 20 | 0 | **evet** | [T] | Gercek disi hiz artisi = zorluk dugmesi, doktrin degil; Doktrin profilinde kapali (Zor profilinde acilir). |
| `dusunHizi` | 1.25 | 1.0 | **evet** | [T] | Karar dongusu sikligi zorluk / performans dugmesi; Doktrin profilinde 1. |
| `dusunHiziOnemli` | 1.3 | 1.0 | **evet** | [T] | Ayni; Doktrin profilinde 1. |
| `isabetSeviye` | 0 | 0 | hayır | [U] | Nisan hatasi duzeltme = hile benzeri; Doktrin profilinde kapali (kullanici karari: yalniz Zor profilinde). |
| `isabetYardim` | 0 | 0 | hayır | [U] | Ayni. |
| `coverHugMesafe` | 0.17 | 0.3 | **evet** | [K~] | Dogrudan yaklasma: siperin arkasinda yuzeye 30-50 cm kala dur (parca / sekme / yuzey vurusu tam dayanmayi cezalandirir); kodun kendi basligindaki ilke. 0.17 kullanici tercihiydi (Zor profili). |
| `siperDusuk` | 1 | 0 | **evet** | [T] | Hull-down: gizli en yuksek durus; baski altinda zaten bir kademe alcalir. Ek alcaltma Zor profilinde. |
| `aciktaGizlen` | true | true | hayır | [G] | Arazi ortusu (olu alan) / yatis: ortuculuk ve gizlenme temel ilkesi; kapali haritada etkisi yok. |
| `bndAgresif` | 2 | 1 | **evet** | [T] | Bounding temposu: dengeli; agresif Zor profilinde (kitapta tek bir tempo yok). |
| `bastirmaYogunluk` | 0.5 | 0.5 | hayır | [K~] | Bastirici ates + manevra ilkesi kitapta (TC 3-21.76 / MCWP 3-11.1); sayi tasarim, mermi ekonomisi korunur. |
| `baskiEtki` | 0.5 | 0.5 | hayır | [G] | Baski altinda isabet kaybi gercekci; 0 hile (korkusuzluk). |
| `ozguven` | 0.5 | 0.5 | hayır | [T] | Moral / courage tabani; yukseltme Zor profilinde. |
| `binaSaldiri` | true | true | hayır | [K~] | Kapi yaninda yigilma, eszamanli giris, oda oda temizleme kitapta (TC 3-21.76 'enter and clear a room'); saldiri tetigi tasarim. |
| `binaGirisBomba` | true | true | hayır | [G] | Giris oncesi el bombasi ROE'ye bagli doktrinel secenek; binada SIVIL yoksa. Kod su an sivil denetimi yapmiyor: acik riski (kod ihtiyaci). |
| `binaPusu` | 90 | 90 | hayır | [T] | Temizlenen odada pusu / guvenlik: kitapta 'temizlendi, emniyet' var, pusu suresi tasarim. |
| `teslimEast` | true | true | hayır | [G] | Teslim olani kabul (Kara Harekati Hukuku); teslim kapali = hile benzeri direnc. |
| `teslimInd` | true | true | hayır | [G] | Ayni. |
| `penetreM` | 60 | 60 | hayır | [T] | Gorunmeyen ama bilinen konuma ates (ortuye ates) mesafesi; tasarim. |

## Kalan ayarlar (194)

İncelenmedi: ya doğrudan kitap tablosundan gelen sayılar (`SAYISAL_ESIKLER_KAYNAK_TABLOSU.md`, `KITABA_UYGUNLUK_DENETIMI.md`) ya da altyapı / arayüz ayarları. Bu belgede değiştirilmesi önerilmedi.

## Bilinen çelişki / kod ihtiyacı

- **Giriş bombası:** `fnc_buildingClearRun` başlığı 'Bombalı giriş YOK (ROE / sivil riski)' diyor, v8.599 `fnc_girisBombasi` ise atıyor. Doktrin ROE'ye bağlı **izin verir**; güvenli çözüm: binada bilinen / yakın SİVİL yoksa at. Kod şu an sivil denetimi yapmıyor `[G]`.
- **Hızlı düşünme / animasyon hızı:** doktrin dışı zorluk düğmeleri; Doktrin profilinde kapalı.

## Sonraki adım

1. Onaydan sonra: yukarıdaki 'değişir' satırları `XEH_PREP.hpp` varsayılanına işlenir + `Zor` profili ayrı dosya olarak verilir (yeni sürüm).
2. PDF gelirse (FM 3-23.30, ATP 3-06 / MCWP 3-35.3, ATP 3-21.8 tam metin): `[G]` satırları sayfa numarasıyla `[K]` / `[K~]` yapılır.
3. Hiçbiri oyunda doğrulanmadı.
