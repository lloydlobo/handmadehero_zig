const std = @import("std");
const platform = @import("handmade_platform");
const game = struct {
    usingnamespace @import("handmade_entity.zig");
    usingnamespace @import("handmade_intrinsics.zig");
    usingnamespace @import("handmade_internals.zig");
    usingnamespace @import("handmade_math.zig");
    usingnamespace @import("handmade_random.zig");
    usingnamespace @import("handmade_sim_region.zig");
    usingnamespace @import("handmade_world.zig");
};

// constants ------------------------------------------------------------------------------------------------------------------------------

const NOT_IGNORE = @import("build_consts").NOT_IGNORE;
const HANDMADE_INTERNAL = @import("build_consts").HANDMADE_INTERNAL;

// local functions ------------------------------------------------------------------------------------------------------------------------

fn OutputSound(_: *game.state, soundBuffer: *platform.sound_output_buffer, toneHz: u32) void {
    const toneVolume = 3000;
    _ = toneVolume;
    const wavePeriod = @divTrunc(soundBuffer.samplesPerSecond, toneHz);
    _ = wavePeriod;

    var sampleOut = soundBuffer.samples;
    var sampleIndex = @as(u32, 0);
    while (sampleIndex < soundBuffer.sampleCount) : (sampleIndex += 1) {
        // !NOT_IGNORE:
        // const sineValue = @sin(gameState.tSine);
        // const sampleValue = @floatToInt(i16, sineValue * @intToFloat(f32, toneVolume);

        const sampleValue = 0;
        sampleOut.* = sampleValue;
        sampleOut += 1;
        sampleOut.* = sampleValue;
        sampleOut += 1;

        // !NOT_IGNORE:
        // gameState.tSine += 2.0 * platform.PI32 * 1.0 / @intToFloat(f32, wavePeriod);
        // if (gameState.tSine > 2.0 * platform.PI32) {
        //     gameState.tSine -= 2.0 * platform.PI32;
        // }
    }
}

fn DrawRectangle(buffer: *platform.offscreen_buffer, vMin: game.v2, vMax: game.v2, r: f32, g: f32, b: f32) void {
    var minX = game.RoundF32ToInt(i32, vMin[0]);
    var minY = game.RoundF32ToInt(i32, vMin[1]);
    var maxX = game.RoundF32ToInt(i32, vMax[0]);
    var maxY = game.RoundF32ToInt(i32, vMax[1]);

    if (minX < 0) {
        minX = 0;
    }

    if (minY < 0) {
        minY = 0;
    }

    if (maxX > @intCast(i32, buffer.width)) {
        maxX = @intCast(i32, buffer.width);
    }

    if (maxY > @intCast(i32, buffer.height)) {
        maxY = @intCast(i32, buffer.height);
    }

    const colour: u32 = (game.RoundF32ToInt(u32, r * 255.0) << 16) | (game.RoundF32ToInt(u32, g * 255.0) << 8) | (game.RoundF32ToInt(u32, b * 255) << 0);

    var row = @ptrCast([*]u8, buffer.memory) + @intCast(u32, minX) * buffer.bytesPerPixel + @intCast(u32, minY) * buffer.pitch;

    var y = minY;
    while (y < maxY) : (y += 1) {
        var pixel = @ptrCast([*]u32, @alignCast(@alignOf(u32), row));
        var x = minX;
        while (x < maxX) : (x += 1) {
            pixel.* = colour;
            pixel += 1;
        }
        row += buffer.pitch;
    }
}

