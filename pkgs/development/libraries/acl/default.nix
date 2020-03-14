{ stdenv, fetchurl, gettext, attr }:

stdenv.mkDerivation rec {
  name = "acl-2.2.53";

  src = fetchurl {
    url = "mirror://savannah/acl/${name}.tar.gz";
    sha256 = "1ir6my3w74s6nfbgbqgzj6w570sn0qjf3524zx8xh67lqrjrigh6";
  };

  outputs = [ "bin" "dev" "out" "man" "doc" ];

  nativeBuildInputs = [ gettext ];
  buildInputs = [ attr ];

  # Upstream use C++-style comments in C code. Remove them.
  # This comment breaks compilation if too strict gcc flags are used.
  patchPhase = ''
    echo "Removing C++-style comments from include/acl.h"
    sed -e '/^\/\//d' -i include/acl.h

    patchShebangs .
  '';

  meta = with stdenv.lib; {
    homepage = "https://savannah.nongnu.org/projects/acl";
    description = "Library and tools for manipulating access control lists";
    platforms = platforms.linux;
    license = licenses.gpl2Plus;
  };
}
