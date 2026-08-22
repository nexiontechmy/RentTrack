# RentTrack Backend Setup (Google Apps Script)

This turns a Google Sheet into a tiny REST API for the RentTrack app. No servers, no
database — just a Sheet and a script.

## 1. Create the Sheet

1. Go to [sheets.google.com](https://sheets.google.com) and create a new, blank spreadsheet.
2. Name it something like **"RentTrack Data"**.
3. You don't need to create any tabs or headers yourself — the script creates a
   `Payments` sheet (tab) with headers automatically the first time it runs.

## 2. Add the script

1. In the spreadsheet, go to **Extensions > Apps Script**.
2. Delete anything in the default `Code.gs` editor.
3. Paste in the full contents of [`Code.gs`](./Code.gs) from this folder.
4. Click the **Save** icon (or Ctrl+S).
5. Rename the project (top left, "Untitled project") to **"RentTrack API"** if you like.

## 3. Deploy as a web app

1. Click **Deploy > New deployment**.
2. Click the gear icon next to "Select type" and choose **Web app**.
3. Fill in:
   - **Description**: `RentTrack API v1`
   - **Execute as**: `Me`
   - **Who has access**: `Anyone`
     - This does *not* make your spreadsheet public — it only allows the web app URL
       to be called without a Google login prompt. Only people with the exact,
       hard-to-guess deployment URL can hit the API.
4. Click **Deploy**.
5. The first time, Google will ask you to **authorize** the script — click through
   the "unverified app" warning (it's your own script) and grant it permission to
   access your spreadsheets.
6. Copy the **Web app URL** shown after deployment. It looks like:
   ```
   https://script.google.com/macros/s/AKfycb.../exec
   ```

## 4. Give me the URL

Paste that deployment URL back here — it goes into the app's Settings screen as
`sheetsScriptUrl`. Nothing is hardcoded in the app, so this is the only place it's
configured.

## 5. Re-deploying after script edits

If you ever edit `Code.gs` again (e.g. to pull an update from me), the existing
deployment URL keeps working *only if* you create a **new version** of the same
deployment:

1. **Deploy > Manage deployments**.
2. Click the pencil/edit icon on the existing deployment.
3. Under **Version**, choose **New version**.
4. Click **Deploy**.

(Creating a brand new deployment instead of a new version of the existing one would
give you a different URL, which would break the app until you update the URL in
Settings again.)

## Quick manual test

Once deployed, you can sanity-check it directly in a browser:

```
https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec?action=getPayments
```

You should see:
```json
{"ok":true,"data":[]}
```

That confirms the API is live and the `Payments` sheet was created.