fn DrawBitmap(buffer: *platform.offscreen_buffer, bitmap: *const game.loaded_bitmap, realX: f32, realY: f32, cAlpha: f32) void {
    var minX = game.RoundF32ToInt(i32, realX);
    var minY = game.RoundF32ToInt(i32, realY);
    var maxX = minX + bitmap.width;
    var maxY = minY + bitmap.height;

    var sourceOffesetX = @as(i32, 0);
    if (minX < 0) {
        sourceOffesetX = -minX;
        minX = 0;
    }

    var sourceOffesetY = @as(i32, 0);
    if (minY < 0) {
        sourceOffesetY = -minY;
        minY = 0;
    }

    if (maxX > @intCast(i32, buffer.width)) {
        maxX = @intCast(i32, buffer.width);
    }

    if (maxY > @intCast(i32, buffer.height)) {
        maxY = @intCast(i32, buffer.height);
    }

    const offset = bitmap.width * (bitmap.height - 1) - sourceOffesetY * bitmap.width + sourceOffesetX;
    // NOTE (Manav): something is buggy here \(_-_)/

    var sourceRow = bitmap.pixels.access + @intCast(u32, if (offset >= 0) offset else 0);
    var destRow = @ptrCast([*]u8, buffer.memory) + @intCast(u32, minX) * buffer.bytesPerPixel + @intCast(u32, minY) * buffer.pitch;

    var y = minY;
    while (y < maxY) : (y += 1) {
        const dest = @ptrCast([*]u32, @alignCast(@alignOf(u32), destRow));
        var x = minX;
        while (x < maxX) : (x += 1) {
            const index = @intCast(u32, x - minX);

            const a = (@intToFloat(f32, ((sourceRow[index] >> 24) & 0xff)) / 255.0) * cAlpha;

            const sR = @intToFloat(f32, ((sourceRow[index] >> 16) & 0xff));
            const sG = @intToFloat(f32, ((sourceRow[index] >> 8) & 0xff));
            const sB = @intToFloat(f32, ((sourceRow[index] >> 0) & 0xff));

            const dR = @intToFloat(f32, ((dest[index] >> 16) & 0xff));
            const dG = @intToFloat(f32, ((dest[index] >> 8) & 0xff));
            const dB = @intToFloat(f32, ((dest[index] >> 0) & 0xff));

            const r = (1 - a) * dR + a * sR;
            const g = (1 - a) * dG + a * sG;
            const b = (1 - a) * dB + a * sB;

            dest[index] = (@floatToInt(u32, if (r + 0.5 > 0) r + 0.5 else 0) << 16) | (@floatToInt(u32, if (g + 0.5 > 0) g + 0.5 else 0) << 8) | (@floatToInt(u32, if (b + 0.5 > 0) b + 0.5 else 0) << 0);
        }

        destRow += buffer.pitch;
        sourceRow -= @intCast(u32, bitmap.width);
    }
}

const bitmap_header = packed struct {
    fileType: u16,
    fileSize: u32,
    reserved1: u16,
    reserved2: u16,
    bitmapOffset: u32,
    size: u32,
    width: i32,
    height: i32,
    planes: u16,
    bitsPerPixel: u16,
    compression: u32,
    sizeOfBitmap: u32,
    horzResolution: u32,
    vertResolution: u32,
    colorsUsed: u32,
    colorsImportant: u32,

    redMask: u32,
    greenMask: u32,
    blueMask: u32,
};

fn DEBUGLoadBMP(thread: *platform.thread_context, ReadEntireFile: platform.debug_platform_read_entire_file, fileName: [*:0]const u8) game.loaded_bitmap {
    var result = game.loaded_bitmap{};

    const readResult = ReadEntireFile(thread, fileName);
    if (readResult.contentSize != 0) {
        const header = @ptrCast(*bitmap_header, readResult.contents);
        var pixels = @ptrCast([*]u8, readResult.contents) + header.bitmapOffset;
        result.width = header.width;
        result.height = header.height;
        result.pixels.colour = pixels;

        std.debug.assert(header.compression == 3);

        const redMask = header.redMask;
        const greenMask = header.greenMask;
        const blueMask = header.blueMask;
        const alphaMask = ~(redMask | greenMask | blueMask);

        const redScan = game.FindLeastSignificantSetBit(redMask);
        const greenScan = game.FindLeastSignificantSetBit(greenMask);
        const blueScan = game.FindLeastSignificantSetBit(blueMask);
        const alphaScan = game.FindLeastSignificantSetBit(alphaMask);

        const redShift = 16 - @intCast(i8, redScan);
        const greenShift = 8 - @intCast(i8, greenScan);
        const blueShift = 0 - @intCast(i8, blueScan);
        const alphaShift = 24 - @intCast(i8, alphaScan);

        const sourceDest = result.pixels.access;

        var index = @as(u32, 0);
        while (index < @intCast(u32, header.height * header.width)) : (index += 1) {
            const c = sourceDest[index];
            sourceDest[index] = (game.RotateLeft(c & redMask, redShift) |
                game.RotateLeft(c & greenMask, greenShift) |
                game.RotateLeft(c & blueMask, blueShift) |
                game.RotateLeft(c & alphaMask, alphaShift));
        }
    }

    return result;
}

const add_low_entity_result = struct {
    low: *game.low_entity,
    lowIndex: u32,
};

fn AddLowEntity(gameState: *game.state, entityType: game.entity_type, pos: game.world_position) add_low_entity_result {
    std.debug.assert(gameState.lowEntityCount < gameState.lowEntities.len);
    const entityIndex = gameState.lowEntityCount;
    gameState.lowEntityCount += 1;

    const entityLow = &gameState.lowEntities[entityIndex];

    entityLow.* = .{
        .sim = .{ .entityType = entityType },
        .p = game.NullPosition(),
    };

    game.ChangeEntityLocation(&gameState.worldArena, gameState.world, entityIndex, entityLow, pos);

    const result = .{
        .low = entityLow,
        .lowIndex = entityIndex,
    };

    return result;
}

