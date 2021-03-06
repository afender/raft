#
# Copyright (c) 2020, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# cython: profile=False
# distutils: language = c++
# cython: embedsignature = True
# cython: language_level = 3

# import raft
from libcpp.memory cimport shared_ptr

from .cuda cimport _Stream, _Error, cudaStreamSynchronize
from .cuda import CudaRuntimeError

cdef class Handle:
    """
    Handle is a lightweight python wrapper around the corresponding C++ class
    of handle_t exposed by RAFT's C++ interface. Refer to the header file
    raft/handle.hpp for interface level details of this struct

    Examples
    --------

    .. code-block:: python

        from raft.common import Stream, Handle
        stream = Stream()
        handle = Handle()
        handle.setStream(stream)

        # call algos here

        # final sync of all work launched in the stream of this handle
        # this is same as `raft.cuda.Stream.sync()` call, but safer in case
        # the default stream inside the `handle_t` is being used
        handle.sync()
        del handle  # optional!
    """

    # handle_t doesn't have copy operator. So, use pointer for the object
    # python world cannot access to this raw object directly, hence use
    # 'size_t'!
    cdef size_t h

    # not using __dict__ unless we need it to keep this Extension as lean as
    # possible
    cdef int n_streams

    def __cinit__(self, n_streams=0):
        self.n_streams = n_streams
        self.h = <size_t>(new handle_t(n_streams))

    def __dealloc__(self):
        h_ = <handle_t*>self.h
        del h_

    def setStream(self, stream):
        cdef size_t s = <size_t>stream.getStream()
        cdef handle_t* h_ = <handle_t*>self.h
        h_.set_stream(<_Stream>s)

    def sync(self):
        """
        Issues a sync on the stream set for this handle.

        Once we make `raft.common.cuda.Stream` as a mandatory option
        for creating `raft.common.Handle`, this should go away
        """
        cdef handle_t* h_ = <handle_t*>self.h
        cdef _Stream stream = h_.get_stream()
        cdef _Error e = cudaStreamSynchronize(stream)
        if e != 0:
            raise CudaRuntimeError("Stream sync")

    def getHandle(self):
        return self.h

    def getNumInternalStreams(self):
        cdef handle_t* h_ = <handle_t*>self.h
        return h_.get_num_internal_streams()

    def __getstate__(self):
        return self.n_streams

    def __setstate__(self, state):
        self.n_streams = state
        self.h = <size_t>(new handle_t(self.n_streams))
