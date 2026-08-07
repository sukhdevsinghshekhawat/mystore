# CODEBASE AUDIT REPORT — Spree Marketplace / Supplier Module

**Date:** 2026-08-04  
**Application:** my_store (Spree 5.6.1 / Rails 8.1.3 / Ruby 3.3.2 / PostgreSQL)  
**Scope:** Full audit of existing implementation for Supplier, Vendor, Merchant, Shipment, Order, Notification, Admin, Webhook, and Inventory features.

---

## 1. EXECUTIVE SUMMARY

The application is a fresh **Spree 5.6.1** storefront running on **Rails 8.1.3** with **Devise** authentication, **Solid Queue** background jobs, **Solid Cache**, and **ActiveStorage**. 

**Critical findings:**

1. **`Spree::VendorConcern` is an OPTIONAL hook** — Spree core already includes conditional `include Spree::VendorConcern if defined?(Spree::VendorConcern)` in **6 core models**: `Order`, `Product`, `Shipment`, `StockLocation`, `ShippingMethod`, `Export`, `Report`. This means Spree has a **plugin-ready vendor extension point** that is currently inactive. Implementing `Spree::VendorConcern` will automatically be included by all 7 models with zero monkey-patching.

2. **Existing vendor scaffolding is incomplete** — A migration adds `seller_id` to `spree_products`, a `VendorAbility` permission set exists, and a `ProductsControllerDecorator` sets `seller_id` from `current_admin_user`. But the `Seller` model, `Seller` role, vendor dashboard, and vendor order flows do **not exist yet**.

3. **Spree has a full Event system** (`Spree::Events`) with `publishes_lifecycle_events`, `publish_event`, and `Spree::Subscriber` base class with async ActiveJob dispatch (`Spree::Events::SubscriberJob`). This should power all notifications instead of custom callbacks.

4. **Spree already has `Spree::OrderApproval`** — a polymorphic order approval table (`pending/approved/rejected`) with `approver` (polymorphic), `level`, `note`, `metadata`, `decided_at`. This maps **directly** to supplier accept/reject workflow.

5. **Spree already emits** `order.completed`, `order.canceled`, `order.resumed`, `shipment.shipped`, `shipment.canceled`, `shipment.resumed`, `order.shipped` events + email subscribers (`OrderEmailSubscriber`, `ShipmentEmailSubscriber`).

6. **No Supplier/Vendor/Merchant/Marketplace model exists** anywhere in the app or Spree core.

7. **No custom mailers, jobs, services, APIs, or admin pages exist** in the host app.

8. **Background job infrastructure is production-ready**: Solid Queue (Rails 8 default), `config/queue.yml` configured, `Spree.queues.*` available.

---

## 2. EXISTING MODELS

### 2.1 Host App Models

| Model | Path | Notes |
|---|---|---|
| `Spree::User` | `app/models/spree/user.rb` | Devise + Spree::UserAddress, UserMethods, UserPaymentSource |
| `Spree::AdminUser` | `app/models/spree/admin_user.rb` | Devise + Spree::AdminUserMethods |
| `VendorAbility` | `app/models/vendor_ability.rb` | Spree::PermissionSets::Base — scopes `Spree::Product` by `seller_id: user.id`, allows `:admin, :create` for products |
| `ApplicationRecord` | `app/models/application_record.rb` | Abstract base |
| `Spree` (module) | `app/models/spree.rb` | Sets `table_name_prefix = "spree_"` |

### 2.2 Spree Core Models (`spree_core-5.6.1`)

**Auth & Users:** `Spree::User`, `Spree::AdminUser`, `Spree::Role`, `Spree::RoleUser`, `Spree::Invitation`, `Spree::ApiKey`, `Spree::RefreshToken`, `Spree::UserIdentity`

**Catalog:** `Spree::Product`, `Spree::Variant`, `Spree::OptionType`, `Spree::OptionValue`, `Spree::Price`, `Spree::PriceList`, `Spree::Asset`, `Spree::Taxon`, `Spree::Taxonomy`, `Spree::Prototype`, `Spree::DataFeed`

**Order:** `Spree::Order`, `Spree::LineItem`, `Spree::OrderApproval`, `Spree::OrderCancellation`, `Spree::OrderPromotion`, `Spree::OrderRoutingRule`

**Checkout:** `Spree::Address`, `Spree::Country`, `Spree::State`, `Spree::Zone`, `Spree::Payment`, `Spree::PaymentMethod`, `Spree::PaymentSession`, `Spree::PaymentSource`, `Spree::CreditCard`, `Spree::Refund`, `Spree::RefundReason`, `Spree::StoreCredit`, `Spree::StoreCreditEvent`, `Spree::StoreCreditCategory`, `Spree::StoreCreditType`, `Spree::GiftCard`, `Spree::GiftCardBatch`

