# FINAL ARCHITECTURE VERIFICATION — Rajvastra Vendor Management System
**As Standalone Spree Extension (`spree_vendor`)**

**Date:** 2026-08-04
**Stack:** Rails 8.1.3 / Spree 5.6.1 / PostgreSQL / Solid Queue / Active Storage / Next.js Storefront

---

## 1. DECISION: STANDALONE SPREE EXTENSION

### 1.1 Why Standalone Extension?

Per user directive: "Implement this feature as a standalone Spree Extension (spree_vendor or spree_marketplace) instead of modifying the Spree core directly."

The `spree_extension` gem (v1.0.2) is already installed as a development dependency. This gives us:
- Official `spree-extension create` generator
- Standard engine template with `isolate_namespace Spree`
- `Spree::Preferences::Configuration` base class
- Install generator (`rails g spree_vendor:install`)
- RSpec scaffolding, Zeitwerk spec, i18n spec
- Drop-in `Gemfile` dependency (`gem 'spree_vendor'`)

### 1.2 Extension Points That Make This Clean

Spree 5.6.1 already provides these hooks — NO core modification needed:

| Extension Point | Location | What It Enables |
|---|---|---|
| `Spree::VendorConcern` (conditional include) | `order.rb`, `product.rb`, `shipment.rb`, `stock_location.rb`, `shipping_method.rb`, `export.rb`, `report.rb` | Auto-includes vendor associations on 7 core models |
| `Spree::OrderApproval` model | `spree_order_approvals` table | Vendor accept/reject with polymorphic approver |
| `Spree::Events` + `Spree::Subscriber` | Full event bus | Async order/shipment notifications |
| `Spree::Shipment` state machine | `pending→ready→shipped` | Packing, shipping, tracking flow |
| `Spree::Shipment#tracking` + `tracking_url` | Shipment model | Courier + tracking number + tracking link |
| `Spree::PermissionSets` | Spree permissions registry | `SpreeVendor::PermissionSets::Vendor` |
| `Spree::Role` | `spree_roles` | `vendor` role (already seeded in initializer) |
| `Spree::Admin::ResourceController` | Admin base | Admin vendor CRUD |
| `Spree::Api::V3::Admin::BaseController` | API base | Vendor admin API |
| `Spree::Api::V3::Store::BaseController` | Storefront API base | Customer tracking API |
| `Spree.tracking_number_service` | `Dependencies` | Tracking number → URL resolution |
| `spree_products.seller_id` | Host app migration | Vendor→Product ownership (already exists) |

---

## 2. ITEM-BY-ITEM REUSE REPORT

### 2.1 Host App — Found Items

| # | Item | Location | Purpose | Reuse? | Extend? | Untouched? |
|---|---|---|---|---|---|---|
| 1 | `VendorAbility` | `app/models/vendor_ability.rb` | Permission set: vendors manage own products via `seller_id` | ✅ **REUSE** | ❌ Deprecated — will be replaced by `SpreeVendor::PermissionSets::Vendor` in extension | — |
| 2 | `ProductsControllerDecorator` | `app/controllers/concerns/spree/admin/products_controller_decorator.rb` | Sets `seller_id = current_admin_user.id` on product create | ⚠️ **MOVE** | Will be moved into extension as decorator (so host app has zero vendor code) | — |
| 3 | `spree_products.seller_id` | `db/migrate/20260804180712_add_seller_id_to_spree_products.rb` | Vendor→Product foreign key | ✅ **REUSE** | Extension adds FK constraint to `spree_vendors` | — |
| 4 | `vendor` role config | `config/initializers/spree.rb:92` | `Spree.permissions.assign(:vendor, [VendorAbility, DashboardDisplay])` | ⚠️ **MOVE** | Moved to extension initializer as `SpreeVendor::PermissionSets::Vendor` | — |
| 5 | `spree_order_approvals` table | Spree core migration | Order approval status (pending/approved/rejected) | ✅ **REUSE** | Extension adds `supplier_id` metadata + services | — |

### 2.2 Spree Core — Found Items

