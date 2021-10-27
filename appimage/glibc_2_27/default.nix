self: super:
let
  nixpkgs-old = builtins.fetchGit {
    # this commit points to glibc 2.27
    url = "https://github.com/nixos/nixpkgs";
    ref = "master";
    rev = "273e58ebd9f8ef04948a89d496c7cb23dab8cbe8";
  };

  old = import nixpkgs-old { inherit (super) system; };

  hack-up-package = path: extra: import path ({
    stdenv = super.stdenv // {
      lib = super.lib;
      isArm = false;
      mkDerivation = attrs: super.stdenv.mkDerivation (attrs // {
        pname = attrs.name;
      });
    };
  } // extra);

  add-pname = pkg: pkg // { pname = pkg.name; };

in {
  # This is another way to potentially make this work.  This brings in
  # parts of the old stdenv that may be overkill however, and
  # sometimes causes stdenv to reference forbidden packages...
  #
  #  glibc = add-pname old.glibc;
  #  glibcInfo = add-pname old.glibcInfo;
  #  glibcLocales = add-pname old.glibcLocales;

  glibc = (hack-up-package "${nixpkgs-old}/pkgs/development/libraries/glibc/default.nix" {
    inherit (super) callPackage;
  }).overrideAttrs (attrs: {
    NIX_CFLAGS_COMPILE = "-Wno-error";
  });
  glibcLocales = (hack-up-package "${nixpkgs-old}/pkgs/development/libraries/glibc/locales.nix" {
    inherit (super) callPackage buildPackages writeText;
  }).overrideAttrs (attrs: {
    configureFlags = (super.lib.withFeatureAs true "headers" "${super.linuxHeaders}/include");
  });
  glibcInfo = hack-up-package "${nixpkgs-old}/pkgs/development/libraries/glibc/info.nix" {
    inherit (super) callPackage texinfo perl;
  };

  # This is needed to things working.  You can find out why chasing
  # this ld thread in Nixpkgs:
  #
  #  https://github.com/NixOS/nixpkgs/pull/85951#issuecomment-619412670
  coreutils = super.coreutils.overrideAttrs (attrs: {
    configureFlags = attrs.configureFlags ++ [ "ac_cv_func_lchmod=no" ];
  });

  # This is not really needed, but it is an attempt to fix the
  # forementioned issue.  Left here for documentation purposes.
  #
  #  coreutils = (hack-up-package "${nixpkgs-old}/pkgs/tools/misc/coreutils/default.nix" {
  #    inherit (super) autoreconfHook texinfo perl libiconv
  #      hostPlatform buildPlatform buildPackages lib xz;
  #    fetchurl = super.stdenv.fetchurlBoot;
  #  }).overrideAttrs (attrs: {
  #    doCheck = false;
  #  });
  #  fetchurl = super.lib.makeOverridable (import "${super.path}/pkgs/build-support/fetchurl") {
  #    inherit (super) lib stdenvNoCC;
  #    inherit (old) curl;
  #  };

  # This is another attempt to get things working, because I am getting the
  # same errors as in here:
  #
  #  https://github.com/NixOS/nixpkgs/pull/85951#issuecomment-619412670
  #
  # It fails to run the Nix code itself, because of subtletiles of the
  # bootstrap process in Nixpkgs that I just can't figure out...
  #
  #  binutils = (hack-up-package "${nixpkgs-old}/pkgs/development/tools/misc/binutils/default.nix" {
  #    inherit (super) buildPackages buildPlatform hostPlatform targetPlatform noSysDirs;
  #    inherit (old) fetchurl zlib;
  #  });
}
