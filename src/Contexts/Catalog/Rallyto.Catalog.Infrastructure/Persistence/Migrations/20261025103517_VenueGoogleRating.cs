using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Rallyto.Catalog.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class VenueGoogleRating : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "google_rating",
                schema: "catalog",
                table: "venues",
                type: "double precision",
                precision: 2,
                scale: 1,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "google_review_count",
                schema: "catalog",
                table: "venues",
                type: "integer",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "google_rating",
                schema: "catalog",
                table: "venues");

            migrationBuilder.DropColumn(
                name: "google_review_count",
                schema: "catalog",
                table: "venues");
        }
    }
}
