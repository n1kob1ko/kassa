# Liefert die fertige Seite aus: index.html, fonts/ und img/. Gebaut wird vorher mit `node build.mjs`.
FROM caddy:2-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY index.html /srv/index.html
COPY fonts /srv/fonts
COPY img /srv/img