**Shipping:** `Spree::Shipment`, `Spree::ShippingMethod`, `Spree::ShippingRate`, `Spree::ShippingCategory`, `Spree::ShippingMethodCategory`, `Spree::ShippingMethodZone`

**Inventory:** `Spree::StockLocation`, `Spree::StockItem`, `Spree::StockMovement`, `Spree::StockReservation`, `Spree::StockTransfer`, `Spree::InventoryUnit`

**Returns:** `Spree::CustomerReturn`, `Spree::ReturnAuthorization`, `Spree::ReturnItem`, `Spree::Reimbursement`, `Spree::ReturnAuthorizationReason`

**Promotions:** `Spree::Promotion`, `Spree::PromotionAction`, `Spree::PromotionRule`, `Spree::PromotionCategory`, `Spree::CouponCode`

**Config:** `Spree::Store`, `Spree::Channel`, `Spree::Market`, `Spree::Country`, `Spree::TaxCategory`, `Spree::TaxRate`, `Spree::Calculator`, `Spree::ZoneMember`

**Webhooks:** `Spree::WebhookEndpoint`, `Spree::WebhookDelivery`

**Events:** `Spree::Event`, `Spree::Subscriber`, `Spree::Events::SubscriberJob`, `Spree::Events::Registry`, `Spree::Events::Adapters::ActiveSupportNotifications`

**State Logging:** `Spree::StateChange` (stateful polymorphic association on Order & Shipment)

**Other:** `Spree::Metafield`, `Spree::MetafieldDefinition`, `Spree::Tag`, `Spree::NewsletterSubscriber`, `Spree::Wishlist`, `Spree::WishedItem`, `Spree::Export`, `Spree::Import`, `Spree::Report`, `Spree::Digital`, `Spree::DigitalLink`, `Spree::Preference`, `Spree::LogEntry`, `Spree::Tracker`, `Spree::StoreCredit`, `Spree::CustomerGroup`, `Spree::CustomerGroupUser`

---

## 3. EXISTING CONTROLLERS

### 3.1 Host App Controllers
| Controller | Path | Notes |
|---|---|---|
| `ApplicationController` | `app/controllers/application_controller.rb` | Minimal - modern browser gate, importmap etag |

### 3.2 Spree Admin Controllers (`spree_admin-5.6.1`)
Full admin suite: `ProductsController`, `OrdersController`, `ShipmentsController`, `StockLocationsController`, `StockItemsController`, `StockMovementsController`, `StockTransfersController`, `UsersController`, `RolesController`, `RoleUsersController`, `StoreCreditsController`, `PaymentsController`, `RefundsController`, `ReimbursementsController`, `CustomerReturnsController`, `ReturnAuthorizationsController`, `ReturnItemsController`, `WebhookEndpointsController`, `WebhookDeliveriesController`, `ShippingMethodsController`, `TaxRatesController`, `PromotionsController`, `GiftCardsController`, `DashboardController`, `ReportsController`, `ExportsController`, `ImportsController`, `ApiKeysController`.

Key detail: **`Spree::Admin::ShipmentsController`** already has `ship`, `split`, `transfer`, `update` actions using `Spree.shipment_update_service` and state machine transitions.

### 3.3 Spree API V3 Controllers (`spree_api-5.6.1`)

**Storefront:** `Spree::Api::V3::Store::BaseController`, `OrdersController`, `CartsController`, `Customer::OrdersController`, `Customer::AddressesController`, `ProductsController`, `CategoriesController`, `AuthController`, `WishlistsController`, `DigitalsController`, `NewsletterSubscribersController`, `MarketsController`, `CurrenciesController`, `LocalesController`, `ChannelsController(s)`

**Admin API:** `Spree::Api::V3::Admin::BaseController`, `OrdersController(s)`, `ProductsController(s)`, `CustomersController`, `CustomerGroupsController`, `AuthController`, `DashboardController`, `WebhookEndpointsController` (via admin), `ApiKeysController`

**Webhooks:** `Spree::Api::V3::Webhooks::PaymentsController`

---

## 4. EXISTING SERVICES (Spree::ServiceModule pattern)

### 4.1 Spree Core Dependency-Injected Services (`spree_core/lib/spree/core/dependencies.rb`)
All injectable via `Spree.dependencies`:

**Cart:** `Spree::Cart::Create/AddItem/Update/RemoveItem/RemoveLineItem/SetQuantity/Empty/Destroy/Associate/ChangeCurrency/Recalculate/EstimateShippingRates/RemoveOutOfStockItems`

**Checkout:** `Spree::Checkout::Next/Advance/Update/Complete/AddStoreCredit/RemoveStoreCredit/GetShippingRates/SelectShippingMethod`

