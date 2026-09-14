-- WhatBot Supabase Auth + RLS
-- The application User table currently uses cuid/text IDs. Until the app profile
-- is linked directly to auth.users.id, verified Supabase Auth email is used to
-- resolve the existing User record. Authorization is enforced by RLS.

create schema if not exists private;

-- The Prisma schema already expects this table, but it was missing from the live DB.
create table if not exists public."WhatsappEvent" (
  id text primary key default ('c'::text || replace(gen_random_uuid()::text, '-'::text, '')),
  "shopId" text not null references public."Shop"(id) on delete cascade,
  "providerMessageId" text not null unique,
  "eventType" text not null,
  payload jsonb not null,
  "createdAt" timestamptz not null default now()
);
create index if not exists "WhatsappEvent_shopId_createdAt_idx" on public."WhatsappEvent" ("shopId", "createdAt");

create or replace function private.current_app_user_id()
returns text language sql stable security definer set search_path = '' as $$
  select u.id from public."User" u
  where lower(u.email) = lower((select auth.jwt()->>'email')) limit 1
$$;

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public."User" u
    where u.id = private.current_app_user_id() and u.role = 'SUPER_ADMIN'
  )
$$;

create or replace function private.owns_shop(target_shop_id text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public."Shop" s
    where s.id = target_shop_id and s."ownerId" = private.current_app_user_id()
  )
$$;

revoke execute on function private.current_app_user_id() from public;
revoke execute on function private.is_admin() from public;
revoke execute on function private.owns_shop(text) from public;
grant execute on function private.current_app_user_id() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.owns_shop(text) to authenticated;

-- Enable RLS on every application table.
alter table public."User" enable row level security;
alter table public."Address" enable row level security;
alter table public."Shop" enable row level security;
alter table public."Product" enable row level security;
alter table public."Order" enable row level security;
alter table public."SubscriptionPlan" enable row level security;
alter table public."Subscription" enable row level security;
alter table public."WhatsappConversation" enable row level security;
alter table public."WhatsappMessage" enable row level security;
alter table public."WhatsappEvent" enable row level security;
alter table public."Review" enable row level security;
alter table public."Payout" enable row level security;
alter table public."EarningProfile" enable row level security;
alter table public."AffiliateProgram" enable row level security;
alter table public."AffiliatePartner" enable row level security;
alter table public."ReferralClick" enable row level security;
alter table public."ReferralConversion" enable row level security;
alter table public."Commission" enable row level security;
alter table public."EarningEvent" enable row level security;
alter table public."EarningPayoutRequest" enable row level security;
alter table public."CreatorCampaign" enable row level security;
alter table public."CreatorApplication" enable row level security;

-- Least-privilege Data API grants.
revoke all on table public."User",public."Address",public."Shop",public."Product",public."Order",public."SubscriptionPlan",public."Subscription",public."WhatsappConversation",public."WhatsappMessage",public."WhatsappEvent",public."Review",public."Payout",public."EarningProfile",public."AffiliateProgram",public."AffiliatePartner",public."ReferralClick",public."ReferralConversion",public."Commission",public."EarningEvent",public."EarningPayoutRequest",public."CreatorCampaign",public."CreatorApplication" from anon,authenticated;
grant select on public."Shop",public."Product",public."SubscriptionPlan",public."Review",public."AffiliateProgram",public."CreatorCampaign" to anon,authenticated;
grant select,insert,update,delete on public."User",public."Address",public."Shop",public."Product",public."Order",public."SubscriptionPlan",public."Subscription",public."WhatsappConversation",public."WhatsappMessage",public."WhatsappEvent",public."Review",public."Payout",public."EarningProfile",public."AffiliateProgram",public."AffiliatePartner",public."ReferralClick",public."ReferralConversion",public."Commission",public."EarningEvent",public."EarningPayoutRequest",public."CreatorCampaign",public."CreatorApplication" to authenticated;

-- User profile.
create policy "user_select_own" on public."User" for select to authenticated
  using (id = private.current_app_user_id() or private.is_admin());
create policy "user_insert_own" on public."User" for insert to authenticated
  with check (lower(email)=lower((select auth.jwt()->>'email')) and role='CUSTOMER');
