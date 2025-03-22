# Compute and display a route from the user's location to some destination
# Allow to set arrival marker, which will work with the departure marker to
# draw paths on the map
# The path.nix module declares an option for defining a list of paths on our
# map, where each path is a list of strings for geographic locations.

{ lib, config, ... }:
let

  # Either a color name, `0xRRGGBB` or `0xRRGGBBAA`
  colorType = lib.types.either
    (lib.types.strMatching "0x[0-9A-F]{6}([0-9A-F]{2})?")
    (lib.types.enum [
        "black" "brown" "green" "purple" "yellow"
        "blue" "gray" "orange" "red" "white"
    ]);
    
  # pathStyleType submodule to allow user customize path with a weight option
  pathStyleType = lib.types.submodule {
      options = {
          weight = lib.mkOption {
              type = lib.types.ints.between 1 20;
              default = 5;
          };

          color = lib.mkOption {
              type = colorType;
              default = "blue";
          };

          # allow paths to be drawn as geodesics, the shortest "as the crow flies" distance btwn two points on Earth.

          geodesic = lib.mkOption {
              type = lib.types.bool;
              default = false;
          };
      };
  };

  pathType = lib.types.submodule {
    options = {
      locations = lib.mkOption {
        type = lib.types.listOf lib.types.str;
      };

      style = lib.mkOption {
          type = pathStyleType;
          default = {};
      };
    };

  };

in
{
  options = {

    # allows users to actually customize path style. makes it possible to have
    # a definition for the users option in the marker.nix module
    # as well as a users definition in path.nix

    users = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
            options.pathstyle = lib.mkOption {
                type = pathStyleType;
                default = {};
            };
        });
    };

    map.paths = lib.mkOption {
      type = lib.types.listOf pathType;
    };
  };

  # augment the API call by setting the requestParams option value with the
  # coordinates transformed appropriately, which will be concatenated with
  # request parameters set elsewhere

  config = {

    # path that connects every user's departure and arrival locations
    map.paths = builtins.map (user: {
        locations = [
            user.departure.location
            user.arrival.location
        ];
        style = user.pathStyle;

    }) (lib.filter (user:
        user.departure.location != null
        && user.arrival.location != null    
    ) (lib.attrValues config.users));

    requestParams =
      let
        attrForLocation = loc:
          "$(${config.scripts.geocode}/bin/geocode ${lib.escapeShellArg loc})";
        
        paramForPath = path:
          let
            attributes =
              [
                "weight:${toString path.style.weight}"
                "color:${path.style.color}"
                "geodesic:${lib.boolToString path.style.geodesic}"
              ]
              ++ builtins.map attrForLocation path.locations;
          in
          ''path="${lib.concatStringsSep "|" attributes}"'';
      in
        builtins.map paramForPath config.map.paths;
  };
}
