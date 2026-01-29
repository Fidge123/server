# Shared test utilities
{ pkgs, self }:

{
  # Base test configuration that can be extended
  mkTest = { name, nodes ? {}, testScript, extraConfig ? {} }:
    pkgs.nixosTest ({
      inherit name testScript;
      nodes = nodes;
    } // extraConfig);

  # Common test assertions
  assertions = {
    # Check if a systemd service is running
    serviceRunning = service: ''
      server.succeed("systemctl is-active ${service}")
    '';

    # Check if a port is listening
    portListening = port: ''
      server.succeed("ss -tln | grep -q ':${toString port}'")
    '';

    # Check if a file exists
    fileExists = path: ''
      server.succeed("test -f ${path}")
    '';

    # Check if a directory exists
    dirExists = path: ''
      server.succeed("test -d ${path}")
    '';
  };
}
