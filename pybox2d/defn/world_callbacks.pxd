from defn.fixture cimport b2Fixture

cdef extern from "b2WorldCallbacks.h":
    cdef cppclass b2DestructionListener:
        # virtual ~b2DestructionListener()
        # void SayGoodbye(b2Joint* joint)
        void SayGoodbye(b2Fixture* fixture)
