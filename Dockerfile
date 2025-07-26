FROM php:8.2-apache

# Install dependencies and enable performance extensions
RUN apt-get update && apt-get install -y \
    libgettextpo-dev \
    libxml2-dev \
    unzip \
    curl \
 && docker-php-ext-install gettext mysqli dom xml opcache \
 && docker-php-ext-enable opcache

# Enable Apache modules for performance
RUN a2enmod rewrite headers expires deflate

# ✅ Allow .htaccess to override PHP settings
RUN sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# ✅ Disable error display and enable logging + performance optimizations
RUN echo "display_errors=Off" > /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "display_startup_errors=Off" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "log_errors=On" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "error_reporting=E_ALL & ~E_NOTICE & ~E_WARNING" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.gc_maxlifetime=2592000" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.cookie_lifetime=2592000" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.cache_expire=43200" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.save_path=/data/sessions" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.gc_probability=1" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.gc_divisor=1000" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.use_strict_mode=1" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.lazy_write=1" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.cookie_secure=1" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.cookie_httponly=1" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "session.cookie_samesite=Lax" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "opcache.interned_strings_buffer=8" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "opcache.max_accelerated_files=4000" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "opcache.revalidate_freq=2" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "opcache.fast_shutdown=1" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "realpath_cache_size=4096K" >> /usr/local/etc/php/conf.d/99-custom.ini \
  && echo "realpath_cache_ttl=600" >> /usr/local/etc/php/conf.d/99-custom.ini

# ✅ Install supercronic
ADD https://github.com/aptible/supercronic/releases/latest/download/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

# Copy Apache performance configuration
COPY apache-performance.conf /etc/apache2/conf-available/performance.conf
RUN a2enconf performance

# Copy app files
COPY . /var/www/html
RUN chown -R www-data:www-data /var/www/html

# ✅ Create persistent storage directories
RUN mkdir -p /data/sessions /data/uploads && chown -R www-data:www-data /data && chmod -R 755 /data

# ✅ Create a startup script to manage persistent storage and services
RUN echo '#!/bin/bash\n\
# Ensure persistent directories exist and are writable\n\
mkdir -p /data/sessions /data/uploads\n\
chown -R www-data:www-data /data\n\
chmod -R 755 /data\n\
# Create symlink for uploads if it doesn'"'"'t exist\n\
if [ ! -L /var/www/html/uploads ]; then\n\
  rm -rf /var/www/html/uploads\n\
  ln -sf /data/uploads /var/www/html/uploads\n\
fi\n\
# Ensure uploads subdirectories exist\n\
mkdir -p /data/uploads/campaigns /data/uploads/logos /data/uploads/csvs\n\
chown -R www-data:www-data /data/uploads\n\
chmod -R 777 /data/uploads\n\
# Start supercronic in background\n\
supercronic /etc/sendy.cron &\n\
# Start Apache\n\
apache2-foreground' > /start.sh && chmod +x /start.sh

# ✅ Copy cron definition file
COPY sendy.cron /etc/sendy.cron

# ✅ Start both cron and Apache using startup script
CMD ["/start.sh"]
