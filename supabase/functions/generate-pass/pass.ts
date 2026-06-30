export interface PassCard {
  id: string; slug: string; display_name: string;
  title?: string | null; company?: string | null; accent_color: string;
}
export interface PassField { type: string; label: string; value: string; sort_order: number }

function rgb(hex: string): string {
  const s = hex.replace("#", "");
  const v = parseInt(s.length === 3 ? s.split("").map((c) => c + c).join("") : s, 16);
  const r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
  return `rgb(${r}, ${g}, ${b})`;
}

export function buildPassJSON(card: PassCard, fields: PassField[], passTypeId: string, teamId: string) {
  const sorted = [...fields].sort((a, b) => a.sort_order - b.sort_order);
  const secondary: { key: string; label: string; value: string }[] = [];
  if (card.title) secondary.push({ key: "title", label: "Titel", value: card.title });
  if (card.company) secondary.push({ key: "company", label: "Firma", value: card.company });
  const auxiliary = sorted.map((f, i) => ({ key: `f${i}`, label: f.label, value: f.value }));
  return {
    formatVersion: 1,
    passTypeIdentifier: passTypeId,
    teamIdentifier: teamId,
    organizationName: "AtollCard",
    description: "AtollCard",
    serialNumber: card.id,
    backgroundColor: rgb(card.accent_color || "#0E7C86"),
    foregroundColor: "rgb(255, 255, 255)",
    labelColor: "rgb(255, 255, 255)",
    barcodes: [{
      format: "PKBarcodeFormatQR",
      message: `https://card.atoll-os.com/${card.slug}`,
      messageEncoding: "iso-8859-1",
    }],
    generic: {
      primaryFields: [{ key: "name", label: "", value: card.display_name }],
      secondaryFields: secondary,
      auxiliaryFields: auxiliary,
    },
  };
}
