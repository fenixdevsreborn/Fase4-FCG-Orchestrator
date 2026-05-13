using Microsoft.AspNetCore.Mvc;

namespace Gateway.Api.Controllers;

[ApiController]
[Route("api/routes")]
public sealed class RoutesController : ControllerBase
{
    [HttpGet]
    public IActionResult GetRoutes()
    {
        var routes = new[]
        {
            new ApiRoute(
                "Users API",
                "POST",
                "/api/auth/login",
                "Public",
                "Authenticate and return a JWT access token.",
                new { email = "admin@usersapi.com", password = "Admin123!" },
                "/swagger/users/v1/swagger.json"),
            new ApiRoute(
                "Users API",
                "POST",
                "/api/users/create",
                "Public",
                "Create a regular user account.",
                new { name = "Test User", email = "user@example.com", password = "Test!123" },
                "/swagger/users/v1/swagger.json"),
            new ApiRoute(
                "Users API",
                "GET",
                "/api/users/me",
                "Bearer token",
                "Return current authenticated user claims.",
                null,
                "/swagger/users/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "GET",
                "/api/games?page=1&pageSize=20",
                "Public",
                "List games from the catalog.",
                null,
                "/swagger/games/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "GET",
                "/api/games/search?q=Ragnrok&page=1&pageSize=20",
                "Public",
                "Fuzzy search games using OpenSearch when available.",
                null,
                "/swagger/games/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "GET",
                "/api/games/{gameId}",
                "Public",
                "Get a game by id.",
                null,
                "/swagger/games/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "POST",
                "/api/games",
                "Admin bearer token",
                "Create a game and enqueue search/read-model synchronization.",
                new
                {
                    name = "Halo Infinite",
                    description = "Sci-fi shooter",
                    price = 199.90,
                    genre = "FPS",
                    imageUrl = "https://example.com/halo.jpg",
                    developer = "343 Industries",
                    releaseDate = "2021-12-08T00:00:00Z",
                    tags = new[] { "fps", "co-op" },
                    metadata = new { edition = "standard" }
                },
                "/swagger/games/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "POST",
                "/api/v1/orders",
                "Bearer token",
                "Create an order for a game.",
                new { gameId = "11111111-1111-1111-1111-111111111111" },
                "/swagger/games/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "GET",
                "/api/user-games",
                "Bearer token",
                "List the authenticated user's purchased games.",
                null,
                "/swagger/games/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "GET",
                "/api/games/search/status",
                "Admin bearer token",
                "Show OpenSearch status and Postgres/index divergence.",
                null,
                "/swagger/games/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "POST",
                "/api/games/search/reindex",
                "Admin bearer token",
                "Reindex all games into OpenSearch.",
                null,
                "/swagger/games/v1/swagger.json"),
            new ApiRoute(
                "Catalog API",
                "GET",
                "/api/games/admin/summary",
                "Admin bearer token",
                "Return admin dashboard metrics.",
                null,
                "/swagger/games/v1/swagger.json")
        };

        return Ok(new
        {
            docs = "/docs",
            swagger = new
            {
                users = "/swagger/users/v1/swagger.json",
                games = "/swagger/games/v1/swagger.json",
                payments = "/swagger/payments/v1/swagger.json",
                notifications = "/swagger/notifications/v1/swagger.json"
            },
            routes
        });
    }

    private sealed record ApiRoute(
        string Service,
        string Method,
        string Path,
        string Auth,
        string Description,
        object? ExampleBody,
        string Swagger);
}
