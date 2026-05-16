# Multi-stage build for the SearchAssistant.Api .NET 10 service.
# Build context is apps/api/ — see docker-publish.sh.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csproj files first to leverage the Docker layer cache for restore.
COPY SearchAssistant.sln ./
COPY SearchAssistant.Domain/SearchAssistant.Domain.csproj         SearchAssistant.Domain/
COPY SearchAssistant.Infrastructure/SearchAssistant.Infrastructure.csproj SearchAssistant.Infrastructure/
COPY SearchAssistant.Api/SearchAssistant.Api.csproj               SearchAssistant.Api/
COPY SearchAssistant.Api.Tests/SearchAssistant.Api.Tests.csproj   SearchAssistant.Api.Tests/
RUN dotnet restore SearchAssistant.Api/SearchAssistant.Api.csproj

COPY . .
RUN dotnet publish SearchAssistant.Api/SearchAssistant.Api.csproj \
        -c Release \
        --no-restore \
        -o /publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /publish ./

ENV ASPNETCORE_URLS=http://+:8080 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_NOLOGO=1
EXPOSE 8080

ENTRYPOINT ["dotnet", "SearchAssistant.Api.dll"]
