from defn.math cimport *
from defn.shape cimport (b2Shape, b2ShapeType, b2MassData)
from defn.collision cimport (b2RayCastInput, b2RayCastOutput, b2AABB)
from defn.body cimport b2Body


cdef extern from "b2Fixture.h":
    cdef struct b2Filter:
        b2Filter()
        uint16 categoryBits
        uint16 maskBits
        int16 groupIndex

    cdef cppclass b2FixtureDef:
        b2FixtureDef()
        const b2Shape* shape
        void* userData
        float32 friction
        float32 restitution
        float32 density
        bool isSensor
        b2Filter filter

    cdef struct b2FixtureProxy:
        b2AABB aabb
        b2Fixture* fixture
        int32 childIndex
        int32 proxyId

    cdef cppclass b2Fixture:
        b2ShapeType GetType() const
        # b2Shape* GetShape()
        const b2Shape* GetShape() const
        void SetSensor(bool sensor)
        bool IsSensor() const
        void SetFilterData(const b2Filter& filter)
        const b2Filter& GetFilterData() const
        void Refilter()
        # b2Body* GetBody()
        const b2Body* GetBody() const
        # b2Fixture* GetNext()
        const b2Fixture* GetNext() const
        void* GetUserData() const
        void SetUserData(void* data)
        bool TestPoint(const b2Vec2& p) const
        bool RayCast(b2RayCastOutput* output, const b2RayCastInput& input, int32 childIndex) const
        void GetMassData(b2MassData* massData) const
        void SetDensity(float32 density)
        float32 GetDensity() const
        float32 GetFriction() const
        void SetFriction(float32 friction)
        float32 GetRestitution() const
        void SetRestitution(float32 restitution)
        const b2AABB& GetAABB(int32 childIndex) const
        void Dump(int32 bodyIndex)
