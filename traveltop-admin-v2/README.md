# TravelTop Admin Console

Internal admin dashboard for TravelTop — built with **React + Vite + Supabase**.

## Quick Start

### 1. Fill in Supabase credentials

Edit `.env`:
```
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

### 2. Run the SQL migration

Open `supabase/admin_rls.sql` in the **Supabase SQL Editor** and run it.
This creates all tables, enables RLS, and sets up admin policies.

### 3. Add your first super_admin

After signing up with your email in Supabase Auth, find your user ID in
Supabase Dashboard → Authentication → Users. Then run in the SQL Editor:

```sql
insert into admin_users (id, full_name, role)
values ('YOUR-UUID-HERE', 'Your Name', 'super_admin');
```

### 4. Enable Realtime

In Supabase Dashboard → Database → Replication, toggle on:
`profiles, agent_details, bookings, orders, payouts, reviews, destinations, products, notifications, announcements`

### 5. Start the dev server

```bash
npm install
npm run dev
```

Opens at `http://localhost:5173`

---

## Pages

| Page | Description |
|------|-------------|
| Dashboard | Live stat cards, 6-month charts, top destinations & agents |
| Destinations | Add/edit with Places sub-section, image upload, month toggles |
| Agents | Pending/Approved/Rejected/Suspended tabs, approve/reject workflow |
| Users | Traveller accounts, booking history, suspend/unsuspend |
| Bookings | Filter by status, admin notes, force cancel, flag for refund |
| Products | Shop inventory with image upload |
| Orders | Status updates (Placed → Delivered), live sync to traveller app |
| Payouts | Agent payout requests, Mark as Paid |
| Reviews | Delete reviews with automatic rating recalculation |
| Announcements | Broadcast to all/agents/travellers, notification bulk insert |
| Admin Users | Invite, role management (super_admin only) |

## Role Permissions

| Feature | super_admin | support_staff |
|---------|-------------|---------------|
| All pages | ✓ | Bookings/Users/Reviews only |
| Delete/Suspend | ✓ | ✗ |
| Admin Users page | ✓ | ✗ |
