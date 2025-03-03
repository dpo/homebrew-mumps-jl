class QrMumps < Formula
  desc "Parallel sparse QR factorization"
  homepage "https://qr_mumps.gitlab.io"
  url "https://gitlab.com/qr_mumps/qr_mumps/-/archive/3.1/qr_mumps-3.1.tar.gz"
  sha256 "6e39dbfa1e6ad3730b006c8953a43cc6da3dfc91f00edeb68a641d364703b773"
  revision 1

  bottle do
    root_url "https://github.com/dpo/homebrew-mumps-jl/releases/download/qr_mumps-3.1_1"
    sha256 cellar: :any,                 arm64_sequoia: "5af4993c5e6a155728748a15a33849e36448f453368b4e7e7bdc71e08351801b"
    sha256 cellar: :any,                 arm64_sonoma:  "bf6ee81c5c3f7248ee1db237d9c19eabc4810d0f330e92f36768fc5f31b8fb92"
    sha256 cellar: :any,                 ventura:       "6346666092415406548a198281467bb9cb1db88489a9808dbb1bdd94ecd24503"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "9fe17db7a4927fcba23b2ddda5a4be22f53adf4fe2540a3ac22e90339fe9023b"
  end

  depends_on "cmake" => :build
  depends_on "gcc"
  depends_on "metis"
  depends_on "openblas"
  depends_on "suite-sparse"

  fails_with :clang # because we use OpenMP

  def install
    cmake_args = %w[-DARITH=d;s;c;z
                    -DBUILD_SHARED_LIBS=ON
                    -DQRM_WITH_TESTS=OFF
                    -DQRM_WITH_EXAMPLES=OFF
                    -DQRM_ORDERING_AMD=ON
                    -DQRM_ORDERING_METIS=ON
                    -DQRM_ORDERING_SCOTCH=OFF
                    -DQRM_WITH_STARPU=OFF
                    -DQRM_WITH_CUDA=OFF
                    -DCMAKE_BUILD_TYPE=Release]
    system "cmake", "-S", ".", "-B", "build", *(std_cmake_args + cmake_args)
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
    pkgshare.install "examples", "aux/ariths.pl"
  end

  test do
    ENV.fortran
    (testpath / "test.f90").write <<~EOS
      program zqrm_example
        use zqrm_mod
        implicit none

        type(zqrm_spmat_type)   :: qrm_spmat
        integer     , target    :: irn(13) = (/1, 1, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5/)
        integer     , target    :: jcn(13) = (/3, 5, 7, 1, 4, 6, 2, 6, 5, 6, 3, 4, 7/)
        complex(r64), target    :: val(13) = (/2.d0, 3.d0, 5.d0, 1.d0, 2.d0, 2.d0, 2.d0, &
                                              2.d0, 2.d0, 2.d0, 1.d0, 2.d0, 2.d0/)
        complex(r64)            :: b(5)    = (/56.d0, 21.d0, 16.d0, 22.d0, 25.d0/)
        complex(r64)            :: xe(7)   = (/1.d0, 2.d0, 3.d0, 4.d0, 5.d0, 6.d0, 7.d0/)
        complex(r64)            :: x(7)    = qrm_zzero
        complex(r64)            :: r(5)    = qrm_zzero
        integer                 :: info
        real(r64)               :: anrm, bnrm, xnrm, rnrm, onrm, fnrm

        call qrm_init()

        ! initialize the matrix data structure.
        call qrm_spmat_init(qrm_spmat)

        qrm_spmat%m   =  5
        qrm_spmat%n   =  7
        qrm_spmat%nz  =  13
        qrm_spmat%irn => irn
        qrm_spmat%jcn => jcn
        qrm_spmat%val => val

        r = b

        call qrm_vecnrm(b, size(b,1), "2", bnrm)

        call qrm_min_norm(qrm_spmat, b, x)

        call qrm_residual_norm(qrm_spmat, r, x, rnrm)
        call qrm_vecnrm(x, qrm_spmat%n, "2", xnrm)
        call qrm_spmat_nrm(qrm_spmat, "f", anrm)

        call qrm_prnt_array(xe,"Expected result is x")
        call qrm_prnt_array(x,"Computed result is x")

        xe = xe-x;
        call qrm_vecnrm(xe, qrm_spmat%n, "2", fnrm)
        write(*,'(" ")')
        write(*,'("Forward error norm       ||xe-x||  = ",e7.2)')fnrm
        write(*,'("Residual norm            ||A*x-b|| = ",e7.2)')rnrm

        stop
      end program zqrm_example
    EOS

    %w[s d c z].each do |p|
      system "perl #{pkgshare}/ariths.pl test.f90 #{p} > #{p}test.f90"
      system ENV["FC"], "#{p}test.f90", "-o", "#{p}test", "-I#{opt_include}", "-L#{opt_lib}", "-lqrm_common",
             "-l#{p}qrm", "-lgomp"
      system "./#{p}test"
    end
  end
end