fn AddWall(gameState: *game.state, absTileX: u32, absTileY: u32, absTileZ: u32) add_low_entity_result {
    const p = game.ChunkPosFromTilePos(gameState.world, @intCast(i32, absTileX), @intCast(i32, absTileY), @intCast(i32, absTileZ), .{ 0, 0, 0 });
    var entity = AddLowEntity(gameState, .Wall, p);

    const height = gameState.world.tileSideInMeters;
    const width = height;
    entity.low.sim.dim = .{ width, height, entity.low.sim.dim[2] };
    game.AddFlags(&entity.low.sim, @enumToInt(game.sim_entity_flags.Collides));

    return entity;
}

fn AddStairs(gameState: *game.state, absTileX: u32, absTileY: u32, absTileZ: u32) add_low_entity_result {
    const p = game.ChunkPosFromTilePos(gameState.world, @intCast(i32, absTileX), @intCast(i32, absTileY), @intCast(i32, absTileZ), .{ 0, 0, 0.5 * gameState.world.tileDepthInMeters });
    var entity = AddLowEntity(gameState, .Stairwell, p);

    const width = gameState.world.tileSideInMeters;
    const height = 2 * gameState.world.tileSideInMeters;
    entity.low.sim.dim = .{ width, height, gameState.world.tileDepthInMeters };
    game.AddFlags(&entity.low.sim, @enumToInt(game.sim_entity_flags.Collides));

    return entity;
}

fn InitHitPoints(entityLow: *game.low_entity, hitPointCount: u32) void {
    std.debug.assert(hitPointCount <= entityLow.sim.hitPoint.len);
    entityLow.sim.hitPointMax = hitPointCount;

    var hitPointIndex = @as(u32, 0);
    while (hitPointIndex < entityLow.sim.hitPointMax) : (hitPointIndex += 1) {
        const hitPoint = &entityLow.sim.hitPoint[hitPointIndex];
        hitPoint.flags = 0;
        hitPoint.filledAmount = game.HIT_POINT_SUB_COUNT;
    }
}

fn AddSword(gameState: *game.state) add_low_entity_result {
    var entity = AddLowEntity(gameState, .Sword, game.NullPosition());

    const height = 0.5;
    const width = 1;
    entity.low.sim.dim = .{ width, height, entity.low.sim.dim[2] };

    game.AddFlags(&entity.low.sim, @enumToInt(game.sim_entity_flags.Movable));

    return entity;
}

fn AddPlayer(gameState: *game.state) add_low_entity_result {
    const p = gameState.cameraP;
    var entity = AddLowEntity(gameState, .Hero, p);

    const height = 0.5;
    const width = 1;
    entity.low.sim.dim = .{ width, height, entity.low.sim.dim[2] };

    game.AddFlags(&entity.low.sim, @enumToInt(game.sim_entity_flags.Collides) | @enumToInt(game.sim_entity_flags.Movable));

    InitHitPoints(entity.low, 3);

    const sword = AddSword(gameState);
    entity.low.sim.sword.index = sword.lowIndex;

    if (gameState.cameraFollowingEntityIndex == 0) {
        gameState.cameraFollowingEntityIndex = entity.lowIndex;
    }

    return entity;
}

fn AddMonstar(gameState: *game.state, absTileX: u32, absTileY: u32, absTileZ: u32) add_low_entity_result {
    const p = game.ChunkPosFromTilePos(gameState.world, @intCast(i32, absTileX), @intCast(i32, absTileY), @intCast(i32, absTileZ), .{ 0, 0, 0 });
    var entity = AddLowEntity(gameState, .Monstar, p);

    const height = 0.5;
    const width = 1;
    entity.low.sim.dim = .{ width, height, entity.low.sim.dim[2] };

    game.AddFlags(&entity.low.sim, @enumToInt(game.sim_entity_flags.Collides) | @enumToInt(game.sim_entity_flags.Movable));

    InitHitPoints(entity.low, 3);

    return entity;
}

fn AddFamiliar(gameState: *game.state, absTileX: u32, absTileY: u32, absTileZ: u32) add_low_entity_result {
    const p = game.ChunkPosFromTilePos(gameState.world, @intCast(i32, absTileX), @intCast(i32, absTileY), @intCast(i32, absTileZ), .{ 0, 0, 0 });
    var entity = AddLowEntity(gameState, .Familiar, p);

    const height = 0.5;
    const width = 1;
    entity.low.sim.dim = .{ width, height, game.Z(entity.low.sim.dim) };

    game.AddFlags(&entity.low.sim, @enumToInt(game.sim_entity_flags.Collides) | @enumToInt(game.sim_entity_flags.Movable));

    return entity;
}