| # | Item | Location | Purpose | Reuse? | Extend? | Untouched? |
|---|---|---|---|---|---|---|
| 6 | `Spree::VendorConcern` conditional include | 7 Spree models | Auto-includes vendor associations when module defined | ✅ **REUSE** | **Extension defines this module** — `app/models/spree/vendor_concern.rb` | Spree core untouched |
| 7 | `Spree::OrderApproval` | `app/models/spree/order_approval.rb` | Order approval with polymorphic approver | ✅ **REUSE as-is** | Services create/update these records | ❌ Core untouched |
| 8 | `Spree::Order` state machine | `order/checkout.rb` | cart→address→delivery→payment→confirm→complete | ❌ NOT REUSED directly | Services use `order.complete!`, `order.cancel!` | ✅ Core untouched |
| 9 | `Spree::Order#approvals` association | `order.rb:181` | `has_many :approvals` → OrderApproval | ✅ **REUSE** | `order.approvals.create(status:...)` | ✅ Core untouched |
| 10 | `Spree::Shipment` state machine | `shipment.rb:73` | pending→ready→shipped, cancel/resume | ✅ **REUSE** | `shipment.ready!`, `shipment.ship!` via services | ✅ Core untouched |
| 11 | `Spree::Shipment#tracking` | `shipment.rb` | Tracking number column | ✅ **REUSE** | Vendor enters tracking via `VendorShipOrderService` | ✅ Core untouched |
| 12 | `Spree::Shipment#tracking_url` | `shipment.rb:467` | Tracking link from shipping method | ✅ **REUSE** | Automatically available to customer | ✅ Core untouched |
| 13 | `Spree::Shipment#shippable?` | `shipment.rb:173` | Requires tracking before ship | ✅ **REUSE** | `shipment.shippable?` gate in service | ✅ Core untouched |
| 14 | `Spree::ShippingMethod#build_tracking_url` | `shipping_method.rb:60` | Builds tracking URL from tracking number | ✅ **REUSE** | Courier tracking URL template | ✅ Core untouched |
| 15 | `Spree.tracking_number_service` | Dependencies | Automatic tracking number detection | ✅ **REUSE** | Auto-detect courier from tracking number | ✅ Core untouched |
| 16 | `Spree::Events` system | `lib/spree/events.rb` | Event publish/subscribe | ✅ **REUSE** | Publish `vendor.order.accepted`, `vendor.shipment.shipped` | ✅ Core untouched |
| 17 | `Spree::Subscriber` | `app/models/spree/subscriber.rb` | Base class for event subscribers | ✅ **REUSE** | `SpreeVendor::Subscribers::OrderAssignmentSubscriber` | ✅ Core untouched |
| 18 | `Spree::Events::SubscriberJob` | `app/jobs/spree/events/subscriber_job.rb` | Async subscriber dispatch | ✅ **REUSE** | All vendor subscribers run async automatically | ✅ Core untouched |
| 19 | `Spree::OrderEmailSubscriber` | spree_emails | Auto email on `order.completed`, `order.canceled` | ✅ **REUSE** | Customer confirmation already handled | ✅ Core untouched |
| 20 | `Spree::ShipmentEmailSubscriber` | spree_emails | Auto email on `shipment.shipped` | ✅ **REUSE** | Customer shipped + tracking email already handled | ✅ Core untouched |
| 21 | `Spree::ShipmentMailer` | spree_emails | `shipped_email(shipment, resend)` | ✅ **REUSE** | Customer tracking email | ✅ Core untouched |
| 22 | `Spree::OrderMailer` | spree_emails | `confirm_email`, `cancel_email` | ✅ **REUSE** | Customer order emails | ✅ Core untouched |
| 23 | `Spree::PermissionSets::Base` | Spree core | Permission set base class | ✅ **REUSE** | `SpreeVendor::PermissionSets::Vendor < Spree::PermissionSets::Base` | ✅ Core untouched |
| 24 | `Spree::Role` | `role.rb` | Role model | ✅ **REUSE** | `Spree::Role.find_or_create_by!(name: 'vendor')` | ✅ Core untouched |
| 25 | `Spree::StockLocation` | `stock_location.rb` | Stock location with address | ✅ **REUSE** | One stock location per vendor (via VendorConcern) | ✅ Core untouched |
| 26 | `Spree::StockItem` | `stock_item.rb` | Inventory per variant per location | ✅ **REUSE** | Vendor inventory via location | ✅ Core untouched |
| 27 | `Spree::StockMovement` | `stock_movement.rb` | Stock movement audit | ✅ **REUSE** | Vendor stock adjustments | ✅ Core untouched |
| 28 | `Spree::Address` | `address.rb` | Full address with country/state | ✅ **REUSE** | Vendor address (belongs_to) | ✅ Core untouched |
| 29 | `Spree::StateChange` | `state_change.rb` | State change audit log | ✅ **REUSE** | Vendor action audit trail | ✅ Core untouched |
| 30 | `Spree::Admin::ResourceController` | spree_admin | Admin CRUD base | ✅ **REUSE** | Admin::VendorsController inherits | ✅ Core untouched |
| 31 | `Spree::Admin::ProductsController` | spree_admin | Product admin | ✅ **REUSE** | Decorated for vendor scoping | ✅ Core untouched |
| 32 | `Spree::Admin::ShipmentsController` | spree_admin | Shipment admin | ✅ **REUSE** | Admin override vendor decisions | ✅ Core untouched |
| 33 | `Spree::Api::V3::Admin::BaseController` | spree_api | Admin API base | ✅ **REUSE** | Vendor admin API endpoints | ✅ Core untouched |
| 34 | `Spree::Api::V3::Store::BaseController` | spree_api | Storefront API base | ✅ **REUSE** | Customer tracking API | ✅ Core untouched |
| 35 | `Spree::Product` revenue/units_sold_count | `product.rb` | Product revenue tracking | ✅ **REUSE** | Vendor revenue calculation | ✅ Core untouched |
| 36 | `Spree::WebhookEndpoint` | `webhook_endpoint.rb` | Webhook infrastructure | ✅ **REUSE** | Optional vendor webhooks | ✅ Core untouched |
| 37 | `Spree::Report` | `report.rb` | Report framework + VendorConcern hook | ✅ **REUSE** | Vendor revenue reports | ✅ Core untouched |
| 38 | `Spree::Export` | `export.rb` | Export framework + VendorConcern hook | ✅ **REUSE** | Vendor CSV exports | ✅ Core untouched |
| 39 | `Spree::PermissionSets::DashboardDisplay` | Spree core | Dashboard display permission | ✅ **REUSE** | Part of vendor permission set | ✅ Core untouched |

