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

# nix-repl> pkgs = import ../../.. {}
# nix-repl> p = import ./test-evaluation.nix
# nix-repl> builtins.typeOf p
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

  isBroken = (n: v: (pkgs.lib.attrByPath ["meta" "broken"] false v));
  findBroken = s : pkgs.lib.filterAttrs isBroken s;
  findNotBroken = s : pkgs.lib.filterAttrs (n: v: ! (isBroken n v) ) s;
  
  # broken and notbroken denotes the value of the meta.broken attribute
  notbroken_pkgs = findNotBroken pkgs.rPackages;
  notbroken_names = builtins.attrNames notbroken_pkgs;

  broken_pkgs = findBroken pkgs.rPackages;
  broken_names = builtins.attrNames broken_pkgs;
  
  fakeDerive = x1: x2: x2;
  fakeSelf = {};
  importPkgNames = s: import s { self = fakeSelf; derive = fakeDerive; };

  bioc_all = pkgs.lib.attrNames (importPkgNames ./bioc-packages.nix);
  bioc_notbroken = pkgs.lib.subtractLists broken_names bioc_all;

  bioc_annotation_all = pkgs.lib.attrNames (importPkgNames ./bioc-annotation-packages.nix);
  bioc_annotation_notbroken = pkgs.lib.subtractLists broken_names bioc_annotation_all;

  bioc_experiment_all = pkgs.lib.attrNames (importPkgNames ./bioc-experiment-packages.nix);
  bioc_experiment_notbroken = pkgs.lib.subtractLists broken_names bioc_experiment_all;

  bioc_workflows_all = pkgs.lib.attrNames (importPkgNames ./bioc-workflows-packages.nix);
  bioc_workflows_notbroken = pkgs.lib.subtractLists broken_names bioc_workflows_all;

  cran_all = pkgs.lib.attrNames (importPkgNames ./cran-packages.nix);
  cran_notbroken = pkgs.lib.subtractLists broken_names cran_all;


  # not broken ones..
  bioc_pkgs            = pkgs.lib.getAttrs bioc_notbroken notbroken_pkgs;
  bioc_annotation_pkgs = pkgs.lib.getAttrs bioc_annotation_notbroken notbroken_pkgs;
  bioc_experiment_pkgs = pkgs.lib.getAttrs bioc_experiment_notbroken notbroken_pkgs;
  bioc_workflows_pkgs  = pkgs.lib.getAttrs bioc_workflows_notbroken notbroken_pkgs;
  cran_pkgs            = pkgs.lib.getAttrs cran_notbroken notbroken_pkgs;

in

{ inherit
  # package sets, none include packages marked broken
  rWrapper # BIG!
  notbroken_pkgs # BIG!
  broken_pkgs
  bioc_pkgs
  bioc_annotation_pkgs
  bioc_experiment_pkgs
  bioc_workflows_pkgs
  cran_pkgs
  
  # names
  notbroken_names
  broken_names
  bioc_all
  bioc_notbroken
  bioc_annotation_all
  bioc_annotation_notbroken
  bioc_experiment_all
  bioc_experiment_notbroken
  bioc_workflows_all
  bioc_workflows_notbroken
  cran_all
  cran_notbroken

  # helper functions
  isBroken
  findBroken
  findNotBroken

  ;}

