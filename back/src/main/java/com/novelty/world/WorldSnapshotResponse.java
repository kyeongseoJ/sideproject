package com.novelty.world;

import java.util.List;

public record WorldSnapshotResponse(List<WorldObjectProgressResponse> objects) {

    public WorldSnapshotResponse {
        objects = List.copyOf(objects);
    }
}
