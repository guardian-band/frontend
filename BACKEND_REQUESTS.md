# Backend Requests — Frontend Team

Bu dosya, frontend'den çözülemeyen ve backend tarafında iş gerektiren konuları
takip eder. Her madde `gb-go-main/openapi.yaml` ve ilgili handler'a atıf yapar.

---

## 1. İlaç kataloğunu genişletmek (öncelik: yüksek)

**Durum:** `api/database.go` içindeki tohum katalogda **5 ilaç** var (Parol,
Aspirin, Coraspin, Augmentin, Lipitor). Bunlardan yalnızca 3'ü etkileşim
modelinin kapsamında; Augmentin ve Lipitor değil.

**Etkisi:** Hasta iki *kapsanan* ilaç ekleyemediği sürece
`POST /api/medication-risk-analyses` hiç 200 dönemiyor. Kapsanan 3 girdiden
ikisi (Aspirin, Coraspin) aynı etken maddeyi taşıdığı için o ikisi birlikte
"distinct ingredient pair" hatası veriyor — yani pratikte tek çalışan
kombinasyon Parol + Aspirin/Coraspin.

**İstenen:** Katalog, modelin tanıdığı ilaçlarla genişletilsin.

### Modelin kapsadığı ilaçların kesin listesi

Model **347 DrugBank ID** tanıyor. Bu liste hiçbir dokümanda yok; model
release'inin içinden çıkarılıyor:

```bash
docker compose exec polypharmacy-ai python -c \
  "import numpy as np; z=np.load('/models/feature_artifact.npz'); print(list(z['drug_ids']))"
```

`medication_catalog_ingredients.ai_supported = TRUE` yalnızca bu listedeki
DrugBank ID'leri için verilmelidir; aksi hâlde analiz 422 döner.

<details>
<summary>347 desteklenen DrugBank ID</summary>

```
DB00176 DB00181 DB00182 DB00186 DB00191 DB00195 DB00196 DB00201 DB00203 DB00204
DB00205 DB00208 DB00210 DB00211 DB00213 DB00214 DB00215 DB00216 DB00222 DB00231
DB00238 DB00243 DB00244 DB00246 DB00250 DB00252 DB00257 DB00261 DB00262 DB00264
DB00268 DB00270 DB00277 DB00280 DB00281 DB00282 DB00285 DB00287 DB00289 DB00291
DB00297 DB00300 DB00303 DB00305 DB00307 DB00310 DB00313 DB00316 DB00317 DB00321
DB00323 DB00328 DB00331 DB00333 DB00334 DB00335 DB00338 DB00339 DB00341 DB00346
DB00350 DB00356 DB00358 DB00359 DB00363 DB00370 DB00371 DB00376 DB00379 DB00381
DB00393 DB00395 DB00398 DB00399 DB00401 DB00404 DB00408 DB00412 DB00419 DB00422
DB00423 DB00425 DB00426 DB00433 DB00435 DB00440 DB00442 DB00448 DB00450 DB00454
DB00455 DB00457 DB00458 DB00460 DB00461 DB00465 DB00472 DB00475 DB00476 DB00477
DB00480 DB00481 DB00482 DB00484 DB00489 DB00490 DB00499 DB00501 DB00502 DB00513
DB00524 DB00530 DB00531 DB00533 DB00537 DB00538 DB00540 DB00541 DB00543 DB00544
DB00545 DB00548 DB00549 DB00550 DB00555 DB00557 DB00559 DB00564 DB00570 DB00571
DB00575 DB00580 DB00582 DB00590 DB00593 DB00594 DB00598 DB00608 DB00612 DB00619
DB00621 DB00623 DB00630 DB00631 DB00632 DB00641 DB00648 DB00656 DB00658 DB00659
DB00661 DB00669 DB00672 DB00678 DB00683 DB00690 DB00691 DB00695 DB00697 DB00708
DB00710 DB00712 DB00718 DB00724 DB00726 DB00727 DB00732 DB00734 DB00737 DB00740
DB00745 DB00746 DB00749 DB00752 DB00753 DB00755 DB00761 DB00763 DB00776 DB00780
DB00784 DB00787 DB00794 DB00798 DB00799 DB00802 DB00804 DB00806 DB00808 DB00809
DB00813 DB00818 DB00819 DB00820 DB00822 DB00829 DB00841 DB00842 DB00843 DB00850
DB00853 DB00861 DB00862 DB00874 DB00879 DB00880 DB00882 DB00884 DB00887 DB00897
DB00899 DB00903 DB00904 DB00905 DB00909 DB00910 DB00915 DB00916 DB00918 DB00920
DB00924 DB00927 DB00934 DB00938 DB00945 DB00950 DB00951 DB00952 DB00953 DB00958
DB00960 DB00962 DB00966 DB00967 DB00969 DB00972 DB00973 DB00975 DB00976 DB00983
DB00990 DB00991 DB00993 DB00996 DB00998 DB00999 DB01001 DB01004 DB01005 DB01006
DB01007 DB01008 DB01009 DB01012 DB01016 DB01019 DB01020 DB01023 DB01026 DB01029
DB01032 DB01033 DB01035 DB01039 DB01041 DB01043 DB01044 DB01045 DB01050 DB01059
DB01062 DB01067 DB01068 DB01069 DB01072 DB01077 DB01088 DB01097 DB01101 DB01105
DB01110 DB01114 DB01115 DB01117 DB01124 DB01127 DB01128 DB01129 DB01132 DB01136
DB01143 DB01149 DB01151 DB01156 DB01159 DB01162 DB01165 DB01173 DB01181 DB01182
DB01188 DB01189 DB01193 DB01194 DB01198 DB01204 DB01205 DB01215 DB01217 DB01220
DB01221 DB01223 DB01224 DB01230 DB01233 DB01236 DB01238 DB01241 DB01242 DB01249
DB01254 DB01264 DB01267 DB01268 DB01275 DB01291 DB01319 DB01320 DB01339 DB01362
DB01589 DB01591 DB01595 DB01609 DB01610 DB01611 DB02530 DB04572 DB06700 DB09026
DB09110 DB09134 DB09153 DB09156 DB09389 DB11868 DB13919
```
</details>