create policy "user_update_own" on public."User" for update to authenticated
  using (id=private.current_app_user_id() or private.is_admin())
  with check (id=private.current_app_user_id() or private.is_admin());
revoke update(role,"passwordHash",balance,"subscriptionStatus","paystackCustomerCode") on public."User" from authenticated;
grant update(name,email,phone,"avatarUrl") on public."User" to authenticated;

-- Addresses.
create policy "address_own" on public."Address" for all to authenticated
  using ("userId"=private.current_app_user_id() or private.is_admin())
  with check ("userId"=private.current_app_user_id() or private.is_admin());

-- Shops and products.
create policy "shop_public_read" on public."Shop" for select to anon,authenticated
  using ("isActive"=true or private.owns_shop(id) or private.is_admin());
create policy "shop_owner_manage" on public."Shop" for all to authenticated
  using ("ownerId"=private.current_app_user_id() or private.is_admin())
  with check ("ownerId"=private.current_app_user_id() or private.is_admin());
create policy "product_public_read" on public."Product" for select to anon,authenticated
  using (exists(select 1 from public."Shop" s where s.id="shopId" and (s."isActive"=true or private.owns_shop(s.id) or private.is_admin())));
create policy "product_owner_manage" on public."Product" for all to authenticated
  using (private.owns_shop("shopId") or private.is_admin())
  with check (private.owns_shop("shopId") or private.is_admin());

-- Orders.
create policy "order_read" on public."Order" for select to authenticated
  using ("customerId"=private.current_app_user_id() or private.owns_shop("shopId") or private.is_admin());
create policy "order_insert" on public."Order" for insert to authenticated
  with check ("customerId"=private.current_app_user_id());
create policy "order_update" on public."Order" for update to authenticated
  using ("customerId"=private.current_app_user_id() or private.owns_shop("shopId") or private.is_admin())
  with check ("customerId"=private.current_app_user_id() or private.owns_shop("shopId") or private.is_admin());

-- Subscriptions/plans.
create policy "subscription_plan_public_read" on public."SubscriptionPlan" for select to anon,authenticated using (true);
create policy "subscription_plan_admin" on public."SubscriptionPlan" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "subscription_own_read" on public."Subscription" for select to authenticated using ("userId"=private.current_app_user_id() or private.is_admin());
create policy "subscription_admin" on public."Subscription" for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- Reviews.
create policy "review_public_read" on public."Review" for select to anon,authenticated using (true);
create policy "review_own_write" on public."Review" for all to authenticated
  using ("userId"=private.current_app_user_id() or private.is_admin())
  with check ("userId"=private.current_app_user_id() or private.is_admin());

-- WhatsApp and merchant payouts.
create policy "wa_conversation_owner" on public."WhatsappConversation" for all to authenticated
  using (private.owns_shop("shopId") or private.is_admin()) with check (private.owns_shop("shopId") or private.is_admin());
create policy "wa_message_owner" on public."WhatsappMessage" for all to authenticated
  using (private.owns_shop("shopId") or private.is_admin()) with check (private.owns_shop("shopId") or private.is_admin());
create policy "wa_event_owner" on public."WhatsappEvent" for select to authenticated
  using (private.owns_shop("shopId") or private.is_admin());
create policy "wa_event_admin" on public."WhatsappEvent" for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy "payout_shop_owner" on public."Payout" for all to authenticated
  using (private.owns_shop("shopId") or private.is_admin()) with check (private.owns_shop("shopId") or private.is_admin());

-- Earnings.
create policy "earning_profile_own" on public."EarningProfile" for select to authenticated
  using ("userId"=private.current_app_user_id() or private.is_admin());
create policy "affiliate_partner_own" on public."AffiliatePartner" for select to authenticated
  using ("userId"=private.current_app_user_id() or private.is_admin());
create policy "referral_conversion_own" on public."ReferralConversion" for select to authenticated
  using (exists(select 1 from public."AffiliatePartner" p where p.id="partnerId" and p."userId"=private.current_app_user_id()) or private.is_admin());
create policy "commission_own" on public."Commission" for select to authenticated
  using (exists(select 1 from public."EarningProfile" e where e.id="earningProfileId" and e."userId"=private.current_app_user_id()) or private.is_admin());
