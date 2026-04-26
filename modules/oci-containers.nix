{
  config,
  pkgs,
  ...
}: {
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  users.users.${config.system.adminUser}.extraGroups = ["docker"];
}
