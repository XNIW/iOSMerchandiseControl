# TASK088 Baseline Counts

Data: 2026-05-09 12:48 -0400

## Tipo verifica

- `READ-ONLY`: query aggregata su progetto linked Supabase `merchandisecontrol-dev` tramite Supabase CLI.
- Nessuna write, nessun seed, nessun delete/truncate/drop/reset/wipe/cleanup.
- Output solo conteggi aggregati; nessun UUID owner, token, JWT, service_role o connection string.

## Collision scan richiesto

| Chiave | Conteggio |
|---|---:|
| `TASK088_SUPPLIER` in `inventory_suppliers.name` | 0 |
| `TASK088_CATEGORY` in `inventory_categories.name` | 0 |
| `TASK088_PRODUCT` in `inventory_products.product_name` | 0 |
| `TASK088_BAR_PRICE` in `inventory_products.barcode` | 0 |

## Baseline prefisso

| Metrica | Conteggio |
|---|---:|
| suppliers con `TASK088_%` | 0 |
| categories con `TASK088_%` | 0 |
| products con `TASK088_%` in barcode/name/item/second name | 0 |
| price rows collegate a product `TASK088_%` | 0 |
| price rows con source/note `TASK088_%` | 0 |

## Esito

**PASS**: nessuna collisione `TASK088_*` rilevata prima di seed/push.

Namespace previsto per runtime:

- supplier: `TASK088_SUPPLIER`
- category: `TASK088_CATEGORY`
- product name: `TASK088_PRODUCT`
- product barcode: `TASK088_BAR_PRICE`
- price source/note: `TASK088_*`
