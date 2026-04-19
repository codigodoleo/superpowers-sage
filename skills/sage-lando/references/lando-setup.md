Deep reference for Lando setup for Sage/Bedrock projects. Loaded on demand from `skills/sage-lando/SKILL.md`.

# Lando Setup

Complete configuration reference for Lando in a Roots Bedrock + Sage project — `.lando.yml`, services, tooling, proxy, database, and environment setup.

## `.lando.yml` — Complete Reference

This is the recommended `.lando.yml` for a Roots Bedrock + Sage project. It uses nginx, PHP 8.3, Redis, and Mailpit.

```yaml
name: {project}
recipe: wordpress
config:
  webroot: ./
  via: nginx
  php: "8.3"
  xdebug: true
  config:
    php: server/php/php.ini
    vhosts: server/www/vhosts.conf
  env_file:
    - .env

services:
  appserver:
    build_as_root:
      - apt-get update -y
      - apt-get install -y curl gnupg
      - curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
      - apt-get install -y nodejs
      - npm install -g yarn@1.22
    build:
      - composer install --no-interaction --optimize-autoloader
    run:
      - ./server/cmd/install-wp.sh
    xdebug: true
    overrides:
      extra_hosts:
        - "host.docker.internal:host-gateway"

  cache:
    type: redis:6

  # Lando has a built-in `mailhog` type. Even though MailHog is unmaintained,
  # Lando's implementation can be pointed at Mailpit for a modern UI.
  # The `api: 4` flag tells Lando to use the newer container format.
  mail:
    api: 4
    type: mailhog
    portforward: true
    hogfrom:
      - appserver

proxy:
  mail:
    - mail-{project}.lndo.site

tooling:
  # Run yarn in the appserver container
  yarn:
    service: appserver

  # Run composer scoped to the theme directory (theme has its own composer.json)
  theme-composer:
    service: appserver
    cmd: composer --working-dir=/app/content/themes/{theme}

  # Run yarn scoped to the theme directory (theme has its own package.json)
  theme-yarn:
    service: appserver
    cmd: yarn --cwd /app/content/themes/{theme}

  # Start the Vite dev server for the theme (HMR + hot reload)
  vite:
    service: appserver
    cmd: yarn --cwd /app/content/themes/{theme} dev

  # Build production assets for the theme
  vite-build:
    service: appserver
    cmd: yarn --cwd /app/content/themes/{theme} build

  # Run wp acorn commands — must specify --path because WP core lives in wp/
  acorn:
    service: appserver
    cmd: wp --path=/app/wp acorn

  # Run Laravel Pint (code style fixer) with the theme's pint.json config
  pint:
    service: appserver
    cmd: ./content/themes/{theme}/vendor/bin/pint --config=content/themes/{theme}/pint.json
```

### Extra PHP Extensions

The `wordpress` recipe includes most common extensions. If you need additional ones, add them under `config`:

```yaml
config:
  php: "8.3"
  # These are loaded by the recipe when specified
  # bcmath, exif, gd, mysqli, zip are typically included by default.
  # For imagick and redis, use build_as_root:
```

For `imagick` and `redis`, install them in `build_as_root`:

```yaml
build_as_root:
  - apt-get update -y
  - apt-get install -y curl gnupg php-imagick php-redis
  - docker-php-ext-enable imagick redis
```

---

## Environment Variables (`.env`)

Bedrock uses a `.env` file instead of `wp-config.php` for configuration. This file must exist at the project root.

```env
DB_NAME=wordpress
DB_USER=wordpress
DB_PASSWORD=wordpress
DB_HOST=database
DB_PREFIX=wp_

WP_ENV=development
WP_HOME=https://{project}.lndo.site
WP_SITEURL=${WP_HOME}/wp

# Generate these with: wp dotenv salts generate
# Or visit: https://roots.io/salts.html
AUTH_KEY='generateme'
SECURE_AUTH_KEY='generateme'
LOGGED_IN_KEY='generateme'
NONCE_KEY='generateme'
AUTH_SALT='generateme'
SECURE_AUTH_SALT='generateme'
LOGGED_IN_SALT='generateme'
NONCE_SALT='generateme'

# ACF Pro license (if using Advanced Custom Fields Pro)
ACF_PRO_KEY=your-key-here
```

### Key details

- **`WP_HOME`** is the public URL of the site. Use `https://` because Lando provides SSL automatically.
- **`WP_SITEURL`** points to `${WP_HOME}/wp` because Bedrock installs WordPress core into a `wp/` subdirectory rather than the project root. This is what keeps core files separate from your application code.
- **`DB_HOST=database`** is the default hostname Lando assigns to the MySQL/MariaDB service in the `wordpress` recipe.
- Salts should be unique per project. Run `wp dotenv salts generate` inside the Lando container, or use the Roots salt generator.

---

## Tooling Explained

Lando's `tooling` section creates shorthand commands (`lando <command>`) that run inside the container. Each one exists for a specific reason:

### `theme-composer` / `theme-yarn`

A Sage theme has its own `composer.json` and `package.json`, completely separate from the root project. The root `composer.json` manages WordPress plugins and core (via Bedrock). The theme's `composer.json` manages PHP dependencies like Acorn, Blade components, and Laravel packages.

