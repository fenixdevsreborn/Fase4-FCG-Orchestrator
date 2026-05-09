using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

namespace Gateway.Api.Controllers;

[ApiController]
[Route("swagger")]
public class SwaggerController : ControllerBase
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<SwaggerController> _logger;
    private readonly IConfiguration _configuration;

    public SwaggerController(
        IHttpClientFactory httpClientFactory,
        ILogger<SwaggerController> logger,
        IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
        _configuration = configuration;
    }

    [HttpGet("users/v1/swagger.json")]
    public async Task<IActionResult> GetUsersSwagger(CancellationToken cancellationToken = default)
    {
        return await FetchAndServeSwagger(
            serviceUrl: GetServiceUrl("UsersService"),
            swaggerPath: "/swagger/v1/swagger.json",
            cancellationToken: cancellationToken);
    }

    [HttpGet("games/v1/swagger.json")]
    public async Task<IActionResult> GetCatalogSwagger(CancellationToken cancellationToken = default)
    {
        return await FetchAndServeSwagger(
            serviceUrl: GetServiceUrl("CatalogService"),
            swaggerPath: "/swagger/v1/swagger.json",
            cancellationToken: cancellationToken);
    }

    [HttpGet("payments/v1/swagger.json")]
    public IActionResult GetPaymentsSwagger()
    {
        // PaymentsAPI é um worker (HostedService) sem endpoints HTTP
        return GetWorkerServiceSwagger("Payments API", "API de Pagamentos - Worker Service (RabbitMQ Consumer)");
    }

    [HttpGet("notifications/v1/swagger.json")]
    public IActionResult GetNotificationsSwagger()
    {
        // NotificationsAPI é um worker (HostedService) sem endpoints HTTP
        return GetWorkerServiceSwagger("Notifications API", "API de Notificações - Worker Service (RabbitMQ Consumer)");
    }

    private async Task<IActionResult> FetchAndServeSwagger(
        string serviceUrl,
        string swaggerPath,
        CancellationToken cancellationToken)
    {
        try
        {
            var httpClient = _httpClientFactory.CreateClient();
            httpClient.Timeout = TimeSpan.FromSeconds(10);
            
            var swaggerUrl = $"{serviceUrl.TrimEnd('/')}{swaggerPath}";
            _logger.LogInformation("Fetching Swagger from: {SwaggerUrl}", swaggerUrl);

            var response = await httpClient.GetAsync(swaggerUrl, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Failed to fetch Swagger from {SwaggerUrl}. Status: {StatusCode}",
                    swaggerUrl,
                    response.StatusCode);
                return StatusCode((int)response.StatusCode, new { error = "Failed to fetch Swagger" });
            }

            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            
            // Parse and modify the swagger.json to update server URLs
            var swaggerDoc = JsonDocument.Parse(content);
            var swaggerJson = ModifySwaggerServerUrls(swaggerDoc, serviceUrl);

            return Content(swaggerJson, "application/json");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Swagger from {ServiceUrl}", serviceUrl);
            return StatusCode(500, new { error = "Internal server error while fetching Swagger" });
        }
    }

    private string ModifySwaggerServerUrls(JsonDocument swaggerDoc, string originalServiceUrl)
    {
        // Modifica os servidores no swagger.json para apontar para o Gateway
        var root = swaggerDoc.RootElement;
        using var stream = new MemoryStream();
        using var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = false });

        writer.WriteStartObject();

        bool serversWritten = false;
        bool securityWritten = false;
        bool hasSecurityDefinition = false;

        // Verifica se já existe security definition
        if (root.TryGetProperty("components", out var components) &&
            components.ValueKind == JsonValueKind.Object &&
            components.TryGetProperty("securitySchemes", out var securitySchemes))
        {
            hasSecurityDefinition = true;
        }

        foreach (var property in root.EnumerateObject())
        {
            if (property.Name == "servers" && property.Value.ValueKind == JsonValueKind.Array)
            {
                // Substitui os servidores para apontar para o Gateway
                // URL deve ser "/" (raiz) porque os endpoints já começam com "/api/"
                writer.WritePropertyName("servers");
                writer.WriteStartArray();
                writer.WriteStartObject();
                writer.WriteString("url", "/");
                writer.WriteString("description", "Gateway API");
                writer.WriteEndObject();
                writer.WriteEndArray();
                serversWritten = true;
            }
            else if (property.Name == "security" && property.Value.ValueKind == JsonValueKind.Array)
            {
                // Preserva a configuração de segurança existente
                property.WriteTo(writer);
                securityWritten = true;
            }
            else
            {
                property.WriteTo(writer);
            }
        }

        // Se não havia servidores, adiciona
        if (!serversWritten)
        {
            writer.WritePropertyName("servers");
            writer.WriteStartArray();
            writer.WriteStartObject();
            writer.WriteString("url", "/");
            writer.WriteString("description", "Gateway API");
            writer.WriteEndObject();
            writer.WriteEndArray();
        }

        // Se não havia security global mas existe security definition, adiciona
        if (!securityWritten && hasSecurityDefinition)
        {
            writer.WritePropertyName("security");
            writer.WriteStartArray();
            writer.WriteStartObject();
            writer.WritePropertyName("Bearer");
            writer.WriteStartArray();
            writer.WriteEndArray();
            writer.WriteEndObject();
            writer.WriteEndArray();
        }

        writer.WriteEndObject();
        writer.Flush();

        return System.Text.Encoding.UTF8.GetString(stream.ToArray());
    }

    private IActionResult GetWorkerServiceSwagger(string title, string description)
    {
        // Retorna um swagger.json mínimo para serviços worker sem endpoints HTTP
        var swaggerJson = $@"{{
  ""openapi"": ""3.0.1"",
  ""info"": {{
    ""title"": ""{title}"",
    ""version"": ""v1"",
    ""description"": ""{description}""
  }},
  ""servers"": [
    {{
      ""url"": ""/"",
      ""description"": ""Gateway API""
    }}
  ],
  ""paths"": {{}},
  ""components"": {{
    ""schemas"": {{
      ""Info"": {{
        ""type"": ""object"",
        ""properties"": {{
          ""message"": {{
            ""type"": ""string"",
            ""description"": ""Este serviço é um Worker (Background Service) que consome eventos do RabbitMQ. Não possui endpoints HTTP.""
          }}
        }}
      }}
    }}
  }}
}}";

        return Content(swaggerJson, "application/json");
    }

    private string GetServiceUrl(string serviceName)
    {
        // Tenta obter da configuração primeiro
        var configKey = $"Services:{serviceName}:BaseUrl";
        var configuredUrl = _configuration[configKey];

        if (!string.IsNullOrEmpty(configuredUrl))
        {
            return configuredUrl;
        }

        // Fallback para os endereços padrão do K8s
        return serviceName switch
        {
            "UsersService" => _configuration["ReverseProxy:Clusters:users-cluster:Destinations:destination1:Address"] 
                ?? "http://users-api-service:8080",
            "CatalogService" => _configuration["ReverseProxy:Clusters:catalog-cluster:Destinations:destination1:Address"] 
                ?? "http://catalog-api-service:8080",
            "PaymentsService" => _configuration["ReverseProxy:Clusters:payments-cluster:Destinations:destination1:Address"] 
                ?? "http://payments-api-service:80",
            "NotificationsService" => _configuration["ReverseProxy:Clusters:notifications-cluster:Destinations:destination1:Address"] 
                ?? "http://notifications-api-service:80",
            _ => throw new ArgumentException($"Unknown service: {serviceName}", nameof(serviceName))
        };
    }
}