create policy "earning_event_own" on public."EarningEvent" for select to authenticated
  using ("userId"=private.current_app_user_id() or private.is_admin());
create policy "earning_payout_own" on public."EarningPayoutRequest" for select to authenticated
  using ("userId"=private.current_app_user_id() or private.is_admin());
create policy "earning_payout_insert" on public."EarningPayoutRequest" for insert to authenticated
  with check ("userId"=private.current_app_user_id() and exists(select 1 from public."EarningProfile" e where e.id="earningProfileId" and e."userId"=private.current_app_user_id()));
create policy "earning_payout_admin" on public."EarningPayoutRequest" for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- Affiliate and creator marketplace.
create policy "affiliate_program_public_read" on public."AffiliateProgram" for select to anon,authenticated
  using (status='ACTIVE' or private.owns_shop("shopId") or private.is_admin());
create policy "affiliate_program_owner_manage" on public."AffiliateProgram" for all to authenticated
  using (private.owns_shop("shopId") or private.is_admin()) with check (private.owns_shop("shopId") or private.is_admin());
create policy "creator_campaign_public_read" on public."CreatorCampaign" for select to anon,authenticated
  using (status='ACTIVE' or private.owns_shop("shopId") or private.is_admin());
create policy "creator_campaign_owner_manage" on public."CreatorCampaign" for all to authenticated
  using (private.owns_shop("shopId") or private.is_admin()) with check (private.owns_shop("shopId") or private.is_admin());
create policy "creator_application_read" on public."CreatorApplication" for select to authenticated
  using ("creatorId"=private.current_app_user_id() or exists(select 1 from public."CreatorCampaign" c where c.id="campaignId" and private.owns_shop(c."shopId")) or private.is_admin());
create policy "creator_application_insert" on public."CreatorApplication" for insert to authenticated
  with check ("creatorId"=private.current_app_user_id());
create policy "creator_application_update" on public."CreatorApplication" for update to authenticated
  using ("creatorId"=private.current_app_user_id() or exists(select 1 from public."CreatorCampaign" c where c.id="campaignId" and private.owns_shop(c."shopId")) or private.is_admin())
  with check ("creatorId"=private.current_app_user_id() or private.is_admin());

-- Conversion/tracking tables are server/admin controlled.
create policy "referral_click_admin" on public."ReferralClick" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "referral_conversion_admin" on public."ReferralConversion" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "commission_admin" on public."Commission" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "earning_event_admin" on public."EarningEvent" for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- Admin full access is intentionally a separate policy. Service-role/server code bypasses RLS.
create policy "admin_user_all" on public."User" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_address_all" on public."Address" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_shop_all" on public."Shop" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_product_all" on public."Product" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_order_all" on public."Order" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_subscription_plan_all" on public."SubscriptionPlan" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_subscription_all" on public."Subscription" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_wa_conversation_all" on public."WhatsappConversation" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_wa_message_all" on public."WhatsappMessage" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_wa_event_all" on public."WhatsappEvent" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_review_all" on public."Review" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_payout_all" on public."Payout" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_earning_profile_all" on public."EarningProfile" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_affiliate_program_all" on public."AffiliateProgram" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_affiliate_partner_all" on public."AffiliatePartner" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_referral_click_all" on public."ReferralClick" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_referral_conversion_all" on public."ReferralConversion" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_commission_all" on public."Commission" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_earning_event_all" on public."EarningEvent" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_earning_payout_all" on public."EarningPayoutRequest" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_creator_campaign_all" on public."CreatorCampaign" for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "admin_creator_application_all" on public."CreatorApplication" for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- RLS lookup indexes.
create index if not exists "User_email_lower_idx" on public."User" (lower(email));
create index if not exists "Order_customerId_idx" on public."Order" ("customerId");
create index if not exists "Shop_ownerId_idx" on public."Shop" ("ownerId");
create index if not exists "AffiliatePartner_userId_idx" on public."AffiliatePartner" ("userId");
create index if not exists "EarningProfile_userId_idx" on public."EarningProfile" ("userId");
create index if not exists "CreatorApplication_creatorId_idx" on public."CreatorApplication" ("creatorId");
