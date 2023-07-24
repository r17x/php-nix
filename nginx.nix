{ config, pkgs, ... }:

let
  nginxConfig = pkgs.writeText "nginx.conf" ''
    # Nginx configuration goes here
    server {
      listen 80;
      server_name localhost;
      location / {
        root /var/www;
      }
      location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
      }
    }
  '';
in
{
  # The Nginx package definition
  environment.systemPackages = with pks; [ 
    nginx 
  ];

  # The Nginx service definition
  services.nginx = {
    enable = true;
    config = nginxConfig;
  };
}