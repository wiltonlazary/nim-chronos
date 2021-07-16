#
#                   Chronos SendFile
#              (c) Copyright 2018-Present
#         Status Research & Development GmbH
#
#              Licensed under either of
#  Apache License, version 2.0, (LICENSE-APACHEv2)
#              MIT license (LICENSE-MIT)

## This module provides cross-platform wrapper for ``sendfile()`` syscall.

{.push raises: [Defect].}

when defined(nimdoc):
  proc sendfile*(outfd, infd: int, offset: int, count: var int): int =
    ## Copies data between file descriptor ``infd`` and ``outfd``. Because this
    ## copying is done within the kernel, ``sendfile()`` is more efficient than
    ## the combination of ``read(2)`` and ``write(2)``, which would require
    ## transferring data to and from user space.
    ##
    ## ``infd`` should be a file descriptor opened for reading and
    ## ``outfd`` should be a descriptor opened for writing.
    ##
    ## The ``infd`` argument must correspond to a file which supports
    ## ``mmap(2)``-like operations (i.e., it cannot be a socket).
    ##
    ## ``offset`` the file offset from which ``sendfile()`` will start reading
    ## data from ``infd``.
    ##
    ## ``count`` is the number of bytes to copy between the file descriptors.
    ## On exit ``count`` will hold number of bytes actually transferred between
    ## file descriptors.
    ##
    ## If the transfer was successful, the number of bytes written to ``outfd``
    ## is stored in ``count``, and ``0`` returned. Note that a successful call
    ## to ``sendfile()`` may write fewer bytes than requested; the caller should
    ## be prepared to retry the call if there were unsent bytes.
    ##
    ## On error, ``-1`` is returned.

when defined(linux) or defined(android):

  proc osSendFile*(outfd, infd: cint, offset: ptr int, count: int): int
      {.importc: "sendfile", header: "<sys/sendfile.h>".}

  proc sendfile*(outfd, infd: int, offset: int, count: var int): int =
    var o = offset
    result = osSendFile(cint(outfd), cint(infd), addr o, count)
    if result >= 0:
      count = result
      result = 0

elif defined(freebsd) or defined(openbsd) or defined(netbsd) or
     defined(dragonflybsd):
  import posix, os
  type
    SendfileHeader* {.importc: "sf_hdtr",
                      header: """#include <sys/types.h>
                                 #include <sys/socket.h>
                                 #include <sys/uio.h>""",
                      pure, final.} = object

  proc osSendFile*(outfd, infd: cint, offset: uint, size: uint,
                   hdtr: ptr SendfileHeader, sbytes: ptr uint,
                   flags: int): int {.importc: "sendfile",
                                      header: """#include <sys/types.h>
                                                 #include <sys/socket.h>
                                                 #include <sys/uio.h>""".}

  proc sendfile*(outfd, infd: int, offset: int, count: var int): int =
    var o = 0'u
    result = osSendFile(cint(infd), cint(outfd), uint(offset), uint(count), nil,
                        addr o, 0)
    if result >= 0:
      count = int(o)
      result = 0
    else:
      let err = osLastError()
      if int(err) == EAGAIN:
        count = int(o)
        result = 0
      else:
        result = -1

elif defined(macosx):
  import posix, os
  type
    SendfileHeader* {.importc: "struct sf_hdtr",
                      header: """#include <sys/types.h>
                                 #include <sys/socket.h>
                                 #include <sys/uio.h>""",
                      pure, final.} = object

  proc osSendFile*(fd, s: cint, offset: int, size: ptr int,
                   hdtr: ptr SendfileHeader,
                   flags: int): int {.importc: "sendfile",
                                      header: """#include <sys/types.h>
                                                 #include <sys/socket.h>
                                                 #include <sys/uio.h>""".}

  proc sendfile*(outfd, infd: int, offset: int, count: var int): int =
    var o = count
    result = osSendFile(cint(infd), cint(outfd), offset, addr o, nil, 0)
    if result >= 0:
      count = int(o)
      result = 0
    else:
      let err = osLastError()
      if int(err) == EAGAIN:
        count = int(o)
        result = 0
      else:
        result = -1
