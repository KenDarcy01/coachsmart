# CoachSmart — Field Notes (alt site)

Self-contained marketing site. Drop this folder into your repo as-is.

## Folder shape
```
website-alt/
  index.html         (no dependencies on other folders)
  images/            (logo + 4 app-store renders)
  firebase.json      (sample — see below)
```

## Deploying to Firebase Hosting (multi-site setup)

If your project already serves `website/` to your main site and you want this folder served to a SECOND Firebase Hosting site:

1. In the Firebase Console, create the second site (Hosting → Add another site).
2. In your project root, tell the CLI about it:
   ```
   firebase target:apply hosting alt YOUR-NEW-SITE-ID
   ```
   (Replace `alt` with whatever target name you like.)
3. Edit your top-level `firebase.json` so it has BOTH targets:
   ```json
   {
     "hosting": [
       { "target": "main", "public": "website",      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"] },
       { "target": "alt",  "public": "website-alt",  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"] }
     ]
   }
   ```
4. `firebase deploy --only hosting:alt`

## Deploying via a GitHub Action

If you want this folder to deploy automatically on push:

```yaml
# .github/workflows/deploy-alt.yml
name: Deploy website-alt to Firebase Hosting
on:
  push:
    branches: [main]
    paths: ['website-alt/**']
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_COACHSMART }}
          channelId: live
          target: alt
          projectId: YOUR-PROJECT-ID
```

Run `firebase init hosting:github` from your repo root and it'll generate the action + secret for you automatically.
