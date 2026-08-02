{
  description = "Pinned development shell for evalcode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/7a1a64774a5fd0b0cd39ac95d0e170ace8b266a0";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs systems (
          system:
          function (import nixpkgs {
            inherit system;
            config.allowUnfree = false;
          })
        );
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          beam = pkgs.beam.packages.erlang_27;
          elixir = beam.elixir_1_20;

          commonPackages = with pkgs; [
            beam.erlang
            beam.rebar3
            elixir
            cacert
            curl
            git
            gnumake
            nodejs_22
            openssl
            pkg-config
            sqlite
            stdenv.cc
            zlib
          ];

          linuxPackages = with pkgs; [ inotify-tools ];
          darwinPackages = with pkgs; [ libiconv ];
        in
        {
          default = pkgs.mkShell {
            packages =
              commonPackages
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxPackages
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin darwinPackages;

            shellHook = ''
              export MIX_HOME="$PWD/.nix-mix"
              export HEX_HOME="$PWD/.nix-hex"
              export MIX_XDG=1
              export ERL_AFLAGS="-kernel shell_history enabled"
              export LANG="en_US.UTF-8"
              export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"

              mkdir -p "$MIX_HOME" "$HEX_HOME"

              elixir_version="$(elixir --version | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
              otp_release="$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' 2>/dev/null)"

              case "$elixir_version" in
                *"Elixir 1.20."*) ;;
                *)
                  echo "Expected Elixir 1.20.x from the pinned flake, got: $elixir_version" >&2
                  return 1
                  ;;
              esac

              if [ "$otp_release" != "27" ]; then
                echo "Expected Erlang/OTP 27 from the pinned flake, got: $otp_release" >&2
                return 1
              fi

              echo "evalcode shell: $elixir_version"
            '';
          };
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
