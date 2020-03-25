# Run
# Test expression evaluation
#
# $ nix build -f test-evaluation.nix rWrapper --dry-run
#
# Test building part of the packages set
#
# $ nix build -f test-evaluation.nix bioc_workflows --show-trace --verbose
#
# to test whether the R package set evaluates properly.

# To play with this in nix repl...

# nix-repl> pkgs = import ../../../default.nix {}
# nix-repl> p = import ./test-evaluation.nix
# ...
# nix-repl> builtins.attrNames p.notMarkedBroken # for example
    


let

  config = {
    allowBroken = true;
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };

  inherit (import ../../.. { inherit config; }) pkgs;

  packagesList = pkgs.lib.filter pkgs.lib.isDerivation (pkgs.lib.attrValues pkgs.rPackages);

  # R with everything. Use --dry-run options to test evaluation.
  # Otherwise "we're going to need a bigger box"
  rWrapper = pkgs.rWrapper.override {
    packages = packagesList;  
  };

  # also a large set
  notMarkedBroken = pkgs.lib.filterAttrs (n: v: ! (pkgs.lib.attrByPath ["meta" "broken"] false v)) pkgs.rPackages;

  # a fairly small set, many just need some debugging.
  markedBroken = pkgs.lib.filterAttrs (n: v: (pkgs.lib.attrByPath ["meta" "broken"] false v)) pkgs.rPackages;
  namesBroken = builtins.attrNames markedBroken;
  
  # # imports from same places a default.nix but exposes subsets
  # rpkgs = import ./package-subsets.nix { pkgs = pkgs; R = pkgs.R; overrides = {}; };

  fakeDerive = x1: x2: x2;
  fakeSelf = {};
  importPkgNames = s: import s { self = fakeSelf; derive = fakeDerive; };

  bioc_all = pkgs.lib.attrNames (importPkgNames ./bioc-packages.nix);
  bioc_notbroken = pkgs.lib.subtractLists namesBroken bioc_all;

  bioc_annotation_all = pkgs.lib.attrNames (importPkgNames ./bioc-annotation-packages.nix);
  bioc_annotation_notbroken = pkgs.lib.subtractLists namesBroken bioc_annotation_all;

  bioc_experiment_all = pkgs.lib.attrNames (importPkgNames ./bioc-experiment-packages.nix);
  bioc_experiment_notbroken = pkgs.lib.subtractLists namesBroken bioc_experiment_all;

  bioc_workflows_all = pkgs.lib.attrNames (importPkgNames ./bioc-workflows-packages.nix);
  bioc_workflows_notbroken = pkgs.lib.subtractLists namesBroken bioc_workflows_all;
  
  # not broken ones..
  bioc_pkgs =            pkgs.lib.getAttrs bioc_notbroken notMarkedBroken;
  bioc_annotation_pkgs = pkgs.lib.getAttrs bioc_annotation_notbroken notMarkedBroken;
  bioc_experiment_pkgs = pkgs.lib.getAttrs bioc_experiment_notbroken notMarkedBroken;
  bioc_workflows_pkgs =  pkgs.lib.getAttrs bioc_workflows_notbroken notMarkedBroken;

in

{ inherit
    rWrapper # BIG! 
    notMarkedBroken
    markedBroken
    bioc_workflows_notbroken
    bioc_pkgs
    bioc_annotation_pkgs
    bioc_experiment_pkgs
    bioc_workflows_pkgs
  ;}

