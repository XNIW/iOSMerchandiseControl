# TASK088 iOS First Push

Data: 2026-05-09 13:10 -0400

## Tipo verifica

- `TEST`: XCTest mirato ProductPrice/manual sync.
- `RUNTIME`: launch iOS Debug su Simulator iPhone 16e iOS 26.2 con argomento `--task088-price-smoke-run`.
- `READ-BACK`: query Supabase read-only aggregata post runtime.
- Nessun token/JWT/refresh/service_role/connection string riportato.

## Patch usata dal runtime

- Runner DEBUG-only `SupabaseTask088ProductPriceSmokeService`, attivabile solo via `--task088-price-smoke-run` / `TASK088_PRICE_SMOKE_RUN=1`.
- Fixture SwiftData isolata in container in-memory per evitare push di righe locali non `TASK088_*`.
- Remote seed additivo e prefisso-scoped:
  - supplier `TASK088_SUPPLIER`
  - category `TASK088_CATEGORY`
  - product `TASK088_BAR_PRICE` / `TASK088_PRODUCT`
  - 4 ProductPrice con source/note `TASK088_*`

## Evidenza runtime

- Launch iOS eseguito su `iPhone 16e` iOS 26.2.
- Log di processo mostra traffico PostgREST con response `201` per insert e response `200` successive per read-back/verifiche.
- Il console summary `debugPrint` non e' comparso in `simctl launch --console`; per questo non viene usato come evidenza primaria.

## Read-back Supabase post push

| Metrica | Valore |
|---|---:|
| supplier exact | 1 |
| category exact | 1 |
| product exact | 1 |
| price rows collegate al product `TASK088_BAR_PRICE` | 4 |
| duplicate logical keys (`owner_user_id + product_id + type + effective_at`) | 0 |
| price rows con source/note `TASK088_*` | 4 |
| purchase last | 122.2 |
| purchase prev | 111.1 |
| retail last | 244.4 |
| retail prev | 211.1 |

## Esito

**PASS remoto / PASS test mirato**: primo push ProductPrice iOS ha creato 4 righe remote attese, senza duplicati logici.