**Orders:** `Spree::Orders::Create/Update/Complete/Approve/Cancel/FindCurrent/FindComplete`

**Shipments:** `Spree::Shipments::Create/Update/ChangeState/AddItem/RemoveItem`

**Fulfillment:** `Spree::Fulfillments::Create`

**Payments:** `Spree::Payments::Create`, `Spree::Payments::HandleWebhook`

**Accounts:** `Spree::Account::Create/Update`

**Addresses:** `Spree::Addresses::Create/Update/Find`

**Line Items:** `Spree::LineItems::Create/Update/Destroy/FindByVariant`

**Credit Cards:** `Spree::CreditCards::Destroy/Find`

**Gift Cards:** `Spree::GiftCards::Apply/Remove/Redeem`

**Finders:** `Spree::Products::Find`, `Spree::Variants::Find`, `Spree::Taxons::Find`, `Spree::Countries::Find`, `Spree::Stores::FindDefault`, `Spree::Addresses::Find`, `Spree::CreditCards::Find`

### 4.2 Key Services Audited

| Service | Notes |
|---|---|
| `Spree::Shipments::Update` | Updates shipment + order payment_state + shipment_state + persists totals inside a transaction |
| `Spree::Shipments::ChangeState` | Calls `shipment.send("#{state}!")` = state machine transition |
| `Spree::Orders::Cancel` | `order_cancel_service` — `order.canceled_by(user)` |
| `Spree::Orders::Approve` | `order_approve_service` — `order.approved_by(user)` |

---

## 5. EXISTING MAILERS

### 5.1 Spree Email Mailers (`spree_emails-5.6.1`)

| Mailer | Methods |
|---|---|
| `Spree::BaseMailer` | Base with store locale |
| `Spree::OrderMailer` | `confirm_email(order, resend)`, `cancel_email(order, resend)`, `store_owner_notification_email(order)`, `payment_link_email(order_id)` |
| `Spree::ShipmentMailer` | `shipped_email(shipment, resend)` |
| `Spree::CustomerMailer` | Customer-related |
| `Spree::ReimbursementMailer` | Reimbursement notifications |
| `Spree::NewsletterMailer` | Newsletter |

**These mailers are wired via subscribers** — `OrderEmailSubscriber` listens to `order.completed`, `order.canceled`, `order.resend_confirmation_email`; `ShipmentEmailSubscriber` listens to `shipment.shipped`. They already handle `store.prefers_send_consumer_transactional_emails?` gating.

### 5.2 Spree Core Mailers
`Spree::BaseMailer`, `Spree::ImportMailer`, `Spree::AdminUserMailer`, `Spree::ReportMailer`, `Spree::ExportMailer`, `Spree::InvitationMailer`, `Spree::WebhookMailer`

### 5.3 Host App
`ApplicationMailer` (bare, no custom mailers)

---

## 6. EXISTING JOBS

### 6.1 Spree Jobs
| Job | Purpose |
|---|---|
| `Spree::Events::SubscriberJob` | Async dispatch for all Spree::Events subscribers (queue: `Spree.queues.events`) |
| `Spree::Products::AutoMatchTaxonsJob` | Auto taxon matching |
| `Spree::Products::TouchTaxonsJob` | Taxonomy touch |

### 6.2 Host App
`ApplicationJob` (base ActiveJob, no custom jobs)

### 6.3 Queue Infrastructure
`config/queue.yml` configured with Solid Queue — `dispatchers` (1s interval, 500 batch), `workers` (queues: "*", threads: 3). Production-ready.

---

## 7. EXISTING STATE MACHINES (Reuse, don't replace)

### 7.1 Order Checkout State Machine (`Spree::Order::Checkout`)
```
cart → address → delivery → payment → confirm → complete
```
Plus: `cancel` → canceled, `return` → returned, `resume` → resumed, `authorize_return` → awaiting_return

### 7.2 Order Status
`draft` / `placed` / `canceled` (string `status` column, default `draft`)

### 7.3 Shipment State Machine (`Spree::Shipment`)
```
pending ⇄ ready → shipped
     ↘ canceled ⇄ resumed
```
Events: `ready`, `pend`, `ship`, `cancel`, `resume`  
Transitions fire webhooks + events: `shipment.shipped`, `shipment.canceled`, `shipment.resumed`, plus `order.shipped` when all shipped.

### 7.4 Product Status State Machine
`draft` → `active` → `archived` (with `activate`, `archive`, `draft` events). Fires `product.activated`, `product.archived`.

### 7.5 Payment State Machine
`checkout` → `processing` → `completed` / `pending` / `failed` / `void`

### 7.6 OrderApproval
**No state machine** — simple `status` column enum: `pending` / `approved` / `rejected`, with `level`, `note`, `decided_at`, `metadata`, polymorphic `approver`. **This is the model for supplier accept/reject.**

