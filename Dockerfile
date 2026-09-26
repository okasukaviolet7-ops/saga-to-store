FROM alpine:3.21

# ─── Install PHP + Node ───────────────────────────────────────────────────────
RUN apk add --no-cache \
    php84 php84-fpm \
    php84-bcmath \
    php84-ctype \
    php84-curl \
    php84-dom \
    php84-exif \
    php84-fileinfo \
    php84-gd \
    php84-iconv \
    php84-intl \
    php84-mbstring \
    php84-mysqli \
    php84-opcache \
    php84-openssl \
    php84-pcntl \
    php84-pdo \
    php84-pdo_mysql \
    php84-phar \
    php84-posix \
    php84-session \
    php84-simplexml \
    php84-sockets \
    php84-tokenizer \
    php84-xml \
    php84-xmlreader \
    php84-xmlwriter \
    php84-zip \
    nodejs npm \
    bash curl git unzip

RUN ln -sf /usr/bin/php84 /usr/bin/php \
    && ln -sf /usr/sbin/php-fpm84 /usr/sbin/php-fpm

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# ─── PHP dependencies ─────────────────────────────────────────────────────────
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction

# ─── Node dependencies ────────────────────────────────────────────────────────
COPY package.json package-lock.json ./
RUN npm ci

# ─── Application code ─────────────────────────────────────────────────────────
COPY . .

# ─── Build assets (wayfinder needs PHP, Vite needs Node) ─────────────────────
RUN cp .env.example .env \
    && php artisan key:generate \
    && php artisan wayfinder:generate --no-interaction \
    && npm run build \
    && php artisan package:discover --ansi \
    && rm .env

# ─── Permissions ─────────────────────────────────────────────────────────────
RUN chown nobody:nobody /var/www/html \
    && chown -R nobody:nobody /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

# ─── PHP-FPM config ──────────────────────────────────────────────────────────
COPY docker/php/php.ini     /etc/php84/conf.d/laravel.ini
COPY docker/php/opcache.ini /etc/php84/conf.d/opcache.ini
COPY docker/php/fpm.conf    /etc/php84/php-fpm.d/www.conf

# ─── Entrypoint ──────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/php-fpm84", "--nodaemonize", "--fpm-config", "/etc/php84/php-fpm.conf"]
