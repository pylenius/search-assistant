using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SearchAssistant.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AreaTitleAndColor : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Color",
                table: "search_areas",
                type: "character varying(9)",
                maxLength: 9,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Title",
                table: "search_areas",
                type: "character varying(80)",
                maxLength: 80,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Color",
                table: "search_areas");

            migrationBuilder.DropColumn(
                name: "Title",
                table: "search_areas");
        }
    }
}