---

## 3. DO NOT CREATE (Already Exists)

Per user directive — these **MUST NOT** be created:

| Do NOT Create | Because |
|---|---|
| `SupplierTracking` | `Spree::Shipment#tracking` + `tracking_url` already exists |
| `SupplierShipment` | `Spree::Shipment` already exists with full state machine |
| `SupplierApproval` | `Spree::OrderApproval` already exists |
| `SupplierProduct` | `spree_products.seller_id` already exists |
| `SupplierInventory` | `Spree::StockItem` + `Spree::StockMovement` already exist |

---

## 4. NEW MODELS — Required Justification (UPDATED per approval)

| New Model | Why Required | Why Not Reuse Existing |
|---|---|---|
| `Spree::Vendor` | Vendor profile (business_name, GST, PAN, verification_status, etc.) — pure entity, no Spree equivalent | `Spree::User` is customer auth; `Spree::AdminUser` is admin auth; neither models a business entity |
| `Spree::VendorBankAccount` (table: `spree_vendor_bank_accounts`) | Multiple bank accounts per vendor; sensitive data (encrypted) | `Spree::StoreCredit` is customer credit, not bank details |
| `Spree::VendorPayout` | Payout records | No Spree equivalent exists |

**REMOVED MODELS (per approval feedback):**
- ~~`Spree::VendorUser`~~ — **REMOVED**. No requirement for multiple vendor logins. Vendor staff login via `Spree::AdminUser` + `Spree::Role('vendor')` (already seeded). Vendor ↔ User association via `Spree::RoleUser` (existing Spree table).
- ~~`Spree::VendorNotification`~~ — **REMOVED**. `noticed` gem natively supports database notifications via its `Notification` model. No separate table needed.

### 4.1 Address: REUSE `Spree::Address`

Vendor address will use `belongs_to :address, class_name: 'Spree::Address'` — same as `Spree::Order` bill/ship addresses. **No `VendorAddress` model.**

### 4.2 Products: REUSE `seller_id`

