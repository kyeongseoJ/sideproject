import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;
import java.util.List;

Class.forName("org.postgresql.Driver");
var connection = DriverManager.getConnection(
        System.getenv("DB_URL"),
        System.getenv("DB_USERNAME"),
        System.getenv("DB_PASSWORD"));
connection.setAutoCommit(false);

for (var migration : List.of(
        "supabase/migrations/001_initial_schema.sql",
        "supabase/migrations/002_seed_missions.sql",
        "supabase/migrations/003_remove_mission_settings.sql",
        "supabase/migrations/004_fix_personality_analysis_mode.sql",
        "supabase/migrations/005_remove_unused_energy_level.sql",
        "supabase/migrations/006_expand_mission_duration_pool.sql",
        "supabase/migrations/007_add_long_and_deviation_missions.sql",
        "supabase/migrations/008_balance_category_mission_counts.sql")) {
    var sql = Files.readString(Path.of(migration), StandardCharsets.UTF_8);
    var statements = sql.split(";\\s*(?=--|CREATE|INSERT|SELECT|ALTER|DROP|$)");
    var executed = 0;
    try {
        for (var raw : statements) {
            var statement = raw.trim();
            if (!statement.isEmpty()) {
                try (Statement jdbcStatement = connection.createStatement()) {
                    jdbcStatement.execute(statement);
                    executed++;
                }
            }
        }
        connection.commit();
        System.out.println(migration + " statements=" + executed);
    } catch (Exception exception) {
        connection.rollback();
        throw exception;
    }
}

try (var statement = connection.createStatement();
        var result = statement.executeQuery("SELECT current_database(), current_user")) {
    result.next();
    System.out.println("connected=" + result.getString(1) + ", user=" + result.getString(2));
}
connection.close();
