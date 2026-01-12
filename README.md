# SHEIN Pricing App (Android - Flutter)

## What it does
- Customers database (name + WhatsApp)
- Create orders per customer
- Add multiple product photos per order
- Per product card:
  - Enter **Price SAR**, **SAR→EGP rate**, **Profit EGP (manual)** (profit is always manual + variable)
  - Choose shipping: **Air (20 days)** or **Land (40 days)**
  - Auto-calc **Unit Price (EGP)** = (SAR * Rate) + Profit
  - **Send** button inside each card → shares image + message to WhatsApp (product-by-product)
  - Confirm / Cancel per product
  - On confirm: enter **Size** + **Quantity** → auto line total
- Order summary: totals for confirmed items only
- Export PDF (with images embedded, not links) and share it

## How to run (fast)
This repo contains the `lib/` code + `pubspec.yaml`.  
To generate Android project scaffolding:
1) Install Flutter (stable)
2) In an empty folder, run:
   - `flutter create .`
3) Copy **this repo files** over the created project (replace `lib/` + `pubspec.yaml`), then:
   - `flutter pub get`
   - `flutter run`

## Notes
- WhatsApp sharing uses the Android share sheet so it can include the image.
- PDF export embeds images in the PDF (not links).
