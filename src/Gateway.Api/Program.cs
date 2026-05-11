using Microsoft.OpenApi;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// Add HttpClientFactory for Swagger aggregation
builder.Services.AddHttpClient();

// Configure YARP Reverse Proxy
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

// Configure Swagger with multiple API definitions
builder.Services.AddSwaggerGen(options =>
{
    // Users API
    options.SwaggerDoc("users-api", new OpenApiInfo
    {
        Title = "Users API",
        Version = "v1",
        Description = "API de Gerenciamento de Usuários - FIAP"
    });

    // Catalog API
    options.SwaggerDoc("catalog-api", new OpenApiInfo
    {
        Title = "Catalog API",
        Version = "v1",
        Description = "API de Catálogo de Jogos - FIAP"
    });

    // Payments API
    options.SwaggerDoc("payments-api", new OpenApiInfo
    {
        Title = "Payments API",
        Version = "v1",
        Description = "API de Pagamentos - FIAP"
    });

    // Notifications API
    options.SwaggerDoc("notifications-api", new OpenApiInfo
    {
        Title = "Notifications API",
        Version = "v1",
        Description = "API de Notificações - FIAP"
    });

    // Add Bearer Token authentication
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "JWT Authorization header using the Bearer scheme."
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
// IMPORTANTE: A ordem do middleware é crítica para o funcionamento correto do gateway
// 1. Health check e rotas locais devem ser mapeadas primeiro
// 2. Swagger middleware para servir documentação
// 3. Controllers locais (SwaggerController) devem ser mapeados antes do proxy
// 4. Reverse Proxy por último, para não interceptar rotas locais

// Health check endpoint (mapear antes do proxy)
app.MapGet("/health", () => Results.Ok(new { status = "Healthy", service = "Gateway API" }));

// Enable Swagger in all environments for K8s
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    // Users API Swagger (served locally by SwaggerController)
    options.SwaggerEndpoint("/swagger/users/v1/swagger.json", "Users API v1");
    
    // Catalog API Swagger (served locally by SwaggerController)
    options.SwaggerEndpoint("/swagger/games/v1/swagger.json", "Catalog API v1");
    
    // Payments API Swagger (served locally by SwaggerController)
    options.SwaggerEndpoint("/swagger/payments/v1/swagger.json", "Payments API v1");
    
    // Notifications API Swagger (served locally by SwaggerController)
    options.SwaggerEndpoint("/swagger/notifications/v1/swagger.json", "Notifications API v1");
    
    options.RoutePrefix = "docs"; // Frontend usa a raiz (/); Swagger fica em /docs
    
    // Configurações para melhorar a experiência do Swagger UI
    options.EnableDeepLinking(); // Permite links diretos para endpoints
    options.DisplayRequestDuration(); // Mostra o tempo de requisição
});

// Map controllers (SwaggerController) ANTES do reverse proxy
// Isso garante que rotas locais não sejam interceptadas pelo proxy
app.MapControllers();

// Map reverse proxy por último - roteia requisições para APIs backend
// Rotas que não foram capturadas pelos controllers acima serão roteadas pelo proxy
app.MapReverseProxy();

app.Run();

public partial class Program { }