`Spree::Vendor has_many :products, foreign_key: :seller_id` — **No `VendorProduct` join table.**

### 4.3 Order Approval: REUSE `Spree::OrderApproval`

Vendor accept/reject = create `Spree::OrderApproval` with:
- `order_id`
- `approver: vendor_user` (polymorphic)
- `status: 'approved' | 'rejected'`
- `level: 'vendor'`
- `note: vendor note`
- `metadata: { vendor_id: ... }`

### 4.4 Shipment Tracking: REUSE `Spree::Shipment` (UPDATED per approval)

**Shipment is the SOURCE OF TRUTH for tracking.** `Spree::Shipment#tracking` + `tracking_url` + state machine handle all tracking. Vendor enters `shipment.tracking` (courier tracking number); courier is the selected `shipping_method`; `shipping_date` = `shipped_at` (auto-set on `ship!`); `estimated_delivery` stored in `shipment.public_metadata['estimated_delivery_at']`. **No `ShipmentTracking` table.**

### 4.5 Inventory: REUSE `Spree::StockLocation` + `Spree::StockItem` (UPDATED per approval)

**Architecture: Vendor → StockLocation → Inventory.**

```
Spree::Vendor
    └── has_one :stock_location, class_name: 'Spree::StockLocation'  (via VendorConcern)
              └── has_many :stock_items  → inventory per variant
              └── has_many :stock_movements → audit trail
              └── has_many :shipments (via stock_location_id)
```

Vendor inventory CRUD operates exclusively through `Spree::StockItem` / `Spree::StockMovement` at the vendor's `Spree::StockLocation`. **No new inventory models.**

---

## 5. EXTENSION STRUCTURE (spree_vendor)

```
spree_vendor/
├── app/
│   ├── controllers/
│   │   ├── spree/admin/
│   │   │   └── vendors_controller.rb               # Admin CRUD
│   │   ├── spree/api/v3/
│   │   │   └── vendor/                             # Vendor API (new namespace)
│   │   │       ├── base_controller.rb
│   │   │       ├── dashboard_controller.rb
│   │   │       ├── orders_controller.rb
│   │   │       └── products_controller.rb
│   │   └── concerns/spree/
│   │       └── admin/products_controller_decorator.rb
│   ├── jobs/spree/vendor/
│   │   ├── base_job.rb
│   │   └── revenue_recalculation_job.rb
│   ├── mailers/spree/
│   │   └── vendor_mailer.rb
│   ├── models/
│   │   ├── spree/
│   │   │   ├── vendor.rb
│   │   │   ├── vendor_bank_account.rb
│   │   │   ├── vendor_payout.rb
│   │   │   └── vendor_concern.rb                   # ← Activates Spree core hooks
│   │   ├── spree/permission_sets/
│   │   │   └── vendor.rb
│   │   └── spree/vendor/
│   │       ├── bank_account.rb
│   │       └── ... (sub-models)
│   ├── subscribers/spree/vendor/
│   │   ├── order_assignment_subscriber.rb
│   │   └── order_status_subscriber.rb
│   └── services/spree/vendor/
│       ├── order_assignment_service.rb
│       ├── accept_order_service.rb
│       ├── reject_order_service.rb
│       ├── pack_order_service.rb
│       ├── ship_order_service.rb
│       ├── revenue_service.rb
│       ├── suspend_service.rb
│       ├── notification_service.rb
│       └── payout_service.rb
├── config/
│   ├── initializers/spree.rb
│   ├── locales/en.yml
│   └── routes.rb
├── db/migrate/
│   └── (extension migrations)
├── lib/
│   ├── spree_vendor.rb
│   ├── spree_vendor/
│   │   ├── engine.rb
│   │   ├── configuration.rb
│   │   ├── version.rb
│   │   └── factories.rb
│   └── generators/spree_vendor/install/
│       └── install_generator.rb
├── spec/
│   └── (RSpec suite)
├── spree_vendor.gemspec
├── Gemfile
└── Rakefile
```

---

## 6. SERVICE LAYER

