class MpichParmetis < Formula
  desc "MPI library for graph partitioning and fill-reducing orderings"
  homepage "https://github.com/KarypisLab/ParMETIS"
  url "https://mirror.math.princeton.edu/pub/ubuntu/pool/multiverse/p/parmetis/parmetis_4.0.3.orig.tar.gz"
  mirror "http://glaros.dtc.umn.edu/gkhome/fetch/sw/parmetis/parmetis-4.0.3.tar.gz"
  sha256 "f2d9a231b7cf97f1fee6e8c9663113ebf6c240d407d3c118c55b3633d6be6e5f"
  revision 5

  bottle do
    root_url "https://github.com/dpo/homebrew-mumps-jl/releases/download/mpich-parmetis-4.0.3_5"
    sha256 cellar: :any,                 arm64_sequoia: "2c05a3761bc9694e6f1dd41822dea711d478427b704921a34d54a7bad9531c5a"
    sha256 cellar: :any,                 ventura:       "ccd152a568df84a98f2248ed87cedd061e3ae5a7a3eedd684c3b405fe7d3f9f7"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "e55e41a59a392c10a2e49c4999cedd1168798173fc5022e30e8b4b61ed9c6be4"
  end

  keg_only "because why not"

  depends_on "cmake" => :build

  # METIS 5.* is required. It comes bundled with ParMETIS.
  # We prefer to brew it ourselves.
  depends_on "metis"

  depends_on "mpich"

  # Do not build the METIS 5.* that ships with ParMETIS.
  patch :DATA

  # Bug fixes from PETSc developers. Mirrored because the SHA-256s get
  # invalidated every time Bitbucket updates the Git version they use.
  patch do
    # From: https://bitbucket.org/petsc/pkg-parmetis/commits/82409d68aa1d6cbc70740d0f35024aae17f7d5cb/raw/
    url "https://raw.githubusercontent.com/Homebrew/patches/f104fbb1e09402798cbbc06d2f695d85398c0c89/parmetis/commit-82409d68.patch"
    sha256 "0349f5bc19a2ba9fe9e1b9d385072dabe59262522bd7cf66f26c6bc31bbb1b86"
  end

  patch do
    # From: https://bitbucket.org/petsc/pkg-parmetis/commits/1c1a9fd0f408dc4d42c57f5c3ee6ace411eb222b/raw/
    url "https://raw.githubusercontent.com/Homebrew/patches/f104fbb1e09402798cbbc06d2f695d85398c0c89/parmetis/commit-1c1a9fd0.patch"
    sha256 "baec5e1fa6bb4f6c59e3ede564485e0ad743f58c9875fd65cb715b5c14a491b5"
  end

  def install
    ENV["LDFLAGS"] = "-L#{Formula["metis"].lib} -lmetis -lm"

    system "make", "config", "prefix=#{prefix}", "shared=1"
    system "make", "install"
    pkgshare.install "Graphs" # Sample data for test
  end

  test do
    system "mpirun", "-np", "2", "#{bin}/ptest", "#{pkgshare}/Graphs/rotor.graph"
  end
end

__END__
diff --git a/CMakeLists.txt b/CMakeLists.txt
index ca945dd..1bf94e9 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -33,7 +33,7 @@ include_directories(${GKLIB_PATH})
 include_directories(${METIS_PATH}/include)

 # List of directories that cmake will look for CMakeLists.txt
-add_subdirectory(${METIS_PATH}/libmetis ${CMAKE_BINARY_DIR}/libmetis)
+#add_subdirectory(${METIS_PATH}/libmetis ${CMAKE_BINARY_DIR}/libmetis)
 add_subdirectory(include)
 add_subdirectory(libparmetis)
 add_subdirectory(programs)

diff --git a/libparmetis/CMakeLists.txt b/libparmetis/CMakeLists.txt
index 9cfc8a7..dfc0125 100644
--- a/libparmetis/CMakeLists.txt
+++ b/libparmetis/CMakeLists.txt
@@ -5,7 +5,7 @@ file(GLOB parmetis_sources *.c)
 # Create libparmetis
 add_library(parmetis ${ParMETIS_LIBRARY_TYPE} ${parmetis_sources})
 # Link with metis and MPI libraries.
-target_link_libraries(parmetis metis ${MPI_LIBRARIES})
+target_link_libraries(parmetis metis ${MPI_LIBRARIES} "-lm")
 set_target_properties(parmetis PROPERTIES LINK_FLAGS "${MPI_LINK_FLAGS}")

 install(TARGETS parmetis
