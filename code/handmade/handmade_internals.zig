const std = @import("std");

const CONTROLLERS = @import("handmade_platform").CONTROLLERS;
const memory_index = @import("handmade_platform").memory_index;
const sim_entity = @import("handmade_sim_region.zig").sim_entity;
const sim_entity_collision_volume_group = @import("handmade_sim_region.zig").sim_entity_collision_volume_group;
const world_position = @import("handmade_world.zig").world_position;
const world = @import("handmade_world.zig").world;
const v2 = @import("handmade_math.zig").v2;

// game data types ------------------------------------------------------------------------------------------------------------------------

pub const memory_arena = struct {
    size: memory_index,
    base_addr: memory_index,
    used: memory_index,
    tempCount: u32,

    pub inline fn Initialize(self: *memory_arena, size: memory_index, base: [*]u8) void {
        self.size = size;
        self.base_addr = @ptrToInt(base);
        self.used = 0;
        self.tempCount = 0;
    }

    pub inline fn PushSize(self: *memory_arena, comptime alignment: u5, size: memory_index) [*]align(alignment) u8 {
        const adjusted_addr = std.mem.alignForward(self.base_addr + self.used, alignment);
        const padding = adjusted_addr - (self.base_addr + self.used);

        std.debug.assert((self.used + size + padding) <= self.size);
        const result = @intToPtr([*]align(alignment) u8, adjusted_addr);
        self.used += size + padding;

        return result;
    }

    pub inline fn PushStruct(self: *memory_arena, comptime T: type) *T {
        return @ptrCast(*T, self.PushSize(@alignOf(T), @sizeOf(T)));
    }

    pub inline fn PushSlice(self: *memory_arena, comptime T: type, comptime count: memory_index) *[count]T {
        return @ptrCast(*[count]T, self.PushSize(@alignOf(T), count * @sizeOf(*[]T)));
    }

    pub inline fn PushArray(self: *memory_arena, comptime T: type, count: memory_index) [*]T {
        return @ptrCast([*]T, self.PushSize(@alignOf(T), count * @sizeOf(T)));
    }

    pub inline fn CheckArena(self: *memory_arena) void {
        std.debug.assert(self.tempCount == 0);
    }
};

pub const temporary_memory = struct {
    arena: *memory_arena,
    used: memory_index,
};

pub const loaded_bitmap = struct {
    width: i32 = 0,
    height: i32 = 0,
    pitch: i32 = 0,
    memory: [*]u8 = undefined,
};

pub const hero_bitmaps = struct {
    alignment: v2,
    head: loaded_bitmap,
    cape: loaded_bitmap,
    torso: loaded_bitmap,
};

pub const low_entity = struct {
    p: world_position,
    sim: sim_entity,
};

pub const controlled_hero = struct {
    entityIndex: u32 = 0,

    ddP: v2 = v2{ 0, 0 },
    dSword: v2 = v2{ 0, 0 },
    dZ: f32 = 0,
};

pub const pairwise_collision_rule = struct {
    canCollide: bool,
    storageIndexA: u32,
    storageIndexB: u32,

    nextInHash: ?*pairwise_collision_rule,
};

pub const ground_buffer = struct {
    p: world_position,
    bitmap: loaded_bitmap,
};

pub const state = struct {
    worldArena: memory_arena,
    world: *world,

    typicalFloorHeight: f32,

    cameraFollowingEntityIndex: u32,
    cameraP: world_position = .{},

    controlledHeroes: [CONTROLLERS]controlled_hero,

    lowEntityCount: u32,
    lowEntities: [100000]low_entity,

    backdrop: loaded_bitmap,
    shadow: loaded_bitmap,
    heroBitmaps: [4]hero_bitmaps,

    grass: [2]loaded_bitmap,
    stones: [4]loaded_bitmap,
    tufts: [3]loaded_bitmap,

    tree: loaded_bitmap,
    sword: loaded_bitmap,
    stairwell: loaded_bitmap,
    metersToPixels: f32,
    pixelsToMeters: f32,

    collisionRuleHash: [256]?*pairwise_collision_rule,
    firstFreeCollisionRule: ?*pairwise_collision_rule,

    nullCollision: *sim_entity_collision_volume_group,
    swordCollision: *sim_entity_collision_volume_group,
    stairCollision: *sim_entity_collision_volume_group,
    playerCollision: *sim_entity_collision_volume_group,
    monstarCollision: *sim_entity_collision_volume_group,
    familiarCollision: *sim_entity_collision_volume_group,
    wallCollision: *sim_entity_collision_volume_group,
    standardRoomCollision: *sim_entity_collision_volume_group,

    time: f32,
};