---

## 8. EXISTING CALLBACKS / EVENTS

### 8.1 Lifecycle Events (`publishes_lifecycle_events`)
All Spree base models automatically publish:
- `*.created` (e.g., `order.created`, `product.created`)
- `*.updated` (e.g., `order.updated`)
- `*.deleted` (e.g., `order.deleted`)

### 8.2 Custom Events Published

| Event | Model | Trigger |
|---|---|---|
| `order.completed` | Order | `finalize!` after transition to complete |
| `order.canceled` | Order | `after_cancel` state machine callback |
| `order.resumed` | Order | `after_resume` state machine callback |
| `order.shipped` | Order | `Shipment#publish_shipment_shipped_event` when all shipped |
| `shipment.shipped` | Shipment | `after_transition to: :shipped` |
| `shipment.canceled` | Shipment | `after_transition to: :canceled` |
| `shipment.resumed` | Shipment | `after_transition from: :canceled` |
| `product.activated` | Product | state machine `activate` |
| `product.archived` | Product | state machine `archive` |

### 8.3 Event Payload
Events carry `id` (prefixed_id), `name`, `store_id`, `payload`, `metadata`, `created_at`. Subscribers receive a `Spree::Event` object.

### 8.4 How Subscribers Work
```ruby
class MySubscriber < Spree::Subscriber
  subscribes_to 'order.completed'  # async: true by default → Spree::Events::SubscriberJob
  def handle(event)
    order = Spree::Order.find_by_prefix_id(event.payload['id'])
    # ...
  end
end
```

---

## 9. EXISTING ADMIN PAGES

Full Spree Admin mounted at `/admin` (default). Includes:
- **Orders**: list, show, edit, shipments (ship/split/transfer), line items, payments, refunds, returns, adjustments, promotions, customer returns, return authorizations, reimbursements
- **Products**: CRUD, clone, variants, digital assets, bulk updates, taxons
- **Stock**: stock items, movements, transfers, locations
- **Customers**: users, store credits, addresses, orders, gift cards
- **Promotions**: full CRUD
- **Gift Cards**: batches and individual
- **Configuration**: stores, channels, markets, shipping methods, tax rates, zones, countries, states, payment methods, roles, admin users
- **Webhooks**: endpoints, deliveries
- **Reports/Exports/Imports**: built-in framework
- **API Keys**: admin API

`Spree::Admin::ProductsController` is **decorated** by host app to set `seller_id = current_admin_user.id`.

---

## 10. EXISTING ROUTES

```ruby
# config/routes.rb
mount Spree::Core::Engine, at: '/'
devise_for :admin_users, class_name: "Spree::AdminUser"
devise_for :users, class_name: "Spree::User"
get "up" => "rails/health#show"
```

Spree Engine adds:
- Storefront: `/products`, `/cart`, `/checkout`, `/account`, etc.
- Admin: `/admin/*` (all CRUD above)
- API v3: `/api/v3/store/...`, `/api/v3/admin/...`, `/api/v3/webhooks/...`

---

## 11. EXISTING SHIPMENT / INVENTORY / STOCK LOGIC

### 11.1 Shipment
- `Spree::Shipment` with state machine (`pending/ready/shipped/canceled/resumed`)
- Tracking field (`tracking`), `tracking_url` (shipping method template or full URL)
- `shippable?` = `can_ship? && (tracked? || digital?)`
- `Spree::Shipments::Update`, `Spree::Shipments::ChangeState`, `Spree::Shipments::Create`, `Spree::Shipments::AddItem`, `Spree::Shipments::RemoveItem`
- Firing `shipment.shipped` event automatically emails customer via `Spree::ShipmentEmailSubscriber` → `Spree::ShipmentMailer.shipped_email`

### 11.2 Inventory
- `Spree::StockItem` (count_on_hand, backorderable), `Spree::StockMovement` (action, quantity, originator), `Spree::StockReservation`
- `Spree::InventoryUnit` — links LineItem → Shipment → Variant, has own state (`on_hand`, `backordered`, `shipped`, `returned`, `canceled`)

### 11.3 Stock Locations
- `Spree::StockLocation` — active, default, kind (warehouse), propagate_all_variants, pickup_enabled, address fields
- Admin CRUD available at `/admin/stock_locations`

### 11.4 Order Routing
- `Spree::OrderRoutingRule` + strategies — Spree 5.5/5.6 auto-splits orders into shipments by stock location / channel / preferred location
- `Order#create_proposed_shipments` uses `order_routing_strategy.for_allocation`

---

## 12. EXISTING NOTIFICATION INFRASTRUCTURE

