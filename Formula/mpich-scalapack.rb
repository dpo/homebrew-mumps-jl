class MpichScalapack < Formula
  desc "High-performance linear algebra for distributed memory machines"
  homepage "https://www.netlib.org/scalapack/"
  url "https://www.netlib.org/scalapack/scalapack-2.1.0.tgz"
  sha256 "61d9216cf81d246944720cfce96255878a3f85dec13b9351f1fa0fd6768220a6"
  license "BSD-3-Clause"
  revision 5

  livecheck do
    url :homepage
    regex(/href=.*?scalapack[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    root_url "https://github.com/dpo/homebrew-mumps-jl/releases/download/mpich-scalapack-2.1.0_5"
    sha256 cellar: :any,                 big_sur:      "1401fc5c28d0200a2249c184a276b44635ff702ef1daa9fce66d123095dbc25e"
    sha256 cellar: :any,                 catalina:     "d4161a07ac76cbd11ee7940e134316c754c5d22d30a2027d8886f388fc776798"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "c2aa1769e5355a6e16763423453214ab5e82bba0e2582661d2a94557ae32490f"
  end

  keg_only "conflicts with a core formula"

  depends_on "cmake" => :build
  depends_on "gcc" # for gfortran
  depends_on "mpich"
  depends_on "openblas"

  # Patch for compatibility with GCC 10
  # https://github.com/Reference-ScaLAPACK/scalapack/pull/26
  patch do
    url "https://github.com/Reference-ScaLAPACK/scalapack/commit/bc6cad585362aa58e05186bb85d4b619080c45a9.patch?full_index=1"
    sha256 "f0892888e5a83d984e023e76eabae8864ad89b90ae3a41d472b960c95fdab981"
  end

  def install
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
