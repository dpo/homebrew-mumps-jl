class MpichScotch < Formula
  desc "Graph/mesh partitioning, clustering, sparse matrix ordering"
  homepage "https://gitlab.inria.fr/scotch"
  url "https://gitlab.inria.fr/scotch/scotch/-/archive/v6.1.0/scotch-v6.1.0.tar.gz"
  sha256 "4fe537f608f0fe39ec78807f90203f9cca1181deb16bfa93b7d4cd440e01bbd1"
  revision 2

  bottle do
    root_url "https://github.com/dpo/homebrew-mumps-jl/releases/download/mpich-scotch-6.1.0_2"
    sha256 cellar: :any,                 big_sur:      "7acb97584768adf95e473e0ea0b02f8139ff411eca6a1894cb35c6be4115ed71"
    sha256 cellar: :any,                 catalina:     "09db62c19adff40a7d490c7ad570ca77634671d9dc8f9464dcfe11fe03681db8"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "c5973553650d1bdf18fdf4320eb1c33554fa02ee17bb78f78c45f36334421c67"
  end

  keg_only "formulae in dpo/mumps-jl are keg only"

  depends_on "bzip2" unless OS.mac?
  depends_on "mpich"
  depends_on "xz" => :optional # Provides lzma compression.

  def install
    ENV.deparallelize
    cd "src" do
      ln_s "Make.inc/Makefile.inc.i686_mac_darwin10", "Makefile.inc"
      # default CFLAGS:
      # -O3 -Drestrict=__restrict -DCOMMON_FILE_COMPRESS_GZ -DCOMMON_PTHREAD
      # -DCOMMON_PTHREAD_BARRIER -DCOMMON_RANDOM_FIXED_SEED -DCOMMON_TIMING_OLD
      # -DSCOTCH_PTHREAD -DSCOTCH_RENAME
      # MPI implementation is not threadsafe, do not use DSCOTCH_PTHREAD

      cflags = %w[-O3 -fPIC -Drestrict=__restrict -DCOMMON_PTHREAD_BARRIER
                  -DCOMMON_PTHREAD
                  -DSCOTCH_CHECK_AUTO -DCOMMON_RANDOM_FIXED_SEED
                  -DCOMMON_TIMING_OLD -DSCOTCH_RENAME
                  -DCOMMON_FILE_COMPRESS_BZ2 -DCOMMON_FILE_COMPRESS_GZ]
      ldflags = if OS.mac?
        # necessary for gcc on Big Sur
        %w[-L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib]
      else
        %w[]
      end
      ldflags += %w[-lm -lz -lpthread -lbz2]

      cflags += %w[-DCOMMON_FILE_COMPRESS_LZMA] if build.with? "xz"
      ldflags += %W[-L#{Formula["xz"].lib} -llzma] if build.with? "xz"

      make_args = ["CCS=#{ENV["CC"]}",
                   "CCP=mpicc",
                   "CCD=mpicc",
                   "RANLIB=echo",
                   "CFLAGS=#{cflags.join(" ")}",
                   "LDFLAGS=#{ldflags.join(" ")}"]

      if OS.mac?
        make_args << "LIB=.dylib"
        make_args << "AR=libtool"
        arflags = ldflags.join(" ") + " -dynamic -install_name #{lib}/$(notdir $@) -undefined dynamic_lookup -o"
        make_args << "ARFLAGS=#{arflags}"
      else
        make_args << "LIB=.so"
        make_args << "ARCH=ar"
        make_args << "ARCHFLAGS=-ruv"
      end

      system "make", "scotch", "VERBOSE=ON", *make_args
      system "make", "ptscotch", "VERBOSE=ON", *make_args
      system "make", "esmumps", "VERBOSE=ON", *make_args
      system "make", "install", "prefix=#{prefix}", *make_args
      system "make", "check", "ptcheck", "EXECP=mpirun -np 2", *make_args
    end

    # Install documentation + sample graphs and grids.
    doc.install Dir["doc/*.pdf"]
    pkgshare.install Dir["doc/*.f"], Dir["doc/*.txt"]
    pkgshare.install "grf", "tgt"
  end

  test do
    mktemp do
      system "echo cmplt 7 | #{bin}/gmap #{pkgshare}/grf/bump.grf.gz - bump.map"
      system "#{bin}/gmk_m2 32 32 | #{bin}/gmap - #{pkgshare}/tgt/h8.tgt brol.map"
      system "#{bin}/gout", "-Mn", "-Oi", "#{pkgshare}/grf/4elt.grf.gz", "#{pkgshare}/grf/4elt.xyz.gz",
             "-", "graph.iv"
    end
  end
end
