# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project file
COPY ["Gateway.Api/Gateway.Api.csproj", "Gateway.Api/"]

# Restore dependencies
RUN dotnet restore "Gateway.Api/Gateway.Api.csproj"

# Copy all source code
COPY . .

# Build the project
WORKDIR "/src/Gateway.Api"
RUN dotnet build "Gateway.Api.csproj" -c Release -o /app/build

# Publish
RUN dotnet publish "Gateway.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/publish .

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "Gateway.Api.dll"]
