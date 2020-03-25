    /* This file defines the composition for CRAN (R) packages. */

{ R, pkgs, overrides }:

let
  inherit (pkgs) cacert fetchurl stdenv lib;

  buildRPackage = pkgs.callPackage ./generic-builder.nix {
    inherit R;
    inherit (pkgs.darwin.apple_sdk.frameworks) Cocoa Foundation;
    inherit (pkgs) gettext gfortran;
  };

  # Generates package templates given per-repository settings
  #
  # some packages, e.g. cncaGUI, require X running while installation,
  # so that we use xvfb-run if requireX is true.
  mkDerive = {mkHomepage, mkUrls}: args:
      lib.makeOverridable ({
        name, version, sha256,
        depends ? [],
        doCheck ? true,
        requireX ? false,
        broken ? false,
        hydraPlatforms ? R.meta.hydraPlatforms
      }: buildRPackage {
    name = "${name}-${version}";
    src = fetchurl {
      inherit sha256;
      urls = mkUrls (args // { inherit name version; });
    };
    inherit doCheck requireX;
    propagatedBuildInputs = depends;
    nativeBuildInputs = depends;
    meta.homepage = mkHomepage (args // { inherit name; });
    meta.platforms = R.meta.platforms;
    meta.hydraPlatforms = hydraPlatforms;
    meta.broken = broken;
  });

  # Templates for generating Bioconductor and CRAN packages
  # from the name, version, sha256, and optional per-package arguments above
  #
  deriveBioc = mkDerive {
    mkHomepage = {name, biocVersion, ...}: "https://bioconductor.org/packages/${biocVersion}/bioc/html/${name}.html";
    mkUrls = {name, version, biocVersion}: [ "mirror://bioc/${biocVersion}/bioc/src/contrib/${name}_${version}.tar.gz"
                                             "mirror://bioc/${biocVersion}/bioc/src/contrib/Archive/${name}_${version}.tar.gz" ];
  };
  deriveBiocAnn = mkDerive {
    mkHomepage = {name, biocVersion, ...}: "https://bioconductor.org/packages/${biocVersion}/data/annotation/html/${name}.html";
    mkUrls = {name, version, biocVersion}: [ "mirror://bioc/${biocVersion}/data/annotation/src/contrib/${name}_${version}.tar.gz" ];
  };
  deriveBiocExp = mkDerive {
    mkHomepage = {name, biocVersion, ...}: "http://www.bioconductor.org/packages/${biocVersion}/data/experiment/html/${name}.html";
    mkUrls = {name, version, biocVersion}: [ "mirror://bioc/${biocVersion}/data/experiment/src/contrib/${name}_${version}.tar.gz" ];
  };
  deriveBiocWrk = mkDerive { # not available on mirrors afaik
    mkHomepage = {name, biocVersion, ...}: "https://www.bioconductor.org/packages/${biocVersion}/workflows/html/${name}.html";
    mkUrls = {name, version, biocVersion}: [ "https://www.bioconductor.org/packages/${biocVersion}/workflows/src/contrib/${name}_${version}.tar.gz"];
  };
  deriveCran = mkDerive {
    mkHomepage = {name, snapshot, ...}: "http://mran.revolutionanalytics.com/snapshot/${snapshot}/web/packages/${name}/";
    mkUrls = {name, version, snapshot}: [ "http://mran.revolutionanalytics.com/snapshot/${snapshot}/src/contrib/${name}_${version}.tar.gz" ];
  };

  # Overrides package definitions with nativeBuildInputs.
  # For example,
  #
  # overrideNativeBuildInputs {
  #   foo = [ pkgs.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     nativeBuildInputs = attrs.nativeBuildInputs ++ [ pkgs.bar ];
  #   });
  # }
  overrideNativeBuildInputs = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        nativeBuildInputs = attrs.nativeBuildInputs ++ value;
      })
    ) overrides;

  # Overrides package definitions with buildInputs.
  # For example,
  #
  # overrideBuildInputs {
  #   foo = [ pkgs.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     buildInputs = attrs.buildInputs ++ [ pkgs.bar ];
  #   });
  # }
  overrideBuildInputs = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        buildInputs = attrs.buildInputs ++ value;
      })
    ) overrides;

  # Overrides package definitions with new R dependencies.
  # For example,
  #
  # overrideRDepends {
  #   foo = [ self.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     nativeBuildInputs = attrs.nativeBuildInputs ++ [ self.bar ];
  #     propagatedNativeBuildInputs = attrs.propagatedNativeBuildInputs ++ [ self.bar ];
  #   });
  # }
  overrideRDepends = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        nativeBuildInputs = attrs.nativeBuildInputs ++ value;
        propagatedNativeBuildInputs = attrs.propagatedNativeBuildInputs ++ value;
      })
    ) overrides;

  # Overrides package definition requiring X running to install.
  # For example,
  #
  # overrideRequireX [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     requireX = true;
  #   };
  # }
  overrideRequireX = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          requireX = true;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  # Overrides package definition to skip check.
  # For example,
  #
  # overrideSkipCheck [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     doCheck = false;
  #   };
  # }
  overrideSkipCheck = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          doCheck = false;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  # Overrides package definition to mark it broken.
  # For example,
  #
  # overrideBroken [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     broken = true;
  #   };
  # }
  overrideBroken = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          broken = true;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  defaultOverrides = old: new:
    let old0 = old; in
    let
      old1 = old0 // (overrideRequireX packagesRequiringX old0);
      old2 = old1 // (overrideSkipCheck packagesToSkipCheck old1);
      old3 = old2 // (overrideRDepends packagesWithRDepends old2);
      old4 = old3 // (overrideNativeBuildInputs packagesWithNativeBuildInputs old3);
      old5 = old4 // (overrideBuildInputs packagesWithBuildInputs old4);
      old6 = old5 // (overrideBroken brokenPackages old5);
      old = old6;
    in old // (otherOverrides old new);

  # Recursive override pattern.
  # `_self` is a collection of packages;
  # `self` is `_self` with overridden packages;
  # packages in `_self` may depends on overridden packages.
  self = (defaultOverrides _self self) // overrides;

  #make subsets for testing
  subsets = { inherit buildRPackage; 
              bioc_packages = import ./bioc-packages.nix { inherit self; derive = deriveBioc; };
              bioc_annotation_packages =  import ./bioc-annotation-packages.nix { inherit self; derive = deriveBiocAnn; } ;
              bioc_experiment_packages = import ./bioc-experiment-packages.nix { inherit self; derive = deriveBiocExp; } ;
              bioc_workflows_packages = import ./bioc-workflows-packages.nix   { inherit self; derive = deriveBiocWrk; } ;
              cran_packages = import ./cran-packages.nix            { inherit self; derive = deriveCran; };
            };
  
  _self = { inherit buildRPackage; } //
          import ./bioc-packages.nix            { inherit self; derive = deriveBioc; } //
          import ./bioc-annotation-packages.nix { inherit self; derive = deriveBiocAnn; } //
          import ./bioc-experiment-packages.nix { inherit self; derive = deriveBiocExp; } //
          import ./bioc-workflows-packages.nix   { inherit self; derive = deriveBiocWrk; } //
          import ./cran-packages.nix            { inherit self; derive = deriveCran; };

  # tweaks for the individual packages and "in self" follow

  packagesWithRDepends = {
    #pander = [ self.codetools ];
    # if R deps are missing for some reason, add them here. For example ...
    # vsn = with self; [ lattice ggplot2 ];
    tesseract = [ self.pdftools ];
  };

  packagesWithNativeBuildInputs = {
    BayesSAE = [ pkgs.gsl_1 ];
    BayesVarSel = [ pkgs.gsl_1 ];
    BayesXsrc = [ pkgs.readline.dev pkgs.ncurses ];
    BiocCheck = [ pkgs.which ];
    Biostrings = [ pkgs.zlib ];
    BitSeq = [ pkgs.zlib.dev pkgs.curl.dev ];
    Cairo = [ pkgs.libtiff pkgs.libjpeg pkgs.cairo.dev pkgs.x11 pkgs.fontconfig.lib ];
    Cardinal = [ pkgs.which ];
    ChemmineOB = [ pkgs.openbabel pkgs.pkgconfig ];
    DiffBind = [ pkgs.zlib.dev pkgs.curl.dev ];
    EMCluster = [ pkgs.liblapack ];
    Formula = [ pkgs.gmp ];
    GLAD = [ pkgs.gsl_1 ];
    HDF5Array = [ pkgs.zlib.dev ];
    HiCseg = [ pkgs.gsl_1 ];
    JavaGD = [ pkgs.jdk ];
    KFKSDS = [ pkgs.gsl_1 ];
    ModelMetrics = lib.optional stdenv.isDarwin pkgs.llvmPackages.openmp;
    MotIV = [ pkgs.gsl_1 ];
    MSGFplus = [ pkgs.jdk];
    PKI = [ pkgs.openssl.dev ];
    R2SWF = [ pkgs.zlib pkgs.libpng pkgs.freetype.dev ];
    RAppArmor = [ pkgs.libapparmor ];
    RGtk2 = [ pkgs.gtk2.dev ];
    RMySQL = [ pkgs.zlib pkgs.libmysqlclient pkgs.openssl.dev ];
    RNetCDF = [ pkgs.netcdf pkgs.udunits ];
    RODBC = [ pkgs.libiodbc ];
    RPostgreSQL = [ pkgs.postgresql pkgs.postgresql ];
    RProtoBuf = [ pkgs.protobuf ];
    RSclient = [ pkgs.openssl.dev ];
    RVowpalWabbit = [ pkgs.zlib.dev pkgs.boost ];
    RcppCNPy = [ pkgs.zlib.dev ];
    RcppGSL = [ pkgs.gsl_1 ];
    RcppZiggurat = [ pkgs.gsl_1 ];
    Rglpk = [ pkgs.glpk ];
    Rhdf5lib = [ pkgs.zlib.dev ];
    Rhpc = [ pkgs.zlib pkgs.bzip2.dev pkgs.icu pkgs.lzma.dev pkgs.openmpi pkgs.pcre.dev ];
    Rhtslib = [ pkgs.zlib.dev pkgs.automake pkgs.autoconf pkgs.bzip2.dev pkgs.lzma.dev pkgs.curl.dev ] ;
    Rlibeemd = [ pkgs.gsl_1 ];
    Rmpfr = [ pkgs.gmp pkgs.mpfr.dev ];
    Rmpi = [ pkgs.openmpi ];
    Rsamtools = [ pkgs.zlib.dev pkgs.curl.dev ];
    Rserve = [ pkgs.openssl ];
    Rssa = [ pkgs.fftw.dev ];
    Rsubread = [ pkgs.zlib.dev ];
    SAVE = [ pkgs.zlib pkgs.bzip2 pkgs.icu pkgs.lzma pkgs.pcre ];
    ShortRead = [ pkgs.zlib.dev ];
    TAQMNGR = [ pkgs.zlib.dev ];
    TKF = [ pkgs.gsl_1 ];
    V8 = [ pkgs.v8 ];
    VariantAnnotation = [ pkgs.zlib.dev ];
    XBRL = [ pkgs.zlib pkgs.libxml2.dev ];
    XML = [ pkgs.libtool pkgs.libxml2.dev pkgs.xmlsec pkgs.libxslt ];
    XVector = [ pkgs.zlib.dev ];
    abn = [ pkgs.gsl_1 ];
    adimpro = [ pkgs.imagemagick ];
    affyPLM = [ pkgs.zlib.dev ];
    affyio = [ pkgs.zlib.dev ];
    animation = [ pkgs.which ];
    audio = [ pkgs.portaudio ];
    bamsignals = [ pkgs.zlib.dev pkgs.curl.dev ];
    bigGP = [ pkgs.openmpi ];
    bio3d = [ pkgs.zlib.dev ];
    bnpmr = [ pkgs.gsl_1 ];
    cairoDevice = [ pkgs.gtk2.dev ];
    chebpol = [ pkgs.fftw ];
    cit = [ pkgs.gsl_1 ];
    curl = [ pkgs.curl.dev ];
    data_table = [pkgs.zlib.dev] ++ lib.optional stdenv.isDarwin pkgs.llvmPackages.openmp;
    devEMF = [ pkgs.xorg.libXft.dev pkgs.x11 ];
    diversitree = [ pkgs.gsl_1 pkgs.fftw ];
    fftw = [ pkgs.fftw.dev ];
    fftwtools = [ pkgs.fftw.dev ];
    gdtools = [ pkgs.cairo.dev pkgs.fontconfig.lib pkgs.freetype.dev ];
    git2r = [ pkgs.zlib.dev pkgs.openssl.dev pkgs.libssh2.dev pkgs.libgit2 pkgs.pkgconfig ];
    glpkAPI = [ pkgs.gmp pkgs.glpk ];
    gmapR = [ pkgs.zlib.dev ];
    gmp = [ pkgs.gmp.dev ];
    graphscan = [ pkgs.gsl_1 ];
    gsl = [ pkgs.gsl ];
    hdf5r = [ pkgs.hdf5.dev];
    h5vc = [ pkgs.zlib.dev pkgs.curl.dev ];
    haven = [ pkgs.libiconv pkgs.zlib.dev ];
    iBMQ = [ pkgs.gsl_1 ];
    igraph = [ pkgs.gmp pkgs.libxml2.dev ];
    imager = [ pkgs.x11 ];
    jpeg = [ pkgs.libjpeg.dev ];
    jqr = [ pkgs.jq.dev ];
    lwgeom = [ pkgs.proj.dev pkgs.geos ];
    kza = [ pkgs.fftw.dev ];
    magick = [ pkgs.imagemagick.dev ];
    mvabund = [ pkgs.gsl_1 ];
    mwaved = [ pkgs.fftw.dev ];
    ncdfFlow = [ pkgs.zlib.dev ];
    ncdf4 = [ pkgs.netcdf ];
    nloptr = [ pkgs.nlopt pkgs.pkgconfig ];
    odbc = [ pkgs.unixODBC ];
    oligo = [ pkgs.zlib.dev ];
    outbreaker = [ pkgs.gsl_1 ];
    pander = [ pkgs.pandoc pkgs.which ];
    pbdMPI = [ pkgs.openmpi ];
    pbdNCDF4 = [ pkgs.netcdf ];
    pbdPROF = [ pkgs.openmpi ];
    pbdZMQ = lib.optionals stdenv.isDarwin [ pkgs.which ];
    pdftools = [ pkgs.poppler pkgs.libjpeg.dev];
    phytools = [ pkgs.which ];
    png = [ pkgs.libpng.dev ];
    proj4 = [ pkgs.proj.dev ];
    protolite = [ pkgs.protobuf ];
    qtbase = [ pkgs.qt4.dev  ];
    qtpaint = [ pkgs.qt4 ];
    rJava = [ pkgs.zlib pkgs.bzip2.dev pkgs.icu pkgs.lzma.dev pkgs.pcre.dev pkgs.jdk pkgs.libzip ];
    rPython = [ pkgs.python ];
    rapport = [ pkgs.which ];
    rapportools = [ pkgs.which ];
    rcdd = [ pkgs.gmp.dev ];
    readxl = [ pkgs.libiconv ];
    reprex = [ pkgs.which ];
    rgdal = [ pkgs.proj.dev pkgs.gdal ];
    rgeos = [ pkgs.geos ];
    rggobi = [ pkgs.ggobi pkgs.gtk2.dev pkgs.libxml2.dev ];
    rhdf5 = [ pkgs.zlib ];
    rjags = [ pkgs.jags ];
    rmatio = [ pkgs.zlib.dev ];
    rpanel = [ pkgs.bwidget ];
    rpg = [ pkgs.postgresql ];
    rtiff = [ pkgs.libtiff.dev ];
    rtracklayer = [ pkgs.zlib.dev ];
    runjags = [ pkgs.jags ];
    rzmq = [ pkgs.zeromq3 ];
    sdcTable = [ pkgs.gmp pkgs.glpk ];
    seewave = [ pkgs.fftw.dev pkgs.libsndfile.dev ];
    seqinr = [ pkgs.zlib.dev ];
    seqminer = [ pkgs.zlib.dev pkgs.bzip2 ];
    sf = [ pkgs.gdal pkgs.proj.dev pkgs.geos ];
    showtext = [ pkgs.zlib pkgs.libpng pkgs.icu pkgs.freetype.dev ];
    simplexreg = [ pkgs.gsl_1 ];
    snpStats = [ pkgs.zlib.dev ];
    spate = [ pkgs.fftw.dev ];
    ssanv = [ pkgs.proj.dev ];
    stringi = [ pkgs.icu.dev ];
    stsm = [ pkgs.gsl_1 ];
    survSNP = [ pkgs.gsl_1 ];
    sysfonts = [ pkgs.zlib pkgs.libpng pkgs.freetype.dev ];
    systemfonts = [ pkgs.fontconfig.dev pkgs.freetype.dev ];
    tesseract = [ pkgs.tesseract pkgs.leptonica pkgs.poppler ];
    tiff = [ pkgs.libtiff.dev ];
    tkrplot = [ pkgs.xorg.libX11 pkgs.tk.dev ];
    topicmodels = [ pkgs.gsl_1 ];
    udunits2 = [ pkgs.udunits pkgs.expat ];
    units = [ pkgs.udunits ];
    xml2 = [ pkgs.libxml2.dev ] ++ lib.optionals stdenv.isDarwin [ pkgs.perl ];
  };

  packagesWithBuildInputs = {
    # sort -t '=' -k 2
    AnnotLists = [ pkgs.flock ];
    DESeq2 = [ pkgs.libiconv ];
    Cairo = [ pkgs.pkgconfig ];
    Hmisc = [ pkgs.libiconv ];
    KernSmooth = [ pkgs.libiconv ];
    Matrix = [ pkgs.libiconv ];
    R2SWF = [ pkgs.pkgconfig ];
    RCurl = [ pkgs.curl.dev ];
    RGtk2 = [ pkgs.pkgconfig ];
    RMark = [ pkgs.which ];
    RProtoBuf = [ pkgs.pkgconfig ];
    RPushbullet = [ pkgs.which ];
    RSpectra = [ pkgs.libiconv ];
    RcppArmadillo = [ pkgs.libiconv ];
    RcppEigen = [ pkgs.libiconv ];
    Rpoppler = [ pkgs.pkgconfig pkgs.poppler.dev ];
    Rsymphony = [ pkgs.pkgconfig pkgs.doxygen pkgs.graphviz pkgs.subversion ];
    Rtsne = [ pkgs.libiconv ];
    SparseM = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    VariantAnnotation = [ pkgs.curl.dev ];
    XML = [ pkgs.pkgconfig ];
    acepack = [ pkgs.libiconv ];
    ade4 = [ pkgs.libiconv ];
    adimpro = [ pkgs.which pkgs.xorg.xdpyinfo ];
    affyPLM = [ pkgs.libiconv ];
    ape = [ pkgs.libiconv ];
    biglm = [ pkgs.libiconv ];
    cairoDevice = [ pkgs.pkgconfig ];
    chebpol = [ pkgs.pkgconfig ];
    cluster = [ pkgs.libiconv ];
    edgeR = [ pkgs.libiconv ];
    expm = [ pkgs.libiconv ];
    fftw = [ pkgs.pkgconfig ];
    gam = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    gdtools = [ pkgs.pkgconfig ];
    genefilter = [ pkgs.libiconv ];
    glmnet = [ pkgs.libiconv ];
    gridGraphics = [ pkgs.which ];
    hexbin = [ pkgs.libiconv ];
    igraph = [ pkgs.libiconv ];
    impute = [ pkgs.libiconv ];
    irlba = [ pkgs.libiconv ];
    jqr = [ pkgs.jq.lib ];
    kernlab = [ pkgs.libiconv ];
    kza = [ pkgs.pkgconfig ];
    magick = [ pkgs.pkgconfig ];
    mclust = [ pkgs.libiconv ];
    mgcv = [ pkgs.libiconv ];
    minqa = [ pkgs.libiconv ];
    mnormt = [ pkgs.libiconv ];
    mvtnorm = [ pkgs.libiconv ];
    mwaved = [ pkgs.pkgconfig ];
    mzR = [ pkgs.netcdf pkgs.zlib.dev ];
    nat = [ pkgs.which ];
    nat_templatebrains = [ pkgs.which ];
    nleqslv = [ pkgs.libiconv ];
    nlme = [ pkgs.libiconv ];
    nnls = [ pkgs.libiconv ];
    odbc = [ pkgs.pkgconfig ];
    oligo = [ pkgs.libiconv ];
    openssl = [ pkgs.pkgconfig ];
    pan = [ pkgs.libiconv ];
    pbdZMQ = lib.optionals stdenv.isDarwin [ pkgs.darwin.binutils ];
    pcaPP = [ pkgs.libiconv ];
    phangorn = [ pkgs.libiconv ];
    preprocessCore = [ pkgs.libiconv ];
    qpdf = [ pkgs.libjpeg.dev pkgs.zlib.dev ];
    qtbase = [ pkgs.cmake pkgs.perl ];
    qtpaint = [ pkgs.cmake ];
    quadprog = [ pkgs.libiconv ];
    quantreg = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    rPython = [ pkgs.which ];
    randomForest = [ pkgs.libiconv ];
    rggobi = [ pkgs.pkgconfig ];
    rgl = [ pkgs.libGLU pkgs.libGLU.dev pkgs.libGL pkgs.xlibsWrapper ];
    rmutil = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    robustbase = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    rrcov = [ pkgs.libiconv ];
    sitmo = [ pkgs.libiconv ];
    sf = [ pkgs.pkgconfig pkgs.sqlite.dev pkgs.proj.dev ];
    showtext = [ pkgs.pkgconfig ];
    spate = [ pkgs.pkgconfig ];
    statmod = [ pkgs.libiconv ];
    stringi = [ pkgs.pkgconfig ];
    sundialr = [ pkgs.libiconv ];
    svKomodo = [ pkgs.which ];
    sysfonts = [ pkgs.pkgconfig ];
    systemfonts = [ pkgs.pkgconfig ];
    tcltk2 = [ pkgs.tcl pkgs.tk ];
    tesseract = [ pkgs.pkgconfig ];
    tikzDevice = [ pkgs.which pkgs.texlive.combined.scheme-medium ];
    ucminf = [ pkgs.libiconv ];
  };

  packagesRequiringX = [
    "accrual"
    "ade4TkGUI"
    "analogue"
    "analogueExtra"
    "AnalyzeFMRI"
    "AnnotLists"
    "AnthropMMD"
    "aplpack"
    "asbio"
    "AtelieR"
    "BAT"
    "bayesDem"
    "BCA"
    "betapart"
    "BiodiversityR"
    "bio_infer"
    "bipartite"
    "biplotbootGUI"
    "blender"
    "cairoDevice"
    "CCTpack"
    "cncaGUI"
    "cocorresp"
    "CommunityCorrelogram"
    "confidence"
    "constrainedKriging"
    "ConvergenceConcepts"
    "cpa"
    "DALY"
    "dave"
    "Deducer"
    "DeducerPlugInExample"
    "DeducerPlugInScaling"
    "DeducerSpatial"
    "DeducerSurvival"
    "DeducerText"
    "Demerelate"
    "detrendeR"
    "dgmb"
    "DivMelt"
    "dpa"
    "DSpat"
    "dynamicGraph"
    "dynBiplotGUI"
    "EasyqpcR"
    "EcoVirtual"
    "ENiRG"
    "exactLoglinTest"
    "fat2Lpoly"
    "fbati"
    "FD"
    "feature"
    "FeedbackTS"
    "FFD"
    "fgui"
    "fisheyeR"
    "fit4NM"
    "forams"
    "forensim"
    "FreeSortR"
    "fscaret"
    "fSRM"
    "gcmr"
    "geomorph"
    "geoR"
    "georob"
    "GGEBiplotGUI"
    "gnm"
    "GPCSIV"
    "GrammR"
    "GrapheR"
    "GroupSeq"
    "gsubfn"
    "GUniFrac"
    "gWidgets2RGtk2"
    "gWidgets2tcltk"
    "gWidgetsRGtk2"
    "gWidgetstcltk"
    "HH"
    "HiveR"
    "ic50"
    "iDynoR"
    "in2extRemes"
    "iplots"
    "isopam"
    "IsotopeR"
    "JGR"
    "KappaGUI"
    "likeLTD"
    "logmult"
    "LS2Wstat"
    "MareyMap"
    "memgene"
    "MergeGUI"
    "metacom"
    "Meth27QC"
    "MetSizeR"
    "MicroStrategyR"
    "migui"
    "miniGUI"
    "MissingDataGUI"
    "mixsep"
    "MplusAutomation"
    "mpmcorrelogram"
    "mritc"
    "multgee"
    "multibiplotGUI"
    "OligoSpecificitySystem"
    "onemap"
    "OpenRepGrid"
    "paleoMAS"
    "pbatR"
    "PBSadmb"
    "PBSmodelling"
    "PCPS"
    "pez"
    "phylotools"
    "picante"
    "PKgraph"
    "plotSEMM"
    "plsRbeta"
    "plsRglm"
    "PopGenReport"
    "poppr"
    "powerpkg"
    "PredictABEL"
    "prefmod"
    "PrevMap"
    "ProbForecastGOP"
    "qtbase"
    "qtpaint"
    "r4ss"
    "RandomFields"
    "rareNMtests"
    "rAverage"
    "Rcmdr"
    "RcmdrPlugin_coin"
    "RcmdrPlugin_depthTools"
    "RcmdrPlugin_DoE"
    "RcmdrPlugin_EACSPIR"
    "RcmdrPlugin_EBM"
    "RcmdrPlugin_EcoVirtual"
    "RcmdrPlugin_EZR"
    "RcmdrPlugin_FactoMineR"
    "RcmdrPlugin_HH"
    "RcmdrPlugin_IPSUR"
    "RcmdrPlugin_KMggplot2"
    "RcmdrPlugin_lfstat"
    "RcmdrPlugin_MA"
    "RcmdrPlugin_mosaic"
    "RcmdrPlugin_MPAStats"
    "RcmdrPlugin_orloca"
    "RcmdrPlugin_plotByGroup"
    "RcmdrPlugin_pointG"
    "RcmdrPlugin_qual"
    "RcmdrPlugin_ROC"
    "RcmdrPlugin_sampling"
    "RcmdrPlugin_SCDA"
    "RcmdrPlugin_SLC"
    "RcmdrPlugin_sos"
    "RcmdrPlugin_steepness"
    "RcmdrPlugin_survival"
    "RcmdrPlugin_TeachingDemos"
    "RcmdrPlugin_temis"
    "RcmdrPlugin_UCA"
    "recluster"
    "relimp"
    "RenextGUI"
    "reshapeGUI"
    "rgl"
    "RHRV"
    "rich"
    "RNCEP"
    "RQDA"
    "RSDA"
    "RSurvey"
    "RunuranGUI"
    "simba"
    "Simile"
    "SimpleTable"
    "SOLOMON"
    "soundecology"
    "spatsurv"
    "sqldf"
    "SRRS"
    "SSDforR"
    "statcheck"
    "StatDA"
    "STEPCAM"
    "stosim"
    "strvalidator"
    "stylo"
    "svDialogstcltk"
    "svIDE"
    "svSocket"
    "svWidgets"
    "SYNCSA"
    "SyNet"
    "tcltk2"
    "TestScorer"
    "TIMP"
    "titan"
    "tkrgl"
    "tkrplot"
    "tmap"
    "tspmeta"
    "TTAinterfaceTrendAnalysis"
    "twiddler"
    "vcdExtra"
    "VecStatGraphs3D"
    "vegan"
    "vegan3d"
    "vegclust"
    "WMCapacity"
    "x12GUI"
  ];

  packagesToSkipCheck = [
    "Rmpi"     # tries to run MPI processes
    "pbdMPI"   # tries to run MPI processes
    "x12GUI"
  ];

  # Packages which cannot be installed due to lack of dependencies or other reasons.
  brokenPackages = [
    "bigGP"  # openmpi related
    "rpanel" # bwidget/Tk issue?
    "tesseract" # pdftoools, poppler ?
    "Rsymphony" # requires pkgs.SYMPHONY
    "x12" # looks for path when installing
    "x12GUI" # depends on x12
    "HDCytoData" "cytofWorkflow" # download fails, depends on HDCytoData
    "rggobi" "explorase" # ggobi compile error
  ];

  otherOverrides = old: new: {
    stringi = old.stringi.overrideDerivation (attrs: {
      postInstall = let
        icuName = "icudt52l";
        icuSrc = pkgs.fetchzip {
          url = "http://static.rexamine.com/packages/${icuName}.zip";
          sha256 = "0hvazpizziq5ibc9017i1bb45yryfl26wzfsv05vk9mc1575r6xj";
          stripRoot = false;
        };
        in ''
          ${attrs.postInstall or ""}
          cp ${icuSrc}/${icuName}.dat $out/library/stringi/libs
        '';
    });

    xml2 = old.xml2.overrideDerivation (attrs: {
      preConfigure = ''
        export LIBXML_INCDIR=${pkgs.libxml2.dev}/include/libxml2
        patchShebangs configure
        '';
    });

    Cairo = old.Cairo.overrideDerivation (attrs: {
      NIX_LDFLAGS = "-lfontconfig";
    });

    curl = old.curl.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    qtpaint = old.curl.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    rzmq = old.curl.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    RcppArmadillo = old.RcppArmadillo.overrideDerivation (attrs: {
      patchPhase = "patchShebangs configure";
    });

    data_table = old.data_table.overrideDerivation (attrs: {
      NIX_CFLAGS_COMPILE = attrs.NIX_CFLAGS_COMPILE
        + lib.optionalString stdenv.isDarwin " -fopenmp";
    });

    ModelMetrics = old.ModelMetrics.overrideDerivation (attrs: {
      NIX_CFLAGS_COMPILE = attrs.NIX_CFLAGS_COMPILE
        + lib.optionalString stdenv.isDarwin " -fopenmp";
    });

    rpf = old.rpf.overrideDerivation (attrs: {
      patchPhase = "patchShebangs configure";
    });

    rpg = old.rpf.overrideDerivation (attrs: {
      patchPhase = "patchShebangs configure";
    });

    Rhdf5lib = old.Rhdf5lib.overrideDerivation (attrs: {
      patches = [ ./patches/Rhdf5lib.patch ];
    });

    rJava = old.rJava.overrideDerivation (attrs: {
      preConfigure = ''
        export JAVA_CPPFLAGS=-I${pkgs.jdk}/include/
        export JAVA_HOME=${pkgs.jdk}
      '';
    });

    JavaGD = old.JavaGD.overrideDerivation (attrs: {
      preConfigure = ''
        export JAVA_CPPFLAGS=-I${pkgs.jdk}/include/
        export JAVA_HOME=${pkgs.jdk}
      '';
    });

    jqr = old.jqr.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    pbdZMQ = old.pbdZMQ.overrideDerivation (attrs: {
      postPatch = lib.optionalString stdenv.isDarwin ''
        for file in R/*.{r,r.in}; do
            sed -i 's#system("which \(\w\+\)"[^)]*)#"${pkgs.darwin.cctools}/bin/\1"#g' $file
        done
      '';
    });

    pdftools = old.curl.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    # delete? need a run time test
    # qtbase = old.qtbase.overrideDerivation (attrs: {
    #   patches = [ ./patches/qtbase.patch ];
    # });

    Rmpi = old.Rmpi.overrideDerivation (attrs: {
      configureFlags = [
        "--with-Rmpi-type=OPENMPI"
      ];
    });

    Rmpfr = old.Rmpfr.overrideDerivation (attrs: {
      configureFlags = [
        "--with-mpfr-include=${pkgs.mpfr.dev}/include"
      ];
    });

    RVowpalWabbit = old.RVowpalWabbit.overrideDerivation (attrs: {
      configureFlags = [
        "--with-boost=${pkgs.boost.dev}" "--with-boost-libdir=${pkgs.boost.out}/lib"
      ];
    });

    RMySQL = old.RMySQL.overrideDerivation (attrs: {
      MYSQL_DIR="${pkgs.libmysqlclient}";
      preConfigure = ''
        patchShebangs configure
      '';
    });

    devEMF = old.devEMF.overrideDerivation (attrs: {
      NIX_CFLAGS_LINK = "-L${pkgs.xorg.libXft.out}/lib -lXft";
      NIX_LDFLAGS = "-lX11";
    });

    slfm = old.slfm.overrideDerivation (attrs: {
      PKG_LIBS = "-L${pkgs.openblasCompat}/lib -lopenblas";
    });

    SamplerCompare = old.SamplerCompare.overrideDerivation (attrs: {
      PKG_LIBS = "-L${pkgs.openblasCompat}/lib -lopenblas";
    });

    # delete? need a run time test to be sure?
    # spMC = old.spMC.overrideDerivation (attrs: {
    #   patches = [ ./patches/spMC.patch ];
    # });

    openssl = old.openssl.overrideDerivation (attrs: {
      PKGCONFIG_CFLAGS = "-I${pkgs.openssl.dev}/include";
      PKGCONFIG_LIBS = "-Wl,-rpath,${pkgs.openssl.out}/lib -L${pkgs.openssl.out}/lib -lssl -lcrypto";
    });

    websocket = old.websocket.overrideDerivation (attrs: {
      PKGCONFIG_CFLAGS = "-I${pkgs.openssl.dev}/include";
      PKGCONFIG_LIBS = "-Wl,-rpath,${pkgs.openssl.out}/lib -L${pkgs.openssl.out}/lib -lssl -lcrypto";
    });

    Rserve = old.Rserve.overrideDerivation (attrs: {
      patches = [ ./patches/Rserve.patch ];
      configureFlags = [
        "--with-server" "--with-client"
      ];
    });

    nloptr = old.nloptr.overrideDerivation (attrs: {
      # Drop bundled nlopt source code. Probably unnecessary, but I want to be
      # sure we're using the system library, not this one.
      preConfigure = "rm -r src/nlopt_src";
    });

    V8 = old.V8.overrideDerivation (attrs: {
      postPatch = ''
        substituteInPlace configure \
          --replace " -lv8_libplatform" ""
      '';

      preConfigure = ''
        export INCLUDE_DIR=${pkgs.v8}/include
        export LIB_DIR=${pkgs.v8}/lib
        patchShebangs configure
      '';
    });

    acs = old.acs.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    gdtools = old.gdtools.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
      NIX_LDFLAGS = "-lfontconfig -lfreetype";
    });

    magick = old.magick.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    protolite = old.protolite.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    rpanel = old.rpanel.overrideDerivation (attrs: {
      preConfigure = ''
        export TCLLIBPATH="${pkgs.bwidget}/lib/bwidget${pkgs.bwidget.version}"
      '';
      TCLLIBPATH = "${pkgs.bwidget}/lib/bwidget${pkgs.bwidget.version}";
    });

    RPostgres = old.RPostgres.overrideDerivation (attrs: {
      preConfigure = ''
        export INCLUDE_DIR=${pkgs.postgresql}/include
        export LIB_DIR=${pkgs.postgresql.lib}/lib
        patchShebangs configure
        '';
    });

    OpenMx = old.OpenMx.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    odbc = old.odbc.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    x13binary = old.x13binary.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    geojsonio = old.geojsonio.overrideDerivation (attrs: {
      buildInputs = [ cacert ] ++ attrs.buildInputs;
    });

    rstan = old.rstan.overrideDerivation (attrs: {
      NIX_CFLAGS_COMPILE = "${attrs.NIX_CFLAGS_COMPILE} -DBOOST_PHOENIX_NO_VARIADIC_EXPRESSION";
    });

    mongolite = old.mongolite.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
      PKGCONFIG_CFLAGS = "-I${pkgs.openssl.dev}/include -I${pkgs.cyrus_sasl.dev}/include -I${pkgs.zlib.dev}/include";
      PKGCONFIG_LIBS = "-Wl,-rpath,${pkgs.openssl.out}/lib -L${pkgs.openssl.out}/lib -L${pkgs.cyrus_sasl.out}/lib -L${pkgs.zlib.out}/lib -lssl -lcrypto -lsasl2 -lz";
    });

    ps = old.ps.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    rlang = old.rlang.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    systemfonts = old.systemfonts.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    littler = old.littler.overrideAttrs (attrs: with pkgs; {
      buildInputs = [ pcre lzma zlib bzip2 icu which ] ++ attrs.buildInputs;
      postInstall = ''
        install -d $out/bin $out/share/man/man1
        ln -s ../library/littler/bin/r $out/bin/r
        ln -s ../library/littler/bin/r $out/bin/lr
        ln -s ../../../library/littler/man-page/r.1 $out/share/man/man1
        # these won't run without special provisions, so better remove them
        rm -r $out/library/littler/script-tests
      '';
    });

  };
in self

