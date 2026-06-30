import { assertEquals, assert } from "jsr:@std/assert@1";
import { buildPassJSON } from "./pass.ts";

const card = {
  id: "cccccccc-0000-0000-0000-000000000001", slug: "jane-doe",
  display_name: "Jane Doe", title: "CTO", company: "Acme", accent_color: "#0E7C86",
};
const fields = [{ type: "email", label: "Work", value: "jane@acme.com", sort_order: 0 }];

Deno.test("buildPassJSON maps card + QR + colors", () => {
  const p = buildPassJSON(card, fields, "pass.swiss.atoll.card.persona", "XK8V89P2QV");
  assertEquals(p.passTypeIdentifier, "pass.swiss.atoll.card.persona");
  assertEquals(p.teamIdentifier, "XK8V89P2QV");
  assertEquals(p.serialNumber, card.id);
  assertEquals(p.barcodes[0].message, "https://card.atoll-os.com/jane-doe");
  assertEquals(p.barcodes[0].format, "PKBarcodeFormatQR");
  assertEquals(p.generic.primaryFields[0].value, "Jane Doe");
  assert(p.backgroundColor.startsWith("rgb("));
});