| Service | Responsibility | Transaction? | Async? |
|---|---|---|---|
| `OrderAssignmentService` | Assign order line items to vendor(s) on `order.completed` | ✅ | via SubscriberJob |
| `AcceptOrderService` | Accept order → create `Spree::OrderApproval` approved + publish `vendor.order.accepted` | ✅ | via SubscriberJob |
| `RejectOrderService` | Reject order → create `Spree::OrderApproval` rejected + publish `vendor.order.rejected` | ✅ | via SubscriberJob |
| `PackOrderService` | Update `order.public_metadata['vendor_status'] = 'packed'` + publish `vendor.order.packed` | ✅ | via SubscriberJob |
| `ShipOrderService` | Update `shipment.tracking`, `shipment.shipped_at`, `shipment.ship!` → automatic `shipment.shipped` event → customer email | ✅ | sync (state machine) |
| `RevenueService` | Calculate vendor revenue from line items (async, cached in `vendor.cached_revenue` JSONB / Rails cache) | — | ✅ RevenueRecalculationJob |
| `SuspendService` | Suspend/activate vendor, disable products | ✅ | default |
| `NotificationService` | Create `Spree::VendorNotification` + route to Noticed | — | ✅ |
| `PayoutService` | Generate payouts from ledger | ✅ | ✅ |

---

## 7. EVENT-DRIVEN NOTIFICATION FLOW

```
[Customer places order]
        ↓ Order completes → Spree publishes `order.completed`
[OrderAssignmentSubscriber (Spree::Subscriber, async via Spree::Events::SubscriberJob)]
        ↓
[OrderAssignmentService: creates VendorOrderAssignment + VendorNotification]
        ↓ publishes `vendor.order.assigned`
[VendorNotificationSubscriber]
        ├── Database: Spree::VendorNotification.create
        ├── Email:    Spree::VendorMailer.new_order_email → SolidQueue → Resend
        └── WhatsApp: Noticed → WhatsAppProvider (Meta Cloud API) → SolidQueue
```

### 7.1 Notification Provider Abstraction

```ruby
# app/services/spree/vendor/notification/delivery.rb (in extension)
module Spree::Vendor::Notification
  class Delivery
    # Abstract. Future providers: Twilio, Interakt, Gupshup
    def self.deliver(notification)
      case notification.channel
      when 'email'    then EmailProvider.new(notification).deliver
      when 'whatsapp' then WhatsAppProvider.new(notification).deliver
      when 'database' then DatabaseProvider.new(notification).deliver
      end
    end
  end
end
```

- **Email**: Abstract → `ResendProvider` (default), future: AWS SES, Mailgun, SendGrid
- **WhatsApp**: Abstract → `MetaWhatsAppProvider` (default), future: Twilio, Interakt, Gupshup

---

## 8. CUSTOMER FLOW

| Stage | Customer Receives | Mechanism |
|---|---|---|
| Order Confirmation | `Spree::OrderMailer.confirm_email` | Existing `OrderEmailSubscriber` on `order.completed` |
| Vendor Accepted | Notification (DB + email) | New `OrderStatusSubscriber` on `vendor.order.accepted` |
| Packed | Notification (DB + email) | New `OrderStatusSubscriber` on `vendor.order.packed` |
| Shipped + Tracking | `Spree::ShipmentMailer.shipped_email` with tracking URL | Existing `ShipmentEmailSubscriber` on `shipment.shipped` |
| Delivered | Notification (DB + email) | Tracking status update → `vendor.order.delivered` |

---

## 9. API EXTENSION (no incompatible APIs)

### 9.1 Vendor API — under `/api/v3/vendor/` (new namespace, same versioning)

| Endpoint | Purpose |
|---|---|
| `GET /api/v3/vendor/dashboard` | Stats: today's orders, pending/approved/rejected/packed/shipped/delivered, revenue, low stock |
| `GET /api/v3/vendor/orders?status=pending` | Vendor order list (eager loaded) |
| `POST /api/v3/vendor/orders/:id/accept` | Accept order |
| `POST /api/v3/vendor/orders/:id/reject` | Reject order |
| `POST /api/v3/vendor/orders/:id/pack` | Mark packed |
| `POST /api/v3/vendor/shipments/:id/track` | Enter courier + tracking number + shipping_date + estimated_delivery |
| `POST /api/v3/vendor/shipments/:id/ship` | Ship (fires `shipment.shipped`) |
| `GET /api/v3/vendor/products` | Products + stock + inventory |
| `PATCH /api/v3/vendor/products/:id` | Update own product |
| `GET /api/v3/vendor/revenue` | Revenue report |
| `GET /api/v3/vendor/notifications` | Dashboard notifications |

