class MpichMumps < Formula
  desc "Parallel Sparse Direct Solver"
  homepage "http://mumps-solver.org"
  url "https://mumps-solver.org/MUMPS_5.5.1.tar.gz"
  sha256 "1abff294fa47ee4cfd50dfd5c595942b72ebfcedce08142a75a99ab35014fa15"
  revision 3

  bottle do
    root_url "https://github.com/dpo/homebrew-mumps-jl/releases/download/mpich-mumps-5.5.1_2"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "6833d90da22519a8dcd311c4cce3d8bd0bcf192b2634a2a14ea20d07d9373bc0"
  end

  keg_only "because why not"

  depends_on "dpo/mumps-jl/mpich-parmetis"
  depends_on "dpo/mumps-jl/mpich-scalapack"

  depends_on "gcc"
  depends_on "mpich"
  depends_on "openblas"

  fails_with :clang # because we use OpenMP

  resource "mumps_simple" do
    url "https://github.com/dpo/mumps_simple/archive/refs/tags/v0.4.tar.gz"
    sha256 "87d1fc87eb04cfa1cba0ca0a18f051b348a93b0b2c2e97279b23994664ee437e"
  end

  def install
    # MUMPS >= 5.3.4 does not compile with gfortran10. Allow some errors to go through.
    # see https://listes.ens-lyon.fr/sympa/arc/mumps-users/2020-10/msg00002.html
    make_args = ["RANLIB=echo", "CDEFS=-DAdd_"]
    optf = ["OPTF=-O"]
    gcc_major_ver = Formula["gcc"].any_installed_version.major
    optf << "-fallow-argument-mismatch" if gcc_major_ver >= 10
    make_args << optf.join(" ")
    orderingsf = "-Dpord"

    makefile = "Makefile.G95.PAR"
    cp "Make.inc/" + makefile, "Makefile.inc"

    lib_args = []

    parmetis_libs = ["-L#{Formula["mpich-parmetis"].opt_lib}",
                     "-lparmetis", "-L#{Formula["metis"].opt_lib}",
                     "-lmetis"]
    make_args += ["LMETISDIR=#{Formula["mpich-parmetis"].opt_lib}",
                  "IMETIS=#{Formula["mpich-parmetis"].opt_include}",
                  "LMETIS=#{parmetis_libs.join(" ")}"]
    orderingsf << " -Dparmetis"
    lib_args += parmetis_libs

    make_args << "ORDERINGSF=#{orderingsf}"

    scalapack_libs = ["-L#{Formula["mpich-scalapack"].opt_lib}", "-lscalapack"]
    make_args += ["CC=mpicc -fPIC",
                  "FC=mpif90 -fPIC",
                  "FL=mpif90 -fPIC",
                  "SCALAP=#{scalapack_libs.join(" ")}",
                  "INCPAR=", # Let MPI compilers fill in the blanks.
                  "LIBPAR=$(SCALAP)"]
    lib_args += scalapack_libs

    blas_lib = ["-L#{Formula["openblas"].opt_lib}", "-lopenblas"]
    make_args << "LIBBLAS=#{blas_lib.join(" ")}"
    make_args << "LAPACK=#{blas_lib.join(" ")}"
    lib_args += blas_lib

    ENV.deparallelize # Build fails in parallel on Mavericks.

    system "make", "all", *make_args

    # make shared lib
    so = OS.mac? ? "dylib" : "so"
    all_load = OS.mac? ? "-all_load" : "--whole-archive"
    noall_load = OS.mac? ? "" : "-Wl,--no-whole-archive"
    compiler = OS.mac? ? "gfortran" : "mpif90" # mpif90 causes segfaults on macOS
    shopts = OS.mac? ? ["-undefined", "dynamic_lookup"] : []
    install_name = ->(libname) { OS.mac? ? ["-Wl,-install_name", "-Wl,#{lib}/#{libname}.#{so}"] : [] }
    cd "lib" do
      libpord_install_name = install_name.call("libpord")
      system compiler, "-fPIC", "-shared", "-Wl,#{all_load}", "libpord.a", *lib_args, \
             noall_load.to_s, *libpord_install_name, *shopts, "-o", "libpord.#{so}"
      lib.install "libpord.#{so}"
      libmumps_common_install_name = install_name.call("libmumps_common")
      system compiler, "-fPIC", "-shared", "-Wl,#{all_load}", "libmumps_common.a", *lib_args, \
             "-L#{lib}", "-lpord", noall_load.to_s, *libmumps_common_install_name, \
             *shopts, "-o", "libmumps_common.#{so}"
      lib.install "libmumps_common.#{so}"
      %w[libsmumps libdmumps libcmumps libzmumps].each do |l|
        libinstall_name = install_name.call(l)
        system compiler, "-fPIC", "-shared", "-Wl,#{all_load}", "#{l}.a", *lib_args, \
               "-L#{lib}", "-lpord", "-lmumps_common", noall_load.to_s, *libinstall_name, \
               *shopts, "-o", "#{l}.#{so}"
      end
    end

    lib.install Dir["lib/*"]

    inreplace "examples/Makefile" do |s|
      s.change_make_var! "libdir", lib
    end

    libexec.install "include"
    include.install_symlink Dir[libexec/"include/*"]

    doc.install Dir["doc/*.pdf"]
    pkgshare.install "examples"

    prefix.install "Makefile.inc"  # For the record.
    File.open(prefix/"make_args.txt", "w") do |f|
      f.puts(make_args.join(" "))  # Record options passed to make.
    end

    resource("mumps_simple").stage do
      simple_args = ["CC=mpicc", "prefix=#{prefix}", "mumps_prefix=#{prefix}",
                     "scalapack_libdir=#{Formula["mpich-scalapack"].opt_lib}"]
      simple_args += ["blas_libdir=#{Formula["openblas"].opt_lib}",
                      "blas_libs=-L$(blas_libdir) -lopenblas"]
      system "make", "SHELL=/bin/bash", *simple_args
      lib.install ("libmumps_simple." + (OS.mac? ? "dylib" : "so"))
      include.install "mumps_simple.h"
    end
  end

  test do
    ENV.prepend_path "LD_LIBRARY_PATH", lib unless OS.mac?
    cp_r pkgshare/"examples", testpath
    opts = ["-fopenmp"]
    mpiopts = ""
    ENV.prepend_path "LD_LIBRARY_PATH", Formula["mpich-scalapack"].opt_lib if OS.linux?
    f90 = "mpif90"
    cc = "mpicc"
    mpirun = "mpirun -np 1 #{mpiopts}"
    includes = "-I#{opt_include}"
    opts << "-L#{Formula["mpich-scalapack"].opt_lib}" << "-lscalapack" << "-L#{opt_lib}"
    ENV.prepend_path "LD_LIBRARY_PATH", Formula["mpich-parmetis"].opt_lib unless OS.mac?
    opts << "-L#{Formula["mpich-parmetis"].opt_lib}" << "-lparmetis"
    opts << "-lmumps_common" << "-lpord"
    opts << "-L#{Formula["openblas"].opt_lib}" << "-lopenblas"

    cd testpath/"examples" do
      system f90, "-o", "ssimpletest", "ssimpletest.F", "-lsmumps", includes, *opts
      system "#{mpirun} ./ssimpletest < input_simpletest_real"
      system f90, "-o", "dsimpletest", "dsimpletest.F", "-ldmumps", includes, *opts
      system "#{mpirun} ./dsimpletest < input_simpletest_real"
      system f90, "-o", "csimpletest", "csimpletest.F", "-lcmumps", includes, *opts
      system "#{mpirun} ./csimpletest < input_simpletest_cmplx"
      system f90, "-o", "zsimpletest", "zsimpletest.F", "-lzmumps", includes, *opts
      system "#{mpirun} ./zsimpletest < input_simpletest_cmplx"
      if OS.mac?
        # fails on linux: gcc-5 not found
        system cc, "-c", "c_example.c", includes
        system f90, "-o", "c_example", "c_example.o", "-ldmumps", *opts
        system(*(mpirun.split + ["./c_example"] + opts))
      end
    end
  end
end
