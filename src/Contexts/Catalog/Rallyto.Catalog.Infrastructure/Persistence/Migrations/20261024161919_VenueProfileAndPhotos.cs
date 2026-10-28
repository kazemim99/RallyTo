using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Rallyto.Catalog.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class VenueProfileAndPhotos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string[]>(
                name: "amenities",
                schema: "catalog",
                table: "venues",
                type: "text[]",
                nullable: false,
                defaultValue: new string[0]);

            migrationBuilder.AddColumn<string[]>(
                name: "court_types",
                schema: "catalog",
                table: "venues",
                type: "text[]",
                nullable: false,
                defaultValue: new string[0]);

            migrationBuilder.AddColumn<string>(
                name: "description",
                schema: "catalog",
                table: "venues",
                type: "character varying(4000)",
                maxLength: 4000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "instagram",
                schema: "catalog",
                table: "venues",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "source_ref",
                schema: "catalog",
                table: "venues",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "source_url",
                schema: "catalog",
                table: "venues",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "tagline",
                schema: "catalog",
                table: "venues",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "telegram",
                schema: "catalog",
                table: "venues",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "website",
                schema: "catalog",
                table: "venues",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "working_hours",
                schema: "catalog",
                table: "venues",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "venue_images",
                schema: "catalog",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    path = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    venue_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_venue_images", x => x.id);
                    table.ForeignKey(
                        name: "fk_venue_images_venues_venue_id",
                        column: x => x.venue_id,
                        principalSchema: "catalog",
                        principalTable: "venues",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_venues_source_ref",
                schema: "catalog",
                table: "venues",
                column: "source_ref",
                unique: true,
                filter: "source_ref IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ix_venue_images_venue_id_sort_order",
                schema: "catalog",
                table: "venue_images",
                columns: new[] { "venue_id", "sort_order" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "venue_images",
                schema: "catalog");

            migrationBuilder.DropIndex(
                name: "ix_venues_source_ref",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "amenities",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "court_types",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "description",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "instagram",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "source_ref",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "source_url",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "tagline",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "telegram",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "website",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "working_hours",
                schema: "catalog",
                table: "venues");
        }
    }
}
