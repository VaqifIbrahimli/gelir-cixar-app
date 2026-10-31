# Baku transport data: sources

Data file: `baku.json` (verifiedAt 2026-10-31). All sources accessed on the date shown.

Method: the bus list, terminals, fares and operators come from AYNA's public route-map API (no login; robots.txt allows all). The API data is partly out of date (its system settings report updateDate 2025-05-07, and several fares are older than AYNA announcements), so fares and routes announced in AYNA news from Sept 2025 to Oct 2026 override the API values. Metro stations come from metro.gov.az line pages. The metro fare has been 0.60 AZN since 2025-10-01 (AYNA, APA).

| # | Source | URL | Accessed |
|---|---|---|---|
| 1 | AYNA bus route map API: route list (getBusList) | https://map-api.ayna.gov.az/api/bus/getBusList | 2026-10-31 |
| 2 | AYNA bus route map API: route detail (getBusById?id=N, ids 1-209) | https://map-api.ayna.gov.az/api/bus/getBusById?id=1 | 2026-10-31 |
| 3 | AYNA bus route map (front end) | https://map.ayna.gov.az/ | 2026-10-31 |
| 4 | AYNA: Yeni tariflər sistemi tətbiq olundu (2025-09-29) | https://ayna.gov.az/az/news/yeni-tarifler-sistemi-tetbiq-olundu-874 | 2026-10-31 |
| 5 | Fed.az: AYNA list of routes with raised fares (2025-09-29) | https://fed.az/az/neqliyyat/avtobus-metroda-qiymet-deyismesi-ile-bagli-ayna-nin-aciqlamasi-si%CC%87yahi-241494 | 2026-10-31 |
| 6 | APA: New bus and metro fares in Baku to take effect from October 1 (2025-09-29) | https://en.apa.az/infrastructure/new-bus-and-metro-fares-in-baku-to-take-effect-from-october-1-479105 | 2026-10-31 |
| 7 | AYNA: 594 və 595 ekspres marşrutlarında qiymət dəyişikliyi (2026-01-13) | https://ayna.gov.az/az/news/594-ve-595-nomreli-ekspres-marsrutlarinda-qiymet-deyisikliyi-992 | 2026-10-31 |
| 8 | Modern.az: Fare on Baku-Sumgayit buses increased (2026-01-13) | https://modern.az/en/country/557242/fare-on-baku-sumgayit-buses-increased/ | 2026-10-31 |
| 9 | AYNA: 218 nömrəli yeni marşrut (2026-10-16) | https://ayna.gov.az/az/news/218-nomreli-yeni-marsrut-xetti-istifadeye-verilir-1259 | 2026-10-31 |
| 10 | AYNA: 156 və 156A (2026-10-29) | https://ayna.gov.az/az/news/156-ve-156a-nomreli-muntezem-marsrutlar-uzre-avtobuslar-yenilenir-1268 | 2026-10-31 |
| 11 | AYNA: 92 (2026-10-13) | https://ayna.gov.az/az/news/92-nomreli-marsrutun-butun-avtobuslari-yenilenir-1255 | 2026-10-31 |
| 12 | AYNA: 199 (2026-08-31) | https://ayna.gov.az/az/news/199-nomreli-marsrutun-butun-avtobuslari-deyisdirilir-1206 | 2026-10-31 |
| 13 | AYNA: 51 və 118A (2026-08-03) | https://ayna.gov.az/az/news/51-ve-118a-nomreli-marsrutlar-uzre-avtobuslar-yenilenir-1180 | 2026-10-31 |
| 14 | AYNA: 135 (2026-07-31) | https://ayna.gov.az/az/news/135-nomreli-marsrutun-avtobuslari-deyisdirilir-1179 | 2026-10-31 |
| 15 | AYNA: 195E (2026-07-27) | https://ayna.gov.az/az/news/195e-nomreli-ekspres-marsrutu-fealiyyete-baslayir-1175 | 2026-10-31 |
| 16 | AYNA: 525A/525B/524 (2026-07-17) | https://ayna.gov.az/az/news/525-nomreli-marsrutun-fealiyyeti-tekmillesdirilir-1167 | 2026-10-31 |
| 17 | AYNA: 150E Koroğlu - Sea Breeze (2026-07-17) | https://ayna.gov.az/az/news/koroglu-nmm-i-sea-breeze-ile-elaqelendiren-ekspres-marsrutu-fealiyyete-baslayir-1166 | 2026-10-31 |
| 18 | AYNA: 39 (2026-07-15) | https://ayna.gov.az/az/news/39-nomreli-marsrutun-hereket-sxemi-ve-avtobuslari-deyisdirilir-1163 | 2026-10-31 |
| 19 | AYNA: 77 və 91 (2026-06-30) | https://ayna.gov.az/az/news/77-ve-91-nomreli-marsrutlar-uzre-avtobuslar-deyisdirilir-1151 | 2026-10-31 |
| 20 | AYNA: 214 və 214A (2026-06-30) | https://ayna.gov.az/az/news/214-ve-214a-nomreli-marsrut-xetlerinde-muasir-avtobuslar-fealiyyet-gosterecek-1149 | 2026-10-31 |
| 21 | AYNA: 149E (2026-06-19) | https://ayna.gov.az/az/news/149e-nomreli-ekspres-marsrutu-fealiyyete-baslayir-1140 | 2026-10-31 |
| 22 | AYNA: 22 (2026-06-16) | https://ayna.gov.az/az/news/22-nomreli-marsrut-uzre-butun-avtobuslar-yenilenir-1135 | 2026-10-31 |
| 23 | AYNA: 107 və 107A (2026-06-02) | https://ayna.gov.az/az/news/107-ve-107a-nomreli-marsrutlar-uzre-sernisinlere-muasir-avtobuslar-xidmet-gosterecek-1125 | 2026-10-31 |
| 24 | AYNA: 161 və 162 (2026-06-01) | https://ayna.gov.az/az/news/161-ve-162-nomreli-marsrutlar-uzre-muasir-avtobuslar-sernisinlere-xidmet-gosterir-1121 | 2026-10-31 |
| 25 | AYNA: 119 (2026-05-31) | https://ayna.gov.az/az/news/119-nomreli-muntezem-marsrutun-avtobuslari-deyisdirilir-1119 | 2026-10-31 |
| 26 | AYNA: 79 (2026-05-31) | https://ayna.gov.az/az/news/79-nomreli-marsrutun-butun-avtobuslar-yenilenir-1118 | 2026-10-31 |
| 27 | AYNA: 102 və 191 (2026-05-14) | https://ayna.gov.az/az/news/102-ve-191-nomreli-muntezem-marsrutlar-uzre-avtobuslar-yenilenir-1097 | 2026-10-31 |
| 28 | AYNA: 45 (2026-05-12) | https://ayna.gov.az/az/news/45-nomreli-muntezem-marsrutun-avtobuslari-yenilenir-1095 | 2026-10-31 |
| 29 | AYNA: 185 (2026-05-01) | https://ayna.gov.az/az/news/185-nomreli-muntezem-marsrutun-avtobuslari-deyisdirilir-1087 | 2026-10-31 |
| 30 | AYNA: 142 (2026-04-30) | https://ayna.gov.az/az/news/142-nomreli-marsrutun-avtobuslari-yenilenir-1086 | 2026-10-31 |
| 31 | AYNA: 140A (2026-04-23) | https://ayna.gov.az/az/news/140a-nomreli-marsrut-nagdsiz-odenis-sistemine-kecir-1077 | 2026-10-31 |
| 32 | AYNA: 53 (2026-04-21) | https://ayna.gov.az/az/news/53-nomreli-seherdaxili-marsrut-uzre-butun-avtobuslar-yenilenir-1075 | 2026-10-31 |
| 33 | AYNA: 41 (2026-03-19) | https://ayna.gov.az/az/news/41-nomreli-marsrut-nagdsiz-odenis-sistemine-kecir-1053 | 2026-10-31 |
| 34 | AYNA: 202 (2026-03-17) | https://ayna.gov.az/az/news/202-nomreli-marsrutun-avtobuslari-yenilenir-1048 | 2026-10-31 |
| 35 | AYNA: 49 (2026-03-07) | https://ayna.gov.az/az/news/49-nomreli-marsrutun-avtobuslari-yenilenir-1039 | 2026-10-31 |
| 36 | AYNA: 569 (2026-02-27) | https://ayna.gov.az/az/news/569-nomreli-marsrut-xettinde-avtobuslar-deyisir-1030 | 2026-10-31 |
| 37 | AYNA: 67 (2026-02-24) | https://ayna.gov.az/az/news/67-nomreli-marsrutun-avtobuslari-yenilenir-1026 | 2026-10-31 |
| 38 | AYNA: 214A (2026-02-21) | https://ayna.gov.az/az/news/214a-nomreli-marsrut-xetti-istifadeye-verilir-1025 | 2026-10-31 |
| 39 | AYNA: 206 (2026-02-10) | https://ayna.gov.az/az/news/206-nomreli-marsrut-uzre-muasir-avtobuslar-sernisinlere-xidmet-gosterecek-1015 | 2026-10-31 |
| 40 | AYNA: 146 (2025-12-05) | https://ayna.gov.az/az/news/146-nomreli-marsrutda-istismar-olunan-avtobuslar-yenilenir-956 | 2026-10-31 |
| 41 | AYNA: 36 (2025-12-05) | https://ayna.gov.az/az/news/36-nomreli-marsrutda-muasir-avtobuslar-sernisinlere-xidmet-gosterecek-955 | 2026-10-31 |
| 42 | AYNA: 12 (2025-12-05) | https://ayna.gov.az/az/news/12-nomreli-marsrutda-ekoloji-temiz-avtobuslar-sernisinlerin-ixtiyarina-verilir-954 | 2026-10-31 |
| 43 | AYNA: 31 (2025-12-01) | https://ayna.gov.az/az/news/31-nomreli-marsrutda-istismar-olunan-butun-avtobuslar-yenilenir-947 | 2026-10-31 |
| 44 | AYNA: 500 (2025-11-10) | https://ayna.gov.az/az/news/sumqayit-seherini-paytaxtla-elaqelendiren-500-nomreli-marsrut-xetti-istifadeye-verilir-923 | 2026-10-31 |
| 45 | AYNA: 71 (2025-11-06) | https://ayna.gov.az/az/news/71-nomreli-marsrut-uzre-muasir-avtobuslar-sernisinlere-xidmet-gosterecek-921 | 2026-10-31 |
| 46 | AYNA: 81 və 160 (2025-10-31) | https://ayna.gov.az/az/news/81-ve-160-nomreli-marsrutlar-uzre-avtobuslar-deyisdirilir-914 | 2026-10-31 |
| 47 | AYNA: 53 (2025-10-31) | https://ayna.gov.az/az/news/53-nomreli-marsrut-uzre-muasir-avtobuslar-sernisinlere-xidmet-gosterecek-913 | 2026-10-31 |
| 48 | AYNA: 503 (2025-10-31) | https://ayna.gov.az/az/news/503-nomreli-muntezem-marsrutun-hereket-sxemi-deyisdirilir-912 | 2026-10-31 |
| 49 | AYNA: E2 (2025-10-16) | https://ayna.gov.az/az/news/e2-nomreli-ekspres-marsrut-xetti-istifadeye-verilir-895 | 2026-10-31 |
| 50 | AYNA: 93 (2025-10-13) | https://ayna.gov.az/az/news/93-nomreli-marsrutun-avtobuslari-yenilenir-890 | 2026-10-31 |
| 51 | AYNA: 340 (2025-09-23) | https://ayna.gov.az/az/news/340-nomreli-muntezem-avtobus-marsrutu-fealiyyete-baslayir-866 | 2026-10-31 |
| 52 | AYNA: Metro xətlərinin ayrılması - dəstəkləyici tədbirlər (2026-08-04) | https://ayna.gov.az/az/news/metro-xetlerinin-ayrilmasi-ile-bagli-ayna-nin-destekleyici-tedbirleri-1182 | 2026-10-31 |
| 53 | AYNA: 6 yeni ekspres marşrutu (M1-M6) (2026-08-13) | https://ayna.gov.az/az/news/6-yeni-ekspres-marsrutu-avqustun-14-den-fealiyyete-baslayir-1192 | 2026-10-31 |
| 54 | AYNA: Ödənişsiz Avtovağzal və Xocəsən metrostansiyaları (2026-09-22) | https://ayna.gov.az/az/news/odenissiz-fealiyyet-gosterecek-avtovagzal-ve-xocesen-metrostansiyalarinin-qarsisinda-avtobuslar-ucun-araliq-dayanacaq-menteqesi-yaradilib-1231 | 2026-10-31 |
| 55 | Bakı Metropoliteni: Qırmızı xətt | https://metro.gov.az/az/about-lines/2 | 2026-10-31 |
| 56 | Bakı Metropoliteni: Yaşıl xətt | https://metro.gov.az/az/about-lines/3 | 2026-10-31 |
| 57 | Bakı Metropoliteni: Bənövşəyi xətt | https://metro.gov.az/az/about-lines/7 | 2026-10-31 |
