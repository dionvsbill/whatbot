# WhatBot

Production multi-vendor Ghana e-commerce platform built with Next.js 14, TypeScript, Tailwind CSS, Prisma and PostgreSQL.

## Current architecture

- Customer storefront and account area
- Seller/shop dashboard and admin controls
- Authentication with signed HTTP-only sessions
- PostgreSQL hosted on the connected Supabase project through Prisma
- Paystack initialization and signed webhook handling
- WhatsApp Cloud API routing and webhooks
- Product search
- Seller subscriptions and payouts
- Jumia/Amazon import service endpoints
- Ghana-specific legal pages
- Production health endpoint at `/api/health`

## Database

The connected Supabase project is provisioned for this application. The Prisma schema in `prisma/schema.prisma` is the source model for the application, and the production database currently contains the required marketplace tables.

For deployment, set `DATABASE_URL` to the Supabase pooled PostgreSQL connection string and `DIRECT_URL` to the direct PostgreSQL connection string. Never commit real credentials to this repository.

## Required environment

Copy `.env.example` to `.env.local` for local development and provide the provider credentials you intend to enable. The health endpoint reports database connectivity and whether Paystack, WhatsApp and media/import providers are configured without exposing secrets.

## Local setup

```bash
npm install
npm run prisma:generate
npm run dev
```

For a first admin account, set `ADMIN_PASSWORD` and `ADMIN_PHONE`, then run:

```bash
npm run prisma:seed
```

## Production checks

After deployment, open `/api/health`. A healthy deployment should return `ok: true` and `database: "connected"`. Provider flags can remain false until their corresponding credentials are configured.
