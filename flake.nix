{
  description = "Nix flake for PHP development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        overlays = [
          (final: prev: {
            php = prev.php82;
            composer = prev.php82Packages.composer;
          })
        ];

        nginxConfig = pkgs.writeTextFile {
          name = "nginx.conf";
          text = ''
            # Nginx configuration goes here
            worker_processes auto;

            events {
              worker_connections 1024;
            }

            http {
              access_log off;
              server {
                listen 8080;
                server_name localhost;

                location / {
                  root ${./public};
                }

                location ~ \.php$ {
                  fastcgi_pass 127.0.0.1:9999;
                  # fastcgi_pass unix:/run/php-fpm.sock;
                  fastcgi_index index.php;
                  include ${pkgs.nginx}/conf/fastcgi_params;
                }
              }
            }
          '';
        };

        pkgs = import nixpkgs { inherit system overlays; };

        scripts = with pkgs; [
          (writeScriptBin "setup" ''
            composer install
          '')
          (writeScriptBin "start" ''
            stop
            cp ${php}/etc/php-fpm.conf.default $PWD/php-fpm.conf
            cat <<EOF > $PWD/php-fpm.conf
            error_log = /dev/null
            [www]
            access.log = /dev/null
            listen = $FPM_PORT
            pm = dynamic
            pm.max_children = 3
            pm.min_spare_servers = 1
            pm.max_spare_servers = 3
            pm.start_servers = 3
            EOF

            echo "start php-fpm in port $FPM_PORT"
            php-fpm -y ./php-fpm.conf -F -O -g $PWD/php-fpm.pid &

            # TODO php-fpm run in port 9999
            echo "start nginx in port XXXX"
            nginx -c ${nginxConfig} -e "$PWD/nginx.error" -g "pid $PWD/nginx.pid;"
          '')
          (writeScriptBin "stop" ''
            echo "stop php-fpm in port $FPM_PORT"
            echo "stop nginx in port XXXX"
            
            for pidFile in `ls -f ./*.pid`; do
            (
              kill -9 $(cat $pidFile) > /dev/null 2>&1
            )
            done
            
            for port in "9999" "8080"; do
            (
              lsof -i ":$port" | awk 'NR>1 {print $2}' | xargs kill
            )
            done
          '')
        ];
      in {
        # Development environment output
        devShells.default = pkgs.mkShell {
          FPM_PORT = 9999;

          buildInputs = with pkgs; [ php composer nginx ] ++ scripts;
          shellHook = ''
          '';
        };
      });
}