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
    root_url "https://github.com/dpo/homebrew-mumps-jl/releases/download/mpich-scalapack-2.1.0_4"
    sha256 cellar: :any,                 big_sur:      "127c22c11d48e4568f52cd68074d3f793fdd17b2b68a6929f9c4d6d087a20c39"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "da7ae29f4228b5f5e7ae875e0da33e8f70f36219a7310748a738d5aa74e768e0"
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