pub const transient_state = struct {
    initialized: bool,
    tranArena: memory_arena,
    groundBufferCount: u32,
    groundBuffers: [*]ground_buffer,
};

// inline pub functions -------------------------------------------------------------------------------------------------------------------

pub inline fn ZeroSize(size: memory_index, ptr: [*]u8) void {
    var byte = ptr;
    var s = size;
    while (s > 0) : (s -= 1) {
        byte.* = 0;
        byte += 1;
    }
}

pub inline fn BeginTemporaryMemory(arena: *memory_arena) temporary_memory {
    var result = temporary_memory{
        .arena = arena,
        .used = arena.used,
    };

    result.arena.tempCount += 1;

    return result;
}

pub inline fn EndTemporaryMemory(tempMem: temporary_memory) void {
    var arena = tempMem.arena;
    std.debug.assert(arena.used >= tempMem.used);
    arena.used = tempMem.used;
    std.debug.assert(tempMem.arena.tempCount > 0);
    arena.tempCount -= 1;
}

// NOTE (Manav): works for slices too.
pub inline fn ZeroStruct(comptime T: type, ptr: *T) void {
    ZeroSize(@sizeOf(T), @ptrCast([*]u8, ptr));
}

pub inline fn GetLowEntity(gameState: *state, index: u32) ?*low_entity {
    var result: ?*low_entity = null;

    if ((index > 0) and (index < gameState.lowEntityCount)) {
        result = &gameState.lowEntities[index];
    }

    return result;
}

// public functions -----------------------------------------------------------------------------------------------------------------------

pub fn ClearCollisionRulesFor(gameState: *state, storageIndex: u32) void {
    var hashBucket = @as(u32, 0);
    while (hashBucket < gameState.collisionRuleHash.len) : (hashBucket += 1) {
        var collisionRule = &gameState.collisionRuleHash[hashBucket];
        while (collisionRule.*) |rule| {
            if ((rule.storageIndexA == storageIndex) or
                (rule.storageIndexB == storageIndex))
            {
                const removedRule = rule;
                collisionRule.* = rule.nextInHash;

                removedRule.nextInHash = gameState.firstFreeCollisionRule;
                gameState.firstFreeCollisionRule = removedRule;
            } else {
                collisionRule = &rule.nextInHash;
            }
        }
    }
}

pub fn AddCollisionRule(gameState: *state, unsortedStorageIndexA: u32, unsortedStorageIndexB: u32, canCollide: bool) void {
    var storageIndexA = unsortedStorageIndexA;
    var storageIndexB = unsortedStorageIndexB;
    if (storageIndexA > storageIndexB) {
        storageIndexA = unsortedStorageIndexB;
        storageIndexB = unsortedStorageIndexA;
    }

    var found: ?*pairwise_collision_rule = null;
    const hashBucket = storageIndexA & (gameState.collisionRuleHash.len - 1);
    var collisionRule: ?*pairwise_collision_rule = gameState.collisionRuleHash[hashBucket];
    while (collisionRule) |rule| : (collisionRule = rule.nextInHash) {
        if ((rule.storageIndexA == storageIndexA) and
            (rule.storageIndexB == storageIndexB))
        {
            found = rule;
            break;
        }
    }

    if (found) |_| {} else {
        found = gameState.firstFreeCollisionRule;
        if (found) |_| {
            gameState.firstFreeCollisionRule = found.?.nextInHash;
        } else {
            found = gameState.worldArena.PushStruct(pairwise_collision_rule);
        }
        found.?.nextInHash = gameState.collisionRuleHash[hashBucket];
        gameState.collisionRuleHash[hashBucket] = found;
    }

    if (found) |rule| {
        rule.canCollide = canCollide;
        rule.storageIndexA = storageIndexA;
        rule.storageIndexB = storageIndexB;
    }
}