| Layer | What Exists |
|---|---|
| Email | `Spree::OrderMailer`, `Spree::ShipmentMailer`, `Spree::CustomerMailer`, `Spree::ReimbursementMailer` |
| Event Bus | `Spree::Events.publish/subscribe` with ActiveSupport::Notifications adapter |
| Subscribers | `Spree::Subscriber` base + `OrderEmailSubscriber`, `ShipmentEmailSubscriber`, `ProductMetricsSubscriber`, `EventLogSubscriber`, `ImportEmailSubscriber`, `ExportSubscriber`, `ReportSubscriber` |
| Async Dispatch | `Spree::Events::SubscriberJob` → Solid Queue |
| Webhook System | `Spree::WebhookEndpoint`, `Spree::WebhookDelivery`, subscriptions JSONB, `Spree::Shipment::Webhooks`, `Spree::Order::Webhooks` (hooks to fill), `WebhookMailer` |
| Store Emails Config | `store.prefers_send_consumer_transactional_emails?`, `store.new_order_notifications_email` |

---

## 13. EXISTING GEMS

| Gem | Version | Purpose |
|---|---|---|
| `rails` | 8.1.3 | Core |
| `spree` | 5.6.1 | Meta-gem |
| `spree_core` | 5.6.1 | Core commerce |
| `spree_admin` | 5.6.1 | Admin UI |
| `spree_api` | 5.6.1 | REST API v3 |
| `spree_emails` | 5.6.1 | Transactional emails |
| `spree_i18n` | 5.3.3 | Translations |
| `spree_dev_tools` | 0.6.3 | Dev tools |
| `devise` | latest | Authentication |
| `solid_queue` | Rails 8 default | Background jobs |
| `solid_cache` | Rails 8 default | Caching |
| `solid_cable` | Rails 8 default | ActionCable |
| `image_processing` | 1.2 | Image variants |
| `pg` | 1.x | PostgreSQL |
| `importmap-rails`, `turbo-rails`, `stimulus-rails` | | Frontend |
| `propshaft` | | Asset pipeline |
| `jbuilder` | | JSON views |
| `bootsnap`, `kamal`, `thruster`, `puma` | | Infrastructure |
| `letter_opener` | | Dev email preview |

**Missing for marketplace**: `pundit` (authorization), `noticed` (multi-channel notifications: email + WhatsApp), `phonelib` (phone validation), `countries` (country data), `money-rails` (money handling), `meilisearch` (search — optional), `aws-sdk-ses` or `resend` (production email), `paper_trail` (audit — optional, Spree has `StateChange` already).

---

## 14. EXISTING VENDOR/SUPPLIER/MERCHANT CODE (Gap Analysis)

| Area | Exists? | Details |
|---|---|---|
| Supplier model | ❌ | None |
| Vendor model | ❌ | None |
| Merchant model | ❌ | None |
| Marketplace model | ❌ | None |
| `spree_products.seller_id` | ✅ | Integer column + index |
| `VendorAbility` | ✅ | Permission set scoping products by `seller_id` |
| Vendor role | ✅ | `vendor` role assigned in `Spree.permissions.assign(:vendor, [VendorAbility, DashboardDisplay])` |
| Product controller decorator | ✅ | Sets `seller_id = current_admin_user.id` on product create |
| `Spree::VendorConcern` hook | ✅ | **Conditional include in 7 Spree core models** — ready for a `VendorConcern` module |
| Vendor dashboard | ❌ | None |
| Vendor order flow | ❌ | None |
| Supplier order approval | ❌ | None (but `Spree::OrderApproval` exists!) |
| Supplier notifications | ❌ | None (but `Spree::Subscriber` system exists!) |
| Supplier shipping | ❌ | None (shipment.shipped event exists!) |
| Supplier API | ❌ | None |
| Admin supplier management | ❌ | None |
| Supplier revenue tracking | ❌ | None (Spree::Product has `revenue`, `units_sold_count` columns!) |

---

## 15. REUSABLE COMPONENTS (Phase 2 Leverage)

