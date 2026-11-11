# Audio Typing Assessment: hosted version (Supabase + free static hosting)

Supabase stores the data, the recordings and the assessor logins. A free static host serves the web page.

| Piece | Where | Free plan |
|---|---|---|
| Passages, submissions, settings | Supabase Postgres | 500 MB database |
| Recordings and passage audio | Supabase Storage (private buckets) | 1 GB storage, 50 MB per file |
| Assessor login | Supabase Auth (email + password) | included |
| The web page (`index.html`, `config.js`) | Netlify, Cloudflare Pages or GitHub Pages | free, HTTPS included |

Read-aloud recordings upload as WebM/Opus, about 0.5–1 MB per minute, so 1 GB holds roughly 1,000 or more recordings.

## 1. Create the Supabase project
1. Sign up at https://supabase.com and create a **new project**. Choose the region closest to your candidates.
2. Open **SQL Editor → New query**, paste all of `schema.sql`, and press **Run**.
3. Open **Authentication → Users → Add user → Create new user**. Enter the assessor's email and a password, and tick *Auto confirm*.
4. Back in the SQL Editor, run this with your assessor email:
   ```sql
   insert into public.assessors (email) values ('assessor@yourcompany.com');
   ```
   Repeat steps 3–4 for each additional assessor.
5. Optional: under **Authentication → Sign In / Providers**, turn off *Allow new users to sign up*. Strangers can't become assessors anyway, because only emails in the `assessors` table get access.

## 2. Connect the page
1. Open **Project Settings → API Keys** and copy the **Publishable key** (`sb_publishable_…`) into `config.js` as `supabasePublishableKey`.
2. Copy the **Project URL** (Project Settings → Data API, in the form `https://xxxx.supabase.co`) into `supabaseUrl`.

The publishable key replaces the old `anon` key. Never use the **secret** key (`sb_secret_…`) in the page: the portal refuses to start if it finds one. Requests made with the publishable key still run as Postgres's built-in `anon` role, which is why `schema.sql` refers to `anon`. That's the role name, not the deprecated key.

## 3. Publish the page (pick one)
- **Netlify Drop** (easiest): go to https://app.netlify.com/drop and drag this whole `hosted` folder onto the page. You get an `https://….netlify.app` link.
- **Cloudflare Pages**: Workers & Pages → Create → Pages → *Upload assets* → upload this folder.
- **GitHub Pages**: push the folder to a repository, then Settings → Pages → deploy from branch.

HTTPS is required for the microphone. All three hosts provide it.

## 4. Use it
- Candidates open the link, press **Candidate**, and take the assessment. They need Chrome or Edge.
- Assessors press **Assessor** and log in with the email and password from step 1.3.
- On first login, go to **Audio passages → Add the two sample passages**, or create your own.
- To move data from the local version, use **Settings → Import backup** with `assessment-backup.json`. Passages and submissions are imported, but recordings are not included in that backup.

## Things to know
- **Free projects pause after about 7 days with no activity.** Your data is kept. Open the Supabase dashboard and press *Restore project* (takes about 1 minute). Open the portal now and then if you run rounds infrequently.
- **Answer keys:** for passages with an **uploaded audio file**, the reference text never leaves the server, and scoring happens when the assessor opens the results. For **computer-voice** passages, the browser needs the text to speak it, so a technical candidate could find it in the browser's developer tools. Use uploaded recordings for high-stakes rounds.
- **Speech-to-text** for read-aloud rounds is done by the candidate's browser: Chrome uses Google's speech service and Edge uses Microsoft's.
- If a candidate's internet drops at submit time, they can retry. If that still fails, the portal downloads their answer and recording to their computer so they can send them to you.
