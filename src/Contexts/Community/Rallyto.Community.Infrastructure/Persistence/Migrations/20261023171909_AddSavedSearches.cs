using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Rallyto.Community.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSavedSearches : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "saved_searches",
                schema: "community",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    criteria = table.Column<string>(type: "jsonb", nullable: false),
                    alerts_enabled = table.Column<bool>(type: "boolean", nullable: false),
                    expires_on = table.Column<DateOnly>(type: "date", nullable: true),
                    alerts_sent = table.Column<int>(type: "integer", nullable: false),
                    pending_matches = table.Column<int>(type: "integer", nullable: false),
                    last_alert_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    city_id = table.Column<int>(type: "integer", nullable: false),
                    sport_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    last_modified_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    last_modified_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_saved_searches", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_saved_searches_owner_id",
                schema: "community",
                table: "saved_searches",
                column: "owner_id");

            migrationBuilder.CreateIndex(
                name: "ix_saved_searches_sport_id_city_id",
                schema: "community",
                table: "saved_searches",
                columns: new[] { "sport_id", "city_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "saved_searches",
                schema: "community");
        }
    }
}
