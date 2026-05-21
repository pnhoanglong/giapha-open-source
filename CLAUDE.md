# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Gia Phả OS is a self-hosted Vietnamese family genealogy management system built with Next.js 16 and Supabase. It allows families to collaboratively manage their family tree with privacy-first design and Vietnamese cultural considerations (lunar calendar support, Vietnamese kinship terminology).

## Development Commands

```bash
# Install dependencies
bun install

# Development server (runs on http://localhost:3000)
bun run dev

# Production build
bun run build

# Start production server
bun run start

# Run linter
bun run lint
```

## Environment Setup

1. Copy `.env.example` to `.env.local`
2. Required environment variables:
   - `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` - Supabase anon/public key
   - `SITE_NAME` (optional) - Display name for the application

## Architecture

### Authentication & Authorization Flow

**Public Access**: The application allows unauthenticated users to view all family tree data (persons, relationships, custom_events) without requiring login. This enables easy sharing of family genealogy information.

**Three-Tier Role System (for editing):**
- **Admin**: Full system access including user management and data import/export (first registered user auto-becomes admin)
- **Editor**: Can create/edit/delete persons and relationships
- **Member**: Read-only access (same as unauthenticated users when logged in)

**Key Pattern**: Row-Level Security (RLS) is enforced at the Supabase database level using PostgreSQL policies:
- **Read access**: Open to everyone (authenticated or not) via `FOR SELECT USING (true)` policies
- **Write access**: Requires authentication and appropriate role (Admin or Editor) using `is_admin()` and `is_editor()` helper functions

**User Activation**: New users must be activated by an admin (`is_active` flag in `profiles` table) before they can perform write operations. Unauthenticated users and inactive users can still view all public data.

### Data Architecture

**Core Tables:**
- `profiles` - User accounts linked to Supabase Auth (`auth.users`)
- `persons` - Family members with birth/death dates (separate year/month/day columns for partial dates)
- `person_details_private` - Sensitive info (phone, occupation, residence) with stricter RLS
- `relationships` - Graph edges connecting persons (marriage, biological_child, adopted_child)
- `custom_events` - User-created family events

**Dual Date System**: The database stores both solar dates (birth_year/month/day) and lunar dates (death_lunar_year/month/day) because Vietnamese death anniversaries follow the lunar calendar. Use `lunar-javascript` library for conversions.

**Relationship Graph**: Family tree is modeled as a directed graph where `persons` are nodes and `relationships` are edges. The `type` field distinguishes marriage (horizontal) from parent-child (vertical) relationships.

### Supabase Client Pattern

**IMPORTANT**: Always use the centralized Supabase client pattern:

```typescript
import { getSupabase, getUser, getProfile, getIsAdmin } from "@/utils/supabase/queries"

// In Server Components (async)
const supabase = await getSupabase()
const user = await getUser()
const profile = await getProfile()
const isAdmin = await getIsAdmin()
```

These functions are React `cache()`d to ensure one client instance per request. Never create Supabase clients directly in components.

**Client vs Server**:
- `utils/supabase/server.ts` - Server Component client (uses cookies)
- `utils/supabase/client.ts` - Client Component client (for browser)
- `utils/supabase/middleware.ts` - Auth middleware

### State Management

**URL-Driven State**: The dashboard uses URL query parameters as the source of truth for UI state (view mode, root person, avatar visibility). This enables shareable links and proper back/forward navigation.

**DashboardContext Pattern** (`components/DashboardContext.tsx`):
- Initializes state from URL on mount
- Syncs state changes back to URL using `window.history.replaceState`
- Provides safe no-op fallback when used outside provider
- Accessed via `useDashboard()` hook

Key query params:
- `?view=list|tree|mindmap` - Visualization mode
- `?rootId={uuid}` - Root person for tree views
- `?avatar=hide` - Toggle avatar display
- `?memberModalId={uuid}` - Open member detail modal

### Kinship Calculation System

The kinship calculator (`utils/kinshipHelpers.ts`) determines Vietnamese family titles (Bác, Chú, Cô, Dì, etc.) between any two people.

**Algorithm**:
1. Build adjacency graph from `relationships` table
2. BFS to find shortest path between two persons
3. Parse path to determine relationship type (ascending/descending/lateral)
4. Compare seniority using `birth_order` (primary) or `birth_year` (fallback)
5. Apply Vietnamese kinship rules based on path and seniority

**Critical Fields**:
- `birth_order` - Sibling rank (1st, 2nd, 3rd child) - most important for kinship
- `generation` - Generation number from family root
- `is_in_law` - Marks spouses who joined the family

### Database Migrations

