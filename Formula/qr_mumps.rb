class QrMumps < Formula
  desc "Parallel sparse QR factorization"
  homepage "https://qr_mumps.gitlab.io"
  url "https://gitlab.com/qr_mumps/qr_mumps/-/archive/3.0.3/qr_mumps-3.0.3.tar.gz"
  sha256 "d5438362cfb4b888f31826c3cf009555a8dbb5eb7a64d0b516c02b54fd60bdac"
  revision 1

  bottle do
    root_url "https://github.com/dpo/homebrew-mumps-jl/releases/download/qr_mumps-3.0.3"
    sha256 cellar: :any,                 monterey:     "850d0d9ad58012f4060e8fc133c80bb73e13694f08e388af9300eae87ae1274c"
    sha256 cellar: :any,                 big_sur:      "9c53ab12c5ec43474926d0ec454f1bee7fb85a7abe1aa30c994c61b60359dc3f"
    sha256 cellar: :any,                 catalina:     "d741381db3583d679816ff95e2d6973ff7537294f1557f911e9e1259defe7819"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "50f8a21bdaf626715bab9f820abac446d97181de01de1ec98e7e98d583057676"
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

        write(*,'("Expected result is x= 1.00000 2.00000 3.00000 4.00000 5.00000 6.00000 7.00000")')
        write(*,'("Computed result is x=",7(1x,f7.5))')x

        xe = xe-x;
        call qrm_vecnrm(xe, qrm_spmat%n, "2", fnrm)
        write(*,'(" ")')
        write(*,'("Forward error norm       ||xe-x||  = ",e7.2)')fnrm
        write(*,'("Residual norm            ||A*x-b|| = ",e7.2)')rnrm

        call qrm_spmat_destroy(qrm_spmat)
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