inline fn PushPiece(
    group: *game.entity_visible_piece_group,
    bitmap: ?*game.loaded_bitmap,
    offset: game.v2,
    offsetZ: f32,
    alignment: game.v2,
    dim: game.v2,
    colour: game.v4,
    entityZC: f32,
) void {
    std.debug.assert(group.pieceCount < group.pieces.len);
    const piece = &group.pieces[group.pieceCount];
    group.pieceCount += 1;
    piece.bitmap = bitmap;
    piece.offset = (@splat(2, group.gameState.metersToPixels) * game.v2{ offset[0], -offset[1] }) - alignment;
    piece.offsetZ = group.gameState.metersToPixels * offsetZ;
    piece.entityZC = entityZC;
    piece.r = game.R(colour);
    piece.g = game.G(colour);
    piece.b = game.B(colour);
    piece.a = game.A(colour);
    piece.dim = dim;
}

inline fn PushBitmap(group: *game.entity_visible_piece_group, bitmap: *game.loaded_bitmap, offset: game.v2, offsetZ: f32, alignment: game.v2, alpha: f32, entityZC: f32) void {
    PushPiece(group, bitmap, offset, offsetZ, alignment, .{ 0, 0 }, .{ 1, 1, 1, alpha }, entityZC);
}

inline fn PushRect(group: *game.entity_visible_piece_group, offset: game.v2, offsetZ: f32, dim: game.v2, colour: game.v4, entityZC: f32) void {
    PushPiece(group, null, offset, offsetZ, .{ 0, 0 }, dim, colour, entityZC);
}

fn DrawHitpoints(entity: *game.sim_entity, pieceGroup: *game.entity_visible_piece_group) void {
    if (entity.hitPointMax >= 1) {
        const healthDim = game.v2{ 0.2, 0.2 };
        const spacingX = 1.5 * game.X(healthDim);
        var hitP = game.v2{
            -0.5 * @intToFloat(f32, entity.hitPointMax - 1) * spacingX,
            -0.25,
        };
        const dHitP = game.v2{ spacingX, 0 };
        var healthIndex = @as(u32, 0);
        while (healthIndex < entity.hitPointMax) : (healthIndex += 1) {
            const hitPoint = entity.hitPoint[healthIndex];
            var colour = game.v4{ 1, 0, 0, 1 };
            if (hitPoint.filledAmount == 0) {
                colour = .{ 0.2, 0.2, 0.2, 1 };
            }

            PushRect(pieceGroup, hitP, 0, healthDim, colour, 0);
            hitP += dHitP;
        }
    }
}

// public functions -----------------------------------------------------------------------------------------------------------------------

