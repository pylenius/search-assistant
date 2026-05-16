using System;
using Microsoft.EntityFrameworkCore.Migrations;
using NetTopologySuite.Geometries;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace SearchAssistant.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:postgis", ",,");

            migrationBuilder.CreateTable(
                name: "searches",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Slug = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    OwnerToken = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Center = table.Column<Point>(type: "geography (Point, 4326)", nullable: true),
                    DefaultZoom = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_searches", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "participants",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SearchId = table.Column<Guid>(type: "uuid", nullable: false),
                    DisplayName = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    Color = table.Column<string>(type: "character varying(9)", maxLength: 9, nullable: false),
                    SessionToken = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    JoinedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    LastSeenAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_participants", x => x.Id);
                    table.ForeignKey(
                        name: "FK_participants_searches_SearchId",
                        column: x => x.SearchId,
                        principalTable: "searches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "paths",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SearchId = table.Column<Guid>(type: "uuid", nullable: false),
                    ParticipantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Geometry = table.Column<LineString>(type: "geography (LineString, 4326)", nullable: false),
                    StartedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    EndedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_paths", x => x.Id);
                    table.ForeignKey(
                        name: "FK_paths_participants_ParticipantId",
                        column: x => x.ParticipantId,
                        principalTable: "participants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_paths_searches_SearchId",
                        column: x => x.SearchId,
                        principalTable: "searches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "position_history",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    ParticipantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Location = table.Column<Point>(type: "geography (Point, 4326)", nullable: false),
                    RecordedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_position_history", x => x.Id);
                    table.ForeignKey(
                        name: "FK_position_history_participants_ParticipantId",
                        column: x => x.ParticipantId,
                        principalTable: "participants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "positions",
                columns: table => new
                {
                    ParticipantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Location = table.Column<Point>(type: "geography (Point, 4326)", nullable: false),
                    AccuracyMeters = table.Column<double>(type: "double precision", nullable: false),
                    HeadingDegrees = table.Column<double>(type: "double precision", nullable: true),
                    RecordedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_positions", x => x.ParticipantId);
                    table.ForeignKey(
                        name: "FK_positions_participants_ParticipantId",
                        column: x => x.ParticipantId,
                        principalTable: "participants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "search_areas",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SearchId = table.Column<Guid>(type: "uuid", nullable: false),
                    Geometry = table.Column<Polygon>(type: "geography (Polygon, 4326)", nullable: false),
                    CreatedByParticipantId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_search_areas", x => x.Id);
                    table.ForeignKey(
                        name: "FK_search_areas_participants_CreatedByParticipantId",
                        column: x => x.CreatedByParticipantId,
                        principalTable: "participants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_search_areas_searches_SearchId",
                        column: x => x.SearchId,
                        principalTable: "searches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_participants_SearchId",
                table: "participants",
                column: "SearchId");

            migrationBuilder.CreateIndex(
                name: "IX_participants_SessionToken",
                table: "participants",
                column: "SessionToken",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_paths_Geometry",
                table: "paths",
                column: "Geometry")
                .Annotation("Npgsql:IndexMethod", "GIST");

            migrationBuilder.CreateIndex(
                name: "IX_paths_ParticipantId",
                table: "paths",
                column: "ParticipantId");

            migrationBuilder.CreateIndex(
                name: "IX_paths_SearchId",
                table: "paths",
                column: "SearchId");

            migrationBuilder.CreateIndex(
                name: "IX_position_history_ParticipantId_RecordedAt",
                table: "position_history",
                columns: new[] { "ParticipantId", "RecordedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_positions_Location",
                table: "positions",
                column: "Location")
                .Annotation("Npgsql:IndexMethod", "GIST");

            migrationBuilder.CreateIndex(
                name: "IX_search_areas_CreatedByParticipantId",
                table: "search_areas",
                column: "CreatedByParticipantId");

            migrationBuilder.CreateIndex(
                name: "IX_search_areas_Geometry",
                table: "search_areas",
                column: "Geometry")
                .Annotation("Npgsql:IndexMethod", "GIST");

            migrationBuilder.CreateIndex(
                name: "IX_search_areas_SearchId",
                table: "search_areas",
                column: "SearchId");

            migrationBuilder.CreateIndex(
                name: "IX_searches_Slug",
                table: "searches",
                column: "Slug",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "paths");

            migrationBuilder.DropTable(
                name: "position_history");

            migrationBuilder.DropTable(
                name: "positions");

            migrationBuilder.DropTable(
                name: "search_areas");

            migrationBuilder.DropTable(
                name: "participants");

            migrationBuilder.DropTable(
                name: "searches");
        }
    }
}
