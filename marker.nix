# use to define marker options like location pins, etc
# a marker is a coplex type with multiple fields and we will set multiple marker
# with marker you can freely assign values to options defined in other modules

{ pkgs, lib, config, ... }:
let
    # Returns the uppercased first letter
    # or number of a string
    firstUpperAlnum = str:
        lib.mapNullable lib.head
        (builtins.match "[^A-Z0-9]*([A-Z0-9]).*"
        (lib.toUpper str));

    # allows either a color name or `0xRRGGBB`
    colorType = lib.types.either
        (lib.types.strMatching "0x[0-9A-F]{6}")
        (lib.types.enum [
            "black" "brown" "green" "purple" "yellow"
            "blue" "gray" "orange" "red" "white" ]);

    markerType = lib.types.submodule {
        options = {
            location = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
            };

            # Use to tell the markers apart with label in uppercase or numbers
            style.label = lib.mkOption {
                type = lib.types.nullOr
                    (lib.types.strMatching "[A-Z0-9]"); # regex matching
                default = null;
            };

            style.color = lib.mkOption {
                type = colorType;
                default = "red";
            };

            # allow user to choose from a set of pre-defined sizes
            style.size = lib.mkOption {
                type = lib.types.enum
                    [ "tiny" "small" "medium" "large" ];
                default = "medium";
            };
        };
    };

    # allow multiple named users to define a list of markers each by additing users options
    # here the subtype will be another submodule which allows declaring a depature marker,
    # suitable for querying the API for the recommended route for a trip
    # define a submodule type for a user with a departure option of type markerType

    userType = lib.types.submodule ({ name, ... }: {
        options = {
            departure = lib.mkOption {
                type = markerType;
                default = {};
            };
        };
        
    # this config allows easy access to name from the marker submodules label option to set a default
        config = {
            departure.style.label = lib.mkDefault
                (firstUpperAlnum name);
        };
    });

in {
    
    options = {
    # allows additing a users attr set to config in any submodule that imports marker.nix where each attrs will be of userType
        users = lib.mkOption {
            type = libe.types.attrsOf userType;
        };

        map.markers = lib.mkOption {
            type = lib.types.listOf markerType;
        };
    };

    # produce and add new elements to the requestParams list (in default.nix)
    config = {
        
    # Takes all depature markers from all users in config arg and adds them to map.markers if their location attrs is not null

        map.markers = lib.filter
            (marker: marker.location != null)
            (lib.concatMap (user: [
                user.departure
            ]) (lib.attrValues config.users))

        # allowing the api to handle centre and zoom level
        map.center = lib.mkIf
            (lib.length config.map.markers >= 1)
            null;

        map.zoom = lib.mkIf
            (lib.length config.map.markers >= 2)
            null;

        # to avoid confusion with map option setting and final config.map config value, we use map func as builtins.map
        #create a unique marker for each users by concating label and location and assign them to requestParams
 
        requestParams = let
            paramForMarker = marker:
                let
                    # Add a mapping for size param to help select appropriate string to pass to the API
                    size = {
                        tiny = "tiny";
                        small = "small";
                        medium = "medium";
                        large = "large";
                    }.${marker.style.size};
 
                    attributes =
                        lib.optional (marker.style.label != null)
                        "label:${marker.style.label}"

                        # make use of selected size
                        ++ lib.optional
                            (size != null)
                            "size=:${size}"

                        ++ [
                            "color:${marker.style.color}" # makes use of the new colorType option
                            "$(${config.scripts.geocode}/bin/geocode ${
                                lib.escapeShellArg marker.location
                            })"
                        ];
                in "markers=\"${lib.concatStringsSep "|" attributes}\"";
            in
                builtins.map paramForMarker config.map.markers;
}