pub export fn UpdateAndRender(
    thread: *platform.thread_context,
    gameMemory: *platform.memory,
    gameInput: *platform.input,
    buffer: *platform.offscreen_buffer,
) void {
    comptime {
        // NOTE (Manav): This is hacky atm. Need to check as we're using win32.LoadLibrary()
        if (@typeInfo(@TypeOf(UpdateAndRender)).Fn.args.len != @typeInfo(platform.UpdateAndRenderType).Fn.args.len or
            (@typeInfo(@TypeOf(UpdateAndRender)).Fn.args[0].arg_type.? != @typeInfo(platform.UpdateAndRenderType).Fn.args[0].arg_type.?) or
            (@typeInfo(@TypeOf(UpdateAndRender)).Fn.args[1].arg_type.? != @typeInfo(platform.UpdateAndRenderType).Fn.args[1].arg_type.?) or
            (@typeInfo(@TypeOf(UpdateAndRender)).Fn.args[2].arg_type.? != @typeInfo(platform.UpdateAndRenderType).Fn.args[2].arg_type.?) or
            (@typeInfo(@TypeOf(UpdateAndRender)).Fn.args[3].arg_type.? != @typeInfo(platform.UpdateAndRenderType).Fn.args[3].arg_type.?) or
            @typeInfo(@TypeOf(UpdateAndRender)).Fn.return_type.? != @typeInfo(platform.UpdateAndRenderType).Fn.return_type.?)
        {
            @compileError("Function signature mismatch!");
        }
    }

    std.debug.assert(@sizeOf(game.state) <= gameMemory.permanentStorageSize);

    const gameState = @ptrCast(*game.state, @alignCast(@alignOf(game.state), gameMemory.permanentStorage));

    if (!gameMemory.isInitialized) {
        _ = AddLowEntity(gameState, .Null, game.NullPosition());

        gameState.backdrop = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_background.bmp");
        gameState.shadow = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_shadow.bmp");
        gameState.tree = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test2/tree00.bmp");
        gameState.stairwell = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test2/rock02.bmp");
        gameState.sword = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test2/rock03.bmp");

        gameState.heroBitmaps[0].head = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_right_head.bmp");
        gameState.heroBitmaps[0].cape = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_right_cape.bmp");
        gameState.heroBitmaps[0].torso = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_right_torso.bmp");
        gameState.heroBitmaps[0].alignment = .{ 72, 182 };

        gameState.heroBitmaps[1].head = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_back_head.bmp");
        gameState.heroBitmaps[1].cape = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_back_cape.bmp");
        gameState.heroBitmaps[1].torso = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_back_torso.bmp");
        gameState.heroBitmaps[1].alignment = .{ 72, 182 };

        gameState.heroBitmaps[2].head = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_left_head.bmp");
        gameState.heroBitmaps[2].cape = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_left_cape.bmp");
        gameState.heroBitmaps[2].torso = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_left_torso.bmp");
        gameState.heroBitmaps[2].alignment = .{ 72, 182 };

        gameState.heroBitmaps[3].head = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_front_head.bmp");
        gameState.heroBitmaps[3].cape = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_front_cape.bmp");
        gameState.heroBitmaps[3].torso = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_front_torso.bmp");
        gameState.heroBitmaps[3].alignment = .{ 72, 182 };

        gameState.worldArena.Initialize(gameMemory.permanentStorageSize - @sizeOf(game.state), gameMemory.permanentStorage + @sizeOf(game.state));
        gameState.world = gameState.worldArena.PushStruct(game.world);

        const world = gameState.world;
        game.InitializeWorld(world, 1.4);

        const tileSideInPixels = 60;
        gameState.metersToPixels = tileSideInPixels / world.tileSideInMeters;

        const tilesPerWidth = 17;
        const tilesPerHeight = 9;

        const screenBaseX = @as(u32, 0);
        const screenBaseY = @as(u32, 0);
        const screenBaseZ = @as(u32, 0);
        var screenX = screenBaseX;
        var screenY = screenBaseY;
        var absTileZ = screenBaseZ;

        var doorLeft = false;
        var doorRight = false;
        var doorTop = false;
        var doorBottom = false;
        var doorUp = false;
        var doorDown = false;

        var screenIndex: u32 = 0;
        while (screenIndex < 2000) : (screenIndex += 1) {
            var randomChoice: u32 = 0;

            if (NOT_IGNORE) {
                if (doorUp or doorDown) {
                    randomChoice = game.RandInt(u32) % 2;
                } else {
                    randomChoice = game.RandInt(u32) % 3;
                }
            }

            var createdZDoor = false;
            if (randomChoice == 2) {
                createdZDoor = true;
                if (absTileZ == screenBaseZ) {
                    doorUp = true;
                } else {
                    doorDown = true;
                }
            } else if (randomChoice == 1) {
                doorRight = true;
            } else {
                doorTop = true;
            }

            var tileY = @as(u32, 0);
            while (tileY < tilesPerHeight) : (tileY += 1) {
                var tileX = @as(u32, 0);
                while (tileX < tilesPerWidth) : (tileX += 1) {
                    const absTileX = screenX * tilesPerWidth + tileX;
                    const absTileY = screenY * tilesPerHeight + tileY;

                    var shouldBeDoor = false;
                    if ((tileX == 0) and (!doorLeft or (tileY != (tilesPerHeight / 2)))) {
                        shouldBeDoor = true;
                    }

                    if ((tileX == (tilesPerWidth - 1)) and (!doorRight or (tileY != (tilesPerHeight / 2)))) {
                        shouldBeDoor = true;
                    }

                    if ((tileY == 0) and (!doorBottom or (tileX != (tilesPerWidth / 2)))) {
                        shouldBeDoor = true;
                    }

                    if ((tileY == (tilesPerHeight - 1)) and (!doorTop or (tileX != (tilesPerWidth / 2)))) {
                        shouldBeDoor = true;
                    }

                    if (shouldBeDoor) {
                        _ = AddWall(gameState, absTileX, absTileY, absTileZ);
                    } else if (createdZDoor) {
                        if ((tileX == 10) and (tileY == 5)) {
                            _ = AddStairs(gameState, absTileX, absTileY, if (doorDown) absTileZ - 1 else absTileZ);
                        }
                    }
                }
            }

            doorLeft = doorRight;
            doorBottom = doorTop;

            if (createdZDoor) {
                doorDown = !doorDown;
                doorUp = !doorUp;
            } else {
                doorDown = false;
                doorUp = false;
            }

            doorRight = false;
            doorTop = false;

            if (randomChoice == 2) {
                if (absTileZ == screenBaseZ) {
                    absTileZ = screenBaseZ + 1;
                } else {
                    absTileZ = screenBaseZ;
                }
            } else if (randomChoice == 1) {
                screenX += 1;
            } else {
                screenY += 1;
            }
        }

        if (!NOT_IGNORE) {
            while (gameState.lowEntityCount < (gameState.lowEntities.len - 16)) {
                const coordinate = 1024 + gameState.lowEntityCount;
                AddWall(gameState, coordinate, coordinate, coordinate);
            }
        }

        const cameraTileX = screenBaseX * tilesPerWidth + 17 / 2;
        const cameraTileY = screenBaseY * tilesPerHeight + 9 / 2;
        const cameraTileZ = screenBaseZ;

        const newCameraP = game.ChunkPosFromTilePos(gameState.world, cameraTileX, cameraTileY, cameraTileZ, .{ 0, 0, 0 });

        gameState.cameraP = newCameraP;

        _ = AddMonstar(gameState, cameraTileX - 3, cameraTileY + 2, cameraTileZ);
        var familiarIndex = @as(u32, 0);
        while (familiarIndex < 1) : (familiarIndex += 1) {
            const familiarOffsetX = @intCast(i32, @rem(game.RandInt(u32), 10)) - 7;
            const familiarOffsetY = @intCast(i32, @rem(game.RandInt(u32), 10)) - 3;

            if ((familiarOffsetX != 0) or (familiarOffsetY != 0)) {
                _ = AddFamiliar(gameState, @intCast(u32, @intCast(i32, cameraTileX) + familiarOffsetX), @intCast(u32, @intCast(i32, cameraTileY) + familiarOffsetY), cameraTileZ);
            }
        }

        gameMemory.isInitialized = true;
    }

    const world = gameState.world;

    const metersToPixels = gameState.metersToPixels;

    for (gameInput.controllers) |controller, controllerIndex| {
        const conHero = &gameState.controlledHeroes[controllerIndex];
        if (conHero.entityIndex == 0) {
            if (controller.buttons.mapped.start.endedDown != 0) {
                conHero.* = .{};
                conHero.entityIndex = AddPlayer(gameState).lowIndex;
            }
        } else {
            conHero.dZ = 0;
            conHero.dSword = .{ 0, 0 };
            conHero.ddP = .{ 0, 0 };

            if (controller.isAnalog) {
                conHero.ddP = .{ controller.stickAverageX, controller.stickAverageX };
            } else {
                if (controller.buttons.mapped.moveUp.endedDown != 0) {
                    conHero.ddP[1] = 1.0;
                }
                if (controller.buttons.mapped.moveDown.endedDown != 0) {
                    conHero.ddP[1] = -1.0;
                }
                if (controller.buttons.mapped.moveLeft.endedDown != 0) {
                    conHero.ddP[0] = -1.0;
                }
                if (controller.buttons.mapped.moveRight.endedDown != 0) {
                    conHero.ddP[0] = 1.0;
                }
            }

            if (controller.buttons.mapped.start.endedDown != 0) {
                conHero.dZ = 3.0;
            }

            conHero.dSword = .{ 0, 0 };
            if (controller.buttons.mapped.actionUp.endedDown != 0) {
                conHero.dSword[1] = 1.0;
            }
            if (controller.buttons.mapped.actionDown.endedDown != 0) {
                conHero.dSword[1] = -1.0;
            }
            if (controller.buttons.mapped.actionLeft.endedDown != 0) {
                conHero.dSword[0] = -1.0;
            }
            if (controller.buttons.mapped.actionRight.endedDown != 0) {
                conHero.dSword[0] = 1.0;
            }
        }
    }

    const tileSpanX = 17 * 3;
    const tileSpanY = 9 * 3;
    const tileSpanZ = 1;
    const cameraBounds = game.rect3.InitCenterDim(.{ 0, 0, 0 }, game.v3{ tileSpanX, tileSpanY, tileSpanZ } * @splat(3, world.tileSideInMeters));

    var simArena: game.memory_arena = undefined;
    simArena.Initialize(gameMemory.transientStorageSize, gameMemory.transientStorage);
    const simRegion = game.BeginSim(&simArena, gameState, gameState.world, gameState.cameraP, cameraBounds, gameInput.dtForFrame);

    if (NOT_IGNORE) {
        DrawRectangle(buffer, .{ 0, 0 }, .{ @intToFloat(f32, buffer.width), @intToFloat(f32, buffer.height) }, 0.5, 0.5, 0.5);
    } else {
        DrawBitmap(buffer, &gameState.backdrop, 0, 0, 1);
    }

    const screenCenterX = 0.5 * @intToFloat(f32, buffer.width);
    const screenCenterY = 0.5 * @intToFloat(f32, buffer.height);

    var pieceGroup = game.entity_visible_piece_group{
        .gameState = gameState,
        .pieceCount = 0,
        .pieces = [1]game.entity_visible_piece{.{
            .bitmap = undefined,
        }} ** 8,
    };

    var entityIndex = @as(u32, 0);
    while (entityIndex < simRegion.entityCount) : (entityIndex += 1) {
        const entity: *game.sim_entity = &simRegion.entities[entityIndex];

        if (entity.updatable) {
            pieceGroup.pieceCount = 0;
            const dt = gameInput.dtForFrame;

            const alpha = 1 - 0.5 * entity.p[2];
            const shadowAlpha = if (alpha > 0) alpha else 0;

            var moveSpec = game.DefaultMoveSpec();
            var ddP = game.v3{ 0, 0, 0 };

            const heroBitmaps = &gameState.heroBitmaps[entity.facingDirection];

            switch (entity.entityType) {
                .Hero => {
                    for (gameState.controlledHeroes) |conHero| {
                        if (entity.storageIndex == conHero.entityIndex) {
                            if (conHero.dZ != 0) {
                                entity.dP[2] = conHero.dZ;
                            }

                            moveSpec.unitMaxAccelVector = true;
                            moveSpec.speed = 50;
                            moveSpec.drag = 8;
                            ddP = .{ game.X(conHero.ddP), game.Y(conHero.ddP), 0 };
                            if ((game.X(conHero.dSword) != 0) or (game.Y(conHero.dSword) != 0)) {
                                switch (entity.sword) {
                                    .ptr => {
                                        const sword = entity.sword.ptr;
                                        if (game.IsSet(sword, @enumToInt(game.sim_entity_flags.NonSpatial))) {
                                            sword.distanceLimit = 5.0;
                                            const dSwordV3 = game.v3{ game.X(conHero.dSword), game.Y(conHero.dSword), 0 };
                                            game.MakeEntitySpatial(sword, entity.p, entity.dP + (dSwordV3 * @splat(3, @as(f32, 5)))); //
                                            game.AddCollisionRule(gameState, sword.storageIndex, entity.storageIndex, false);
                                        }
                                    },

                                    .index => {
                                        unreachable;
                                    },
                                }
                            }
                        }
                    }

                    PushBitmap(&pieceGroup, &gameState.shadow, .{ 0, 0 }, 0, heroBitmaps.alignment, shadowAlpha, 0.0);
                    PushBitmap(&pieceGroup, &heroBitmaps.torso, .{ 0, 0 }, 0, heroBitmaps.alignment, 1.0, 1.0);
                    PushBitmap(&pieceGroup, &heroBitmaps.cape, .{ 0, 0 }, 0, heroBitmaps.alignment, 1.0, 1.0);
                    PushBitmap(&pieceGroup, &heroBitmaps.head, .{ 0, 0 }, 0, heroBitmaps.alignment, 1.0, 1.0);

                    DrawHitpoints(entity, &pieceGroup);
                },

                .Wall => {
                    PushBitmap(&pieceGroup, &gameState.tree, .{ 0, 0 }, 0, .{ 40, 80 }, 1.0, 1.0);
                },

                .Stairwell => {
                    PushRect(&pieceGroup, .{ 0, 0 }, 0, .{ game.X(entity.dim), game.Y(entity.dim) }, .{ 1, 1, 0, 1 }, 0);
                },

                .Sword => {
                    moveSpec.unitMaxAccelVector = false;
                    moveSpec.speed = 0;
                    moveSpec.drag = 0;

                    if (entity.distanceLimit == 0) {
                        game.ClearCollisionRulesFor(gameState, entity.storageIndex);
                        game.MakeEntityNonSpatial(entity);
                    }

                    PushBitmap(&pieceGroup, &gameState.shadow, .{ 0, 0 }, 0, heroBitmaps.alignment, shadowAlpha, 0.0);
                    PushBitmap(&pieceGroup, &gameState.sword, .{ 0, 0 }, 0, .{ 29, 10 }, 1.0, 1.0);
                },

                .Familiar => {
                    var closestHero: ?*game.sim_entity = null;
                    var closestHeroDSq = game.Square(10);
                    if (!NOT_IGNORE) {
                        var testEntityIndex = @as(u32, 0);
                        while (testEntityIndex < simRegion.entityCount) : (testEntityIndex += 1) {
                            const testEntity: *game.sim_entity = &simRegion.entities[testEntityIndex];
                            if (testEntity.entityType == .Hero) {
                                var testDSq = game.LengthSq(3, testEntity.p - entity.p);

                                if (closestHeroDSq > testDSq) {
                                    closestHero = testEntity;
                                    closestHeroDSq = testDSq;
                                }
                            }
                        }
                    }

                    if (closestHero) |hero| {
                        if (closestHeroDSq > game.Square(3)) {
                            const accelaration = 0.5;
                            const oneOverLength = accelaration / game.SquareRoot(closestHeroDSq);
                            ddP = @splat(3, oneOverLength) * (hero.p - entity.p);
                        }
                    }

                    moveSpec.unitMaxAccelVector = true;
                    moveSpec.speed = 50;
                    moveSpec.drag = 8;

                    entity.tBob += dt;
                    if (entity.tBob > 2 * platform.PI32) {
                        entity.tBob -= 2 * platform.PI32;
                    }
                    const bobSin = game.Sin(2 * entity.tBob);
                    PushBitmap(&pieceGroup, &gameState.shadow, .{ 0, 0 }, 0, heroBitmaps.alignment, (0.5 * shadowAlpha) + (0.2 * bobSin), 0.0);
                    PushBitmap(&pieceGroup, &heroBitmaps.head, .{ 0, 0 }, 0.25 * bobSin, heroBitmaps.alignment, 1.0, 1.0);
                },

                .Monstar => {
                    PushBitmap(&pieceGroup, &gameState.shadow, .{ 0, 0 }, 0, heroBitmaps.alignment, shadowAlpha, 0.0);
                    PushBitmap(&pieceGroup, &heroBitmaps.torso, .{ 0, 0 }, 0, heroBitmaps.alignment, 1.0, 1.0);

                    DrawHitpoints(entity, &pieceGroup);
                },

                .Null => {
                    unreachable;
                },
            }

            if (!game.IsSet(entity, @enumToInt(game.sim_entity_flags.NonSpatial)) and
                game.IsSet(entity, @enumToInt(game.sim_entity_flags.Movable)))
            {
                game.MoveEntity(gameState, simRegion, entity, gameInput.dtForFrame, &moveSpec, ddP);
            }

            const zFudge = 1 + 0.1 * game.Z(entity.p);

            const entityGroundPointX = screenCenterX + metersToPixels * zFudge * game.X(entity.p);
            const entityGroundPointY = screenCenterY - metersToPixels * zFudge * game.Y(entity.p);
            const entityz = -metersToPixels * entity.p[2];

            if (!NOT_IGNORE) {
                const playerLeftTop = .{
                    .x = entityGroundPointX - 0.5 * metersToPixels * entity.width,
                    .y = entityGroundPointY - 0.5 * metersToPixels * entity.height,
                };
                const entityWidthHeight = game.v{ .V2 = .{ entity.width, entity.height } };

                DrawRectangle(
                    buffer,
                    playerLeftTop,
                    playerLeftTop + game.Scale(entityWidthHeight, metersToPixels).V2,
                    1.0,
                    1.0,
                    0.0,
                );
            }

            var pieceIndex = @as(u32, 0);
            while (pieceIndex < pieceGroup.pieceCount) : (pieceIndex += 1) {
                const piece = pieceGroup.pieces[pieceIndex];
                const center = game.v2{
                    entityGroundPointX + piece.offset[0],
                    entityGroundPointY + piece.offset[1] + piece.offsetZ + piece.entityZC * entityz,
                };

                if (piece.bitmap) |b| {
                    DrawBitmap(buffer, b, center[0], center[1], piece.a);
                } else {
                    const halfDim = piece.dim * @splat(2, 0.5 * metersToPixels);
                    DrawRectangle(buffer, center - halfDim, center + halfDim, piece.r, piece.g, piece.b);
                }
            }
        }
    }

    const worldOrigin: game.world_position = .{};
    const diff: [3]f32 = game.Substract(simRegion.world, &worldOrigin, &simRegion.origin);
    DrawRectangle(buffer, diff[0..2].*, .{ 10, 10 }, 1, 1, 0);

    game.EndSim(simRegion, gameState);
}