**Schema Management**:
- `docs/schema.sql` - Complete database schema with RLS policies
- `docs/seed.sql` - Sample data for demo
- `docs/migrations/` - Incremental migration files

When modifying schema:
1. Add new migration file with timestamp: `YYYYMMDDHHMMSS_description.sql`
2. Test migration on local Supabase instance
3. Apply to production via Supabase Dashboard SQL Editor

**Important**: Schema uses `CREATE IF NOT EXISTS` and `DROP POLICY IF EXISTS` patterns to be safely re-runnable.

### Component Organization

Components are flat in `components/` directory (no nested folders). Key component types:

**Form Components**:
- `MemberForm.tsx` - Comprehensive person create/edit form with validation
- `PersonSelector.tsx` - Searchable person picker with typeahead
- `RelationshipManager.tsx` - Complex relationship CRUD interface

**Visualization Components**:
- `FamilyTree.tsx` - Traditional tree layout (SVG-based)
- `BubbleMapTree.tsx` - Bubble chart using D3.js force simulation
- `MindmapTree.tsx` - Horizontal mindmap with `MindmapNode.tsx`

**Context Providers**:
- `UserProvider.tsx` - Current user and profile data
- `DashboardContext.tsx` - Dashboard UI state

### Vietnamese Calendar Integration

**Lunar Date Handling**: Death anniversaries must use lunar dates because Vietnamese families observe death anniversaries according to the lunar calendar.

```typescript
import { Solar, Lunar } from "lunar-javascript"
import { getTodayLunar, convertSolarToLunarDate } from "@/utils/dateHelpers"

// Get today's lunar date
const todayLunar = getTodayLunar() // { year, month, day, dayOfWeek }

// Convert death anniversary to current year's solar date
const solarDate = Lunar.fromYmd(year, month, day).getSolar()
```

### Data Import/Export

The system supports three formats:

1. **JSON** - Full data export including all metadata
2. **CSV** - Simple tabular format for spreadsheet editing
3. **GEDCOM** - Standard genealogy format (v5.5.5) for interoperability

Export/import logic in `components/DataImportExport.tsx` and `utils/gedcom.ts`, `utils/csv.ts`.

## Common Patterns

### Adding a New Person Field

1. Add column to `persons` table in migration file
2. Update `Person` type in `types/index.ts`
3. Add form input in `components/MemberForm.tsx`
4. Update display in `components/MemberDetailContent.tsx`
5. Include field in data export functions

### Adding a New User Role

Roles are enum-based. To add new role:
1. Add to `user_role_enum` in schema
2. Update `UserRole` type in `types/index.ts`
3. Add RLS policies for new role capabilities
4. Update UI permission checks (use `getIsAdmin()`, `getProfile()?.role`)

### Working with Relationships

Relationships are **directional** for parent-child but **bidirectional** for marriage:
- `biological_child`/`adopted_child`: person_a is parent, person_b is child
- `marriage`: order doesn't matter (query checks both person_a and person_b)

Always query both directions when finding connections.

## Testing Locally

1. Create free Supabase project at https://supabase.com
2. Run `docs/schema.sql` in SQL Editor to create tables
3. (Optional) Run `docs/seed.sql` for sample data
4. Configure `.env.local` with Supabase credentials
5. Run `bun run dev`
6. Register first user (auto-becomes admin)
7. Configure Redirect URLs in Supabase Dashboard → Authentication → URL Configuration

## Deployment

**Recommended**: Deploy to Vercel (zero-config Next.js hosting)

**Environment Configuration**:
- Set three env vars: `SITE_NAME`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY`
- Configure Supabase Redirect URLs to include production domain

**Post-Deployment**:
- Add production URL to Supabase → Authentication → URL Configuration
- Add wildcard redirect URL: `https://yourdomain.com/**`
- Verify first user can register and becomes admin

## Key Constraints

1. **No self-relationships**: `CHECK (person_a != person_b)` on relationships table
2. **Unique relationship pairs**: Same two people can't have duplicate relationship of same type
3. **First user is admin**: Automatic admin promotion handled in RLS policies
4. **Auth required**: All dashboard routes require authenticated user (checked in layout)
5. **Inactive users blocked**: Users with `is_active = false` see waiting screen

## Vietnamese Language & Culture

- UI is entirely in Vietnamese (lang="vi" in HTML)
- Fonts: Inter (sans-serif) + Playfair Display (serif) with Vietnamese character support
- Kinship terminology follows northern Vietnamese convention
- Lunar calendar support is mandatory for death anniversary features
- Date formats follow Vietnamese conventions (day/month/year)
