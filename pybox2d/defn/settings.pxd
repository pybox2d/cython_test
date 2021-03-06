from defn.common cimport *

# TODO some structures are defined using these values. They need to match
# up with what the b2Settings.h definitions say:
# TODO this is defined in collision.pxd as cimport on DEF does not work?
# DEF b2_maxManifoldPoints = 2
# TODO this is defined in shape.pxd as cimport on DEF does not work?
# DEF b2_maxPolygonVertices = 8


cdef extern from "b2Settings.h":
    const float32 b2_maxFloat
    const float32 b2_epsilon
    const float32 b2_pi

    const float b2_aabbExtension
    const float b2_aabbMultiplier
    const float b2_linearSlop
    const float b2_angularSlop
    const float b2_polygonRadius
    const int b2_maxSubSteps
    const int b2_maxTOIContacts
    const float b2_velocityThreshold
    const float b2_maxLinearCorrection
    const float b2_maxAngularCorrection
    const float b2_maxTranslation
    const float b2_maxTranslationSquared
    const float b2_maxRotation
    const float b2_maxRotationSquared
    const float b2_baumgarte
    const float b2_toiBaugarte
    const float b2_timeToSleep
    const float b2_angularSleepTolerance

    cdef struct b2Version:
        int32 major
        int32 minor
        int32 revision

    cdef extern b2Version b2_version;
    void b2Log(const char* string, ...)

