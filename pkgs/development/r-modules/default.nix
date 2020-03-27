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
    propagatedBuildInputs = depends ++ (lib.optionals stdenv.isDarwin [ pkgs.libiconv ]);
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

  packagesWithNativeBuildInputs = with pkgs; {
    AMOUNTAIN = [ gsl_1 ];
    BayesSAE = [ gsl_1 ];
    BayesVarSel = [ gsl_1 ];
    BayesXsrc = [ readline.dev ncurses ];
    BiocCheck = [ which ];
    Biostrings = [ zlib ];
    BitSeq = [ zlib.dev curl.dev ];
    Cairo = [ libtiff libjpeg cairo.dev x11 fontconfig.lib ];
    Cardinal = [ which ];
    ChemmineOB = [ openbabel pkgconfig ];
    DiffBind = [ zlib.dev curl.dev ];
    DirichletMultinomial = [ gsl_1 ];
    EMCluster = [ liblapack ];
    Formula = [ gmp ];
    GLAD = [ gsl_1 ];
    HDF5Array = [ zlib.dev ];
    HiCseg = [ gsl_1 ];
    JavaGD = [ jdk ];
    KFKSDS = [ gsl_1 ];
    ModelMetrics = lib.optional stdenv.isDarwin llvmPackages.openmp;
    MotIV = [ gsl_1 ];
    MSGFplus = [ jdk];
    PKI = [ openssl.dev ];
    R2SWF = [ zlib libpng freetype.dev ];
    RAppArmor = [ libapparmor ];
    RGtk2 = [ gtk2.dev ];
    RMySQL = [ zlib libmysqlclient openssl.dev ];
    RNetCDF = [ netcdf udunits ];
    RODBC = [ libiodbc ];
    RPostgreSQL = [ postgresql postgresql ];
    RProtoBuf = [ protobuf ];
    RSclient = [ openssl.dev ];
    RVowpalWabbit = [ zlib.dev boost ];
    RcppCNPy = [ zlib.dev ];
    RcppGSL = [ gsl_1 ];
    RcppZiggurat = [ gsl_1 ];
    Rglpk = [ glpk ];
    Rhdf5lib = [ zlib.dev ];
    Rhpc = [ zlib bzip2.dev icu lzma.dev openmpi pcre.dev ];
    Rhtslib = [ zlib.dev automake autoconf bzip2.dev lzma.dev curl.dev ] ;
    Rlibeemd = [ gsl_1 ];
    Rmpfr = [ gmp mpfr.dev ];
    Rmpi = [ openmpi ];
    Rsamtools = [ zlib.dev curl.dev ];
    Rserve = [ openssl ];
    Rssa = [ fftw.dev ];
    Rsubread = [ zlib.dev ];
    SAVE = [ zlib bzip2 icu lzma pcre ];
    ShortRead = [ zlib.dev ];
    TAQMNGR = [ zlib.dev ];
    TKF = [ gsl_1 ];
    V8 = [ v8 ];
    VariantAnnotation = [ zlib.dev ];
    XBRL = [ zlib libxml2.dev ];
    XML = [ libtool libxml2.dev xmlsec libxslt ];
    XVector = [ zlib.dev ];
    abn = [ gsl_1 ];
    adimpro = [ imagemagick ];
    affyPLM = [ zlib.dev ];
    affyio = [ zlib.dev ];
    animation = [ which ];
    audio = [ portaudio ];
    bamsignals = [ zlib.dev curl.dev ];
    bigGP = [ openmpi ];
    bio3d = [ zlib.dev ];
    bnpmr = [ gsl_1 ];
    cairoDevice = [ gtk2.dev ];
    chebpol = [ fftw ];
    cit = [ gsl_1 ];
    curl = [ curl.dev ];
    data_table = [zlib.dev] ++ lib.optional stdenv.isDarwin llvmPackages.openmp;
    devEMF = [ xorg.libXft.dev x11 ];
    diversitree = [ gsl_1 fftw ];
    fftw = [ fftw.dev ];
    fftwtools = [ fftw.dev ];
    gdtools = [ cairo.dev fontconfig.lib freetype.dev ];
    git2r = [ zlib.dev openssl.dev libssh2.dev libgit2 pkgconfig ];
    glpkAPI = [ gmp glpk ];
    gmapR = [ zlib.dev ];
    gmp = [ gmp.dev ];
    graphscan = [ gsl_1 ];
    gsl = [ gsl ];
    hdf5r = [ hdf5.dev];
    h5vc = [ zlib.dev curl.dev ];
    haven = [ libiconv zlib.dev ];
    iBMQ = [ gsl_1 ];
    igraph = [ gmp libxml2.dev ];
    imager = [ x11 ];
    jpeg = [ libjpeg.dev ];
    jqr = [ jq.dev ];
    lwgeom = [ proj.dev geos ];
    kza = [ fftw.dev ];
    magick = [ imagemagick.dev ];
    mvabund = [ gsl_1 ];
    mwaved = [ fftw.dev ];
    ncdfFlow = [ zlib.dev ];
    ncdf4 = [ netcdf ];
    nloptr = [ nlopt pkgconfig ];
    odbc = [ unixODBC ];
    oligo = [ zlib.dev ];
    outbreaker = [ gsl_1 ];
    pander = [ pandoc which ];
    pbdMPI = [ openmpi ];
    pbdNCDF4 = [ netcdf ];
    pbdPROF = [ openmpi ];
    pbdZMQ = lib.optionals stdenv.isDarwin [ which ];
    pdftools = [ poppler libjpeg.dev];
    phytools = [ which ];
    png = [ libpng.dev ];
    proj4 = [ proj.dev ];
    protolite = [ protobuf ];
    qtbase = [ qt4.dev  ];
    qtpaint = [ qt4 ];
    rJava = [ zlib bzip2.dev icu lzma.dev pcre.dev jdk libzip ];
    rPython = [ python ];
    rapport = [ which ];
    rapportools = [ which ];
    rcdd = [ gmp.dev ];
    readxl = [ libiconv ];
    reprex = [ which ];
    rgdal = [ proj.dev gdal ];
    rgeos = [ geos ];
    rggobi = [ ggobi gtk2.dev libxml2.dev ];
    rhdf5 = [ zlib ];
    rjags = [ jags ];
    rmatio = [ zlib.dev ];
    rpanel = [ bwidget ];
    rpg = [ postgresql ];
    rtiff = [ libtiff.dev ];
    rtracklayer = [ zlib.dev ];
    runjags = [ jags ];
    rzmq = [ zeromq3 ];
    sdcTable = [ gmp glpk ];
    seewave = [ fftw.dev libsndfile.dev ];
    seqinr = [ zlib.dev ];
    seqminer = [ zlib.dev bzip2 ];
    sf = [ gdal proj.dev geos ];
    showtext = [ zlib libpng icu freetype.dev ];
    simplexreg = [ gsl_1 ];
    snpStats = [ zlib.dev ];
    spate = [ fftw.dev ];
    ssanv = [ proj.dev ];
    stringi = [ icu.dev ];
    stsm = [ gsl_1 ];
    survSNP = [ gsl_1 ];
    sysfonts = [ zlib libpng freetype.dev ];
    systemfonts = [ fontconfig.dev freetype.dev ];
    tesseract = [ tesseract leptonica poppler ];
    tiff = [ libtiff.dev ];
    tkrplot = [ xorg.libX11 tk.dev ];
    topicmodels = [ gsl_1 ];
    udunits2 = [ udunits expat ];
    units = [ udunits ];
    xml2 = [ libxml2.dev ] ++ lib.optionals stdenv.isDarwin [ perl ];
  };

  packagesWithBuildInputs = with pkgs; {
    # sort -t '=' -k 2
    AnnotLists = [ flock ];
    BANDITS = [ libiconv ];
    CGEN = [ libiconv ];
    GenSA = [ libiconv ];
    GeneSelectMMD  = [ libiconv ];
    CNAnorm = [libiconv ];
    Cairo = [ pkgconfig ];
    Delaporte = [ libiconv ];
    DESeq2 = [ libiconv ];
    DNAcopy = [ libiconv ];
    GRENITS = [ libiconv ];
    HDTD = [ libiconv ];
    HilbertVisGUI = [ gtkmm2.dev pkg-config which pkgconfig gnumake ];
    HiddenMarkov = [ libiconv ];
    Hmisc = [ libiconv ];
    Iso = [ libiconv ];
    KernSmooth = [ libiconv ];
    LEA = [ libiconv ];
    LVSmiRNA = [ libiconv ];
    JunctionSeq = [ libiconv ];
    Matrix = [ libiconv ];
    R2SWF = [ pkgconfig ];
    RCurl = [ curl.dev ];
    RGtk2 = [ pkgconfig ];
    RMark = [ which ];
    RProtoBuf = [ pkgconfig ];
    RPushbullet = [ which ];
    RSpectra = [ libiconv ];
    RcppArmadillo = [ libiconv ];
    RcppEigen = [ libiconv ];
    Rpoppler = [ pkgconfig poppler.dev ];
    Rsymphony = [ pkgconfig doxygen graphviz subversion ];
    Rtsne = [ libiconv ];
    SparseM = lib.optionals stdenv.isDarwin [ libiconv ];
    VariantAnnotation = [ curl.dev ];
    XML = [ pkgconfig ];
    acepack = [ libiconv ];
    ade4 = [ libiconv ];
    adimpro = [ which xorg.xdpyinfo ];
    affyPLM = [ libiconv ];
    ape = [ libiconv ];
    biglm = [ libiconv ];
    cairoDevice = [ pkgconfig ];
    chebpol = [ pkgconfig ];
    cluster = [ libiconv ];
    edgeR = [ libiconv ];
    expm = [ libiconv ];
    fftw = [ pkgconfig ];
    gam = lib.optionals stdenv.isDarwin [ libiconv ];
    gdtools = [ pkgconfig ];
    genefilter = [ libiconv ];
    glmnet = [ libiconv ];
    gridGraphics = [ which ];
    gsubfn = [ flock xorg.xdpyinfo x11 ];
    hexbin = [ libiconv ];
    igraph = [ libiconv ];
    impute = [ libiconv ];
    irlba = [ libiconv ];
    jqr = [ jq.lib ];
    kernlab = [ libiconv ];
    kza = [ pkgconfig ];
    magick = [ pkgconfig ];
    mclust = [ libiconv ];
    mgcv = [ libiconv ];
    minqa = [ libiconv ];
    mnormt = [ libiconv ];
    mvtnorm = [ libiconv ];
    mwaved = [ pkgconfig ];
    mzR = [ netcdf zlib.dev ];
    nat = [ which ];
    nat_templatebrains = [ which ];
    nleqslv = [ libiconv ];
    nlme = [ libiconv ];
    nnls = [ libiconv ];
    odbc = [ pkgconfig ];
    oligo = [ libiconv ];
    openssl = [ pkgconfig ];
    pan = [ libiconv ];
    pbdZMQ = lib.optionals stdenv.isDarwin [ darwin.binutils ];
    pcaPP = [ libiconv ];
    phangorn = [ libiconv ];
    preprocessCore = [ libiconv ];
    qpdf = [ libjpeg.dev zlib.dev ];
    qtbase = [ cmake perl ];
    qtpaint = [ cmake ];
    quadprog = [ libiconv ];
    quantreg = lib.optionals stdenv.isDarwin [ libiconv ];
    rPython = [ which ];
    randomForest = [ libiconv ];
    rggobi = [ pkgconfig ];
    rgl = [ libGLU libGLU.dev libGL xlibsWrapper ];
    rmutil = lib.optionals stdenv.isDarwin [ libiconv ];
    robustbase = lib.optionals stdenv.isDarwin [ libiconv ];
    rrcov = [ libiconv ];
    rsvg = [ librsvg.dev pkgconfig ];    
    sitmo = [ libiconv ];
    sf = [ pkgconfig sqlite.dev proj.dev ];
    showtext = [ pkgconfig ];
    spate = [ pkgconfig ];
    statmod = [ libiconv ];
    stringi = [ pkgconfig ];
    sundialr = [ libiconv ];
    svKomodo = [ which ];
    sysfonts = [ pkgconfig ];
    systemfonts = [ pkgconfig ];
    tcltk2 = [ tcl tk ];
    tesseract = [ pkgconfig ];
    tikzDevice = [ which texlive.combined.scheme-medium ];
    ucminf = [ libiconv ];
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
    "Rsymphony" # requires SYMPHONY, never packaged for nixpkgs
    "x12" # looks for path when installing
    "x12GUI" # depends on x12
    "HDCytoData" "cytofWorkflow" # download fails, depends on HDCytoData
    "rggobi" "explorase" "ggrisk" "PKgraph" # ggobi compile error
    "gsubfn" # xvb-run can't find mcookie
    "rae230aprobe"  "rae230bcdf"  "sqldf"  "miRNAtap"  "miRNAtap" "sqldf" "miRNAtap" "miRNAtap_db"# gsubfn fails
    "HilbertVisGUI"
    # bad download: https://experimenthub.bioconductor.org/metadata/experimenthub.sqlit
    "DuoClustering2018" "FlowSorted_CordBloodCombined_450k" "FlowSorted_CordBlood_450k" "TabulaMurisData"
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

