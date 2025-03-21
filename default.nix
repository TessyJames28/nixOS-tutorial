{ pkgs, lib, ... }: { # Declaring options
    options = {
        scripts.output = lib.mkOption {
            type = lib.types.package;
            };
        };
        
        config = {
            scripts.output = pkgs.writeShellApplication {
                name = "map";
                runtimeInputs = with pkgs; [ curl feh ];
                text = ''
                    ${./map.sh} size=640x640 scale=2 | feh -
                '';
            };
        };
    }
