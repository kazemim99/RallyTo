# Deploying Rallyto

Production runs on `194.1.155.230` (Ubuntu 24.04, 2 vCPU, 3.8 GB RAM, 20 GB disk), a box **shared** with AsanRezerve,
x-ui and other services. Everything here adds to that box without touching them: each nginx vhost claims only its own
`server_name`, containers publish nothing but the API on loopback, and each has a memory limit. Run `nginx -t` before
every reload; a broken config would take the other sites down with it.

| Address | What serves it |
|---|---|
| `https://rallyto.ir` | host nginx, static files in `/var/www/rallyto/landing`; `/m/` proxied to the API |
| `https://admin.rallyto.ir` | host nginx, static files in `/var/www/rallyto/admin` |
| `https://api.rallyto.ir` | host nginx → `127.0.0.1:5100` → container `rallyto-api` |
| `https://app.rallyto.ir` | a temporary redirect to `rallyto.ir` (nothing of its own yet) |

`www.rallyto.ir` has no DNS record and no vhost. Certificates are Let's Encrypt, one per name, renewed by certbot's
timer through `/var/www/certbot`. The stack lives in `/opt/rallyto` (`docker-compose.prod.yml`, `.env`), owned by the
user `rallyto` (docker group, no sudo); nginx and certbot work is done as root.

## Secrets

`/opt/rallyto/.env` (mode 600) is the only place they exist. `POSTGRES_PASSWORD` and `JWT_SECRET_KEY` were generated on
the server. The owner fills `ADMIN_EMAIL`, `ADMIN_PASSWORD` (10+ characters), `MELIPAYAMAK_USERNAME`,
`MELIPAYAMAK_API_KEY`, `MELIPAYAMAK_OTP_BODY_ID` and `FIREBASE_CREDENTIALS_JSON` (the service-account JSON on one line,
in single quotes). The API refuses to start in Production without them (`ProductionConfigurationGuard`).

## Deploying the API

The image is built from the repository and loaded onto the server, so no registry is involved:

```
docker build -f src/Host/Rallyto.Host/Dockerfile -t rallyto-api:latest .
docker save rallyto-api:latest | gzip | ssh root@194.1.155.230 'gunzip | docker load'
ssh root@194.1.155.230 'cd /opt/rallyto && docker compose -f docker-compose.prod.yml up -d'
```

Migrations run when the API starts. Back up first once there is real data:
`docker exec rallyto-postgres-1 pg_dump -U rallyto -Fc rallyto > /opt/rallyto/backup-$(date +%F).dump`.

Check: `curl -s http://127.0.0.1:5100/health/ready` on the server, then `docker stats --no-stream`.

## Deploying the admin panel

```
cd rallyto-admin
VITE_API_BASE_URL=https://api.rallyto.ir npm run build
tar -C dist -czf - . | ssh root@194.1.155.230 'rm -rf /var/www/rallyto/admin/* && tar -C /var/www/rallyto/admin -xzf - && chmod -R a+rX /var/www/rallyto/admin'
```

## Deploying the landing site

The club directory comes from a snapshot, so take it from the live API first (with an empty snapshot the build simply
leaves the directory out):

```
cd rallyto-landing
npm run venues
npm run build
tar -C dist -czf - . | ssh root@194.1.155.230 'rm -rf /var/www/rallyto/landing/* && tar -C /var/www/rallyto/landing -xzf - && chmod -R a+rX /var/www/rallyto/landing'
```

## nginx

The vhosts are in `deploy/nginx/`. To change one:

```
scp deploy/nginx/rallyto-<name>.conf root@194.1.155.230:/etc/nginx/sites-available/
ssh root@194.1.155.230 'nginx -t && systemctl reload nginx'
```

A new name needs its certificate first: enable `deploy/nginx/rallyto-acme.conf` with that name (port 80 only), run
`certbot certonly --webroot -w /var/www/certbot -d <name>`, then install the final vhost and remove the temporary one.