### Doğrulanmış 12 ilaçlık öneri

Aşağıdaki DrugBank ID'lerinin her biri (a) Wikipedia/DrugBank'tan bağımsız
teyit edildi, (b) modelin 347'lik kümesinde olduğu doğrulandı. Marka adları
Türkiye pazarına göre seçildi — **etken madde eşlemeleri sizin tarafınızdan da
teyit edilmeli**, üretime girmeden önce.

| Marka | Doz | Etken madde | DrugBank |
|---|---|---|---|
| Brufen | 400mg | ibuprofen | DB01050 |
| Glucophage | 1000mg | metformin | DB00331 |
| Zocor | 20mg | simvastatin | DB00641 |
| Beloc | 50mg | metoprolol | DB00264 |
| Losec | 20mg | omeprazole | DB00338 |
| Pantpas | 40mg | pantoprazole | DB00213 |
| Lasix | 40mg | furosemide | DB00695 |
| Norvasc | 5mg | amlodipine | DB00381 |
| Cipro | 500mg | ciprofloxacin | DB00537 |
| Neurontin | 600mg | gabapentin | DB00996 |
| Prozac | 20mg | fluoxetine | DB00472 |
| Diazem | 5mg | diazepam | DB00829 |

Bu 12 kayıt, geliştirme veritabanına test amaçlı uygulandı (aşağıdaki SQL).
Kalıcı olması için `database.go` tohumuna eklenmesi gerekiyor.

<details>
<summary>Uygulanan SQL</summary>

