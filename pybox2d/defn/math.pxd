from defn.common cimport *

cdef extern from "b2Math.h":
    inline float32 b2Distance(const b2Vec2& a, const b2Vec2& b)

    cdef cppclass b2Vec2:
        b2Vec2()
        b2Vec2(float32 x, float32 y)
        void SetZero()
        void Set(float32 x_, float32 y_)

        b2Vec2 operator -() const
        float32 operator () (int32 i) const
        float32& operator () (int32 i)
        # not yet supported in cython:
        # void operator += (const b2Vec2& v)
        # void operator -= (const b2Vec2& v)
        # void operator *= (float32 a)
        float32 Length() const
        float32 LengthSquared() const
        float32 Normalize()
        bool IsValid() const
        b2Vec2 Skew() const
        float32 x, y


    cdef cppclass b2Vec3:
        b2Vec3()
        b2Vec3(float32 x, float32 y, float32 z)
        void SetZero()
        void Set(float32 x_, float32 y_, float32 z_)
        b2Vec3 operator -() const
        # void operator += (const b2Vec3& v)
        # void operator -= (const b2Vec3& v)
        # void operator *= (float32 s)
        float32 x, y, z

    cdef cppclass b2Mat22:
        b2Mat22()
        b2Mat22(const b2Vec2& c1, const b2Vec2& c2)
        b2Mat22(float32 a11, float32 a12, float32 a21, float32 a22)
        void Set(const b2Vec2& c1, const b2Vec2& c2)
        void SetIdentity()
        void SetZero()
        b2Mat22 GetInverse() const
        b2Vec2 Solve(const b2Vec2& b) const
        b2Vec2 ex, ey;

    cdef cppclass b2Mat33:
        b2Mat33()
        b2Mat33(const b2Vec3& c1, const b2Vec3& c2, const b2Vec3& c3)
        void SetZero()
        b2Vec3 Solve33(const b2Vec3& b) const;
        b2Vec2 Solve22(const b2Vec2& b) const;
        void GetInverse22(b2Mat33* M) const;
        void GetSymInverse33(b2Mat33* M) const;
        b2Vec3 ex, ey, ez;

    cdef cppclass b2Rot:
        b2Rot()
        b2Rot(float32 angle)
        void Set(float32 angle)
        void SetIdentity()
        float32 GetAngle() const
        b2Vec2 GetXAxis() const
        b2Vec2 GetYAxis() const
        float32 s, c;

    cdef cppclass b2Transform:
        b2Transform()
        b2Transform(const b2Vec2& position, const b2Rot& rotation)
        void SetIdentity()
        void Set(const b2Vec2& position, float32 angle)
        b2Vec2 p;
        b2Rot q;

    cdef cppclass b2Sweep:
        void GetTransform(b2Transform* xfb, float32 beta) const;
        void Advance(float32 alpha);
        void Normalize();

        b2Vec2 localCenter;
        b2Vec2 c0, c;
        float32 a0, a;
        float32 alpha0;

    inline b2Vec2 b2Mul(const b2Transform& T, const b2Vec2& v)
