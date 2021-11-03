{ pkgs ? import <nixpkgs> { } }:

let
  muslPkgs = import pkgs.path {
    localSystem.config = "x86_64-unknown-linux-musl";
  };

in
rec {

  appdir2appimage = pkgs.callPackage ./appimage.nix { };

  nix2appdir = pkgs.callPackage ./appdir.nix { inherit muslPkgs; };

  nix2appimage = x: appdir2appimage (nix2appdir x);

  appimage = nix2appimage;

  appdir = nix2appdir;
}