```sql
INSERT INTO medication_catalog (id,name,strength) SELECT '7270c6e4-4cab-4edd-9af8-237301009e91','Brufen','400mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Brufen');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT 'a2f1fb66-40d7-4d74-88b7-a528c237062d','7270c6e4-4cab-4edd-9af8-237301009e91','ibuprofen','DB01050',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='7270c6e4-4cab-4edd-9af8-237301009e91');
INSERT INTO medication_catalog (id,name,strength) SELECT 'b28b9caa-7ed2-467f-8990-e5f3bfbcf0b6','Glucophage','1000mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Glucophage');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '541531d5-52c7-4f01-b822-4c69060d37ff','b28b9caa-7ed2-467f-8990-e5f3bfbcf0b6','metformin','DB00331',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='b28b9caa-7ed2-467f-8990-e5f3bfbcf0b6');
INSERT INTO medication_catalog (id,name,strength) SELECT 'c14909ac-68fd-4d2c-b6f9-fe07db875f61','Zocor','20mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Zocor');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '01649233-eb98-4ca7-9cc5-79bbe4b0abdc','c14909ac-68fd-4d2c-b6f9-fe07db875f61','simvastatin','DB00641',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='c14909ac-68fd-4d2c-b6f9-fe07db875f61');
INSERT INTO medication_catalog (id,name,strength) SELECT 'e2999ec1-9fa8-4d1f-ab66-d273628b872d','Beloc','50mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Beloc');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '26e21d35-719f-4498-80fe-cc56ad0bccdb','e2999ec1-9fa8-4d1f-ab66-d273628b872d','metoprolol','DB00264',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='e2999ec1-9fa8-4d1f-ab66-d273628b872d');
INSERT INTO medication_catalog (id,name,strength) SELECT '9f63ee91-f3c0-48ce-9c96-ac7a30a7d76b','Losec','20mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Losec');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '4de7e507-0a7b-4b31-8cdc-49c2dcb26dc6','9f63ee91-f3c0-48ce-9c96-ac7a30a7d76b','omeprazole','DB00338',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='9f63ee91-f3c0-48ce-9c96-ac7a30a7d76b');
INSERT INTO medication_catalog (id,name,strength) SELECT '47fa12b9-6d02-4a98-835a-eeee6734db24','Pantpas','40mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Pantpas');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '5d273711-6213-4898-9a10-45f39a3c1619','47fa12b9-6d02-4a98-835a-eeee6734db24','pantoprazole','DB00213',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='47fa12b9-6d02-4a98-835a-eeee6734db24');
INSERT INTO medication_catalog (id,name,strength) SELECT 'fe931c5c-7ad3-4750-b878-ba81cef949ff','Lasix','40mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Lasix');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '69b80c0b-33e5-4633-884a-2766b19b5d8f','fe931c5c-7ad3-4750-b878-ba81cef949ff','furosemide','DB00695',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='fe931c5c-7ad3-4750-b878-ba81cef949ff');
INSERT INTO medication_catalog (id,name,strength) SELECT '2078c71f-4e2c-4f43-98a3-1f8493fa7a8b','Norvasc','5mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Norvasc');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT 'f8f291b5-d0af-4f73-ae58-95d58c8130ad','2078c71f-4e2c-4f43-98a3-1f8493fa7a8b','amlodipine','DB00381',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='2078c71f-4e2c-4f43-98a3-1f8493fa7a8b');
INSERT INTO medication_catalog (id,name,strength) SELECT 'db1791ef-4e34-4144-ad75-d0e2bf7c0fd6','Cipro','500mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Cipro');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '8eadbc3c-717a-4417-b4ad-72f1a4744dee','db1791ef-4e34-4144-ad75-d0e2bf7c0fd6','ciprofloxacin','DB00537',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='db1791ef-4e34-4144-ad75-d0e2bf7c0fd6');
INSERT INTO medication_catalog (id,name,strength) SELECT 'fb81003c-7ec5-4667-a9af-d5725157bf43','Neurontin','600mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Neurontin');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '49b3dd9d-b31e-4878-b2c3-bb4ad2f4dcf8','fb81003c-7ec5-4667-a9af-d5725157bf43','gabapentin','DB00996',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='fb81003c-7ec5-4667-a9af-d5725157bf43');
INSERT INTO medication_catalog (id,name,strength) SELECT 'b72b45ba-a537-4000-9293-de572155004a','Prozac','20mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Prozac');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT 'e9ff1c92-6d87-44c5-a3ef-81552775de08','b72b45ba-a537-4000-9293-de572155004a','fluoxetine','DB00472',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='b72b45ba-a537-4000-9293-de572155004a');
INSERT INTO medication_catalog (id,name,strength) SELECT '8fd06071-bd5d-4afc-bd39-497e0639a43f','Diazem','5mg' WHERE NOT EXISTS (SELECT 1 FROM medication_catalog WHERE name='Diazem');
INSERT INTO medication_catalog_ingredients (id,catalog_item_id,ingredient_name,drugbank_id,ai_supported) SELECT '19949585-055f-4ca7-b01f-efb671eaedfa','8fd06071-bd5d-4afc-bd39-497e0639a43f','diazepam','DB00829',TRUE WHERE EXISTS (SELECT 1 FROM medication_catalog WHERE id='8fd06071-bd5d-4afc-bd39-497e0639a43f');
```
</details>

---

## 2. `GET /api/medications` NULL `instructions` ile 500 dönüyor

**Hata:**
```
sql: Scan error on column index 4, name "instructions":
converting NULL to string is unsupported
```

`schema.sql:134` — `instructions TEXT` (nullable), ama `api/medications.go:46`
düz `string`'e scan ediyor. **Talimatı olmayan tek bir ilaç, o hastanın ilaç
listesinin tamamını çökertiyor.** `POST /api/medications` boş instructions ile
kayıt oluşturabildiği için tetiklenmesi kolay.

**İstenen:** `sql.NullString` ile okunsun. `strength` de nullable, aynı kontrol
onun için de gerekli.

---

## 3. Şema migration'ı yok

`schema.sql` tamamen `CREATE TABLE IF NOT EXISTS`. Mevcut bir veritabanına
**yeni kolon eklenmiyor**. Güncel backend'i eski bir volume üzerinde çalıştıran
herkes şu hatayı alıyor:

```
pq: column "catalog_item_id" of relation "medications" does not exist
```

Eksik kolonlar tespit edildi ve geliştirme veritabanına elle eklendi:

```sql
ALTER TABLE medications ADD COLUMN catalog_item_id UUID REFERENCES medication_catalog(id) ON DELETE SET NULL;
ALTER TABLE patient_link_invitations ADD COLUMN share_phone_number BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE patient_relationships ADD COLUMN share_phone_number BOOLEAN NOT NULL DEFAULT FALSE;
```

**İstenen:** Yeni kolonlar için `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`
satırları ya da gerçek bir migration aracı.

---

## 4. AI servisi `compose.yaml`'daki yolda değil

`compose.yaml` → `polypharmacy-ai.build.context: ../ai`. Servis repo'su
`ai-main` adıyla geliyor ve model release ayrı bir zip. Doğru yerleşim:

```
ai/                  ← servis repo'su (Dockerfile, src/api/)
└── model-release/   ← model dosyaları (read-only mount)
```

**İstenen:** README veya `init-backend.md`'ye bu yerleşimin yazılması; aksi hâlde
herkes aynı şeyi elle çözüyor.
