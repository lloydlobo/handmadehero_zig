const std = @import("std");
const platform = @import("handmade_platform");
const game = struct {
    usingnamespace @import("handmade_intrinsics.zig");
    usingnamespace @import("handmade_internals.zig");
    usingnamespace @import("handmade_math.zig");
    usingnamespace @import("handmade_tile.zig");
    usingnamespace @import("handmade_random.zig");
};

// constants ------------------------------------------------------------------------------------------------------------------------------

const NOT_IGNORE = @import("build_consts").NOT_IGNORE;
const HANDMADE_INTERNAL = @import("build_consts").HANDMADE_INTERNAL;

// local functions ------------------------------------------------------------------------------------------------------------------------

fn SetTileValue(arena: *game.memory_arena, tileMap: *game.tile_map, absTileX: u32, absTileY: u32, absTileZ: u32, tileValue: u32) void {
    const chunkPos = game.GetChunkPositionFor(tileMap, absTileX, absTileY, absTileZ);
    const tileChunk = game.GetTileChunk(tileMap, chunkPos.tileChunkX, chunkPos.tileChunkY, chunkPos.tileChunkZ);

    std.debug.assert(tileChunk != null);

    if (tileChunk.?.tiles) |_| {} else {
        const tileCount = tileMap.chunkDim * tileMap.chunkDim;
        tileChunk.?.tiles = game.PushArrayPtr(u32, tileCount, arena);

        var tileIndex: u32 = 0;
        while (tileIndex < tileCount) : (tileIndex += 1) {
            tileChunk.?.tiles.?[tileIndex] = 1;
        }
    }

    game.SetTileValue(tileMap, tileChunk, chunkPos.relTileX, chunkPos.relTileY, tileValue);
}

