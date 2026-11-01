# NamelessMC on Cloudflare Containers

This deployment package runs this NamelessMC fork in a PHP 8.3 + Apache container behind a Cloudflare Worker.

It is **not** a pure JavaScript Worker conversion. NamelessMC is a PHP application and needs a PHP runtime plus a MySQL-compatible database.

## Architecture

- Cloudflare Worker: receives HTTP requests and forwards them to one named container.
- Cloudflare Container: PHP 8.3, Apache, Composer dependencies and this repository's NamelessMC source.
- MySQL/MariaDB: external database, configured in the normal NamelessMC installer.
- Cloudflare R2: persistent installation config, uploads and PHP sessions, mounted into the container with TigrisFS/FUSE.

The container's local disk is disposable. Do not store the only copy of uploads, configuration or sessions on its local filesystem. R2 FUSE is object-storage-backed and does not have full local-disk performance or POSIX semantics; this is a practical compatibility layer, not a high-performance database filesystem.

## Prerequisites

- Cloudflare Workers Paid plan with Containers enabled.
- Docker running on the machine or CI runner that performs deployment.
- A Cloudflare R2 bucket dedicated to NamelessMC persistent files.
- An external MySQL/MariaDB database reachable from Cloudflare Containers.
- A Cloudflare API token with permission to deploy Workers/Containers and manage the target account's resources.

D1 is not a drop-in replacement for NamelessMC's MySQL PDO database. Use MySQL or MariaDB.

## 1. Create the R2 bucket

Create a bucket, for example `namelessmc-data`.

Create an R2 API token scoped to that bucket with Object Read and Write permissions. Keep its access key and secret key private.

## 2. Install dependencies

From this directory:

```bash
npm install
```

## 3. Configure Worker secrets

From this directory, use Wrangler to set the following values. Wrangler prompts securely for each secret:

```bash
npx wrangler secret put AWS_ACCESS_KEY_ID --config wrangler.jsonc
npx wrangler secret put AWS_SECRET_ACCESS_KEY --config wrangler.jsonc
npx wrangler secret put R2_ACCOUNT_ID --config wrangler.jsonc
npx wrangler secret put R2_BUCKET_NAME --config wrangler.jsonc
```

The R2 account ID and bucket name are not cryptographic secrets, but are kept as Worker secrets here to keep the setup simple.

## 4. Deploy

Docker must be running because Wrangler builds and pushes the container image during deployment.

```bash
npm run deploy
```

Check the Worker health endpoint at `https://namelessmc-cloudflare.<your-workers-subdomain>.workers.dev/__health`.

## 5. Connect a hostname

After the first successful deployment, add a Worker custom domain or route in the Cloudflare dashboard for the hostname you want to use. Do not point your main Storm SMP domain at this deployment until installation and testing are complete.

## 6. Install NamelessMC

Open the new hostname in a browser and follow the normal NamelessMC installer.

For database configuration, use the host, port, database name, username and password from your external MySQL/MariaDB provider. The database must accept connections from the Cloudflare Container's outbound network. Do not use `localhost` unless the database is running in the same container (it is not).

The installer writes `core/config.php` into the R2-backed config directory. Uploaded files and PHP sessions are also stored in the R2 bucket.

## Important limitations

- This package does not provision a MySQL server. You must supply an external MySQL/MariaDB database.
- Container images are built from the current repository source; the deployment worker is a proxy and does not rewrite NamelessMC's PHP code.
- R2 FUSE is slower than a local filesystem. It is used only for mutable app data, not for the entire PHP source tree.
- PHP sessions are persisted through R2 FUSE. If login/session behavior is slow or unreliable, move PHP sessions to a dedicated Redis-compatible service or implement a database-backed session handler.
- Only one container instance is configured because all instances share one writable R2-backed filesystem. Do not increase `max_instances` without designing multi-instance session and file consistency.
- The normal browser installer is intentionally used. Do not commit database credentials or admin passwords to Git.
- Keep the R2 bucket private and use a bucket-scoped API token.
