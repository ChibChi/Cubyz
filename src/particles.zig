const std = @import("std");

const main = @import("main");
const game = @import("game.zig");
const World = game.World;

const vec = @import("vec.zig");
const Vec3f = vec.Vec3f;
const Vec3d = vec.Vec3d;
const Vec4i = vec.Vec4i;
const Mat4f = vec.Mat4f;

const graphics = @import("graphics.zig");
const c = graphics.c;
const Shader = graphics.Shader;
const SSBO = graphics.SSBO;
const Color = graphics.Color;

var arena = main.heap.NeverFailingArenaAllocator.init(main.globalAllocator);
const allocator = arena.allocator();

pub var particleManager: ParticleManager = undefined; 

pub fn init() void { // MARK: init()
    particleManager = .init();
}

pub const Particle = struct { // MARK: Particle
    const Self = @This();

    // color: Color,
    relativePos: Vec3d,
    // vel: Vec3d,
    // scale: f32,

    currentLife: f32 = 0,
    lifetime: f32,

    active: bool,

    pub fn init() Self {
        return Self{
            .relativePos = Vec3d{0, 0, 0},
            .curretLife = 0,
            .lifetime = 0,
            .active = false,
        };
    }

    pub fn reset(self: *Self, _: Vec3d, lifetime: f32) void {
        self.relativePos = .{0, 0, 0};
        // self.vel = vel;
        self.currentLife = 0;
        self.lifetime = lifetime;
        self.active = true;
    }

    pub fn update(self: *Self, deltaTime: f64) void {
        if (!self.active) {
            return;
        }

        // self.relativePos += self.vel * @as(Vec3d, @splat(deltaTime));
        self.currentLife += deltaTime;
        if (self.currentLife >= self.lifetime) {
            self.active = false;
        }
    }
};

pub const ParticleEmitter = struct { // MARK: ParticleEmitter
    const Self = @This();

    pos: Vec3d = .{0, 0, 8},
    currentInterval: f64 = 0,
    interval: f64,

    particlePool: [128]Particle = undefined,
    nextId: usize = 0,

    pub fn init(self: *Self, interval: f64) void {
        self.interval = interval;
        self.particlePool = allocator.alloc(Particle, 128);

        for (self.particlePool) |*particle| {
            particle.* = .init();
        }
    }

    fn createParticle(self: *Self, lifetime: f32) void {
        const id = self.nextId;
        self.nextId = (id + 1) % self.particlePool.len;

        self.particlePool[id].reset(Vec3d{ 0, 0, 0 }, lifetime);
    }

    pub fn update(self: *Self, deltaTime: f64) void {
        self.currentInterval += deltaTime;
        if (self.currentInterval >= self.interval) {
            self.currentInterval = 0;
            self.createParticle(2000);
        }

        for (self.particlePool) |*particle| {
            if (!particle.active) {
                continue;
            }
            particle.update(deltaTime);
        }
    }
};

pub const ParticleManager = struct { // MARK: ParticleManager
    const Self = @This();

    var particleEmitterPool: [1]ParticleEmitter = undefined;

    pub fn init() void {
        particleEmitterPool = allocator.alloc(ParticleEmitter, 1);

        for (particleEmitterPool) |*pool| {
            pool.* = .init(5000);
        }
    }

    pub fn update(deltaTime: f64) void {
        for (particleEmitterPool) |emitterPool| {
            emitterPool.update(deltaTime);
        }
    }
};

pub const ParticleRenderer = struct { // MARK: ParticleRenderer
    var shader: Shader = undefined;
    var uniforms: struct {
        projectionMatrix: c_int,
        viewMatrix: c_int,
		modelMatrix: c_int,
        position: c_int
        // ambientLight: c_int,
        // modelPosition: c_int,
    } = undefined;


    pub fn init() void {
        shader = Shader.initAndGetUniforms("assets/cubyz/shaders/particle.vs", "assets/cubyz/shaders/particle.fs", "", &uniforms);
        const rawData = [_]f32{
            -0.5, 0.0, -0.5, 0, 0,
            0.5, 0.0, -0.5, 1, 0,
            0.5, 0.0, 0.5, 1, 1,
            -0.5, 0.0, 0.5, 0, 1,
        };

        const indices = [_]c_int{
            0, 1, 2,
            2, 3, 0,
        };

        c.glBindVertexArray(main.renderer.chunk_meshing.vao);
        c.glGenVertexArrays(1, &vao);
		c.glBindVertexArray(vao);
    }

    pub fn deinit() void {
        shader.deinit();
    }

    fn bindCommonUniforms(projMatrix: Mat4f, viewMatrix: Mat4f, position: Vec3f) void {
		shader.bind();
		c.glUniformMatrix4fv(uniforms.projectionMatrix, 1, c.GL_TRUE, @ptrCast(&projMatrix));
		c.glUniformMatrix4fv(uniforms.viewMatrix, 1, c.GL_TRUE, @ptrCast(&viewMatrix));
        c.glUniform3fv(uniforms.position, 1, @ptrCast(&position));
	}

    fn drawParticle(vertices: u31, modelMatrix: Mat4f) void {
		c.glUniformMatrix4fv(uniforms.modelMatrix, 1, c.GL_TRUE, @ptrCast(&modelMatrix));
		c.glDrawElements(c.GL_TRIANGLES, vertices, c.GL_UNSIGNED_INT, null);
	}

    pub fn renderParticles(projMatrix: Mat4f, _: Vec3f, playerPos: Vec3d) void {
        _ = playerPos;
        bindCommonUniforms(projMatrix, game.camera.viewMatrix);
        
        for (particleManager.particleEmitterPool) |particleEmitter| {
            const emitterPos = particleEmitter.pos;

            for (particleEmitter.particlePool) |particle| {
                if (!particle.active){
                    continue;
                }
                const pos = emitterPos + particle.relativePos;
                const modelMatrix = Mat4f.translation(@floatCast(pos));
				// modelMatrix = modelMatrix.mul(Mat4f.rotationX(-rot[0]));
				// modelMatrix = modelMatrix.mul(Mat4f.rotationY(-rot[1]));
				// modelMatrix = modelMatrix.mul(Mat4f.rotationZ(-rot[2]));
				// modelMatrix = modelMatrix.mul(Mat4f.scale(@splat(scale)));
				// modelMatrix = modelMatrix.mul(Mat4f.translation(@splat(-0.5)));
                drawParticle(6, modelMatrix);
            }
            
        }
    }
};
