class MpichScalapack < Formula
  desc "High-performance linear algebra for distributed memory machines"
  homepage "https://www.netlib.org/scalapack/"
  url "https://www.netlib.org/scalapack/scalapack-2.2.0.tgz"
  sha256 "40b9406c20735a9a3009d863318cb8d3e496fb073d201c5463df810e01ab2a57"
  license "BSD-3-Clause"
  revision 3

  livecheck do
    url :homepage
    regex(/href=.*?scalapack[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    root_url "https://github.com/dpo/homebrew-mumps-jl/releases/download/mpich-scalapack-2.2.0_3"
    sha256 cellar: :any,                 arm64_sequoia: "f0ed7265eadad55f1f08e8e10cb72294b8e252c6b57f79caa4ed5d315e22361e"
    sha256 cellar: :any,                 ventura:       "ce6c6f2643d5baa60320a1aa152506b40f362733ce17ddff4c2bc3b8fca314a1"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "600c331eddf81bd1d4342d4edb51d33cec5b4503162cc85bd4e20f7b0914499d"
  end

  keg_only "conflicts with a core formula"

  depends_on "cmake" => :build
  depends_on "gcc" # for gfortran
  depends_on "mpich"
  depends_on "openblas"

  # Apply upstream commit to fix build with gfortran-12.  Remove in next release.
  patch do
    url "https://github.com/Reference-ScaLAPACK/scalapack/commit/a0f76fc0c1c16646875b454b7d6f8d9d17726b5a.patch?full_index=1"
    sha256 "2b42d282a02b3e56bb9b3178e6279dc29fc8a17b9c42c0f54857109286a9461e"
  end

  patch :DATA

  def install
    # Fix compile with newer Clang
    ENV.append_to_cflags "-Wno-implicit-function-declaration"

    mkdir "build" do
      blas = "-L#{Formula["openblas"].opt_lib} -lopenblas"
      system "cmake", "..", *std_cmake_args, "-DBUILD_SHARED_LIBS=ON",
                      "-DBLAS_LIBRARIES=#{blas}", "-DLAPACK_LIBRARIES=#{blas}"
      system "make", "all"
      system "make", "install"
    end

    pkgshare.install "EXAMPLE"
  end

  test do
    cp_r pkgshare/"EXAMPLE", testpath
    cd "EXAMPLE" do
      system "mpif90", "-o", "xsscaex", "psscaex.f", "pdscaexinfo.f", "-L#{opt_lib}", "-lscalapack"
      assert `mpirun -np 4 ./xsscaex | grep 'INFO code' | awk '{print $NF}'`.to_i.zero?
      system "mpif90", "-o", "xdscaex", "pdscaex.f", "pdscaexinfo.f", "-L#{opt_lib}", "-lscalapack"
      assert `mpirun -np 4 ./xdscaex | grep 'INFO code' | awk '{print $NF}'`.to_i.zero?
      system "mpif90", "-o", "xcscaex", "pcscaex.f", "pdscaexinfo.f", "-L#{opt_lib}", "-lscalapack"
      assert `mpirun -np 4 ./xcscaex | grep 'INFO code' | awk '{print $NF}'`.to_i.zero?
      system "mpif90", "-o", "xzscaex", "pzscaex.f", "pdscaexinfo.f", "-L#{opt_lib}", "-lscalapack"
      assert `mpirun -np 4 ./xzscaex | grep 'INFO code' | awk '{print $NF}'`.to_i.zero?
    end
  end
end

__END__
diff --git a/CMakeLists.txt b/CMakeLists.txt
index 85ea82a..86222e0 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -232,7 +232,7 @@ append_subdir_files(src-C "SRC")

 if (UNIX)
    add_library(scalapack ${blacs} ${tools} ${tools-C} ${extra_lapack} ${pblas} ${pblas-F} ${ptzblas} ${ptools} ${pbblas} ${redist} ${src} ${src-C})
-   target_link_libraries( scalapack ${LAPACK_LIBRARIES} ${BLAS_LIBRARIES})
+   target_link_libraries( scalapack ${LAPACK_LIBRARIES} ${BLAS_LIBRARIES} ${MPI_Fortran_LIBRARIES})
    scalapack_install_library(scalapack)
 else (UNIX) # Need to separate Fortran and C Code
    OPTION(BUILD_SHARED_LIBS "Build shared libraries" ON )
