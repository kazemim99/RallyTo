# Deploying Rallyto

Production runs on `45.144.17.225` (Ubuntu 24.04, 6 vCPU, 7.8 GB RAM, 59 GB disk), a box **shared** with AsanRezerve,
NahalVPN, x-ui and other services. Everything here adds to that box without touching them: each nginx vhost claims only its own
`server_name`, containers publish nothing but the API on loopback, and each has a memory limit. Run `nginx -t` before
every reload; a broken config would take the other sites down with it.

| Address | What serves it |
|---|---|
| `https://rallyto.ir` | host nginx, static files in `/var/www/rallyto/landing`; `/m/` proxied to the API; `/download/rallyto.apk` from `/var/www/rallyto/downloads` |
| `https://admin.rallyto.ir` | host nginx, static files in `/var/www/rallyto/admin` |
| `https://api.rallyto.ir` | host nginx → `127.0.0.1:5100` → container `rallyto-api` |
| `https://app.rallyto.ir` | host nginx, the player app's web build in `/var/www/rallyto/app` (the way to use Rallyto on iPhone) |
| `https://www.rallyto.ir` | host nginx, redirects to `https://rallyto.ir` |

Certificates are Let's Encrypt, one per name, renewed by certbot's timer through `/var/www/certbot`. The stack lives in
`/opt/rallyto` (`docker-compose.prod.yml`, `.env`, root only).

## Secrets

`/opt/rallyto/.env` (mode 600) is the only place they exist. `POSTGRES_PASSWORD` and `JWT_SECRET_KEY` were generated on
the server. The owner fills `ADMIN_EMAIL`, `ADMIN_PASSWORD` (10+ characters), `MELIPAYAMAK_USERNAME`,
`MELIPAYAMAK_API_KEY`, `MELIPAYAMAK_OTP_BODY_ID` and `FIREBASE_CREDENTIALS_JSON` (the service-account JSON on one line,
in single quotes). The API refuses to start in Production without them (`ProductionConfigurationGuard`).

## Deploying the API

The image is built from the repository and loaded onto the server, so no registry is involved:

```
docker build -f src/Host/Rallyto.Host/Dockerfile -t rallyto-api:latest .
docker save rallyto-api:latest | gzip | ssh root@45.144.17.225 'gunzip | docker load'
ssh root@45.144.17.225 'cd /opt/rallyto && docker compose -f docker-compose.prod.yml up -d'
```

Migrations run when the API starts. Back up first once there is real data:
`docker exec rallyto-postgres-1 pg_dump -U rallyto -Fc rallyto > /opt/rallyto/backup-$(date +%F).dump`.

Check: `curl -s http://127.0.0.1:5100/health/ready` on the server, then `docker stats --no-stream`.

## Deploying the admin panel

```
cd rallyto-admin
VITE_API_BASE_URL=https://api.rallyto.ir npm run build
tar -C dist -czf - . | ssh root@45.144.17.225 'rm -rf /var/www/rallyto/admin/* && tar -C /var/www/rallyto/admin -xzf - && chmod -R a+rX /var/www/rallyto/admin'
```

This clears the folder before it copies, so a dropped connection leaves the panel empty: rerun it until it finishes.

## Deploying the landing site

The club directory comes from a snapshot, so take it from the live API first (with an empty snapshot the build simply
leaves the directory out). `npm run venues` refuses an API too old to send a club's contact details, so deploy the
current API image first; while the API is down, `VENUES_FROM=<file>` takes a saved answer of the same shape:

```
cd rallyto-landing
npm run venues
npm run build
cd ..
deploy/publish-landing.sh
```

The script copies the build aside, checks its hash and file count, and only then swaps it in, so a dropped connection
leaves the live site as it was. The site it replaces stays as `/var/www/rallyto/landing.replaced-<time>`; `landing.prev`
is an older backup. Nothing is deleted, so clear old copies by hand when the disk needs it. Behind a VPN that does not
reach the server, set `SSH_BIND` to this machine's address on the direct network.

## Deploying the player app (APK and web)

Build both as `rallyto-app/README.md` › Release builds says (the APK is signed with the upload key; keep that key safe),
then:

```
deploy/publish-app.sh all     # or: web | apk
```

The web build is swapped in like the landing site (the one it replaces stays as `app.replaced-<time>`); the APK
replaces `/var/www/rallyto/downloads/rallyto.apk`, and the previous one stays beside it as `rallyto-<time>.apk`. The
APK sits outside the landing folder so publishing the site never removes it. The API must list `https://app.rallyto.ir`
in `Cors__AllowedOrigins` (it is in `docker-compose.prod.yml`), or the web app cannot call it.

## nginx

The vhosts are in `deploy/nginx/`. To change one:

```
scp deploy/nginx/rallyto-<name>.conf root@45.144.17.225:/etc/nginx/sites-available/
ssh root@45.144.17.225 'nginx -t && systemctl reload nginx'
```

A new name needs its certificate first: enable `deploy/nginx/rallyto-acme.conf` with that name (port 80 only), run
`certbot certonly --webroot -w /var/www/certbot --account a711897da3d25f998e9fa5436562bf72 --deploy-hook 'systemctl reload nginx' -d <name>`
(the server has two Let's Encrypt accounts, so certbot asks without `--account`), then install the final vhost and remove the temporary one.
