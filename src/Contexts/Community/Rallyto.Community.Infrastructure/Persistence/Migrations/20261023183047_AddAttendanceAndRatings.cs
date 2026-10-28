using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Rallyto.Community.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAttendanceAndRatings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "attendance_opened_at",
                schema: "community",
                table: "matches",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "rating_reminders_sent_at",
                schema: "community",
                table: "matches",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "resolved_at",
                schema: "community",
                table: "matches",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "answered_at",
                schema: "community",
                table: "match_participants",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "attendance",
                schema: "community",
                table: "match_participants",
                type: "character varying(16)",
                maxLength: 16,
                nullable: true);

            migrationBuilder.AddColumn<List<Guid>>(
                name: "no_show_flags",
                schema: "community",
                table: "match_participants",
                type: "uuid[]",
                nullable: false,
                defaultValueSql: "'{}'::uuid[]");

            migrationBuilder.AddColumn<string>(
                name: "outcome",
                schema: "community",
                table: "match_participants",
                type: "character varying(16)",
                maxLength: 16,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ratings",
                schema: "community",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    match_id = table.Column<Guid>(type: "uuid", nullable: false),
                    sport_id = table.Column<Guid>(type: "uuid", nullable: false),
                    rater_id = table.Column<Guid>(type: "uuid", nullable: false),
                    ratee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    stars = table.Column<int>(type: "integer", nullable: false),
                    tags = table.Column<int>(type: "integer", nullable: false),
                    level = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    private_note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    submitted_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    window_closes_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    revealed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    removed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    removed_by = table.Column<Guid>(type: "uuid", nullable: true),
                    removal_reason = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    last_modified_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    last_modified_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ratings", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_matches_status_resolved_at",
                schema: "community",
                table: "matches",
                columns: new[] { "status", "resolved_at" });

            migrationBuilder.CreateIndex(
                name: "ix_ratings_match_id_rater_id_ratee_id",
                schema: "community",
                table: "ratings",
                columns: new[] { "match_id", "rater_id", "ratee_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ratings_ratee_id_sport_id",
                schema: "community",
                table: "ratings",
                columns: new[] { "ratee_id", "sport_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ratings_window_closes_at",
                schema: "community",
                table: "ratings",
                column: "window_closes_at",
                filter: "revealed_at IS NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ratings",
                schema: "community");

            migrationBuilder.DropIndex(
                name: "ix_matches_status_resolved_at",
                schema: "community",
                table: "matches");

            migrationBuilder.DropColumn(
                name: "attendance_opened_at",
                schema: "community",
                table: "matches");

            migrationBuilder.DropColumn(
                name: "rating_reminders_sent_at",
                schema: "community",
                table: "matches");

            migrationBuilder.DropColumn(
                name: "resolved_at",
                schema: "community",
                table: "matches");

            migrationBuilder.DropColumn(
                name: "answered_at",
                schema: "community",
                table: "match_participants");

            migrationBuilder.DropColumn(
                name: "attendance",
                schema: "community",
                table: "match_participants");

            migrationBuilder.DropColumn(
                name: "no_show_flags",
                schema: "community",
                table: "match_participants");

            migrationBuilder.DropColumn(
                name: "outcome",
                schema: "community",
                table: "match_participants");
        }
    }
}
