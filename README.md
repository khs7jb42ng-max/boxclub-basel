# BOXCLUB BASEL — Website + Member App (starter)

This package keeps the existing cinematic 3D website and adds an installable mobile-first member app under `/app/`.

## Included
- `index.html`: original 3D cinematic homepage preserved, with a Member App entry point added.
- `app/`: installable PWA interface (iPhone Safari: Share → Add to Home Screen; Android: Install).
- `supabase/schema.sql`: starter database for profiles, roles, memberships, payments, social posts, likes, comments, follows, stories, training, attendance, events, announcements and notifications.

## Important status
The app currently has a **demo preview** when no backend is configured. Demo preview is not real authentication and does not save accounts, posts, payments or member records. The SQL and UI are a foundation, not a claim that payment, push notifications, audio/video calls or live broadcasting are already production-ready.

## Publish on GitHub Pages
1. Upload the contents of this folder to the root of repository `boxclub-basel` (keep `index.html` at the root).
2. GitHub → Settings → Pages → Deploy from branch → `main` / root.
3. App URL: `https://khs7jb42ng-max.github.io/boxclub-basel/app/`.
4. Use HTTPS (GitHub Pages already provides it).

## Activate real accounts and data
1. Create a Supabase project.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Copy `app/config.example.js` to `app/config.js`; fill in the Supabase Project URL and anon/public key.
4. Add `config.js` to the repo. The anon key is public by design; Row Level Security is mandatory. Never add a service-role key to browser code.
5. Sign up with your own email. In Supabase Authentication → Users, copy your user UUID. Run the final SQL comment in the schema to assign `super_admin` to that UUID.
6. Set Auth URL configuration: Site URL `https://khs7jb42ng-max.github.io`; add redirect URLs for the app path.

## Payments / Apple Pay
Apple Pay needs a payment provider account (for example Stripe), business verification, an eligible Swiss account, domain registration/verification and a server-side checkout + webhook. Do not collect card details in this static app. Membership status must only be marked paid after a verified provider webhook. Payment intents and secrets must live in a server/edge function, never in the browser. Apple Pay availability depends on device, browser, merchant eligibility and provider configuration.

## Still required before production
- Finish server-side payment checkout + signed webhook and test Apple Pay / cards.
- Push notifications via APNs/Web Push with permission and a server worker.
- Chat and audio/video calls via a managed real-time service (e.g. LiveKit) with authenticated tokens.
- Live event streaming provider, moderation, reporting and media storage lifecycle.
- Admin CRUD screens for every resource, audit logs, backups, privacy policy, consent and age/guardian controls for minors.
- Security review and tests using separate member/coach/admin/super-admin accounts.

## Design
Black / fight red / championship gold. The current homepage design and its 3D scrolling intro are retained.
