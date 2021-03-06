from defn.math cimport *
from defn.fixture cimport b2Fixture, b2FixtureDef
from defn.shape cimport (b2Shape, b2ShapeType, b2MassData)
from defn.world cimport b2World


cdef extern from "b2Body.h":
    cdef enum b2BodyType:
        b2_staticBody = 0
        b2_kinematicBody
        b2_dynamicBody

    cdef cppclass b2BodyDef:
        b2BodyDef()
        b2BodyType type
        b2Vec2 position
        float32 angle
        b2Vec2 linearVelocity
        float32 angularVelocity
        float32 linearDamping
        float32 angularDamping
        bool allowSleep
        bool awake
        bool fixedRotation
        bool bullet
        bool active
        void* userData
        float32 gravityScale

    cdef cppclass b2Body:
        b2Fixture* CreateFixture(const b2FixtureDef* defn)
        b2Fixture* CreateFixture(const b2Shape* shape, float32 density)
        void DestroyFixture(b2Fixture* fixture)
        void SetTransform(const b2Vec2& position, float32 angle)
        const b2Transform& GetTransform() const
        const b2Vec2& GetPosition() const
        float32 GetAngle() const
        const b2Vec2& GetWorldCenter() const
        const b2Vec2& GetLocalCenter() const
        void SetLinearVelocity(const b2Vec2& v)
        const b2Vec2& GetLinearVelocity() const
        void SetAngularVelocity(float32 omega)
        float32 GetAngularVelocity() const
        void ApplyForce(const b2Vec2& force, const b2Vec2& point, bool wake)
        void ApplyForceToCenter(const b2Vec2& force, bool wake)
        void ApplyTorque(float32 torque, bool wake)
        void ApplyLinearImpulse(const b2Vec2& impulse, const b2Vec2& point, bool wake)
        void ApplyAngularImpulse(float32 impulse, bool wake)
        float32 GetMass() const
        float32 GetInertia() const
        void GetMassData(b2MassData* data) const
        void SetMassData(const b2MassData* data)
        void ResetMassData()
        b2Vec2 GetWorldPoint(const b2Vec2& localPoint) const
        b2Vec2 GetWorldVector(const b2Vec2& localVector) const
        b2Vec2 GetLocalPoint(const b2Vec2& worldPoint) const
        b2Vec2 GetLocalVector(const b2Vec2& worldVector) const
        b2Vec2 GetLinearVelocityFromWorldPoint(const b2Vec2& worldPoint) const
        b2Vec2 GetLinearVelocityFromLocalPoint(const b2Vec2& localPoint) const
        float32 GetLinearDamping() const
        void SetLinearDamping(float32 linearDamping)
        float32 GetAngularDamping() const
        void SetAngularDamping(float32 angularDamping)
        float32 GetGravityScale() const
        void SetGravityScale(float32 scale)
        void SetType(b2BodyType type)
        b2BodyType GetType() const
        void SetBullet(bool flag)
        bool IsBullet() const
        void SetSleepingAllowed(bool flag)
        bool IsSleepingAllowed() const
        void SetAwake(bool flag)
        bool IsAwake() const
        void SetActive(bool flag)
        bool IsActive() const
        void SetFixedRotation(bool flag)
        bool IsFixedRotation() const
        # b2Fixture* GetFixtureList()
        const b2Fixture* GetFixtureList() const
        # b2JointEdge* GetJointList()
        # const b2JointEdge* GetJointList() const
        # b2ContactEdge* GetContactList()
        # const b2ContactEdge* GetContactList() const
        # b2Body* GetNext()
        const b2Body* GetNext() const
        void* GetUserData() const
        void SetUserData(void* data)
        # b2World* GetWorld()
        # const b2World* GetWorld() const
        void Dump()
