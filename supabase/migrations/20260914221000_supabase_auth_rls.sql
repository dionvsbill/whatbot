-- WhatBot Supabase Auth + RLS hardening
-- Identity is resolved from the verified Supabase Auth email claim to the
-- existing application User row. This keeps the current Prisma IDs intact
-- while the application transitions fully to Supabase Auth.

create schema if not exists private;

create or replace function private.current_app_user_id()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from public."User" u
  where lower(u.email) = lower((select auth.jwt() ->> 'email'))
  limit 1
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public."User" u
    where u.id = private.current_app_user_id()
      and u.role = 'SUPER_ADMIN'
  )
$$;

create or replace function private.owns_shop(target_shop_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public."Shop" s
    where s.id = target_shop_id
      and s.ownerId = private.current_app_user_id()
  )
$$;

create or replace function private.is_shop_customer(target_shop_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public."Order" o
    where o.shopId = target_shop_id
      and o.customerId = private.current_app_user_id()
  )
$$;

revoke execute on function private.current_app_user_id() from public;
revoke execute on function private.is_admin() from public;
revoke execute on function private.owns_shop(text) from public;
revoke execute on function private.is_shop_customer(text) from public;
grant execute on function private.current_app_user_id() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.owns_shop(text) to authenticated;
grant execute on function private.is_shop_customer(text) to authenticated;

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

-- Start from least privilege for Data API roles.
revoke all on table public."User", public."Address", public."Shop", public."Product", public."Order",
  public."SubscriptionPlan", public."Subscription", public."WhatsappConversation", public."WhatsappMessage",
  public."WhatsappEvent", public."Review", public."Payout", public."EarningProfile", public."AffiliateProgram",
  public."AffiliatePartner", public."ReferralClick", public."ReferralConversion", public."Commission",
  public."EarningEvent", public."EarningPayoutRequest", public."CreatorCampaign", public."CreatorApplication"
from anon, authenticated;

-- Public storefront data.
grant select on table public."Shop", public."Product", public."SubscriptionPlan", public."Review",
  public."AffiliateProgram", public."CreatorCampaign" to anon, authenticated;

-- Authenticated clients get DML privileges; RLS below controls the rows.
grant select, insert, update, delete on table public."User", public."Address", public."Shop", public."Product",
  public."Order", public."SubscriptionPlan", public."Subscription", public."WhatsappConversation",
  public."WhatsappMessage", public."WhatsappEvent", public."Review", public."Payout", public."EarningProfile",
  public."AffiliateProgram", public."AffiliatePartner", public."ReferralClick", public."ReferralConversion",
  public."Commission", public."EarningEvent", public."EarningPayoutRequest", public."CreatorCampaign",
  public."CreatorApplication" to authenticated;

-- Users: a signed-in user can access only their own application profile.
drop policy if exists "user_select_own" on public."User";
drop policy if exists "user_insert_own" on public."User";
drop policy if exists "user_update_own" on public."User";
create policy "user_select_own" on public."User" for select to authenticated
  using (private.current_app_user_id() = id or private.is_admin());
create policy "user_insert_own" on public."User" for insert to authenticated
  with check (lower(email) = lower((select auth.jwt() ->> 'email')) and role = 'CUSTOMER');
create policy "user_update_own" on public."User" for update to authenticated
  using (private.current_app_user_id() = id or private.is_admin())
  with check (private.current_app_user_id() = id or private.is_admin());

-- Prevent browser clients from changing security/accounting fields on User.
revoke update (role, passwordHash, balance, subscriptionStatus, paystackCustomerCode)
on table public."User" from authenticated;
grant update (name, email, phone, avatarUrl) on table public."User" to authenticated;

-- Addresses.
drop policy if exists "address_own_all" on public."Address";
create policy "address_own_all" on public."Address" for all to authenticated
  using (userId = private.current_app_user_id() or private.is_admin())
  with check (userId = private.current_app_user_id() or private.is_admin());

-- Shops: public can read active shops; owners/admins manage them.
drop policy if exists "shop_public_read" on public."Shop";
drop policy if exists "shop_owner_manage" on public."Shop";
create policy "shop_public_read" on public."Shop" for select to anon, authenticated
  using (isActive = true or private.owns_shop(id) or private.is_admin());
create policy "shop_owner_manage" on public."Shop" for all to authenticated
  using (ownerId = private.current_app_user_id() or private.is_admin())
  with check (ownerId = private.current_app_user_id() or private.is_admin());

