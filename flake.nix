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
            phpPackages = prev.php82Packages;
            composer = prev.phpPackages.composer;
          })
        ];

        pkgs = import nixpkgs { inherit system overlays; };

        scripts = with pkgs; [
          (writeScriptBin "setup" ''
            composer install
          '')

          (writeScriptBin "start-phpfpm" ''
            # TODO
          '')

          (writeScriptBin "start-nginx" ''
            # set nginx dir for this project
            nginxDir="$PROJECT_DIR_TMP/nginx"

            # make dir when not exist
            [[ ! -d "$nginxDir" ]] && mkdir $nginxDir && mkdir "$nginxDir/logs"

            # copy default nginx config from /nix/store to $nginxDir
            for c in `ls -f ${nginx}/conf/*.default`; do
            (
              ${toString "name=\"$\{c%.default\}\""}
              name="$(basename $name)"
              to="$nginxDir/$name"
              cat $c > "$to"
              # uncomment by line number in nginx.conf
              [[ "$name" == "nginx.conf" ]] && for N in 2 5 9 21 22 23 25; do
              (
                ${gnused}/bin/sed -i "$N s/#//" $to
              )
              done
            )
            done 

            echo "start nginx"
            ${nginx}/bin/nginx -p "$nginxDir" -c "nginx.conf" -e "logs/error.log"
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
            # nginx -c  -e "$PWD/nginx.error" -g "pid $PWD/nginx.pid;"
          '')

          (writeScriptBin "stop-nginx" ''
            for pidFile in `find $PROJECT_DIR_TMP -name "*.pid" -type f`; do
            (
              echo "Stoping $(basename $pidFile)..."
              kill $(cat $pidFile) > /dev/null 2>&1
              echo "Stopped $(basename $pidFile)."
              rm -f $pidFile
            )
            done
          '')
        ];
      in
      {
        # Development environment output
        devShells.default = pkgs.mkShell {
          PHP_FPM_PORT = 9999;
          NGINX_PORT = 8080;
          buildInputs = with pkgs; [ php composer nginx ] ++ scripts;
          shellHook = ''
            export PROJECT_DIR_TMP="$PWD/.tmp";
            [[ ! -d $PROJECT_DIR_TMP]] && mkdir -p $PROJECT_DIR_TMP
          '';
        };
      });
}