pub export fn GetSoundSamples(_: *platform.thread_context, gameMemory: *platform.memory, soundBuffer: *platform.sound_output_buffer) void {
    comptime {
        // NOTE (Manav): This is hacky atm. Need to check as we're using win32.LoadLibrary()
        if (@typeInfo(@TypeOf(GetSoundSamples)).Fn.args.len != @typeInfo(platform.GetSoundSamplesType).Fn.args.len or
            (@typeInfo(@TypeOf(GetSoundSamples)).Fn.args[0].arg_type.? != @typeInfo(platform.GetSoundSamplesType).Fn.args[0].arg_type.?) or
            (@typeInfo(@TypeOf(GetSoundSamples)).Fn.args[1].arg_type.? != @typeInfo(platform.GetSoundSamplesType).Fn.args[1].arg_type.?) or
            (@typeInfo(@TypeOf(GetSoundSamples)).Fn.args[2].arg_type.? != @typeInfo(platform.GetSoundSamplesType).Fn.args[2].arg_type.?) or
            @typeInfo(@TypeOf(GetSoundSamples)).Fn.return_type.? != @typeInfo(platform.GetSoundSamplesType).Fn.return_type.?)
        {
            @compileError("Function signature mismatch!");
        }
    }

    const gameState = @ptrCast(*game.state, @alignCast(@alignOf(game.state), gameMemory.permanentStorage));
    OutputSound(gameState, soundBuffer, 400);
}
