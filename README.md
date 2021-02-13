# TwitchDiscordConnector

The very start of a server to allow people to listen to twitch hooks and send messages to discord channels.
This should generally be available to everyone, though you may need to bring your own AWS credentials.

## Libraries Used

I prefer a lower number of dependencies so I've included as few libraries as possible. Unfortunately s3 required 4(!) libraries to get done, but 90% of the code is interacting with `:poison` / `:httpoison` / `:plug_cowboy`. If you're interested in what a bare plug server looks like and how it does things, this might be interesting to you.

## Setup

You should create a `db.json` file in the runtime directory (or change the path given in `lib/twitch_discord_connector.ex`). This is where the server will read credentials. Other keys will get filled in as the server runs (it uses this json file to cache things like the subscription info) and the file is generally used to avoid needing a 2nd durable storage service. 

### Important Keys

- twitch_users: This key stores the twitch users the server is watching using their user id (as a string) as the key.
- twitch_users[id].hook: url for the webhook associated with this user. Every other value will be filled in but this one is set manually right now.
- twitch_creds: Twitch API credentials. Must have to subscribe to updates. Expected keys in skeleton below.
- digital_ocean_aws: Should probably be named `aws`, contains the `key` and `secret` and `base_url` for accessing a S3-compliant storage service.


Below is a sample skeleton for the values you might want to include:
```
{
  "twitch_users": {
    "35634557": {
      "hook": "https://discord.com/api/webhooks/[...]"
    }
  },
  "twitch_creds": {
    "client_secret": "[client secret]",
    "client_id": "[client id]"
  },
  "digital_ocean_aws": {
    "secret": "[...]",
    "key": "[...]",
    "base_url": "https://img.naturecultur.es"
  }
}
```

You should also consider putting the same things in `test_image_db.json` for testing purposes - it will allow the tests to make requests against twitch.

## Nginx

This server is designed to be run behind nginx. I used [this](https://dennisreimann.de/articles/phoenix-nginx-config.html) helpful guide as a start and then took out things that I didn't seem to have (like `ssl_dhparam`).

This does not include using nginx to deliver static assets, which I should do in theory.

Here, reproduced, is the configuration file at `/etc/nginx/sites-available/twitch`.
```
upstream twitch {
  server localhost:4000;
}

# redirect all http requests to https
# and also listen on IPv6 addresses
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name twitch.naturecultur.es www.twitch.naturecultur.es;

  return 301 https://$server_name$request_uri;
}

# the main server directive for ssl connections
# where we also use http2 (see asset delivery)
server {
  listen 443 ssl http2 default_server;
  listen [::]:443 ssl http2 default_server;
  server_name twitch.naturecultur.es www.twitch.naturecultur.es;

  # paths to certificate and key provided by Let's Encrypt
  ssl_certificate /etc/letsencrypt/live/twitch.naturecultur.es/fullchain.pem; # managed by Certbot
  ssl_certificate_key /etc/letsencrypt/live/twitch.naturecultur.es/privkey.pem; # managed by Certbot

  # SSL settings that currently offer good results in the SSL check
  # and have a reasonable backwards-compatibility, taken from
  # - https://cipherli.st/
  # - https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
  ssl_ecdh_curve secp384r1;
  ssl_session_cache shared:SSL:10m;
  ssl_session_tickets off;
  ssl_stapling on;
  ssl_stapling_verify on;
  #ssl_dhparam /etc/ssl/certs/dhparam.pem;

  # security enhancements
  add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
  add_header X-Frame-Options DENY;
  add_header X-Content-Type-Options nosniff;

  # Let's Encrypt keeps its files here
  location ~ /.well-known {
    root /var/www/html;
    allow all;
  }

  # besides referencing the extracted upstream this stays the same
  location / {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://twitch;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}```

## Future

- Web iterface for configuring webhooks
- Who knows?!


## Installation

Right now you gotta download it!