/*
 * SPDX-FileCopyrightText: 2024 Wavelens UG <info@wavelens.io>
 *
 * SPDX-License-Identifier: AGPL-3.0-only
 */

{ lib, pkgs, config, ... }: let
  cfg = config.services.gradient;
in {
  imports = [
    ./gradient-frontend.nix
  ];

  options = {
    services.gradient = {
      enable = lib.mkEnableOption "Enable Gradient";
      configureNginx = lib.mkEnableOption "Configure Nginx";
      package = lib.mkPackageOption pkgs "gradient-server" { };
      domain = lib.mkOption {
        description = "The domain under which Gradient runs.";
        type = lib.types.str;
        example = "gradient.example.com";
      };

      baseDir = lib.mkOption {
        description = "The base directory for Gradient.";
        type = lib.types.str;
        default = "/var/lib/gradient";
      };

      user = lib.mkOption {
        description = "The group under which Gradient runs.";
        type = lib.types.str;
        default = "gradient";
      };

      group = lib.mkOption {
        description = "The user under which Gradient runs.";
        type = lib.types.str;
        default = "gradient";
      };

      ip = lib.mkOption {
        description = "The IP address on which Gradient listens.";
        type = lib.types.str;
        default = "127.0.0.1";
      };

      port = lib.mkOption {
        description = "The port on which Gradient listens.";
        type = lib.types.int;
        default = 3000;
      };

      jwtSecret = lib.mkOption {
        description = "The secret key used to sign JWTs.";
        type = lib.types.str;
      };

      cryptSecret = lib.mkOption {
        description = "The base64-encoded secret key.";
        type = lib.types.str;
      };

      databaseUrl = lib.mkOption {
        description = "The URL of the database to use.";
        type = lib.types.str;
        default = "postgres://postgres:postgres@localhost:5432/gradient";
      };

      binpath_nix = lib.mkOption {
        description = "The path to the Nix binary.";
        type = lib.types.str;
        default = lib.getExe pkgs.nix;
        defaultText = "nix";
      };

      binpath_git = lib.mkOption {
        description = "The path to the Git binary.";
        type = lib.types.str;
        default = lib.getExe pkgs.git;
        defaultText = "git";
      };

      oauthEnable = lib.mkEnableOption "Enable OAuth";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.gradient-server = {
      path = [ pkgs.nix pkgs.git ];
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "postgresql.service"
      ];

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        StateDirectory = "gradient";
        DynamicUser = true;
        User = cfg.user;
        Group = cfg.group;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        Restart = "on-failure";
        RestartSec = 10;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        WorkingDirectory = cfg.baseDir;
      };

      environment = {
        XDG_CACHE_HOME = "${cfg.baseDir}/www/.cache";
        GRADIENT_IP = cfg.ip;
        GRADIENT_PORT = toString cfg.port;
        GRADIENT_DATABASE_URL = cfg.databaseUrl;
        GRADIENT_JWT_SECRET = cfg.jwtSecret;
        GRADIENT_MAX_CONCURRENT_EVALUATIONS = toString 1;
        GRADIENT_MAX_CONCURRENT_BUILDS = toString 1;
        GRADIENT_OAUTH_ENABLE = lib.mkForce (if cfg.oauthEnable then "true" else "false");
        GRADIENT_CRYPT_SECRET = cfg.cryptSecret;
        GRADIENT_BINPATH_NIX = cfg.binpath_nix;
        GRADIENT_BINPATH_GIT = cfg.binpath_git;
      };
    };

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
      "ca-derivations"
    ];

    services.nginx = lib.mkIf cfg.configureNginx {
      enable = true;
      virtualHosts."${cfg.domain}".locations = {
        "/" = lib.mkIf cfg.frontend.enable {
          proxyPass = "http://127.0.0.1:${toString config.services.gradient.frontend.port}";
          proxyWebsockets = true;
        };

        "/api" = {
          proxyPass = "http://127.0.0.1:${toString config.services.gradient.port}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
