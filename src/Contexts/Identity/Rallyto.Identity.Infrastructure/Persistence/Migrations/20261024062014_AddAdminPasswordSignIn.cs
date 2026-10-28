using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Rallyto.Identity.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAdminPasswordSignIn : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "email",
                schema: "identity",
                table: "user_accounts",
                type: "character varying(256)",
                maxLength: 256,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "failed_password_attempts",
                schema: "identity",
                table: "user_accounts",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "password_hash",
                schema: "identity",
                table: "user_accounts",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "password_locked_until",
                schema: "identity",
                table: "user_accounts",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_user_accounts_email",
                schema: "identity",
                table: "user_accounts",
                column: "email",
                unique: true,
                filter: "email IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_user_accounts_email",
                schema: "identity",
                table: "user_accounts");

            migrationBuilder.DropColumn(
                name: "email",
                schema: "identity",
                table: "user_accounts");

            migrationBuilder.DropColumn(
                name: "failed_password_attempts",
                schema: "identity",
                table: "user_accounts");

            migrationBuilder.DropColumn(
                name: "password_hash",
                schema: "identity",
                table: "user_accounts");

            migrationBuilder.DropColumn(
                name: "password_locked_until",
                schema: "identity",
                table: "user_accounts");
        }
    }
}
