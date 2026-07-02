export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      card_events: {
        Row: {
          card_id: string
          coarse_geo: string | null
          id: number
          occurred_at: string
          referrer: string | null
          type: Database["public"]["Enums"]["card_event_type"]
        }
        Insert: {
          card_id: string
          coarse_geo?: string | null
          id?: never
          occurred_at?: string
          referrer?: string | null
          type: Database["public"]["Enums"]["card_event_type"]
        }
        Update: {
          card_id?: string
          coarse_geo?: string | null
          id?: never
          occurred_at?: string
          referrer?: string | null
          type?: Database["public"]["Enums"]["card_event_type"]
        }
        Relationships: [
          {
            foreignKeyName: "card_events_card_id_fkey"
            columns: ["card_id"]
            isOneToOne: false
            referencedRelation: "cards"
            referencedColumns: ["id"]
          },
        ]
      }
      card_fields: {
        Row: {
          card_id: string
          id: string
          label: string
          sort_order: number
          type: Database["public"]["Enums"]["card_field_type"]
          value: string
        }
        Insert: {
          card_id: string
          id?: string
          label: string
          sort_order?: number
          type: Database["public"]["Enums"]["card_field_type"]
          value: string
        }
        Update: {
          card_id?: string
          id?: string
          label?: string
          sort_order?: number
          type?: Database["public"]["Enums"]["card_field_type"]
          value?: string
        }
        Relationships: [
          {
            foreignKeyName: "card_fields_card_id_fkey"
            columns: ["card_id"]
            isOneToOne: false
            referencedRelation: "cards"
            referencedColumns: ["id"]
          },
        ]
      }
      cards: {
        Row: {
          accent_color: string
          company: string | null
          cover_url: string | null
          created_at: string
          display_name: string
          id: string
          is_active: boolean
          label: string
          logo_url: string | null
          owner_id: string
          photo_url: string | null
          slug: string
          theme: string
          title: string | null
          visibility: Database["public"]["Enums"]["card_visibility"]
        }
        Insert: {
          accent_color?: string
          company?: string | null
          cover_url?: string | null
          created_at?: string
          display_name: string
          id?: string
          is_active?: boolean
          label?: string
          logo_url?: string | null
          owner_id: string
          photo_url?: string | null
          slug: string
          theme?: string
          title?: string | null
          visibility?: Database["public"]["Enums"]["card_visibility"]
        }
        Update: {
          accent_color?: string
          company?: string | null
          cover_url?: string | null
          created_at?: string
          display_name?: string
          id?: string
          is_active?: boolean
          label?: string
          logo_url?: string | null
          owner_id?: string
          photo_url?: string | null
          slug?: string
          theme?: string
          title?: string | null
          visibility?: Database["public"]["Enums"]["card_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "cards_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      connections: {
        Row: {
          card_id: string
          coarse_geo: string | null
          company: string | null
          created_at: string
          email: string | null
          first_name: string | null
          id: string
          last_name: string | null
          name: string
          note: string | null
          phone: string | null
        }
        Insert: {
          card_id: string
          coarse_geo?: string | null
          company?: string | null
          created_at?: string
          email?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          name: string
          note?: string | null
          phone?: string | null
        }
        Update: {
          card_id?: string
          coarse_geo?: string | null
          company?: string | null
          created_at?: string
          email?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          name?: string
          note?: string | null
          phone?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "connections_card_id_fkey"
            columns: ["card_id"]
            isOneToOne: false
            referencedRelation: "cards"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string | null
          id: string
        }
        Insert: {
          created_at?: string
          display_name?: string | null
          id: string
        }
        Update: {
          created_at?: string
          display_name?: string | null
          id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      get_public_card: {
        Args: { p_slug: string }
        Returns: Database["public"]["CompositeTypes"]["public_card"]
        SetofOptions: {
          from: "*"
          to: "public_card"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      record_card_event: {
        Args: {
          p_coarse_geo?: string
          p_slug: string
          p_type: Database["public"]["Enums"]["card_event_type"]
        }
        Returns: undefined
      }
      record_connection: {
        Args: {
          p_coarse_geo?: string
          p_company?: string
          p_email?: string
          p_first_name?: string
          p_last_name?: string
          p_name?: string
          p_note?: string
          p_phone?: string
          p_slug: string
        }
        Returns: undefined
      }
      slug_available: { Args: { p_slug: string }; Returns: boolean }
    }
    Enums: {
      card_event_type: "view" | "tap" | "save" | "share"
      card_field_type:
        | "phone"
        | "email"
        | "url"
        | "social"
        | "address"
        | "custom"
      card_visibility: "public" | "unlisted" | "private"
    }
    CompositeTypes: {
      public_card: {
        display_name: string | null
        title: string | null
        company: string | null
        theme: string | null
        accent_color: string | null
        cover_url: string | null
        logo_url: string | null
        photo_url: string | null
        fields: Json | null
      }
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      card_event_type: ["view", "tap", "save", "share"],
      card_field_type: ["phone", "email", "url", "social", "address", "custom"],
      card_visibility: ["public", "unlisted", "private"],
    },
  },
} as const

