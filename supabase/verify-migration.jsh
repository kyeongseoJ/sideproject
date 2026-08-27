import java.sql.DriverManager;
import java.util.List;

Class.forName("org.postgresql.Driver");
var connection = DriverManager.getConnection(
        System.getenv("DB_URL"),
        System.getenv("DB_USERNAME"),
        System.getenv("DB_PASSWORD"));
var tables = List.of(
        "novelty_user", "nickname_banned_word", "survey_response", "survey_interest",
        "user_personality_profile", "user_profile_interest", "mission",
        "mission_llm_generation", "mission_status_log", "user_mission",
        "user_mission_category_stat", "world_object",
        "world_object_level", "user_world_object");
for (var table : tables) {
    try (var statement = connection.createStatement();
            var result = statement.executeQuery("SELECT COUNT(*) FROM " + table)) {
        result.next();
        System.out.println(table + "=" + result.getLong(1));
    }
}
var checks = List.of(
        "mission_base=" + "SELECT COUNT(*) FROM mission WHERE source_type = 'BASE'",
        "world_levels=" + "SELECT COUNT(*) FROM world_object_level",
        "mission_orphans=" + "SELECT COUNT(*) FROM mission_status_log l LEFT JOIN mission m ON m.mission_id = l.mission_id WHERE m.mission_id IS NULL",
        "user_mission_orphans=" + "SELECT COUNT(*) FROM user_mission um LEFT JOIN novelty_user u ON u.user_id = um.user_id WHERE u.user_id IS NULL",
        "world_level_orphans=" + "SELECT COUNT(*) FROM user_world_object u LEFT JOIN world_object_level l ON l.world_object_id = u.world_object_id AND l.object_level = u.current_level WHERE l.world_object_id IS NULL");
for (var check : checks) {
    var split = check.indexOf('=');
    var name = check.substring(0, split);
    var query = check.substring(split + 1);
    try (var statement = connection.createStatement(); var result = statement.executeQuery(query)) {
        result.next();
        System.out.println(name + "=" + result.getLong(1));
    }
}
try (var statement = connection.createStatement();
        var result = statement.executeQuery("""
                SELECT pg_get_constraintdef(oid)
                  FROM pg_constraint
                 WHERE conrelid = 'survey_response'::regclass
                   AND conname = 'ck_survey_response_analysis_mode'
                """)) {
    if (!result.next()) {
        throw new IllegalStateException("Missing ck_survey_response_analysis_mode constraint.");
    }
    System.out.println("analysis_mode_constraint=" + result.getString(1));
}
try (var statement = connection.createStatement();
        var result = statement.executeQuery("SELECT sequencename, last_value FROM pg_sequences WHERE schemaname = 'public' ORDER BY sequencename")) {
    while (result.next()) {
        System.out.println("sequence." + result.getString(1) + "=" + result.getLong(2));
    }
}
try (var statement = connection.createStatement();
        var result = statement.executeQuery("""
                SELECT COUNT(*)
                  FROM information_schema.columns
                 WHERE table_schema = 'public'
                   AND table_name = 'survey_response'
                   AND column_name = 'energy_level'
                """)) {
    result.next();
    if (result.getLong(1) != 0) {
        throw new IllegalStateException("Obsolete survey_response.energy_level column remains.");
    }
    System.out.println("survey_response.energy_level=absent");
}
try (var statement = connection.createStatement();
        var result = statement.executeQuery("SELECT MIN(estimated_minutes), MAX(estimated_minutes) FROM mission WHERE enabled = 'Y'")) {
    result.next();
    if (result.getInt(1) < 5 || result.getInt(2) < 180) {
        throw new IllegalStateException("Mission duration pool does not cover 5 to 180 minutes.");
    }
    System.out.println("mission.duration_minutes=" + result.getInt(1) + ".." + result.getInt(2));
}
try (var statement = connection.createStatement();
        var result = statement.executeQuery("SELECT count(*) FROM mission WHERE enabled = 'Y'")) {
    result.next();
    if (result.getInt(1) < 366) {
        throw new IllegalStateException("Expected the expanded mission catalog to contain at least 366 active missions.");
    }
    System.out.println("mission.active_count=" + result.getInt(1));
}
try (var statement = connection.createStatement();
        var result = statement.executeQuery("SELECT COUNT(*) FROM (SELECT category FROM mission WHERE enabled = 'Y' GROUP BY category HAVING COUNT(*) <> 50) mismatched")) {
    result.next();
    if (result.getInt(1) != 0) {
        throw new IllegalStateException("Every active mission category must contain exactly 50 missions.");
    }
    System.out.println("mission.category_counts=all_50");
}
try (var statement = connection.createStatement();
        var result = statement.executeQuery("SELECT COUNT(DISTINCT category) FROM mission WHERE enabled = 'Y'")) {
    result.next();
    if (result.getInt(1) != 8) {
        throw new IllegalStateException("Expected eight active mission categories.");
    }
    System.out.println("mission.category_count=8");
}
var duplicateChecks = List.of(
        "title_normalized=" + "SELECT COUNT(*) FROM (SELECT title_normalized FROM mission WHERE enabled = 'Y' GROUP BY title_normalized HAVING COUNT(*) > 1) duplicates",
        "content_fingerprint=" + "SELECT COUNT(*) FROM (SELECT content_fingerprint FROM mission WHERE enabled = 'Y' GROUP BY content_fingerprint HAVING COUNT(*) > 1) duplicates");
for (var check : duplicateChecks) {
    var split = check.indexOf('=');
    var name = check.substring(0, split);
    var query = check.substring(split + 1);
    try (var statement = connection.createStatement(); var result = statement.executeQuery(query)) {
        result.next();
        if (result.getInt(1) != 0) {
            throw new IllegalStateException("Duplicate active mission " + name + " values found.");
        }
        System.out.println("mission.duplicate." + name + "=0");
    }
}
connection.close();
