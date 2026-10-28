# Venue import tool

This tool finds candidate clubs on Google Places and submits them to Rallyto. They land in the admin review
queue, never directly in the app (design decision D15).

## Where to run it

Google Maps Platform does not serve Iranian accounts or IP addresses. Run the tool from a machine **outside Iran**,
with a Google Cloud project that:

- has a non-Iranian billing account;
- has the **Places API (New)** enabled.

## What it needs

- The Rallyto API base URL.
- An **admin** access token. Sign in to the admin panel and copy the token, or use the OTP API.
- A Google API key restricted to the Places API.

## Run

```bash
# Look first: write what would be imported to a file, upload nothing.
dotnet run --project tools/Rallyto.VenueImport -- \
  --api https://api.rallyto.example --token "<admin token>" --google-key "<key>" \
  --province "فارس" --dry-run fars.json

# Import one province, then review it in the admin panel (Venue candidates).
dotnet run --project tools/Rallyto.VenueImport -- \
  --api https://api.rallyto.example --token "<admin token>" --google-key "<key>" --province "فارس"

# The whole country (31 provinces); slow and quota-hungry.
dotnet run --project tools/Rallyto.VenueImport -- --api ... --token ... --google-key ...
```

## How it searches

For every city, the tool searches each sport keyword followed by the city name, for example «باشگاه تنیس شیراز».
The keywords are in `ImportModel.cs › SportKeywords`:

| Sport | Keywords |
|---|---|
| Tennis | «باشگاه تنیس», «زمین تنیس» |
| Padel | «پدل» |
| Badminton | «سالن بدمینتون» |
| Squash | «اسکواش» |

Each search reads up to 3 result pages of 20 places. `--delay-ms` (default 300) spaces out the requests.

## Running it again is safe

- **Duplicate results:** the tool keeps one result per Google `place_id`.
- **Already in the system:** the API skips places that are already a venue, and places imported before in any
  state. Rejected places therefore do not come back.
