import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(join(root, relativePath), "utf8");
}

function contains(source, required, label = required) {
  assert.ok(source.includes(required), label);
}

const core = read("iOSMerchandiseControl/ProductImportCore.swift");
const excel = read("iOSMerchandiseControl/ExcelSessionViewModel.swift");
const view = read("iOSMerchandiseControl/ImportAnalysisView.swift");
const tests = read("iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift");
const fixture = JSON.parse(
  read("tests/fixtures/supplier-import/android-canonical-sample.json"),
);

for (const key of fixture.publicKeysAudit.allowed) {
  contains(core, `static let ${key} = "${key}"`, `missing AndroidImportKey.${key}`);
}

for (const [legacy, canonical] of [
  ["stockquantity", "quantity"],
  ["suppliername", "supplier"],
  ["categoryname", "category"],
  ["prevpurchase", "oldPurchasePrice"],
  ["prevretail", "oldRetailPrice"],
]) {
  contains(core, `"${legacy}": AndroidImportKey.${canonical}`);
}

contains(core, "AndroidImportKey.allKeys.contains(trimmed)");
contains(core, "return \"\"");
contains(core, "let realQuantity = numeric(row[AndroidImportKey.realQuantity])");
contains(core, "return numeric(row[AndroidImportKey.quantity])");
contains(core, "pendingByBarcode[barcode] = PendingRow(");
contains(core, "rowErrorKeys.append(\"import.analysis.row_error.retail_required\")");
contains(core, "finalRetail = retail.value.map(roundPrice)");
assert.equal(core.includes("quantitySum"), false, "quantity summing must not exist");
assert.equal(core.includes("stockQuantity -> quantity"), false, "forbidden public key wording leaked into core contract");

contains(excel, "ExcelImportAnalysisTable");
contains(excel, "headerSource");
contains(excel, "applyHeuristics(");
contains(excel, "headerSource[columnIndex] = \"pattern\"");

contains(core, "static func calculatedRetailPrice(");
contains(core, "static func applyRetailMarkup(");
contains(view, "ProductImportCore.applyRetailMarkup(");

for (const requiredTest of [
  "testGoldenSupplierImportFixtureMatchesAndroidContract",
  "testHeaderlessSupplierRowsPromotePatternColumnsWithHeaderSource",
  "testDuplicateBarcodeUsesLastRowWithoutSummingQuantity",
  "testNewProductMissingRetailPriceBlocksApplyEvenWithItemNumber",
  "testRetailMarkupHelperFillsOnlyEmptyRetailPriceByDefault",
  "testLegacyImportAliasesNormalizeToAndroidCanonicalKeys",
  "testMappedRowsExposeOnlyAndroidCanonicalKeys",
]) {
  contains(tests, requiredTest);
}

for (const key of fixture.publicKeysAudit.forbidden) {
  assert.equal(
    fixture.previewRows.some((row) => Object.hasOwn(row, key)),
    false,
    `${key} leaked into fixture previewRows`,
  );
}

assert.ok(fixture.sheetRows.length > fixture.sampleRows.length);
assert.ok(fixture.blockedRows.some((row) => row.code === "missing_required_retail_price"));
assert.deepEqual(new Set(Object.keys(fixture.parseNumberResults)), new Set([
  "1.234,56",
  "1,234.56",
  "1234,56",
  "1234",
]));

console.log("IOS SUPPLIER IMPORT PARITY STATIC CHECK PASS");