-- Products: only products belonging to active/public shops are public.
drop policy if exists "product_public_read" on public."Product";
drop policy if exists "product_owner_manage" on public."Product";
create policy "product_public_read" on public."Product" for select to anon, authenticated
  using (exists (select 1 from public."Shop" s where s.id = shopId and (s.isActive = true or private.owns_shop(s.id) or private.is_admin())));
create policy "product_owner_manage" on public."Product" for all to authenticated
  using (private.owns_shop(shopId) or private.is_admin())
  with check (private.owns_shop(shopId) or private.is_admin());

-- Orders: customers see/manage their own orders; merchants see orders for their shops.
drop policy if exists "order_customer_or_shop_read" on public."Order";
drop policy if exists "order_customer_insert" on public."Order";
drop policy if exists "order_owner_update" on public."Order";
create policy "order_customer_or_shop_read" on public."Order" for select to authenticated
  using (customerId = private.current_app_user_id() or private.owns_shop(shopId) or private.is_admin());
create policy "order_customer_insert" on public."Order" for insert to authenticated
  with check (customerId = private.current_app_user_id());
create policy "order_owner_update" on public."Order" for update to authenticated
  using (customerId = private.current_app_user_id() or private.owns_shop(shopId) or private.is_admin())
  with check (customerId = private.current_app_user_id() or private.owns_shop(shopId) or private.is_admin());

-- Subscription plans are public to read; writes are admin-only.
drop policy if exists "subscription_plan_admin_write" on public."SubscriptionPlan";
create policy "subscription_plan_admin_write" on public."SubscriptionPlan" for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

drop policy if exists "subscription_own_read" on public."Subscription";
drop policy if exists "subscription_admin_manage" on public."Subscription";
create policy "subscription_own_read" on public."Subscription" for select to authenticated
  using (userId = private.current_app_user_id() or private.is_admin());
create policy "subscription_admin_manage" on public."Subscription" for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- Reviews are public to read; authenticated users can only write their own reviews.
drop policy if exists "review_public_read" on public."Review";
drop policy if exists "review_own_write" on public."Review";
create policy "review_public_read" on public."Review" for select to anon, authenticated using (true);
create policy "review_own_write" on public."Review" for all to authenticated
  using (userId = private.current_app_user_id() or private.is_admin())
  with check (userId = private.current_app_user_id() or private.is_admin());

-- Merchant WhatsApp data.
drop policy if exists "wa_conversation_owner" on public."WhatsappConversation";
drop policy if exists "wa_message_owner" on public."WhatsappMessage";
drop policy if exists "wa_event_owner" on public."WhatsappEvent";
create policy "wa_conversation_owner" on public."WhatsappConversation" for all to authenticated
  using (private.owns_shop(shopId) or private.is_admin())
  with check (private.owns_shop(shopId) or private.is_admin());
create policy "wa_message_owner" on public."WhatsappMessage" for all to authenticated
  using (private.owns_shop(shopId) or private.is_admin())
  with check (private.owns_shop(shopId) or private.is_admin());
create policy "wa_event_owner" on public."WhatsappEvent" for select to authenticated
  using (private.owns_shop(shopId) or private.is_admin());
create policy "wa_event_admin_write" on public."WhatsappEvent" for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- Merchant payouts.
drop policy if exists "payout_shop_owner" on public."Payout";
create policy "payout_shop_owner" on public."Payout" for all to authenticated
  using (private.owns_shop(shopId) or private.is_admin())
  with check (private.owns_shop(shopId) or private.is_admin());

-- Earnings: users see only their own earning records.
drop policy if exists "earning_profile_own" on public."EarningProfile";
drop policy if exists "affiliate_partner_own" on public."AffiliatePartner";
drop policy if exists "referral_conversion_own" on public."ReferralConversion";
drop policy if exists "commission_own" on public."Commission";
drop policy if exists "earning_event_own" on public."EarningEvent";
drop policy if exists "earning_payout_own" on public."EarningPayoutRequest";
create policy "earning_profile_own" on public."EarningProfile" for select to authenticated
  using (userId = private.current_app_user_id() or private.is_admin());
create policy "affiliate_partner_own" on public."AffiliatePartner" for select to authenticated
  using (userId = private.current_app_user_id() or private.is_admin());
create policy "referral_conversion_own" on public."ReferralConversion" for select to authenticated
  using (partnerId in (select ap.id from public."AffiliatePartner" ap where ap.userId = private.current_app_user_id()) or private.is_admin());