### 9.2 Customer API — extend existing storefront

| Endpoint | Purpose |
|---|---|
| `GET /api/v3/store/orders/:number` (existing) | Already includes shipments — add `tracking_url`, `public_metadata['vendor_status']` in serializer decorator |

### 9.3 Admin API

| Endpoint | Purpose |
|---|---|
| `GET /api/v3/admin/vendors` | List vendors |
| `POST /api/v3/admin/vendors` | Create vendor |
| `PATCH /api/v3/admin/vendors/:id` | Update vendor |
| `POST /api/v3/admin/vendors/:id/verify` | Verify vendor |
| `POST /api/v3/admin/vendors/:id/suspend` | Suspend vendor |
| `POST /api/v3/admin/vendors/:id/orders/:order_id/override` | Override vendor decision |

---

## 10. DATABASE DESIGN

### 10.1 New Tables

```sql
-- spree_vendors
CREATE TABLE spree_vendors (
  id              BIGSERIAL PRIMARY KEY,
  name            VARCHAR NOT NULL,
  business_name   VARCHAR NOT NULL,
  owner_name      VARCHAR NOT NULL,
  gst_number      VARCHAR,
  pan_number      VARCHAR,
  phone           VARCHAR,
  email           VARCHAR NOT NULL,
  status          VARCHAR NOT NULL DEFAULT 'pending',  -- pending/active/suspended
  verification_status VARCHAR NOT NULL DEFAULT 'unverified', -- unverified/pending/verified/rejected
  address_id      BIGINT REFERENCES spree_addresses(id),
  profile_image_id BIGINT,
  created_by_id   BIGINT,
  updated_by_id   BIGINT,
  created_at      TIMESTAMP NOT NULL,
  updated_at      TIMESTAMP NOT NULL
);
CREATE INDEX idx_spree_vendors_on_status ON spree_vendors(status);
CREATE INDEX idx_spree_vendors_on_email ON spree_vendors(email) WHERE email IS NOT NULL;

-- spree_vendor_bank_accounts (support multiple accounts)
CREATE TABLE spree_vendor_bank_accounts (
  id            BIGSERIAL PRIMARY KEY,
  vendor_id     BIGINT NOT NULL REFERENCES spree_vendors(id),
  account_holder_name VARCHAR NOT NULL,
  account_number VARCHAR NOT NULL,       -- encrypted
  bank_name     VARCHAR NOT NULL,
  ifsc_code     VARCHAR NOT NULL,         -- encrypted
  branch        VARCHAR,
  is_default    BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMP NOT NULL,
  updated_at    TIMESTAMP NOT NULL
);
CREATE INDEX idx_vendor_bank_accounts_on_vendor ON spree_vendor_bank_accounts(vendor_id);

-- spree_vendor_users (join vendor ↔ Spree::AdminUser)
CREATE TABLE spree_vendor_users (
  id         BIGSERIAL PRIMARY KEY,
  vendor_id  BIGINT NOT NULL REFERENCES spree_vendors(id),
  user_id    BIGINT NOT NULL REFERENCES spree_admin_users(id),
  role       VARCHAR DEFAULT 'owner',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
CREATE UNIQUE INDEX idx_vendor_users_unique ON spree_vendor_users(vendor_id, user_id);

-- spree_vendor_notifications
CREATE TABLE spree_vendor_notifications (
  id          BIGSERIAL PRIMARY KEY,
  vendor_id   BIGINT NOT NULL REFERENCES spree_vendors(id),
  type        VARCHAR NOT NULL,
  title       VARCHAR NOT NULL,
  message     TEXT,
  payload     JSONB,
  read_at     TIMESTAMP,
  created_at  TIMESTAMP NOT NULL,
  updated_at  TIMESTAMP NOT NULL
);
CREATE INDEX idx_vendor_notifications_lookup ON spree_vendor_notifications(vendor_id, read_at, created_at);

-- spree_vendor_payouts
CREATE TABLE spree_vendor_payouts (
  id           BIGSERIAL PRIMARY KEY,
  vendor_id    BIGINT NOT NULL REFERENCES spree_vendors(id),
  bank_account_id BIGINT REFERENCES spree_vendor_bank_accounts(id),
  amount       DECIMAL(10,2) NOT NULL,
  currency     VARCHAR NOT NULL,
  status       VARCHAR NOT NULL DEFAULT 'pending',  -- pending/processing/paid/failed
  reference    VARCHAR,
  period_start DATE,
  period_end   DATE,
  paid_at      TIMESTAMP,
  created_at   TIMESTAMP NOT NULL,
  updated_at   TIMESTAMP NOT NULL
);
CREATE INDEX idx_vendor_payouts_lookup ON spree_vendor_payouts(vendor_id, status, period_start, period_end);
```

