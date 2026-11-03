# Zenvora — Mobile-only Setup (PC ki zarurat nahi)

## 1) Database (5 min)
1. supabase.com → apna project → **SQL Editor → New query**
2. `supabase/ALL_IN_ONE.sql` ka poora text paste → **RUN**
   (isme tumhara admin email `kajgarvarad@gmail.com` already hai)

## 2) "Function not found" fix (Buy / Checkout)
Ye error isliye aata hai ki Edge Functions Supabase par deploy nahi hue.
Sabse aasan tarika (GitHub se):
1. Supabase → Account → **Access Tokens** → naya token banao
2. GitHub repo → Settings → Secrets and variables → Actions → New secret:
   - `SUPABASE_ACCESS_TOKEN`  (upar wala token)
   - `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`
     (Razorpay Dashboard → Test mode se pehle try karo)
3. GitHub → **Actions → Deploy Supabase Functions → Run workflow**

COD ke liye bhi `razorpay-checkout` function deploy hona zaroori hai.

## 3) Login (Google)
- Supabase → Authentication → Providers → **Google ON**, Web Client ID + Secret daalo
- Supabase → Authentication → Providers → **Email ON**
- Google Cloud Console me Android OAuth client: package `com.zenvora.zenvora` + APK ka SHA-1
- `android/app/google-services.json` same package ka hona chahiye

## 4) Razorpay webhook
Razorpay Dashboard → Webhooks:
`https://bpvfbzkefyqocmqdggtb.supabase.co/functions/v1/razorpay-webhook`
Events: payment.captured, payment.failed. Secret = `RAZORPAY_WEBHOOK_SECRET`.

## 5) Data daalna (categories / products)
App me login karo (admin email se) → Account → Admin Panel → Categories, Products, Banners add karo.
Bina products ke home khali dikhega.

## 6) APK
GitHub → Actions → **Build Zenvora APK** → Run → artifact download.