fn OutputSound(_: *game.state, soundBuffer: *platform.sound_output_buffer, toneHz: u32) void {
    const toneVolume = 3000;
    _ = toneVolume;
    const wavePeriod = @divTrunc(soundBuffer.samplesPerSecond, toneHz);
    _ = wavePeriod;

    var sampleOut = soundBuffer.samples;
    var sampleIndex: u32 = 0;
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
    var minX = game.RoundF32ToInt(i32, vMin.x);
    var minY = game.RoundF32ToInt(i32, vMin.y);
    var maxX = game.RoundF32ToInt(i32, vMax.x);
    var maxY = game.RoundF32ToInt(i32, vMax.y);

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

fn DrawBitmap(buffer: *platform.offscreen_buffer, bitmap: *const game.loaded_bitmap, realX: f32, realY: f32, alignX: i32, alignY: i32) void {
    const alignedRealX = realX - @intToFloat(f32, alignX);
    const alignedRealY = realY - @intToFloat(f32, alignY);

    var minX = game.RoundF32ToInt(i32, alignedRealX);
    var minY = game.RoundF32ToInt(i32, alignedRealY);
    var maxX = game.RoundF32ToInt(i32, alignedRealX + @intToFloat(f32, bitmap.width));
    var maxY = game.RoundF32ToInt(i32, alignedRealY + @intToFloat(f32, bitmap.height));

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

    var sourceRow = bitmap.pixels.access + @intCast(u32, bitmap.width * (bitmap.height - 1) - sourceOffesetY * bitmap.width + sourceOffesetX);
    var destRow = @ptrCast([*]u8, buffer.memory) + @intCast(u32, minX) * buffer.bytesPerPixel + @intCast(u32, minY) * buffer.pitch;

    var y = minY;
    while (y < maxY) : (y += 1) {
        const dest = @ptrCast([*]u32, @alignCast(@alignOf(u32), destRow));
        var x = minX;
        while (x < maxX) : (x += 1) {
            const index = @intCast(u32, x - minX);

            const a = @intToFloat(f32, ((sourceRow[index] >> 24) & 0xff)) / 255.0;
            const sR = @intToFloat(f32, ((sourceRow[index] >> 16) & 0xff));
            const sG = @intToFloat(f32, ((sourceRow[index] >> 8) & 0xff));
            const sB = @intToFloat(f32, ((sourceRow[index] >> 0) & 0xff));

            const dR = @intToFloat(f32, ((dest[index] >> 16) & 0xff));
            const dG = @intToFloat(f32, ((dest[index] >> 8) & 0xff));
            const dB = @intToFloat(f32, ((dest[index] >> 0) & 0xff));

            const r = (1 - a) * dR + a * sR;
            const g = (1 - a) * dG + a * sG;
            const b = (1 - a) * dB + a * sB;

            dest[index] = (@floatToInt(u32, r + 0.5) << 16) | (@floatToInt(u32, g + 0.5) << 8) | (@floatToInt(u32, b + 0.5) << 0);
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

fn GetEntity(gameState: *game.state, index: u32) ?*game.entity {
    var entity: ?*game.entity = null;

    if (index > 0) {
        entity = if (gameState.entities[index]) |*e| e else null;
    }

    return entity;
}

fn InitializaPlayer(gameState: *game.state, entityIndex: u32) void {
    const entity = GetEntity(gameState, entityIndex);

    std.debug.assert(entity != null);

    entity.?.exists = true;
    entity.?.p.absTileX = 1;
    entity.?.p.absTileY = 3;
    entity.?.p.offset_ = .{ .x = 0, .y = 0 };
    entity.?.height = 1.4;
    entity.?.width = 0.75 * entity.?.height;

    if (GetEntity(gameState, gameState.cameraFollowingEntityIndex) == null) {
        gameState.cameraFollowingEntityIndex = entityIndex;
    }
}

fn AddEntity(gameState: *game.state) u32 {
    const entityIndex = gameState.entityCount;
    gameState.entityCount += 1;

    std.debug.assert(gameState.entityCount < gameState.entities.len);
    var entity = &gameState.entities[entityIndex];
    entity.* = .{};

    return entityIndex;
}

fn TestWall(wallX: f32, relX: f32, relY: f32, playerDeltaX: f32, playerDeltaY: f32, tMin: *f32, minY: f32, maxY: f32) void {
    const tEpsilon = 0.0001;
    if (playerDeltaX != 0) {
        const tResult = (wallX - relX) / playerDeltaX;
        const y = relY + tResult * playerDeltaY;

        if ((tResult >= 0) and (tMin.* > tResult)) {
            if ((y >= minY) and (y <= maxY)) {
                tMin.* = @maximum(0, tResult - tEpsilon);
            }
        }
    }
}

fn MovePlayer(gameState: *game.state, entity: *game.entity, dt: f32, accelaration: game.v2) void {
    const tileMap = gameState.world.tileMap;

    var ddP = accelaration;

    const ddPLength = game.LengthSq(ddP);
    if (ddPLength > 1.0) {
        _ = ddP.scale(1.0 / game.SquareRoot(ddPLength));
    }

    const playerSpeed = @as(f32, 50.0);
    _ = ddP.scale(playerSpeed); // NOTE (Manav): ddP *= playerSpeed;

    _ = ddP.add(game.scale(entity.dP, -8.0)); // NOTE (Manav): ddP += -8.0 * entity.dP;

    const oldPlayerP = entity.p;

    // NOTE (Manav): playerDelta = (0.5 * ddP * square(dt)) + entity.dP * dt;
    const playerDelta = game.add(game.scale(ddP, 0.5 * game.square(dt)), game.scale(entity.dP, dt));
    _ = entity.dP.add(game.scale(ddP, dt)); // NOTE (Manav): entity.dP += ddP * dt;
    var newPlayerP = game.Offset(tileMap, oldPlayerP, playerDelta);

    if (!NOT_IGNORE) {
        var playerLeft = newPlayerP;
        playerLeft.offset_.x -= 0.5 * entity.width;
        playerLeft = game.RecanonicalizePosition(tileMap, playerLeft);

        var playerRight = newPlayerP;
        playerRight.offset_.x += 0.5 * entity.width;
        playerRight = game.RecanonicalizePosition(tileMap, playerRight);

        var collided = false;
        var colP = game.tile_map_position{};
        if (!game.IsTileMapPointEmpty(tileMap, newPlayerP)) {
            colP = newPlayerP;
            collided = true;
        }

        if (!game.IsTileMapPointEmpty(tileMap, playerLeft)) {
            colP = playerLeft;
            collided = true;
        }

        if (!game.IsTileMapPointEmpty(tileMap, playerRight)) {
            colP = playerRight;
            collided = true;
        }

        if (collided) {
            var r = game.v2{};

            if (colP.absTileX < entity.p.absTileX) {
                r = .{ .x = 1, .y = 0 };
            }

            if (colP.absTileX > entity.p.absTileX) {
                r = .{ .x = -1, .y = 0 };
            }

            if (colP.absTileY < entity.p.absTileY) {
                r = .{ .x = 0, .y = 1 };
            }

            if (colP.absTileY > entity.p.absTileY) {
                r = .{ .x = 0, .y = -1 };
            }

            // NOTE (Manav): entity.dP += - 1*inner(entity.dp, r) * r;
            _ = entity.dP.sub(game.scale(r, 1 * game.inner(entity.dP, r)));
        } else {
            entity.p = newPlayerP;
        }
    } else {

        // !NOT_IGNORE:
        // const minTileX = @minimum(oldPlayerP.absTileX, newPlayerP.absTileX);
        // const minTileY = @minimum(oldPlayerP.absTileY, newPlayerP.absTileY);
        // const onePastMaxTileX = @maximum(oldPlayerP.absTileX, newPlayerP.absTileX) + 1;
        // const onePastMaxTileY = @maximum(oldPlayerP.absTileY, newPlayerP.absTileY) + 1;

        const startTileX = oldPlayerP.absTileX;
        const startTileY = oldPlayerP.absTileY;
        const endTileX = newPlayerP.absTileX;
        const endTileY = newPlayerP.absTileY;

        if (endTileX > startTileX) {
            // @breakpoint();
        }

        const deltaX = game.SignOf(@intCast(i32, endTileX) - @intCast(i32, startTileX));
        const deltaY = game.SignOf(@intCast(i32, endTileY) - @intCast(i32, startTileY));

        const absTileZ = entity.p.absTileZ;
        var tMin = @as(f32, 1.0);

        var absTileY = startTileY;
        while (true) {

            var absTileX = startTileX;
            while (true) {
                const testTileP = game.CenteredTilePoint(absTileX, absTileY, absTileZ);
                const tileValue = game.GetTileValueFromPos(tileMap, testTileP);
                if (!game.IsTileValueEmpty(tileValue)) {
                    const minCorner = game.v2{ .x = -0.5 * tileMap.tileSideInMeters, .y = -0.5 * tileMap.tileSideInMeters };
                    const maxCorner = game.v2{ .x = 0.5 * tileMap.tileSideInMeters, .y = 0.5 * tileMap.tileSideInMeters };

                    const relOldPlayerP = game.Substract(tileMap, &oldPlayerP, &testTileP);
                    const rel = relOldPlayerP.dXY;

                    TestWall(minCorner.x, rel.x, rel.y, playerDelta.x, playerDelta.y, &tMin, minCorner.y, maxCorner.y);
                    TestWall(maxCorner.x, rel.x, rel.y, playerDelta.x, playerDelta.y, &tMin, minCorner.y, maxCorner.y);
                    TestWall(minCorner.y, rel.y, rel.x, playerDelta.y, playerDelta.x, &tMin, minCorner.x, maxCorner.x);
                    TestWall(maxCorner.y, rel.y, rel.x, playerDelta.y, playerDelta.x, &tMin, minCorner.x, maxCorner.x);
                }

                if (absTileX == endTileX) {
                    break;
                } else {
                    // TODO (Manav): improve this
                    absTileX = if (deltaX > 0) absTileX + @intCast(u32, deltaX) else absTileX - @intCast(u32, -deltaX);
                }
            }

            if (absTileY == endTileY) {
                break;
            } else {
                // TODO (Manav): improve this
                absTileY = if (deltaY > 0) absTileY + @intCast(u32, deltaY) else absTileY - @intCast(u32, -deltaY);
            }
        }

        entity.p = game.Offset(tileMap, oldPlayerP, game.scale(playerDelta, tMin));
    }

    if (!game.AreOnSameTile(&oldPlayerP, &entity.p)) {
        const newTileValue = game.GetTileValueFromPos(tileMap, entity.p);

        if (newTileValue == 3) {
            entity.p.absTileZ +%= 1;
        } else if (newTileValue == 4) {
            entity.p.absTileZ -%= 1;
        }
    }

    if ((entity.dP.x == 0) and (entity.dP.y == 0)) {
        // NOTE(casey): Leave FacingDirection whatever it was
    } else if (game.AbsoluteValue(entity.dP.x) > game.AbsoluteValue(entity.dP.y)) {
        if (entity.dP.x > 0) {
            entity.facingDirection = 0;
        } else {
            entity.facingDirection = 2;
        }
    } else {
        if (entity.dP.y > 0) {
            entity.facingDirection = 1;
        } else {
            entity.facingDirection = 3;
        }
    }
}

// public functions -----------------------------------------------------------------------------------------------------------------------

pub export fn UpdateAndRender(thread: *platform.thread_context, gameMemory: *platform.memory, gameInput: *platform.input, buffer: *platform.offscreen_buffer) void {
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
        _ = AddEntity(gameState);

        gameState.backdrop = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_background.bmp");

        gameState.heroBitmaps[0].head = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_right_head.bmp");
        gameState.heroBitmaps[0].cape = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_right_cape.bmp");
        gameState.heroBitmaps[0].torso = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_right_torso.bmp");
        gameState.heroBitmaps[0].alignX = 72;
        gameState.heroBitmaps[0].alignY = 182;

        gameState.heroBitmaps[1].head = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_back_head.bmp");
        gameState.heroBitmaps[1].cape = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_back_cape.bmp");
        gameState.heroBitmaps[1].torso = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_back_torso.bmp");
        gameState.heroBitmaps[1].alignX = 72;
        gameState.heroBitmaps[1].alignY = 182;

        gameState.heroBitmaps[2].head = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_left_head.bmp");
        gameState.heroBitmaps[2].cape = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_left_cape.bmp");
        gameState.heroBitmaps[2].torso = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_left_torso.bmp");
        gameState.heroBitmaps[2].alignX = 72;
        gameState.heroBitmaps[2].alignY = 182;

        gameState.heroBitmaps[3].head = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_front_head.bmp");
        gameState.heroBitmaps[3].cape = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_front_cape.bmp");
        gameState.heroBitmaps[3].torso = DEBUGLoadBMP(thread, gameMemory.DEBUGPlatformReadEntireFile, "test/test_hero_front_torso.bmp");
        gameState.heroBitmaps[3].alignX = 72;
        gameState.heroBitmaps[3].alignY = 182;

        gameState.cameraP.absTileX = 17 / 2;
        gameState.cameraP.absTileY = 9 / 2;

        game.InitializeArena(&gameState.worldArena, gameMemory.permanentStorageSize - @sizeOf(game.state), gameMemory.permanentStorage + @sizeOf(game.state));

        gameState.world = game.PushStruct(game.world, &gameState.worldArena);

        const world = gameState.world;
        world.tileMap = game.PushStruct(game.tile_map, &gameState.worldArena);

        const tileChunkCountX = 128;
        const tileChunkCountY = 128;
        const tileChunkCountZ = 2;

        const chunkShift = 4;
        const chunkDim = @as(u32, 1) << @intCast(u5, chunkShift);

        var tileMap = world.tileMap;
        tileMap.chunkShift = chunkShift;
        tileMap.chunkMask = (@as(u32, 1) << @intCast(u5, chunkShift)) - 1;
        tileMap.chunkDim = chunkDim;

        tileMap.tileChunkCountX = tileChunkCountX;
        tileMap.tileChunkCountY = tileChunkCountY;
        tileMap.tileChunkCountZ = tileChunkCountZ;
        tileMap.tileChunks = game.PushArraySlice(game.tile_chunk, tileChunkCountX * tileChunkCountY * tileChunkCountZ, &gameState.worldArena);

        tileMap.tileSideInMeters = 1.4;

        const tilesPerWidth = 17;
        const tilesPerHeight = 9;

        // !NOT_IGNORE
        // var screenX: u32 = std.math.maxInt(i32) / 2;
        // var screenY: u32 = std.math.maxInt(i32) / 2;
        var screenX: u32 = 0;
        var screenY: u32 = 0;

        var absTileZ: u32 = 0;

        var doorLeft = false;
        var doorRight = false;
        var doorTop = false;
        var doorBottom = false;
        var doorUp = false;
        var doorDown = false;

        var screenIndex: u32 = 0;
        while (screenIndex < 100) : (screenIndex += 1) {
            var randomChoice: u32 = 0;
            if (doorUp or doorDown) {
                randomChoice = game.RandInt(u32) % 2;
            } else {
                randomChoice = game.RandInt(u32) % 3;
            }

            var createdZDoor = false;
            if (randomChoice == 2) {
                createdZDoor = true;
                if (absTileZ == 0) {
                    doorUp = true;
                } else {
                    doorDown = true;
                }
            } else if (randomChoice == 1) {
                doorRight = true;
            } else {
                doorTop = true;
            }

            var tileY: u32 = 0;
            while (tileY < tilesPerHeight) : (tileY += 1) {
                var tileX: u32 = 0;
                while (tileX < tilesPerWidth) : (tileX += 1) {
                    const absTileX = screenX * tilesPerWidth + tileX;
                    const absTileY = screenY * tilesPerHeight + tileY;

                    var tileValue: u32 = 1;
                    if ((tileX == 0) and (!doorLeft or (tileY != (tilesPerHeight / 2)))) {
                        tileValue = 2;
                    }

                    if ((tileX == (tilesPerWidth - 1)) and (!doorRight or (tileY != (tilesPerHeight / 2)))) {
                        tileValue = 2;
                    }

                    if ((tileY == 0) and (!doorBottom or (tileX != (tilesPerWidth / 2)))) {
                        tileValue = 2;
                    }

                    if ((tileY == (tilesPerHeight - 1)) and (!doorTop or (tileX != (tilesPerWidth / 2)))) {
                        tileValue = 2;
                    }

                    if ((tileX == 10) and (tileY == 6)) {
                        if (doorUp) {
                            tileValue = 3;
                        }

                        if (doorDown) {
                            tileValue = 4;
                        }
                    }

                    SetTileValue(&gameState.worldArena, world.tileMap, absTileX, absTileY, absTileZ, tileValue);
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
                if (absTileZ == 0) {
                    absTileZ = 1;
                } else {
                    absTileZ = 0;
                }
            } else if (randomChoice == 1) {
                screenX += 1;
            } else {
                screenY += 1;
            }
        }

        gameMemory.isInitialized = true;
    }

    const world = gameState.world;
    const tileMap = world.tileMap;

    const tileSideInPixels = 60;
    const metersToPixels = @intToFloat(f32, tileSideInPixels) / tileMap.tileSideInMeters;

    // const lowerLeftX = -@intToFloat(f32, tileSideInPixels) / 2;
    // const lowerLeftY = @intToFloat(f32, buffer.height);

    for (gameInput.controllers) |controller, controllerIndex| {
        if (GetEntity(gameState, gameState.playerIndexForController[controllerIndex])) |*controllingEntity| {
            var ddP = game.v2{};
            if (controller.isAnalog) {
                ddP = .{ .x = controller.stickAverageX, .y = controller.stickAverageX };
            } else {
                if (controller.buttons.mapped.moveUp.endedDown != 0) {
                    ddP.y = 1.0;
                }
                if (controller.buttons.mapped.moveDown.endedDown != 0) {
                    ddP.y = -1.0;
                }
                if (controller.buttons.mapped.moveLeft.endedDown != 0) {
                    ddP.x = -1.0;
                }
                if (controller.buttons.mapped.moveRight.endedDown != 0) {
                    ddP.x = 1.0;
                }
            }

            MovePlayer(gameState, controllingEntity.*, gameInput.dtForFrame, ddP);
        } else {
            if (controller.buttons.mapped.start.endedDown != 0) {
                const entityIndex = AddEntity(gameState);
                InitializaPlayer(gameState, entityIndex);
                gameState.playerIndexForController[controllerIndex] = entityIndex;
            }
        }
    }

    if (GetEntity(gameState, gameState.cameraFollowingEntityIndex)) |cameraFollowingEntity| {
        gameState.cameraP.absTileZ = cameraFollowingEntity.p.absTileZ;

        const diff = game.Substract(tileMap, &cameraFollowingEntity.p, &gameState.cameraP);
        if (diff.dXY.x > (9 * tileMap.tileSideInMeters)) {
            gameState.cameraP.absTileX += 17;
        }
        if (diff.dXY.x < -(9 * tileMap.tileSideInMeters)) {
            gameState.cameraP.absTileX -= 17;
        }
        if (diff.dXY.y > (5 * tileMap.tileSideInMeters)) {
            gameState.cameraP.absTileY += 9;
        }
        if (diff.dXY.y < -(5 * tileMap.tileSideInMeters)) {
            gameState.cameraP.absTileY -= 9;
        }
    }

    DrawBitmap(buffer, &gameState.backdrop, 0, 0, 0, 0);

    const screenCenterX = 0.5 * @intToFloat(f32, buffer.width);
    const screenCenterY = 0.5 * @intToFloat(f32, buffer.height);

    var relRow: i32 = -10;
    while (relRow < 10) : (relRow += 1) {
        var relCol: i32 = -20;
        while (relCol < 20) : (relCol += 1) {
            const col = @bitCast(u32, @intCast(i32, gameState.cameraP.absTileX) + relCol);
            const row = @bitCast(u32, @intCast(i32, gameState.cameraP.absTileY) + relRow);
            const tileID = game.GetTileValueFromAbs(tileMap, col, row, gameState.cameraP.absTileZ);

            if (tileID > 1) {
                var grey: f32 = 0.5;

                if (tileID == 2) {
                    grey = 1;
                }

                if (tileID > 2) {
                    grey = 0.25;
                }

                if ((col == gameState.cameraP.absTileX) and (row == gameState.cameraP.absTileY)) {
                    grey = 0.0;
                }

                const tileSide = .{ .x = @as(f32, 0.5) * tileSideInPixels, .y = @as(f32, 0.5) * tileSideInPixels };
                const cen = .{
                    .x = screenCenterX - metersToPixels * gameState.cameraP.offset_.x + @intToFloat(f32, relCol * tileSideInPixels),
                    .y = screenCenterY + metersToPixels * gameState.cameraP.offset_.y - @intToFloat(f32, relRow * tileSideInPixels),
                };

                // NOTE (Manav): min = cen - 0.9 * tileSide
                const min = game.sub(cen, game.scale(tileSide, 0.9));
                // NOTE (Manav): max = cen + 0.9 * tileSide
                const max = game.add(cen, game.scale(tileSide, 0.9));

                DrawRectangle(buffer, min, max, grey, grey, grey);
            }
        }
    }

    var entityIndex = @as(u32, 0);
    while (entityIndex < gameState.entityCount) : (entityIndex += 1) {
        if (gameState.entities[entityIndex]) |entity| {
            if (entity.exists) {
                const diff = game.Substract(tileMap, &entity.p, &gameState.cameraP);

                const playerR = 1.0;
                const playerG = 1.0;
                const playerB = 0.0;

                const playerGroundPointX = screenCenterX + metersToPixels * diff.dXY.x;
                const playerGroundPointY = screenCenterY - metersToPixels * diff.dXY.y;
                const playerLeftTop = .{
                    .x = playerGroundPointX - 0.5 * metersToPixels * entity.width,
                    .y = playerGroundPointY - metersToPixels * entity.height,
                };
                const entityWidthHeight = .{ .x = entity.width, .y = entity.height };

                DrawRectangle(
                    buffer,
                    playerLeftTop,
                    game.add(playerLeftTop, game.scale(entityWidthHeight, metersToPixels)),
                    playerR,
                    playerG,
                    playerB,
                );

                const heroBitmaps = gameState.heroBitmaps[entity.facingDirection];

                DrawBitmap(buffer, &heroBitmaps.torso, playerGroundPointX, playerGroundPointY, heroBitmaps.alignX, heroBitmaps.alignY);
                DrawBitmap(buffer, &heroBitmaps.cape, playerGroundPointX, playerGroundPointY, heroBitmaps.alignX, heroBitmaps.alignY);
                DrawBitmap(buffer, &heroBitmaps.head, playerGroundPointX, playerGroundPointY, heroBitmaps.alignX, heroBitmaps.alignY);
            }
        }
    }
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
