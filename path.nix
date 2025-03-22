# Compute and display a route from the user's location to some destination
# Allow to set arrival marker, which will work with the departure marker to
# draw paths on the map
# The path.nix module declares an option for defining a list of paths on our
# map, where each path is a list of strings for geographic locations.

{ lib, config, ... }:
let
  pathType = lib.types.submodule {
    options = {
      locations = lib.mkOption {
        type = lib.types.listOf lib.types.str;
      };
    };
  };

in
{
  options = {
    map.paths = lib.mkOption {
      type = lib.types.listOf pathType;
    };
  };

  # augment the API call by setting the requestParams option value with the
  # coordinates transformed appropriately, which will be concatenated with
  # request parameters set elsewhere

  config = {
    requestParams =
      let
        attrForLocation = loc:
          "$(${config.scripts.geocode}/bin/geocode ${lib.escapeShellArg loc})";
        
        paramForPath = path:
          let
            attributes =
              builtins.map attrForLocation path.locations;
          in
          ''path="${lib.concatStringsSep "|" attributes}"'';
      in
        builtins.map paramForPath config.map.paths;
  };
}