### 10.2 Modified Spree Tables (extension migrations only — UPDATED per approval)

**IMPORTANT (per approval):** `vendor_id` is **NOT** added to `spree_orders`. A single order can contain products from multiple vendors. Vendor ownership lives at **`spree_line_items.vendor_id`** (per line item) and **`spree_shipments.vendor_id`** (per shipment). Order-level vendor queries use `joins(:line_items).where(line_items: { vendor_id: ... })`.

```sql
-- 1. Add FK from existing seller_id → spree_vendors
ALTER TABLE spree_products
  ADD CONSTRAINT fk_products_vendor FOREIGN KEY (seller_id) REFERENCES spree_vendors(id);

-- 2. vendor_id on spree_line_items (per line-item vendor ownership)
ALTER TABLE spree_line_items
  ADD COLUMN vendor_id BIGINT REFERENCES spree_vendors(id);
CREATE INDEX idx_spree_line_items_on_vendor_id ON spree_line_items(vendor_id);
CREATE INDEX idx_spree_line_items_on_vendor_id_and_order
  ON spree_line_items(vendor_id, order_id);

-- 3. vendor_id on spree_shipments (per-shipment vendor ownership)
ALTER TABLE spree_shipments
  ADD COLUMN vendor_id BIGINT REFERENCES spree_vendors(id);
CREATE INDEX idx_spree_shipments_on_vendor_id ON spree_shipments(vendor_id);
```

**No vendor_id on `spree_orders`** — multi-vendor orders supported natively.

---

## 11. SEQUENCE DIAGRAM

```
Customer        Storefront        Spree Core        SpreeVendor Extension        Vendor UI        Customer Email
    │                │                │                      │                        │                 │
    │── place order ─→│                │                      │                        │                 │
    │                │── complete ────→│                      │                        │                 │
    │                │                │── order.completed ───→ SubscriberJob          │                 │
    │                │                │                      │── OrderAssignmentService│                 │
    │                │                │                      │── assign vendor ──────→│                 │
    │                │                │                      │── notify ────────────→│ Vendor Email    │
    │                │                │                      │                        │                 │
    │                │                │                      │←── accept ─────────────│                 │
    │                │                │                      │── OrderApproval approved│                 │
    │                │                │                      │── vendor.order.accepted│                 │
    │                │                │                      │── OrderStatusSubscriber│                 │
    │                │                │                      │                        │── email ───────→│
    │                │                │                      │                        │                 │
    │                │                │                      │←── pack ───────────────│                 │
    │                │                │                      │── vendor.order.packed ─→│── email ──────→│
    │                │                │                      │                        │                 │
    │                │                │                      │←── track+ship ─────────│                 │
    │                │                │                      │── shipment.tracking = X│                 │
    │                │                │                      │── shipment.ship! ─────→│                 │
    │                │                │                      │── shipment.shipped ───→│── email+tracking→│
    │←── status ─────│←── tracking ───│                      │                        │                 │
    │                │                │                      │←── delivered ──────────│                 │
    │                │                │                      │── vendor.order.delivered│── email ──────→│
```

---

## 12. MIGRATION PLAN

