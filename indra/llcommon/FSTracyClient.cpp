//
//          Tracy profiler
//         ----------------
//
// For fast integration, compile and
// link with this source file (and none
// other) in your executable (or in the
// main DLL / shared object on multi-DLL
// projects).
//

// Define TRACY_ENABLE to enable profiler.
// #define __CYGWIN__
#include "common/TracySystem.cpp"

#ifdef TRACY_ENABLE
// <FS:Beq> are we actively profiling?
// At some point this should move to fsprofiler.cpp to correspond with the headerfile
#ifdef TRACY_ENABLE
namespace FSProfiler
{
	bool	active{false};
}
#endif
// </FS:Beq>

#ifdef _MSC_VER
#  pragma warning(push, 0)
#endif

#include "common/tracy_lz4.cpp"
#include "client/TracyProfiler.cpp"
#include "client/TracyCallstack.cpp"
#include "client/TracySysTime.cpp"
#ifndef __CYGWIN__
#define __CYGWIN__
#include "client/TracySysTrace.cpp"
#undef __CYGWIN__
#else
#include "client/TracySysTrace.cpp"
#endif
#include "common/TracySocket.cpp"
#include "client/tracy_rpmalloc.cpp"
#include "client/TracyDxt1.cpp"

#if TRACY_HAS_CALLSTACK == 2 || TRACY_HAS_CALLSTACK == 3 || TRACY_HAS_CALLSTACK == 4 || TRACY_HAS_CALLSTACK == 6
#  include "libbacktrace/alloc.cpp"
#  include "libbacktrace/dwarf.cpp"
#  include "libbacktrace/fileline.cpp"
#  include "libbacktrace/mmapio.cpp"
#  include "libbacktrace/posix.cpp"
#  include "libbacktrace/sort.cpp"
#  include "libbacktrace/state.cpp"
#  if TRACY_HAS_CALLSTACK == 4
#    include "libbacktrace/macho.cpp"
#  else
#    include "libbacktrace/elf.cpp"
#  endif
#endif

#ifdef _MSC_VER
#  pragma comment(lib, "ws2_32.lib")
#  pragma comment(lib, "dbghelp.lib")
#  pragma warning(pop)
#endif

#endif