| Reusable Component | How to Use |
|---|---|
| `Spree::VendorConcern` hook | Implement module in `app/models/spree/vendor_concern.rb` — gets auto-included in Order, Product, Shipment, StockLocation, ShippingMethod, Export, Report |
| `Spree::OrderApproval` | Supplier accept/reject per order with status pending/approved/rejected, polymorphic approver, note, metadata, decided_at |
| `Spree::Order` state machine | Reuse `complete`, `cancel`, `resume` — never override |
| `Spree::Shipment` state machine | Reuse `ready`, `ship`, `cancel`, `resume` for packing→shipped→delivered flow |
| `Spree::Events` + `Spree::Subscriber` | All notifications (email/WhatsApp/dashboard) via subscribers on `order.completed`, `shipment.shipped`, custom `supplier.order.accepted` events |
| `Spree::EmailSubscriber` pattern | Extend with `SupplierEmailSubscriber` |
| `Spree::Event::SubscriberJob` | Auto async dispatch via Solid Queue |
| `Spree::ShipmentMailer`, `Spree::OrderMailer` | Customer-side emails already wired to `shipment.shipped` / `order.completed` |
| `Spree::Admin::ShipmentsController` | Admin already can ship/track/transfer — extend for supplier |
| `Spree::Admin::ResourceController` | Base for new admin supplier controller |
| `Spree::StockLocation` | Each supplier gets a stock location (or map supplier to stock location) |
| `Spree::StockItem` / `StockMovement` | Supplier inventory management |
| `Spree::StateChange` | Supplier action audit trail |
| `Spree::WebhookEndpoint` + subscriptions | Optional external webhooks for suppliers |
| `Spree::Product` revenue/units_sold_count | Supplier revenue reporting |
| `Spree::PermissionSets` | VendorAbility + new SupplierAbility |
| `Spree::Role` | Create `supplier` role |
| `Spree::Product` `seller_id` | Supplier-product association (already migrated) |
| `Spree::Shipment#tracking` | Supplier enters tracking number; `shipment_shipped` event triggers customer email automatically |
| `Spree::Shipment#tracking_url` | Tracking link from shipping method template |
| `Spree::Reports` framework | Supplier revenue/payout reports |
| `Spree::Exports` framework | Supplier CSV exports |
| `Spree::Admin::BaseController` | Admin-only supplier management pages |
| `Spree::Api::V3::Admin::BaseController` | Admin API for suppliers |
| `Spree::Api::V3::Store::BaseController` | Storefront API for customer order status/tracking |
| `Spree::Customer::OrdersController` | Existing customer order history — add tracking info to serializer |
| `Spree::Order#number`, prefixed IDs | All external references |

---

## 16. DATABASE TABLES (Current)

### 16.1 Custom Tables (Host App)
| Table | Columns | Notes |
|---|---|---|
| `spree_products.seller_id` | `integer`, indexed | Added via migration 20260804180712 |

### 16.2 Relevant Spree Tables
| Table | Key Columns |
|---|---|
| `spree_orders` | `number`, `state`, `status`, `shipment_state`, `payment_state`, `total`, `user_id`, `store_id`, `completed_at` |
| `spree_shipments` | `number`, `state`, `tracking`, `stock_location_id`, `order_id`, `shipped_at`, `address_id` |
| `spree_order_approvals` | `order_id`, `approver_id/type`, `status`, `level`, `note`, `metadata`, `decided_at` |
| `spree_products` | `seller_id`, `revenue`, `units_sold_count`, `status`, `store_id` |
| `spree_stock_locations` | `name`, `active`, `default`, `kind`, `address fields` |
| `spree_stock_items` | `variant_id`, `stock_location_id`, `count_on_hand`, `backorderable` |
| `spree_stock_movements` | `stock_item_id`, `action`, `quantity`, `originator` |
| `spree_inventory_units` | `order_id`, `shipment_id`, `line_item_id`, `variant_id`, `state`, `quantity` |
| `spree_state_changes` | `stateful_type/id`, `name`, `previous_state`, `next_state`, `user_id` |
| `spree_webhook_endpoints` | `store_id`, `url`, `secret_key`, `subscriptions`, `active` |
| `spree_webhook_deliveries` | `endpoint_id`, `event_name`, `payload`, `success`, `response_code` |
| `spree_role_users` | `user_id/type`, `role_id`, `resource_id/type`, `store_id` |
| `spree_roles` | `name` |
| `spree_users` | `email`, `first_name`, `last_name`, `phone` |
| `spree_shipping_methods` | `name`, `code`, `tracking_url`, `estimated_transit_days` |
| `spree_store_credits` | `user_id`, `amount`, `amount_used`, `category_id`, `currency` |

---

## 17. GAP ANALYSIS — WHAT MUST BE BUILT

### 17.1 New Models
| Model | Notes |
|---|---|
| `Spree::Supplier` | Name, business_name, GST, phone, email, address, bank_details, status |
| `Spree::Supplier::BankDetail` | Nested model for bank details (encrypted) |
| `Spree::Supplier::Address` | Nested model (or reuse `Spree::Address` with `label`) |
| `Spree::SupplierUser` | Join supplier ↔ Spree::AdminUser (or Spree::User) |
| `Spree::SupplierProduct` | Optional join (or reuse `Product#seller_id`) |
| `Spree::SupplierOrder` | Optional join supplier ↔ order |
| `Spree::SupplierOrder` line_item association | via `spree_line_items.supplier_id` or through products |
| `Spree::SupplierNotification` | Dashboard notifications |
| `Spree::TrackingDetail` | Courier, tracking_number, shipping_date, estimated_delivery (Extends `Spree::Shipment`) |

