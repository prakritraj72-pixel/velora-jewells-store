# Velora Jewells

A dark, gothic jewellery storefront preview for Velora Jewells.

## Current state

- `index.html`: responsive storefront with category filters and a browser-only preview cart.
- `admin.html`: admin dashboard UI preview. It is **not authenticated** and must not be used to manage real customer data.
- `supabase/schema.sql`: initial database schema draft. It has **not been applied** to a Supabase project.

The sample catalogue and prices are placeholders. Cart state is stored in the browser session only. No real checkout, payment, inventory updates, or order creation is enabled.

## Business rules to enforce server-side

- Minimum product subtotal: INR 500 (50,000 paise), excluding shipping.
- Prepaid: charge the full product subtotal through a verified payment provider.
- COD: collect INR 70 (7,000 paise) online as the delivery advance; product subtotal remains due at delivery.
- Never mark an order paid based only on a browser redirect. Verify provider signatures/webhooks server-side.
- Reserve/decrement stock transactionally only after the intended order/payment state is verified.
- Never expose a Supabase service-role key in browser code.

## Setup checklist

1. Create a **new Velora Jewells Supabase organization/project** separate from Elyra.
2. Review the SQL and apply it only to that dedicated project.
3. Configure admin authorization using trusted server-side `app_metadata` claims and verify row-level security policies.
4. Implement a server-side checkout endpoint, payment provider verification/webhooks, stock reservation, idempotency and order status history.
5. Configure private product-image storage policies.
6. Connect the storefront/admin UI to the database using only a publishable key.
7. Test minimum subtotal, COD advance, prepaid payment, duplicate webhooks, out-of-stock items, authorization and refunds.
8. Deploy with HTTPS and environment secrets kept outside the public repository.

## Important

Do not accept real customer payments until the backend, payment verification, inventory transactions, privacy/returns policies and order notifications have been implemented and tested.