- `lando composer require some/package` installs at the project root (WordPress-level).
- `lando theme-composer require some/package` installs inside the theme (theme-level).

Same applies to `yarn` vs `theme-yarn` for JavaScript dependencies.

### `acorn`

Acorn is Sage's Laravel-based framework. Its CLI is accessed through `wp acorn`. Because WordPress core lives in `wp/` (not the webroot), you must pass `--path=/app/wp` so WP-CLI can locate it. The `acorn` tooling command wraps this so you can run `lando acorn <command>` without remembering the path flag.

Common uses: `lando acorn view:cache`, `lando acorn optimize`, `lando acorn vendor:publish`.

### `vite` / `vite-build`

These are convenience wrappers that change into the theme directory before running the Vite dev server or production build. Without them, you would need to `cd` into the theme and run `yarn dev` manually inside the container.

### `pint`

Laravel Pint is the code style fixer used by Sage. The tooling command points at the theme's `vendor/bin/pint` binary and its `pint.json` configuration file.

---

## Server Configuration Files

### `server/php/php.ini`

Place this file at `server/php/php.ini`. It is referenced by the `config.php` key in `.lando.yml`.

```ini
upload_max_filesize = 256M
post_max_size = 256M
memory_limit = 512M
max_execution_time = 300
display_errors = On

[xdebug]
xdebug.mode = debug,develop
xdebug.start_with_request = yes
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
```

### `server/www/vhosts.conf`

Place this file at `server/www/vhosts.conf`. It is referenced by the `config.vhosts` key in `.lando.yml`. This nginx configuration handles the Bedrock directory structure where WordPress core lives in `wp/`.

```nginx
server {
    listen 80 default_server;
    listen 443 ssl;

    server_name localhost;

    ssl_certificate /certs/cert.crt;
    ssl_certificate_key /certs/cert.key;

    root /app;
    index index.php index.html;

    # Serve static files from the project root first
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Handle requests to the wp/ subdirectory
    location /wp/ {
        try_files $uri $uri/ /wp/index.php?$args;
    }

    # WordPress admin rewrites
    location /wp/wp-admin/ {
        try_files $uri $uri/ /wp/wp-admin/index.php?$args;
    }

    # PHP handling
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass fpm:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout 300;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }

    location ~ ^/(composer\.|package\.json|yarn\.lock|\.env) {
        deny all;
    }
}
```

---

## WordPress Auto-Install Script

### `server/cmd/install-wp.sh`

This script runs on every `lando start` (via the `run` key). It is idempotent: if WordPress is already installed, it skips the installation steps.

```bash
#!/usr/bin/env bash
set -euo pipefail

WP="wp --path=/app/wp --allow-root"

# Wait for database to be ready
echo "Waiting for database..."
while ! $WP db check > /dev/null 2>&1; do
    sleep 1
done
echo "Database is ready."

# Check if WordPress is already installed
if $WP core is-installed 2>/dev/null; then
    echo "WordPress is already installed. Skipping installation."
else
    echo "Installing WordPress..."

    $WP core install \
        --url="${WP_HOME:-https://{project}.lndo.site}" \
        --title="{project}" \
        --admin_user=admin \
        --admin_password=admin \
        --admin_email=admin@example.com \
        --skip-email

    echo "WordPress installed successfully."
fi

# Activate the theme (safe to run multiple times)
echo "Activating theme..."
$WP theme activate {theme} 2>/dev/null || true

# Activate plugins (safe to run multiple times)
echo "Activating plugins..."
$WP plugin activate --all 2>/dev/null || true

# Set permalink structure
$WP rewrite structure '/%postname%/' --hard 2>/dev/null || true

# Flush rewrite rules
$WP rewrite flush --hard 2>/dev/null || true

echo "Setup complete."
```

Make the script executable:

```bash
chmod +x server/cmd/install-wp.sh
```

---

## Proxy and HTTPS

### Automatic SSL

Lando automatically provides HTTPS for all `.lndo.site` domains. There is no manual certificate setup required. When you run `lando start`, the proxy assigns your project a URL like `https://{project}.lndo.site`.

### Proxy configuration

The `proxy` key in `.lando.yml` maps Lando services to subdomains:

```yaml
proxy:
  mail:
    - mail-{project}.lndo.site
```

This exposes the Mailpit web UI at `https://mail-{project}.lndo.site`. The main appserver is automatically proxied to `https://{project}.lndo.site` by the `wordpress` recipe.

### Impact on Vite HMR

The Vite dev server runs inside the container but the browser connects from the host machine. Because Lando uses its own SSL certificates and proxied domains, Vite's HMR (Hot Module Replacement) websocket connection needs to be configured to match. See `frontend-stack.md` for the required `vite.config.js` settings including `server.host`, `server.origin`, and certificate handling.

### WP_HOME must use HTTPS

Always set `WP_HOME=https://{project}.lndo.site` (not `http://`). Since Lando's proxy serves over HTTPS, using `http://` will cause redirect loops or mixed-content warnings.