### 17.2 New Services
| Service | Purpose |
|---|---|
| `Spree::Supplier::OrderAssignment` | Assign order to supplier on completion (use event subscriber) |
| `Spree::Supplier::OrderAccept` | Accept order → create `Spree::OrderApproval` + event |
| `Spree::Supplier::OrderReject` | Reject order → create `Spree::OrderApproval` rejected + event |
| `Spree::Supplier::OrderPack` | Mark order as packed |
| `Spree::Supplier::Shipment` | Update shipment tracking + ship → triggers `shipment.shipped` event |
| `Spree::Supplier::Revenue` | Calculate supplier revenue by period |
| `Spree::Supplier::Dashboard` | Dashboard stats |
| `Spree::Supplier::Payout` | Payout generation |
| `Spree::Supplier::Suspend` | Suspend/activate supplier |

### 17.3 New Jobs
| Job | Purpose |
|---|---|
| `Spree::Supplier::NotifySupplierJob` | Email + WhatsApp + dashboard notification on new order |
| `Spree::Supplier::NotifyCustomerJob` | Customer email + status update when supplier ships |
| `Spree::Supplier::TrackingUpdateJob` | Update tracking status |
| `Spree::Supplier::RevenueRecalculationJob` | Async revenue aggregation |

### 17.4 New Mailers
| Mailer | Purpose |
|---|---|
| `Spree::SupplierMailer` | `new_order_email`, `order_accepted_email`, `order_rejected_email`, `payout_email`, `suspended_email` |
| Extend `Spree::ShipmentMailer` | Already handles customer `shipped_email` — add tracking info |

### 17.5 New Controllers
| Controller | Purpose |
|---|---|
| `Spree::Admin::SuppliersController` | Admin CRUD for suppliers |
| `Spree::Admin::Supplier::OrdersController` | Admin view supplier orders |
| `Spree::Supplier::DashboardController` | Supplier dashboard |
| `Spree::Supplier::OrdersController` | Supplier order workflow |
| `Spree::Supplier::ProductsController` | Supplier products management |
| `Spree::Supplier::InventoryController` | Supplier stock management |
| `Spree::Supplier::ProfileController` | Supplier profile |
| `Spree::Api::V3::Supplier::BaseController` | Supplier API base |
| `Spree::Api::V3::Store::Orders::TrackingsController` | Customer tracking info |

### 17.6 New Policies / Abilities
| Policy | Purpose |
|---|---|
| `Spree::SupplierAbility` | Permission set for supplier role |
| `Spree::SupplierPolicy` | Pundit-style policy (or extend VendorAbility) |

### 17.7 New APIs
| API | Purpose |
|---|---|
| `GET /api/v3/supplier/dashboard` | Stats |
| `GET /api/v3/supplier/orders` | List orders (pending/accepted/rejected/packed/shipped/delivered/cancelled) |
| `POST /api/v3/supplier/orders/:id/accept` | Accept |
| `POST /api/v3/supplier/orders/:id/reject` | Reject |
| `POST /api/v3/supplier/orders/:id/pack` | Mark packed |
| `POST /api/v3/supplier/shipments/:id/track` | Add courier/tracking/shipping_date/estimated_delivery |
| `POST /api/v3/supplier/shipments/:id/ship` | Ship → customer notified |
| `GET /api/v3/supplier/products` | Supplier products + inventory |
| `GET /api/v3/supplier/revenue` | Revenue stats |
| `GET /api/v3/store/orders/:number/tracking` | Customer tracking |

### 17.8 Database Changes
| Table | Change |
|---|---|
| `spree_suppliers` | NEW — supplier master data |
| `spree_supplier_bank_details` | NEW — encrypted bank details (1:1) |
| `spree_supplier_addresses` or reuse `spree_addresses` | Supplier address |
| `spree_supplier_users` | Join supplier → user |
| `spree_products.seller_id` | **Already exists** — add FK to `spree_suppliers` |
| `spree_line_items.supplier_id` | NEW — supplier for each line item (denormalized for fast queries) |
| `spree_orders.supplier_id` | NEW — indexed denormalized for supplier order lists |
| `spree_shipments.supplier_id` | NEW — supplier on shipment |
| `spree_shipment_trackings` | NEW — courier, tracking_number, shipping_date, estimated_delivery |
| `spree_supplier_notifications` | NEW — dashboard notifications |
| `spree_supplier_payouts` | NEW — supplier payout records |
| `spree_supplier_ledger` | NEW — revenue/commission/payout ledger |

---

## 18. RECOMMENDED GEMS (Phase 3)

