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
        "user_mission_setting", "user_mission_category_stat", "world_object",
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
        var result = statement.executeQuery("SELECT sequencename, last_value FROM pg_sequences WHERE schemaname = 'public' ORDER BY sequencename")) {
    while (result.next()) {
        System.out.println("sequence." + result.getString(1) + "=" + result.getLong(2));
    }
}
connection.close();
