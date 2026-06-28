export type FieldType = 'phone' | 'email' | 'url' | 'social' | 'address' | 'custom'

export interface PublicField {
  type: FieldType
  label: string
  value: string
}

export interface PublicCard {
  display_name: string
  title: string | null
  company: string | null
  theme: string
  accent_color: string
  cover_url: string | null
  logo_url: string | null
  photo_url: string | null
  fields: PublicField[]
}