create policy "commission_own" on public."Commission" for select to authenticated
  using (earningProfileId in (select ep.id from public."EarningProfile" ep where ep.userId = private.current_app_user_id()) or private.is_admin());
create policy "earning_event_own" on public."EarningEvent" for select to authenticated
  using (userId = private.current_app_user_id() or private.is_admin());
create policy "earning_payout_own" on public."EarningPayoutRequest" for select to authenticated
  using (userId = private.current_app_user_id() or private.is_admin());
create policy "earning_payout_request" on public."EarningPayoutRequest" for insert to authenticated
  with check (userId = private.current_app_user_id() and earningProfileId in (select ep.id from public."EarningProfile" ep where ep.userId = private.current_app_user_id()));
create policy "earning_payout_admin" on public."EarningPayoutRequest" for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- Affiliate programs: active programs are public; merchants administer their programs.
drop policy if exists "affiliate_program_public_read" on public."AffiliateProgram";
drop policy if exists "affiliate_program_shop_manage" on public."AffiliateProgram";
create policy "affiliate_program_public_read" on public."AffiliateProgram" for select to anon, authenticated
  using (status = 'ACTIVE' or private.owns_shop(shopId) or private.is_admin());
create policy "affiliate_program_shop_manage" on public."AffiliateProgram" for all to authenticated
  using (private.owns_shop(shopId) or private.is_admin())
  with check (private.owns_shop(shopId) or private.is_admin());

-- Creator campaigns: active campaigns are public; merchants administer their own.
drop policy if exists "creator_campaign_public_read" on public."CreatorCampaign";
drop policy if exists "creator_campaign_shop_manage" on public."CreatorCampaign";
create policy "creator_campaign_public_read" on public."CreatorCampaign" for select to anon, authenticated
  using (status = 'ACTIVE' or private.owns_shop(shopId) or private.is_admin());
create policy "creator_campaign_shop_manage" on public."CreatorCampaign" for all to authenticated
  using (private.owns_shop(shopId) or private.is_admin())
  with check (private.owns_shop(shopId) or private.is_admin());

-- Creator applications: creator owns their application; campaign merchant/admin can review.
drop policy if exists "creator_application_access" on public."CreatorApplication";
create policy "creator_application_access" on public."CreatorApplication" for select to authenticated
  using (
    creatorId = private.current_app_user_id()
    or exists (select 1 from public."CreatorCampaign" c where c.id = campaignId and private.owns_shop(c.shopId))
    or private.is_admin()
  );
drop policy if exists "creator_application_insert" on public."CreatorApplication";
create policy "creator_application_insert" on public."CreatorApplication" for insert to authenticated
  with check (creatorId = private.current_app_user_id());
drop policy if exists "creator_application_update" on public."CreatorApplication";
create policy "creator_application_update" on public."CreatorApplication" for update to authenticated
  using (creatorId = private.current_app_user_id() or exists (select 1 from public."CreatorCampaign" c where c.id = campaignId and private.owns_shop(c.shopId)) or private.is_admin())
  with check (creatorId = private.current_app_user_id() or exists (select 1 from public."CreatorCampaign" c where c.id = campaignId and private.owns_shop(c.shopId)) or private.is_admin());

-- Tracking/conversion tables are intentionally server-side only for normal users.
drop policy if exists "referral_click_admin" on public."ReferralClick";
drop policy if exists "referral_conversion_admin" on public."ReferralConversion";
drop policy if exists "commission_admin" on public."Commission";
drop policy if exists "earning_event_admin" on public."EarningEvent";
create policy "referral_click_admin" on public."ReferralClick" for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy "referral_conversion_admin" on public."ReferralConversion" for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy "commission_admin" on public."Commission" for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy "earning_event_admin" on public."EarningEvent" for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- Admins can manage every application table through the Data API.
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

-- Policy lookup indexes.
create index if not exists "User_email_lower_idx" on public."User" (lower(email));
create index if not exists "Order_customerId_idx" on public."Order" ("customerId");
create index if not exists "Shop_ownerId_idx" on public."Shop" ("ownerId");
create index if not exists "AffiliatePartner_userId_idx" on public."AffiliatePartner" ("userId");
create index if not exists "EarningProfile_userId_idx" on public."EarningProfile" ("userId");
create index if not exists "CreatorApplication_creatorId_idx" on public."CreatorApplication" ("creatorId");
