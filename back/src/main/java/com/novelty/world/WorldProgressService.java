package com.novelty.world;

import org.springframework.stereotype.Service;

import com.novelty.mission.MissionCategory;
import com.novelty.user.UserService;
import com.novelty.world.WorldRepository.UserWorldProgress;
import com.novelty.world.WorldRepository.WorldObjectDefinition;

@Service
public class WorldProgressService {

    private final UserService userService;
    private final WorldRepository worldRepository;

    public WorldProgressService(UserService userService, WorldRepository worldRepository) {
        this.userService = userService;
        this.worldRepository = worldRepository;
    }

    public WorldSnapshotResponse getSnapshot(String userKey) {
        long userId = userService.requireUserId(userKey);
        return new WorldSnapshotResponse(worldRepository.findSnapshot(userId));
    }

    public WorldGrowthResponse applyMissionCompletion(
            long userId,
            MissionCategory category,
            int difficulty) {
        int awardedExp = rewardExp(difficulty);
        WorldObjectDefinition object = requireDefinition(category);
        UserWorldProgress previous = worldRepository.findProgressForUpdate(userId, object.id())
                .orElse(new UserWorldProgress(0, 1));
        int currentExp = Math.addExact(previous.exp(), awardedExp);
        int currentLevel = worldRepository.findLevel(object.id(), currentExp);
        worldRepository.upsertProgress(userId, object.id(), currentExp, currentLevel);
        return response(object, awardedExp, previous.level(), currentLevel, currentExp, true);
    }

    public WorldGrowthResponse currentWithoutReward(long userId, MissionCategory category) {
        WorldObjectDefinition object = requireDefinition(category);
        UserWorldProgress current = worldRepository.findProgressForUpdate(userId, object.id())
                .orElse(new UserWorldProgress(0, 1));
        return response(object, 0, current.level(), current.level(), current.exp(), false);
    }

    static int rewardExp(int difficulty) {
        if (difficulty < 1 || difficulty > 3) {
            throw new IllegalArgumentException("Mission difficulty must be between 1 and 3.");
        }
        return difficulty * 10;
    }

    private WorldObjectDefinition requireDefinition(MissionCategory category) {
        if (category == null) {
            throw new IllegalArgumentException("Mission category is required.");
        }
        return worldRepository.findDefinition(category)
                .orElseThrow(() -> new IllegalStateException("World object definition is missing."));
    }

    private WorldGrowthResponse response(
            WorldObjectDefinition object,
            int awardedExp,
            int previousLevel,
            int currentLevel,
            int currentExp,
            boolean rewardApplied) {
        return new WorldGrowthResponse(
                object.objectCode(),
                object.category().name(),
                awardedExp,
                previousLevel,
                currentLevel,
                currentExp,
                worldRepository.findNextRequiredExp(object.id(), currentLevel),
                currentLevel > previousLevel,
                rewardApplied);
    }
}