| Step | Migration | Notes |
|---|---|---|
| 1 | `CreateSpreeVendors` | vendors + indexes + FKs |
| 2 | `CreateSpreeVendorBankAccounts` | encrypted columns via `has_encrypted` |
| 3 | ~~`CreateSpreeVendorUsers`~~ | **REMOVED** per approval — no `VendorUser` needed |
| 4 | ~~`CreateSpreeVendorNotifications`~~ | **REMOVED** per approval — Noticed handles DB notifications |
| 5 | `CreateSpreeVendorPayouts` | payouts |
| 6 | ~~`AddVendorIdToSpreeOrders`~~ | **REMOVED** per approval — no vendor_id on orders (multi-vendor) |
| 7 | `AddVendorIdToSpreeShipments` | per-shipment vendor ownership + index |
| 8 | `AddVendorIdToSpreeLineItems` | per-line-item vendor ownership + composite index (vendor_id, order_id) |
| 9 | `AddForeignKeyToSpreeProductsSellerId` | FK from existing `seller_id` → `spree_vendors` |
| 10 | (no order status column needed) | `public_metadata['vendor_status']` via JSONB |

---

## 13. GEMS

| Gem | Purpose | In Extension gemspec |
|---|---|---|
| `noticed` | Multi-channel notifications (DB + email + WhatsApp + future push) | ✅ Production dep |
| `phonelib` | Phone validation | ✅ Production dep |
| `resend` | Email delivery (default provider) | ✅ Production dep |
| `faraday` | WhatsApp Meta Cloud API calls | ✅ Production dep (via noticed) |
| `spree`, `spree_admin`, `spree_api`, `spree_emails` | Spree deps | ✅ |
| `rspec-rails`, `factory_bot_rails` (via spree_dev_tools) | Testing | ✅ Dev deps |

**NOT included**: `pundit` (Spree PermissionSets suffice), `money-rails` (Spree has Money), `paper_trail` (Spree has StateChange), `twilio-ruby` (abstraction layer handles it).

---

## 14. TESTING STRATEGY

- **RSpec** via spree_dev_tools
- **Model specs**: Vendor, VendorBankAccount (encryption), VendorUser, VendorNotification, VendorPayout
- **Service specs**: each service isolated with factory
- **Subscriber specs**: event → subscriber → service dispatch
- **Controller specs**: vendor API + admin API authorization
- **System specs**: vendor dashboard flow (accept → pack → track → ship)
- **Migration specs**: up/down rollback verification
- **Zeitwerk + i18n specs** (included in template)

---

## 15. ROLLBACK STRATEGY

- Every migration has `down` method (drop tables / remove columns / drop FKs)
- Extension can be removed by: `bundle remove spree_vendor` + `rails db:rollback STEP=N`
- No Spree core tables modified — only additive columns/FKs
- All events/subscribers are in extension namespace; removing extension = no vendor events fire
- `Spree::VendorConcern` is conditionally defined — if extension removed, Spree core just skips the include

---

## 16. UPGRADE COMPATIBILITY

- ✅ No Spree core files modified — 100% compatible with Spree 5.6 → 6.0 upgrades
- ✅ Uses only official extension points (`VendorConcern`, `Spree::Subscriber`, `Spree::Events`, `PermissionSets`, decorators)
- ✅ New tables use `spree_` prefix (same as core)
- ✅ API versioned under `/api/v3/` (same as Spree)
- ✅ `isolate_namespace Spree` (standard Spree extension pattern)
- ✅ Preferences via `Spree::Preferences::Configuration` (standard)
- ✅ Install generator (`rails g spree_vendor:install`) (standard)

---

## 17. IMPLEMENTATION PHASES

### Phase A: Skeleton (approved now)
1. Run `spree-extension create spree_vendor` generator
2. Configure gemspec + Gemfile
3. Add `gem 'spree_vendor', path: 'engines/spree_vendor'` to host Gemfile

### Phase B: Data Layer
4. Migrations (10)
5. Models + validations + scopes + encrypted bank details
6. VendorConcern module (activates Spree core hooks)

### Phase C: Services + Events
7. 9 services
8. 2 subscribers
9. VendorMailer
10. Notification delivery abstraction (Email + WhatsApp providers)

### Phase D: Controllers + APIs + UI
11. Admin::VendorsController
12. API V3 vendor namespace (11 endpoints)
13. Vendor dashboard views (Tailwind + Turbo)
14. Admin vendor management views

### Phase E: Testing + Polish
15. Full RSpec suite
16. Documentation
17. Performance review (indexes, eager loading, N+1 audit)

---

*This architecture verification document is the deliverable that must be approved before Phase A begins.*