| Gem | Purpose | Recommendation |
|---|---|---|
| `pundit` | Authorization | **YES** — supplier policies |
| `noticed` | Multi-channel notifications (email/WhatsApp/in-app) | **YES** — if multi-channel is needed beyond email |
| `phonelib` | Phone validation for supplier phone | **YES** |
| `countries` | Country data for supplier addresses | **Optional** — Spree has its own countries table |
| `money-rails` | Money handling for revenue/payouts | **NO** — Spree already uses `Spree::Money` / `DisplayMoney` |
| `paper_trail` | Audit logs | **NO** — Spree has `Spree::StateChange` + `Spree::LogEntry` |
| `resend` or `aws-sdk-ses` | Production email | **YES** — production email sending |
| `twilio-ruby` | WhatsApp notifications | **YES** for WhatsApp |
| `meilisearch` | Product search | **Optional** — only if needed, Spree has `Spree.search_provider = Spree::SearchProvider::Meilisearch` config |
| `activerecord-import` | Bulk inserts | **Optional** — for heavy ledger operations |

**Do NOT introduce**: `devise` (already present), `cancancan` (Spree has its own Ability/PermissionSets), `state_machines` (Spree has it), `solid_queue` (present), `solid_cache` (present), `image_processing` (present).

---

## 19. PHASE 4 IMPLEMENTATION PLAN (Pre-Approval Draft)

### 19.1 Architecture
```
Customer places order
    ↓
Order completes → `order.completed` event fires
    ↓
SupplierOrderAssignmentJob (async subscriber)
    ↓
Creates supplier assignment + dashboard notification + email
    ↓
Supplier accepts/rejects via Supplier::OrdersController
    ↓
(Packing) → (Tracking entry: courier, tracking_number, shipping_date, estimated_delivery)
    ↓
Shipment::ship → `shipment.shipped` event → Customer tracking email + order status update
    ↓
Delivered (tracking status update)
```

### 19.2 Supplier Model
```ruby
Spree::Supplier
- name, business_name, gst, phone, email, status (active/suspended/pending)
- has_one :address (Spree::Address)
- has_one :bank_detail
- has_many :products (via seller_id)
- has_many :users (supplier users, via Spree::Role)
- has_many :orders
- has_many :shipments
- has_many :stock_locations
- has_many :trackings
```

### 19.3 Reuse Matrix
| Need | Reuse |
|---|---|
| Supplier product ownership | `spree_products.seller_id` (existing) |
| Supplier order assignment | New `Spree::Supplier::OrderAssignmentService` + `Spree::SupplierOrder` join |
| Accept/reject | `Spree::OrderApproval` (existing table) |
| Order state | Spree::Order state machine (complete/cancel) — untouched |
| Shipment state | Spree::Shipment state machine (ready/ship/resume/cancel) — untouched |
| Tracking | New `Spree::ShipmentTracking` model + `Spree::Shipment#tracking`, `tracking_url` |
| Customer emails | Spree::OrderMailer, Spree::ShipmentMailer (existing, auto-wired) |
| Supplier emails | New `Spree::SupplierMailer` |
| Notifications | `Spree::Events` + new subscribers |
| Background jobs | Solid Queue + `Spree::Events::SubscriberJob` |
| Admin | Spree Admin + `Spree::Admin::ResourceController` |
| API | Spree API v3 patterns |

### 19.4 Anti-N+1 Strategy
- `Spree::Supplier.includes(:products, :orders, :shipments)` on dashboard
- `Order.includes(:line_items, :shipments, :user, :supplier)` on order lists
- Use `preload` / `eager_load` consistently
- Denormalize `supplier_id` on `spree_orders`, `spree_line_items`, `spree_shipments` for fast scoped queries
- Add composite indexes: `(supplier_id, created_at)`, `(supplier_id, state)`, `(shipment_id, tracking_number)`

---

## 20. RISKS & MITIGATIONS

| Risk | Mitigation |
|---|---|
| Overriding Spree state machine | Never use `state_machine` on Order/Shipment — use services that call existing `ship!`, `cancel!` etc. |
| Callback spaghetti | Use `Spree::Events` + subscribers, avoid adding new AR callbacks to Spree models |
| N+1 queries | Denormalized supplier_id + includes + composite indexes |
| Background job failure | Use Solid Queue retry + `Spree::Events::SubscriberJob` retry_on StandardError |
| Tracking data loss | Unique index on `shipment_id + tracking_number` |
| Supplier revenue accuracy | Service object with `Spree::Product#revenue` + async recalculation |
| Security | SupplierAbility (PermissionSets) + Pundit policies + API key auth for supplier API |
| Migration safety | Add nullable columns first, backfill, then add NOT NULL constraint |

---

**Report prepared by:** Automated codebase audit  
**Status:** READY FOR APPROVAL — Phase 4 implementation will commence after audit approval