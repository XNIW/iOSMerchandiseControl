Admin Products exact-total final note

Valid browser evidence:
- Screenshot: docs/TASKS/EVIDENCE/TASK-136/screenshots/admin-products-page1-exact-total.png
- Runtime URL shown in browser: 127.0.0.1
- Selected shop UI: TASK068E REHEARSAL 260618231325 / Products
- Pagination range visible: 1-10 of 19,710 / Page 1 of 1971
- Exact total metric visible: 19,710
- Filtered exact total metric visible: 19,710
- Loaded lower bound metric visible separately: 11+
- Current page metric visible: 1-10
- Search scope metric visible: Server-side
- Catalog scope metric visible: Legacy mobile bridge

Interpretation:
- Admin Products no longer leaves "Exact total: Calculating..." indefinitely in the verified browser capture.
- The page still renders only the current page of 10 rows.
- The lower-bound state remains separate from the exact count, so 11+ is no longer presented as the catalog total.

Discarded attempt:
- A later Safari automation attempt on 2026-06-20 read the ChatGPT tab/start page instead of localhost and was removed from evidence. It must not be used as Admin proof.
