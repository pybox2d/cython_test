from defn.world cimport b2World
from defn.joint cimport (b2Joint, b2JointDef, b2RevoluteJointDef)


cdef class WorldStatus(Base):
    '''WorldStatus

    Attributes
    ----------
    tree_height : int
        height of the broadphase dynamic tree
    tree_balance : int
        balance of the broadphase dynamic tree
    tree_quality : float
        quality of the broadphase dynamic tree, where the smaller the value,
        the better (minimum is 1)
    proxy_count : int
        number of broadphase proxies
    body_count : int
        total number of bodies in the world
    joint_count : int
        total number of joints in the world
    contact_count : int
        total number of contacts in the world, with 0 or more contact points
    '''
    cdef public int tree_height
    cdef public int tree_balance
    cdef public float tree_quality
    cdef public int proxy_count
    cdef public int body_count
    cdef public int joint_count
    cdef public int contact_count

    def __init__(self, **kw):
        for attr, value in kw.items():
            setattr(self, attr, value)

    cpdef _get_repr_info(self):
        return [(attr, getattr(self, attr))
                for attr in ('tree_height', 'tree_balance', 'tree_quality',
                             'proxy_count', 'body_count', 'joint_count',
                             'contact_count')
                ]


cdef class World:
    cdef b2World *world
    cdef dict _bodies
    cdef dict _joints
    cdef dict _linked_joints
    cdef object _default_body_class

    cdef dict _contact_classes
    cdef ContactListener *_contact_listener
    cdef object _monitor_mode

    def __cinit__(self):
        self.world = new b2World(b2Vec2(0.0, 0.0))
        self._bodies = {}
        self._joints = {}
        self._linked_joints = {}
        self._contact_classes = {}
        self._contact_listener = NULL
        self._monitor_mode = MonitorModeType('bulk')

    def __dealloc__(self):
        self.disable_contact_monitoring()

        if self._joints:
            for joint in self._joints.values():
                (<Joint>joint).invalidate()

            self._joints.clear()
            self._linked_joints.clear()

        if self._bodies:
            for body in self._bodies.values():
                (<Body>body).invalidate()

            self._bodies.clear()

        del self.world

    def __init__(self, gravity=None, default_body_class=None):
        '''The world class manages all physics entities, dynamic simulation,
        and asynchronous queries.
        '''
        if gravity is None:
            gravity = (0, -10)

        if default_body_class is None:
            default_body_class = Body

        self.default_body_class = default_body_class
        self.gravity = gravity

    property default_body_class:
        '''Default Body class.

        create_body() by default returns a pybox2d.Body instance, but you have
        the option of subclassing this for different body types in your
        simulation.
        '''
        def __get__(self):
            return self._default_body_class

        def __set__(self, cls not None):
            if not issubclass(cls, Body):
                raise TypeError('Class must be a subclass of Body')

            self._default_body_class = cls

    property gravity:
        '''The global gravity vector.'''

        def __get__(self):
            return to_vec2(self.world.GetGravity())

        def __set__(self, value):
            self.world.SetGravity(to_b2vec2(value))

    def _iter_bodies(self):
        '''Iterate over Bodies in the world

        Note: users may attempt to delete or add bodies during iteration, so
        the exposed property returns a full list.
        '''
        cdef b2Body *bptr = self.world.GetBodyList()

        while bptr:
            yield self._bodies[pointer_as_key(bptr)]
            bptr = bptr.GetNext()

    property bodies:
        '''List of all bodies in the world'''
        def __get__(self):
            return list(self._iter_bodies())

    def _iter_joints(self):
        '''Iterate over Joints in the world

        Note: users may attempt to delete or add joints during iteration, so
        the exposed property returns a full list.
        '''
        cdef b2Joint *jptr = self.world.GetJointList()

        while jptr:
            yield self._joints[pointer_as_key(jptr)]
            jptr = jptr.GetNext()

    property joints:
        '''List of all joints in the world'''
        def __get__(self):
            return list(self._iter_joints())

    def step(self, float time_step, int velocity_iterations,
             int position_iterations):
        '''Take a time step.

        This performs collision detection, integration, and constraint
        solution.

        Parameters
        ----------
        time_step : float
            the amount of time to simulate, this should not vary.
        velocity_iterations : float
            Number of iterations for the velocity constraint solver.
        position_iterations :
            Number of iterations for the position constraint solver.
        '''
        if self._contact_listener != NULL and self._monitor_mode == 'bulk':
            for body in self._bodies.values():
                del body.monitor_contacts[:]

        self.world.Step(time_step, velocity_iterations, position_iterations)

    def clear_forces(self):
        '''Manually clear the force buffer on all bodies.

        By default, forces are cleared automatically after each call to Step.
        The default behavior is modified by setting auto_clear_forces.  The
        purpose of this function is to support sub-stepping. Sub-stepping is
        often used to maintain a fixed sized time step under a variable
        frame-rate.  When you perform sub-stepping you will disable auto
        clearing of forces and instead call ClearForces after all sub-steps are
        complete in one pass of your game loop.
        '''
        self.world.ClearForces()

    property auto_clear_forces:
        '''Automatic clearing of forces after each time step.'''
        def __get__(self):
            return self.world.GetAutoClearForces()

        def __set__(self, auto_clear):
            self.world.SetAutoClearForces(auto_clear)

    @property
    def locked(self):
        '''Is the world locked (in the middle of a time step).'''
        return self.world.IsLocked()

    def shift_origin(self, new_origin):
        '''Shift the world origin.

        Useful for large worlds.
        The body shift formula is: position -= new_origin

        Parameters
        ----------
        newOrigin : Vec2
            the new origin with respect to the old origin
        '''
        self.world.ShiftOrigin(to_b2vec2(new_origin))

    property sub_stepping:
        '''Enable/disable single stepped continuous physics. For testing.'''
        def __get__(self):
            return self.world.GetSubStepping()

        def __set__(self, sub_stepping):
            self.world.SetSubStepping(sub_stepping)

    property continuous_physics:
        '''Enable/disable continuous physics. For testing.'''
        def __get__(self):
            return self.world.GetContinuousPhysics()

        def __set__(self, continuous_physics):
            self.world.SetContinuousPhysics(continuous_physics)

    property warm_starting:
        '''Enable/disable warm starting. For testing.'''
        def __get__(self):
            return self.world.GetWarmStarting()

        def __set__(self, warm_starting):
            self.world.SetWarmStarting(warm_starting)

    property allow_sleeping:
        '''Enable/disable sleep.'''
        def __get__(self):
            return self.world.GetAllowSleeping()

        def __set__(self, allow_sleeping):
            self.world.SetAllowSleeping(allow_sleeping)

    def create_body_from_def(self, BodyDef body_defn, *, body_class=None):
        '''Create a body from a BodyDef

        Parameters
        ----------
        body_defn : BodyDef
            The body definition
        body_class : subclass of Body, optional
            The wrapped Body will be of this type.

        Returns
        -------
        body : body_class
        '''
        if body_defn is None:
            raise ValueError('Body definition must be specified')

        if body_class is None:
            body_class = self.default_body_class

        if not issubclass(body_class, Body):
            raise TypeError('body_class must be a subclass of Body')

        bptr = self.world.CreateBody(body_defn.thisptr)
        body = body_class()
        (<Body>body).thisptr = bptr

        self._bodies[pointer_as_key(bptr)] = body

        # userdata is never passed along to the Box2D-level objects, so it
        # exists only in pybox2d
        if body_defn.data is not None:
            body.data = body_defn.data

        if body_defn.fixtures is not None:
            for fixture in body_defn.fixtures:
                if isinstance(fixture, dict):
                    fixture_dict = fixture
                    body.create_fixture(**fixture_dict)
                else:
                    body.create_fixture_from_def(fixture)

        return body

    def create_static_body(self, *, body_class=None, **kwargs):
        '''Create a static body with the given keyword arguments

        Parameters
        ----------
        body_class : subclass of Body, optional
            The wrapped Body will be of this type.
        kwargs : dict
            Keyword arguments for the StaticBodyDef

        Returns
        -------
        body : body_class
        '''
        defn = StaticBodyDef(**kwargs)
        return self.create_body_from_def(defn, body_class=body_class)

    def create_dynamic_body(self, *, body_class=None, **kwargs):
        '''Create a dynamic body with the given keyword arguments

        Parameters
        ----------
        body_class : subclass of Body, optional
            The wrapped Body will be of this type.
        kwargs : dict
            Keyword arguments for the DynamicBodyDef

        Returns
        -------
        body : body_class
        '''
        defn = DynamicBodyDef(**kwargs)
        return self.create_body_from_def(defn, body_class=body_class)

    def create_kinematic_body(self, *, body_class=None, **kwargs):
        '''Create a kinematic body with the given keyword arguments

        Parameters
        ----------
        body_class : subclass of Body, optional
            The wrapped Body will be of this type.
        kwargs : dict
            Keyword arguments for the KinematicBodyDef

        Returns
        -------
        body : body_class
        '''
        defn = KinematicBodyDef(**kwargs)
        return self.create_body_from_def(defn, body_class=body_class)

    def destroy_body(self, Body body not None):
        '''Destroy (remove) a body from the world

        All associated shapes and joints will be deleted.

        Parameters
        ----------
        body : Body
            The body to remove
        '''
        if not body.valid:
            raise RuntimeError('Body no longer valid')

        for joint in list(body._joints):
            self.destroy_joint(joint)

        cdef b2Body *bptr = body.thisptr
        del self._bodies[pointer_as_key(bptr)]

        body.invalidate()
        del body
        self.world.DestroyBody(bptr)

    def destroy_joint(self, Joint joint not None):
        '''Destroy (remove) a joint from the world

        Parameters
        ----------
        joint : Joint
            The joint to remove
        '''
        if not joint.valid:
            raise RuntimeError('Joint no longer valid')

        key = hash(joint)
        if key in self._linked_joints:
            for other_joint in self._linked_joints[key]:
                other_key = hash(other_joint)
                # first clear the other joint's reference to this one
                self._linked_joints[other_key].remove(joint)

                if isinstance(other_joint, CompositeJoint):
                    # if the other joint is a composite linking this one, it
                    # should be deleted first
                    self.destroy_joint(other_joint)

            del self._linked_joints[key]

        del self._joints[key]

        joint.body_a._joints.remove(joint)
        joint.body_b._joints.remove(joint)

        cdef b2Joint *jptr = joint.joint
        joint.invalidate()
        self.world.DestroyJoint(jptr)

    cdef create_joint_from_defn(self, b2JointDef* defn, Body body_a,
                                Body body_b):

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Joint *jptr = self.world.CreateJoint(defn)
        joint = Joint.upcast(jptr)
        (<Joint>joint).body_a = body_a
        body_a._joints.append(joint)

        (<Joint>joint).body_b = body_b
        body_b._joints.append(joint)

        self._joints[pointer_as_key(jptr)] = joint
        return joint

    def create_revolute_joint(self, bodies, *, anchor=None,
                              reference_angle=None, local_anchors=None,
                              collide_connected=False, angle_limit=None,
                              motor=False, motor_speed=0.0,
                              max_motor_torque=0.0):
        '''Create a revolute joint

        A revolute joint requires an anchor point where the bodies are joined.
        This uses local anchor points so that the initial configuration can
        violate the constraint slightly. You also need to specify the initial
        relative angle for joint limits. This helps when saving and loading a
        game.

        The local anchor points are measured from the body's origin rather than
        the center of mass because:

        1. you might not know where the center of mass will be.
        2. if you add/remove shapes from a body and recompute the mass,
           the joints will be broken.

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        anchor : Vec2, optional
            The world anchor point where the bodies will be joined
            If unspecified, reference_angle and local_anchors must be
            specified.
        reference_angle : float, optional
            Reference angle in radians
            If unspecified, reference_angle is automatically calculated to be:

            ``body_b.angle - body_a.angle``

        local_anchors : (anchor_a, anchor_b), Vec2, optional
            Local anchor points relative to (body_a, body_b).
            Required if 'anchor' is unspecified.
        motor : bool, optional
            Enable the joint motor (default: False)
        motor_speed : float, optional
            Desired motor speed [radians/s]
        max_motor_torque : float, optional
            Maximum motor torque used to achieve the desired motor_speed [N-m]
        angle_limit : (lower_angle, upper_angle), float
            Joint angle limits, in radians. If None, limits will be disabled.
        '''
        body_a, body_b = bodies

        cdef b2RevoluteJointDef defn
        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        if local_anchors is not None:
            anchora, anchorb = local_anchors
            defn.bodyA = ba
            defn.bodyB = bb
            defn.localAnchorA = to_b2vec2(anchora)
            defn.localAnchorB = to_b2vec2(anchorb)

            if reference_angle is None:
                reference_angle = body_b.angle - body_a.angle

            defn.referenceAngle = reference_angle
        elif anchor is not None:
            defn.Initialize(ba, bb, to_b2vec2(anchor))
        else:
            raise ValueError('Must specify either local_anchors or anchor')


        enable_limit = (angle_limit is not None)
        if angle_limit is None:
            angle_limit = (0, 0)

        defn.collideConnected = collide_connected
        defn.enableMotor = motor
        defn.motorSpeed = motor_speed
        defn.maxMotorTorque = max_motor_torque
        defn.enableLimit = enable_limit
        defn.lowerAngle = angle_limit[0]
        defn.upperAngle = angle_limit[1]
        return self.create_joint_from_defn(&defn, body_a, body_b)

    def create_distance_joint(self, bodies, *, collide_connected=False,
                              anchors=None, damping_ratio=0.0,
                              frequency_hz=0.0, length=None,
                              local_anchors=None):
        '''Create a distance joint between two bodies

        A distance joint constrains two points on two bodies to remain at a
        fixed distance from each other. You can view this as a massless, rigid
        rod.

        Two options for initialization of the joint:

        1. set local_anchors (and optionally length)
        2. set anchors in world coordinates, length is calculated automatically

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        anchors : (anchor_a, anchor_b), Vec2, optional
            body_a, body_b anchor points in world coordinates. To use, both
            anchor_a and anchor_b must be specified. `length` will be
            calculated automatically.
        local_anchors : (anchor_a, anchor_b), Vec2, optional
            Local anchor points relative to (body_a, body_b).
            Required if 'anchors' is unspecified.
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        damping_ratio : float, optional
            The damping ratio. 0 = no damping, 1 = critical damping.
        frequency_hz : float, optional
            The mass-spring-damper frequency in Hertz. A value of 0 disables
            softness.
        length : float, optional
            The natural length between the anchor points.
        '''
        body_a, body_b = bodies

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2DistanceJointDef defn
        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        defn.bodyA = ba
        defn.bodyB = bb
        if local_anchors is not None:
            local_anchor_a, local_anchor_b = local_anchors
            if local_anchor_a is None:
                raise ValueError('Must specify both local anchors or neither')
            if local_anchor_b is None:
                raise ValueError('Must specify both local anchors or neither')

            # Initialize the bodies, anchors, and length using the local
            # anchors.
            defn.localAnchorA = to_b2vec2(local_anchor_a)
            defn.localAnchorB = to_b2vec2(local_anchor_b)
            if length is None:
                length = b2Distance(ba.GetWorldPoint(defn.localAnchorA),
                                    bb.GetWorldPoint(defn.localAnchorB))
            defn.length = length
        elif anchors is not None:
            # Initialize the bodies, anchors, and length using the world anchors.
            anchor_a, anchor_b = anchors
            defn.Initialize(ba, bb, to_b2vec2(anchor_a), to_b2vec2(anchor_b))
        else:
            raise ValueError('Must specify either local_anchors or anchors')

        defn.collideConnected = collide_connected
        defn.dampingRatio = damping_ratio
        defn.frequencyHz = frequency_hz
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)

    def create_friction_joint(self, bodies, *, collide_connected=False,
                              local_anchors=None, anchor=None,
                              max_force=0.0, max_torque=0.0):
        '''Create a friction joint between two bodies

        Friction joint. This is used for top-down friction. It provides 2D
        translational friction and angular friction.

        Two options for initialization of the joint:

        1. set local_anchors for each body
        2. set a single world anchor point

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        anchor : Vec2, optional
            The world anchor point where the bodies will be joined
            If unspecified, local anchors must be specified.
        local_anchors : (anchor_a, anchor_b), Vec2, optional
            Local anchor points relative to (body_a, body_b).
            Required if 'anchor' is unspecified.
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        max_force : float, optional
            The maximum friction force in N.
        max_torque : float, optional
            The maximum friction torque in N-m.
        '''
        body_a, body_b = bodies

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        cdef b2FrictionJointDef defn
        if anchor is not None:
            # Initialize the bodies, anchors, axis, and reference angle using
            # the world anchor and world axis.
            defn.Initialize(ba, bb, to_b2vec2(anchor))
        elif local_anchors is not None:
            # Initialize the bodies, anchors, axis, and reference angle using
            # local body anchors
            anchora, anchorb = local_anchors

            defn.bodyA = ba
            defn.bodyB = bb
            defn.localAnchorA = to_b2vec2(anchora)
            defn.localAnchorB = to_b2vec2(anchorb)
        else:
            raise ValueError('Must specify either local_anchors or anchor')

        defn.collideConnected = collide_connected
        defn.maxForce = max_force
        defn.maxTorque = max_torque
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)

    def create_gear_joint(self, joints, *, collide_connected=False,
                          ratio=1.0):
        '''Create a gear joint between two revolute/prismatic joints

        A gear joint is used to connect two joints together. Either joint can
        be a revolute or prismatic joint. You specify a gear ratio to bind the
        motions together:

        coordinate1 + ratio * coordinate2 = constant

        The ratio can be negative or positive. If one joint is a revolute joint
        and the other joint is a prismatic joint, then the ratio will have
        units of length or units of 1/length.

        Parameters
        ----------
        joints : (joint_a, joint_b), Joint instances
            The first revolute/prismatic joint attached to the gear joint.
            Requires two existing revolute or prismatic joints (any combination
            will work).
        ratio : float, optional
            The gear ratio.
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        '''
        joint_a, joint_b = joints
        if (not isinstance(joint_a, (RevoluteJoint, PrismaticJoint)) or
                not isinstance(joint_b, (RevoluteJoint, PrismaticJoint))):
            raise TypeError('Joints must either be revolute or prismatic')

        if not joint_a.valid:
            raise RuntimeError('Joint A no longer valid')
        if not joint_b.valid:
            raise RuntimeError('Joint B no longer valid')

        cdef Body body_a = joint_a.body_b
        cdef Body body_b = joint_b.body_b

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2GearJointDef defn
        defn.bodyA = body_a.thisptr
        defn.bodyB = body_b.thisptr
        defn.joint1 = (<Joint>joint_a).joint
        defn.joint2 = (<Joint>joint_b).joint
        defn.ratio = ratio
        defn.collideConnected = collide_connected

        joint = self.create_joint_from_defn((<b2JointDef*>&defn), body_a,
                                            body_b)

        cdef GearJoint gj = <GearJoint>joint
        gj.joint_a = joint_a
        gj.joint_b = joint_b

        # link the joints back to this gear joint, since if either is destroyed
        # this gear joint will have to be destroyed
        self._link_joint(joint_a, gj)
        self._link_joint(gj, joint_a)

        self._link_joint(joint_b, gj)
        self._link_joint(gj, joint_b)
        return joint

    cdef _link_joint(self, Joint joint1, Joint joint2):
        '''Link a b2Joint `jptr` to a Joint, so when one is destructed the
        other can be cleaned up'''
        key = hash(joint1)

        if key not in self._linked_joints:
            self._linked_joints[key] = []

        self._linked_joints[key].append(joint2)

    def create_motor_joint(self, bodies, *, collide_connected=False,
                           angular_offset=None, correction_factor=0.3,
                           linear_offset=None, max_force=1.0, max_torque=1.0):
        '''Create a motor joint between two bodies

        A motor joint is used to control the relative motion between two
        bodies. A typical usage is to control the movement of a dynamic body
        with respect to the ground.

        Two options for initialization:

        1. Specify linear_offset and angular_offset manually
        2. Specify neither, and calculate the current offsets between the
           bodies

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        angular_offset : float, optional
            The bodyB angle minus bodyA angle in radians.
        correction_factor : float, optional
            Position correction factor in the range [0,1].
        linear_offset : Vec2, optional
            Position of bodyB minus the position of bodyA, in bodyA's frame, in
            meters.
        max_force : float, optional
            The maximum motor force in N.
        max_torque : float, optional
            The maximum motor torque in N-m.
        '''
        body_a, body_b = bodies

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        cdef b2MotorJointDef defn
        defn.bodyA = ba
        defn.bodyB = bb
        if angular_offset is not None or linear_offset is not None:
            if angular_offset is None or linear_offset is None:
                raise ValueError('Must specify both offsets or neither one')
            defn.angularOffset = angular_offset
            defn.linearOffset = to_b2vec2(linear_offset)
        else:
            # Initialize the bodies and offsets using the current transforms.
            defn.Initialize(ba, bb)

        defn.collideConnected = collide_connected
        defn.correctionFactor = correction_factor
        defn.maxForce = max_force
        defn.maxTorque = max_torque
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)

    def create_mouse_joint(self, bodies, *, collide_connected=False,
                           damping_ratio=0.7, frequency_hz=5.0, max_force=0.0,
                           target=None):
        '''Create a mouse joint between two bodies

        A mouse joint is used to make a point on a body track a specified
        world point. This a soft constraint with a maximum force. This allows
        the constraint to stretch and without applying huge forces.

        NOTE: this joint is not documented in the manual because it was
        developed to be used in the testbed. If you want to learn how to use
        the mouse joint, look at the testbed.

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        damping_ratio : float, optional
            The damping ratio. 0 = no damping, 1 = critical damping.
        frequency_hz : float, optional
            The response speed.
        max_force : float, optional
            The maximum constraint force that can be exerted to move the
            candidate body. Usually you will express as some multiple of the
            weight (multiplier * mass * gravity).
        target : Vec2, optional
            The initial world target point. This is assumed to coincide with
            the body anchor initially.
        '''
        body_a, body_b = bodies

        if target is None:
            target = (0.0, 0.0)

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        cdef b2MouseJointDef defn
        defn.bodyA = ba
        defn.bodyB = bb
        defn.collideConnected = collide_connected
        defn.dampingRatio = damping_ratio
        defn.frequencyHz = frequency_hz
        defn.maxForce = max_force
        defn.target = to_b2vec2(target)
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)

    def create_prismatic_joint(self, bodies, *, collide_connected=False,
                               local_anchors=None, anchor=None, axis=None,
                               enable_limit=False, enable_motor=False,
                               local_axis_a=None, lower_translation=0.0,
                               max_motor_force=0.0, motor_speed=0.0,
                               reference_angle=0.0, upper_translation=0.0):
        '''Create a prismatic joint between two bodies

        A prismatic joint. This joint provides one degree of freedom:
        translation along an axis fixed in bodyA. Relative rotation is
        prevented. You can use a joint limit to restrict the range of motion
        and a joint motor to drive the motion or to model joint friction.

        Two options for initialization:

        1. Specify (world) anchor and axis
        2. Specify local_anchors, local_axis_a

        If unspecified, reference_angle is automatically calculated to be

        ``body_b.angle - body_a.angle``

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        anchor : Vec2, optional
            The world anchor point where the bodies will be joined
            Requires axis to be specified as well
            If unspecified, local_anchors, local_axis_a, and reference_angle
            must be specified.
        axis : Vec2, optional
            Unit world axis for the joint
            Requires anchor to be specified as well
        local_anchors : (anchor_a, anchor_b), Vec2, optional
            Local anchor points relative to (body_a, body_b).
            Required if 'anchor' is unspecified.
        enable_limit : bool, optional
            Enable/disable the joint limit.
        enable_motor : bool, optional
            Enable/disable the joint motor.
        local_axis_a : Vec2, optional
            The local translation unit axis in bodyA.
            Required if 'anchor' is unspecified.
        lower_translation : float, optional
            The lower translation limit, usually in meters.
        max_motor_force : float, optional
            The maximum motor torque, usually in N-m.
        motor_speed : float, optional
            The desired motor speed in radians per second.
        reference_angle : float, optional
            The constrained angle between the bodies:
            |   bodyB_angle - bodyA_angle
            Required if 'anchor' is unspecified.
        upper_translation : float, optional
            The upper translation limit, usually in meters.
        '''
        body_a, body_b = bodies

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        cdef b2PrismaticJointDef defn
        defn.bodyA = ba
        defn.bodyB = bb
        if anchor is not None or axis is not None:
            if anchor is None or axis is None:
                raise ValueError('Must specify both anchor and axis')

            # Initialize the bodies, anchors, axis, and reference angle using
            # the world anchor and unit world axis.
            defn.Initialize(ba, bb, to_b2vec2(anchor), to_b2vec2(axis))
        elif (local_anchors is not None or local_axis_a is not None):
            if local_axis_a is None:
                local_axis_a = (1.0, 0.0)

            if reference_angle is None:
                reference_angle = body_b.angle - body_a.angle

            if (local_anchors is None or local_axis_a is None):
                raise ValueError('Must specify local_anchors, local_axis_a')

            local_anchor_a, local_anchor_b = local_anchors
            defn.localAnchorA = to_b2vec2(local_anchor_a)
            defn.localAnchorB = to_b2vec2(local_anchor_b)
            defn.localAxisA = to_b2vec2(local_axis_a)
            defn.referenceAngle = reference_angle
        else:
            raise ValueError('Must specify either anchor or local_anchors')

        defn.collideConnected = collide_connected
        defn.enableLimit = enable_limit
        defn.enableMotor = enable_motor
        defn.lowerTranslation = lower_translation
        defn.upperTranslation = upper_translation
        defn.maxMotorForce = max_motor_force
        defn.motorSpeed = motor_speed
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)

    def create_pulley_joint(self, bodies, *, collide_connected=True,
                            ground_anchors=None, local_anchors=None,
                            anchors=None, lengths=None, ratio=1.0):
        '''Create a pulley joint between two bodies

        The pulley joint is connected to two bodies and two fixed ground
        points. The pulley supports a ratio such that:

        length1 + ratio * length2 <= constant

        Yes, the force transmitted is scaled by the ratio.

        Warning: the pulley joint can get a bit squirrelly by itself. They
        often work better when combined with prismatic joints. You should also
        cover the the anchor points with static shapes to prevent one side
        from going to zero length.

        ground_anchors is required.

        Initialization options:

        1. Specify anchors, and ratio
        2. Specify local_anchors, individual lengths, and ratio

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        collide_connected : bool, optional
            Allow collision between connected bodies (default: True)
        ground_anchors : (ground_anchor_a, ground_anchor_b), Vec2
            The ground anchors in world coordinates. These points never move.
        lengths : (length_a, length_b), float, optional
            The reference lengths for the segment attached to the respective
            bodies.
        local_anchors : (local_anchor_a, local_anchor_b), Vec2, optional
            Local anchor points relative to (body_a, body_b).
            Required if 'anchors' is unspecified.
        anchors : (anchor_a, anchor_b), Vec2, optional
            World anchor points for (body_a, body_b).
            Required if 'local_anchors' is unspecified.
        ratio : float, optional
            The pulley ratio, used to simulate a block-and-tackle.
        '''
        body_a, body_b = bodies

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        cdef b2PulleyJointDef defn
        defn.bodyA = ba
        defn.bodyB = bb

        if ground_anchors is None:
            ground_anchor_a = (-1.0, 1.0)
            ground_anchor_b = (1.0, 1.0)
        else:
            ground_anchor_a, ground_anchor_b = ground_anchors

        if ratio <= b2_epsilon:
            raise ValueError('Ratio must be at minimum b2_epsilon ({})'
                             ''.format(b2_epsilon))

        if local_anchors is not None:
            local_anchor_a, local_anchor_b = local_anchors
            length_a, length_b = lengths

            # local_anchor_a = (-1.0, 0.0)
            # local_anchor_b = (1.0, 0.0)
            defn.groundAnchorA = to_b2vec2(ground_anchor_a)
            defn.groundAnchorB = to_b2vec2(ground_anchor_b)
            defn.localAnchorA = to_b2vec2(local_anchor_a)
            defn.localAnchorB = to_b2vec2(local_anchor_b)
            defn.lengthA = length_a
            defn.lengthB = length_b
            defn.ratio = ratio
        elif anchors is not None:
            # Initialize the bodies, anchors, lengths, max lengths, and ratio
            # using the world anchors.
            anchor_a, anchor_b = anchors
            defn.Initialize(ba, bb, to_b2vec2(ground_anchor_a),
                            to_b2vec2(ground_anchor_b), to_b2vec2(anchor_a),
                            to_b2vec2(anchor_b), ratio)
        else:
            raise ValueError('Must specify local_anchors or anchors')

        defn.collideConnected = collide_connected
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)


    def create_rope_joint(self, bodies, *, collide_connected=False,
                          local_anchors=None, max_length=0.0):
        '''Create a rope joint between two bodies

        A rope joint enforces a maximum distance between two points on two
        bodies. It has no other effect. Warning: if you attempt to change the
        maximum length during the simulation you will get some non-physical
        behavior. A model that would allow you to dynamically modify the length
        would have some sponginess, so Erin Catto chose not to implement it
        that way.

        See `world.create_distance_joint` if you want to dynamically control
        length.

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        local_anchors : (local_anchor_a, local_anchor_b), Vec2, optional
            Local anchor points relative to (body_a, body_b).
            Defaults to ((-1, 0), (1, 0))
        max_length : float, optional
            The maximum length of the rope. Warning: this must be larger than
            b2_linearSlop or the joint will have no effect.
        '''
        body_a, body_b = bodies

        if local_anchors is None:
            local_anchor_a = (-1.0, 0.0)
            local_anchor_b = (1.0, 0.0)
        else:
            local_anchor_a, local_anchor_b = local_anchors

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        cdef b2RopeJointDef defn
        defn.bodyA = ba
        defn.bodyB = bb
        defn.collideConnected = collide_connected
        defn.localAnchorA = to_b2vec2(local_anchor_a)
        defn.localAnchorB = to_b2vec2(local_anchor_b)
        defn.maxLength = max_length
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)

    def create_weld_joint(self, bodies, *, collide_connected=False,
                          local_anchors=None, anchor=None, damping_ratio=0.0,
                          frequency_hz=0.0, reference_angle=None):
        '''Create a weld joint between two bodies

        A weld joint essentially glues two bodies together. A weld joint may
        distort somewhat because the island constraint solver is approximate.

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        local_anchors : (local_anchor_a, local_anchor_b), Vec2, optional
            Local anchor points relative to (body_a, body_b).
            Required if 'anchor' is unspecified.
        anchor : Vec2, optional
            The world anchor point where the bodies will be joined
            If unspecified, reference_angle and local_anchors must be
            specified.
        damping_ratio : float, optional
            The damping ratio. 0 = no damping, 1 = critical damping.
        frequency_hz : float, optional
            The mass-spring-damper frequency in Hertz. Rotation only. Disable
            softness with a value of 0.
        reference_angle : float, optional
            The bodyB angle minus bodyA angle in the reference state (radians).
            If unspecified, reference_angle is automatically calculated to be:

            ``body_b.angle - body_a.angle``

        '''
        body_a, body_b = bodies

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        cdef b2WeldJointDef defn
        defn.bodyA = ba
        defn.bodyB = bb

        if local_anchors is not None:
            local_anchor_a, local_anchor_b = local_anchors
            if reference_angle is None:
                reference_angle = body_b.angle - body_a.angle
            defn.localAnchorA = to_b2vec2(local_anchor_a)
            defn.localAnchorB = to_b2vec2(local_anchor_b)
            defn.referenceAngle = reference_angle
        else:
            # Initialize the bodies, anchors, and reference angle using a world
            # anchor point.
            defn.Initialize(ba, bb, to_b2vec2(anchor))

        defn.collideConnected = collide_connected
        defn.dampingRatio = damping_ratio
        defn.frequencyHz = frequency_hz
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)

    def create_wheel_joint(self, bodies, *, collide_connected=False,
                           local_anchors=None, anchor=None, axis=None,
                           local_axis_a=None,
                           damping_ratio=0.7, enable_motor=False,
                           frequency_hz=2.0, max_motor_torque=0.0,
                           motor_speed=0.0):
        '''Create a wheel joint between two bodies

        A wheel joint. This joint provides two degrees of freedom: translation
        along an axis fixed in bodyA and rotation in the plane. In other
        words, it is a point to line constraint with a rotational motor and a
        linear spring/damper. This joint is designed for vehicle suspensions.

        Initialization options:

        1. Set local_anchors and local_axis_a
        2. Set world anchor point and axis

        Parameters
        ----------
        bodies : (body_a, body_b), Body instances
            The bodies to join together
        collide_connected : bool, optional
            Allow collision between connected bodies (default: False)
        local_anchors : (anchor_a, anchor_b), Vec2, optional
            Local anchor points relative to (body_a, body_b).
            Required if 'anchor' is unspecified.
        local_axis_a : Vec2, optional
            The local translation axis in bodyA.
        anchor : Vec2, optional
            The world anchor point where the bodies will be joined.
        axis : Vec2, optional
            The world translation axis
        damping_ratio : float, optional
            Suspension damping ratio, one indicates critical damping
        enable_motor : bool, optional
            Enable/disable the joint motor.
        frequency_hz : float, optional
            Suspension frequency, zero indicates no suspension
        local_anchor_a : Vec2, optional
            The local anchor point relative to bodyA's origin.
        local_anchor_b : Vec2, optional
            The local anchor point relative to bodyB's origin.
        max_motor_torque : float, optional
            The maximum motor torque, usually in N-m.
        motor_speed : float, optional
            The desired motor speed in radians per second.
        '''
        body_a, body_b = bodies

        if not isinstance(body_a, Body) or not isinstance(body_b, Body):
            raise TypeError('Bodies must be a subclass of Body')

        if not body_a.valid:
            raise RuntimeError('Body A no longer valid')
        if not body_b.valid:
            raise RuntimeError('Body B no longer valid')

        cdef b2Body *ba=(<Body>body_a).thisptr
        cdef b2Body *bb=(<Body>body_b).thisptr

        cdef b2WheelJointDef defn
        defn.bodyA = ba
        defn.bodyB = bb
        if local_anchors is not None or local_axis_a is not None:
            if local_anchors is None or local_axis_a is None:
                raise ValueError('Must specify both local_anchors and '
                                 'local_axis_a')

            local_anchor_a, local_anchor_b = local_anchors
            # local_axis_a = (1.0, 0.0)
            defn.localAnchorA = to_b2vec2(local_anchor_a)
            defn.localAnchorB = to_b2vec2(local_anchor_b)
            defn.localAxisA = to_b2vec2(local_axis_a)
        elif anchor is None or axis is None:
            raise ValueError('Must specify both anchor and axis')
        else:
            # Initialize the bodies, anchors, axis, and reference angle using
            # the world anchor and world axis.
            defn.Initialize(ba, bb, to_b2vec2(anchor), to_b2vec2(axis))

        defn.collideConnected = collide_connected
        defn.dampingRatio = damping_ratio
        defn.enableMotor = enable_motor
        defn.frequencyHz = frequency_hz
        defn.maxMotorTorque = max_motor_torque
        defn.motorSpeed = motor_speed
        return self.create_joint_from_defn((<b2JointDef*>&defn), body_a, body_b)

    def raycast_all(self, point1, point2):
        '''Cast a ray from point1 to point2

        Parameters
        ----------
        point1 : Vec2
        point2 : Vec2

        Yields
        ------
        info : RaycastInfo
            All fixtures that lie on the ray between point1 and point2
        '''
        for info, resp in self.raycast_iterable(point1, point2):
            yield info
            resp.continue_without_clipping()

    def raycast_closest(self, point1, point2):
        '''Cast a ray from point1 to point2

        Get the closest fixture to point1 that lies between point1 and point2.

        Parameters
        ----------
        point1 : Vec2
        point2 : Vec2

        Returns
        -------
        info : RaycastInfo(body, fixture, point, normal, fraction)
            The first fixture that lies on the ray between point1 and point2
        '''
        info = None
        for info, resp in self.raycast_iterable(point1, point2):
            # return the current fraction to find the closest point.
            resp.set(info.fraction)

        return info

    def raycast_any(self, point1, point2):
        '''Cast a ray from point1 to point2

        Get the first fixture that lies between point1 and point2.
        This is not necessarily the closest fixture.

        Parameters
        ----------
        point1 : Vec2
        point2 : Vec2

        Returns
        -------
        info : RaycastInfo(body, fixture, point, normal, fraction)
            The first fixture that lies on the ray between point1 and point2
        '''
        info = None
        for info, resp in self.raycast_iterable(point1, point2):
            resp.stop()

        return info

    def raycast_iterable(self, point1, point2):
        '''Cast a ray from point1 to point2

        Get the first fixture that lies between point1 and point2.

        Parameters
        ----------
        point1 : Vec2
        point2 : Vec2

        Yields
        ------
        info : RaycastInfo(body, fixture, point, normal, fraction)
            The first fixture that lies on the ray between point1 and point2
        resp : RaycastResponseWrapper
            Control how the raycast proceeds by interacting with this object.

        '''
        return RaycastIterable(self, point1, point2)

    property monitor_mode:
        '''Monitor mode

        See MonitorModeType
        '''
        def __get__(self):
            return self._monitor_mode

        def __set__(self, mode):
            was_enabled = (self._contact_listener != NULL)
            if was_enabled:
                self.disable_contact_monitoring()

            self._monitor_mode = MonitorModeType(mode).value

            if was_enabled:
                self.enable_contact_monitoring()

    def monitor_contacts(self, body_class_a, body_class_b, *, enable=True):
        '''Monitor contacts between bodies of body_class_a and body_class_b.

        Contacts will be recorded in body_a.contacts and body_b.contacts after
        every world.step() call.

        Benefits of this over monitor_contacts:
        It's fast and will cause the least burden with making numerous Python
        calls per step.

        Possible downsides:
        It's possible that this can miss contacts, as sub-stepping will have a
        contact begin and end in a single call to World.step.  It is not
        possible to control what happens exactly when contacts happen.

        Parameters
        ----------
        body_class_a : subclass of Body
            The body subclass to monitor contacts with...
        body_class_b : subclass of Body
            this body subclass.
        enable : bool, optional
            Enable contact monitoring, if not already enabled (defaults to
            True)
        '''

        if not issubclass(body_class_a, Body):
            raise TypeError('body_class_a must be a subclass of Body')
        if not issubclass(body_class_b, Body):
            raise TypeError('body_class_b must be a subclass of Body')

        self._add_contact_monitor(body_class_a, body_class_b)
        self._add_contact_monitor(body_class_b, body_class_a)

        if enable:
            self.enable_contact_monitoring()

    def _add_contact_monitor(self, cls_a, cls_b):
        try:
            self._contact_classes[cls_a].add(cls_b)
        except KeyError:
            self._contact_classes[cls_a] = set([cls_b])

    def _remove_contact_monitor(self, cls_a, cls_b):
        try:
            others = self._contact_classes[cls_a]
        except KeyError:
            return

        del self._contact_classes[cls_a]

        for other in others:
            self._contact_classes[other].remove(cls_a)
            if not self._contact_classes[other]:
                del self._contact_classes[other]

    def enable_contact_monitoring(self):
        '''Enable contact monitoring

        See monitor_contacts and monitor_bulk_contacts for more information.
        '''
        if self._contact_listener:
            return

        if self._monitor_mode == MonitorModeType.bulk:
            self._contact_listener = new BulkContactListener(self)
        elif self._monitor_mode == MonitorModeType.callbacks:
            self._contact_listener = new OnlyContactListener(self)
        else:
            self._contact_listener = new FullContactListener(self)

    def disable_contact_monitoring(self):
        '''Temporarily stop monitoring all contacts

        See monitor_contacts and monitor_bulk_contacts for more information.
        '''
        if self._contact_listener:
            del self._contact_listener
            self._contact_listener = NULL

    def clear_contact_monitoring(self, body_class_a=None,
                                 body_class_b=None, *, allow_disable=True):
        '''Stop monitoring contacts

        If body_class_a and body_class_b are unspecified, all contact
        monitoring will be cleared.

        See monitor_contacts and monitor_bulk_contacts for more information.

        Parameters
        ----------
        body_class_a : subclass of Body, optional
            The body subclass to monitor contacts with...
        body_class_b : subclass of Body, optional
            this body subclass.
        allow_disable : bool, optional
            Allow disabling of contact monitoring if none are left
        '''
        if body_class_a is not None and body_class_b is not None:
            self._remove_contact_monitor(body_class_a, body_class_b)
        elif body_class_a is not None:
            if body_class_a not in self._contact_classes:
                return

            for other_class in list(self._contact_classes[body_class_a]):
                self._remove_contact_monitor(body_class_a, other_class)
        else:
            self._contact_classes.clear()

        if allow_disable and not self._contact_classes:
            self.disable_contact_monitoring()

    cdef _filter_contact(self, b2Contact *contact):
        cdef const b2Body *bptr_a = contact.GetFixtureA().GetBody()

        # TODO this dict access is done twice, the other time in
        #      ContactInfo._setup
        body_a = self._bodies[pointer_as_key(<void*>bptr_a)]

        # TODO some level of intelligent caching, this is really bad
        cls_a = body_a.__class__
        other_classes = None
        try:
            other_classes = self._contact_classes[cls_a]
        except KeyError:
            for cls in self._contact_classes.keys():
                if issubclass(cls_a, cls):
                    other_classes = self._contact_classes[cls_a]
                    break

        if other_classes is None:
            return False

        cdef const b2Body *bptr_b = contact.GetFixtureB().GetBody()
        body_b = self._bodies[pointer_as_key(<void*>bptr_b)]
        cls_b = body_b.__class__

        if cls_b in self._contact_classes:
            return True
        else:
            for cls in self._contact_classes.keys():
                if issubclass(cls_b, cls):
                    return True

        return False

    cdef _begin_bulk_contact(self, b2Contact *contact):
        cdef ContactBeginInfo c = ContactBeginInfo()
        if self._filter_contact(contact):
            c._setup(self, contact)
            body_a, body_b = c.bodies
            body_a.monitor_contacts.append(c)
            body_b.monitor_contacts.append(c)

    cdef _end_bulk_contact(self, b2Contact *contact):
        cdef ContactEndInfo c = ContactEndInfo()
        if self._filter_contact(contact):
            c._setup(self, contact)
            body_a, body_b = c.bodies
            body_a.monitor_contacts.append(c)
            body_b.monitor_contacts.append(c)

    cdef _begin_contact_callback(self, b2Contact *contact):
        cdef ContactBeginInfo c = ContactBeginInfo()
        if self._filter_contact(contact):
            c._setup(self, contact)
            body_a, body_b = c.bodies
            body_a.contact_begin(c)
            body_b.contact_begin(c)

    cdef _end_contact_callback(self, b2Contact *contact):
        cdef ContactEndInfo c = ContactEndInfo()
        if self._filter_contact(contact):
            c._setup(self, contact)
            body_a, body_b = c.bodies
            body_a.contact_end(c)
            body_b.contact_end(c)

    cdef _pre_solve(self, b2Contact *contact, const b2Manifold *b2manifold):
        cdef ContactPreSolveInfo c = ContactPreSolveInfo()
        if self._filter_contact(contact):
            c._setup(self, contact, True)
            body_a, body_b = c.bodies

            old_manifold = Manifold.from_b2Manifold(b2manifold)
            body_a.contact_pre_solve(c, old_manifold)
            body_b.contact_pre_solve(c, old_manifold)

            c.contact = NULL

    cdef _post_solve(self, b2Contact *contact,
                     const b2ContactImpulse *b2impulse):
        cdef ContactPostSolveInfo c = ContactPostSolveInfo()
        if self._filter_contact(contact):
            c._setup(self, contact, True)
            body_a, body_b = c.bodies
            impulse = ContactImpulse.from_b2ContactImpulse(b2impulse)
            body_a.contact_post_solve(c, impulse)
            body_b.contact_post_solve(c, impulse)

            c.contact = NULL

    @property
    def status(self):
        '''Status of low-level things in the world

        Returns
        -------
        status_tuple : WorldStatus
            see WorldStatus for more information
        '''
        cdef const b2ContactManager *cm = &self.world.GetContactManager()
        cdef const b2BroadPhase *bp = &cm.m_broadPhase
        return WorldStatus(tree_height=bp.GetTreeHeight(),
                           tree_balance=bp.GetTreeBalance(),
                           tree_quality=bp.GetTreeQuality(),
                           proxy_count=self.world.GetProxyCount(),
                           body_count=self.world.GetBodyCount(),
                           joint_count=self.world.GetJointCount(),
                           contact_count=self.world.GetContactCount(),
                           )
