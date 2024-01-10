using System.Net.Http.Headers;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using dotnet_web_api.Services;
using Microsoft.AspNetCore.Authorization;
using Azure.Core;
using Azure.Identity;
using dotnet_web_api.Options;
using Microsoft.Extensions.Options;
using Azure.Data.Tables;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Services.AppAuthentication;
using Microsoft.OpenApi.Models;
using Microsoft.AspNetCore.Mvc.Authorization;
using System.IdentityModel.Tokens.Jwt;
using dotnet_web_api.Controllers;

var builder = WebApplication.CreateBuilder(args);

using var loggerFactory = LoggerFactory.Create(loggingBuilder => loggingBuilder
    .SetMinimumLevel(LogLevel.Trace)
    .AddConsole());

ILogger logger = loggerFactory.CreateLogger<Program>();

logger.LogInformation("Reading configuration");
// Read Cosmos DB configuration 
string? subscriptionId = builder.Configuration["Services:CosmosDBSubcriptionId"];
string? resourceGroupName = builder.Configuration["Services:CosmosDBResourceGroupName"];
string? accountName = builder.Configuration["Services:CosmosDBAccount"];
string? databaseName = builder.Configuration["Services:CosmosDBDatabaseName"];
string? externalDatabaseName = builder.Configuration["Services:ExternalCosmosDBDatabaseName"];

logger.LogInformation($"CosmosDB subscriptionId: {subscriptionId}");
logger.LogInformation($"CosmosDB resourceGroupName: {resourceGroupName}");
logger.LogInformation($"CosmosDB accountName: {accountName}");
logger.LogInformation($"CosmosDB databaseName: {databaseName}");

if ((string.IsNullOrEmpty(subscriptionId)) ||
    (string.IsNullOrEmpty(resourceGroupName)) ||
    (string.IsNullOrEmpty(accountName)) ||
    (string.IsNullOrEmpty(databaseName))
    )
{
    logger.LogInformation("Loading Storage Table configuration");
    // Add Storage Table configuration 
    // Add a custom scoped service for Table using Azure Storage Table API.
    builder.Services
        .AddOptions<TableStorageOptions<ITableStorageVisitService>>()
            .Configure<IConfiguration>((settings, configuration) =>
            {
                configuration.GetSection("Services:StorageVisit").Bind(settings);
            }).Services
        .AddTransient((Func<IServiceProvider, TokenCredential>)(sp =>
        {
            return new DefaultAzureCredential
            (
                new DefaultAzureCredentialOptions
                {
                    // Linux platform
                    ExcludeSharedTokenCacheCredential = true,
                }
            );
        }))
        .AddSingleton((Func<IServiceProvider, ITableClientFactory>)((sp) =>
        {
            var optionsTableClientVisit =
                sp.GetRequiredService<IOptions<TableStorageOptions<ITableStorageVisitService>>>();

            var tokenCredential = sp.GetRequiredService<TokenCredential>();

            var factory = new TableClientFactory();
            if ((optionsTableClientVisit.Value.Endpoint != null) &&
                (optionsTableClientVisit.Value.TableName != null))
                factory.AddClient(
                    name: nameof(ITableStorageVisitService),
                    instance: CreateTableClient(
                        new Uri(optionsTableClientVisit.Value.Endpoint),
                        optionsTableClientVisit.Value.TableName,
                        tokenCredential));

            return factory;
        }))
        .AddScoped<ITableStorageVisitService, TableStorageVisitService>();
}
else
{
    logger.LogInformation("Loading CosmosDB configuration");
    // Add a custom scoped service for CosmosDB.
    builder.Services
        //.AddOptions<CosmosDBOptions>()
        //    .Configure<IConfiguration>((settings, configuration) =>
        //    {
        //        configuration.GetSection("Services").Bind(settings);
        //    }).Services

        .AddOptions<TableStorageOptions<ITableStorageVisitService>>()
            .Configure<IConfiguration>((settings, configuration) =>
            {
                configuration.GetSection("Services:CosmosDBVisit").Bind(settings);
            }).Services
        .AddSingleton((Func<IServiceProvider, ICosmosClientFactory>)((sp) =>
        {
            //var optionsCosmos =
            //    sp.GetRequiredService<IOptions<CosmosDBOptions>>();
            var optionsTableClientVisit =
                sp.GetRequiredService<IOptions<TableStorageOptions<ITableStorageVisitService>>>();

            var factory = new CosmosClientFactory();

            //string? subscriptionId = optionsCosmos.Value.CosmosDBSubscriptionId;
            //string? resourceGroupName = optionsCosmos.Value.CosmosDBResourceGroupName;
            //string? accountName = optionsCosmos.Value.CosmosDBAccountName;
            //string? databaseName = optionsCosmos.Value.CosmosDBDatabaseName;

            // If the CosmosDB configuration is not set
            // returns empty factory
            if ((string.IsNullOrEmpty(subscriptionId)) ||
            (string.IsNullOrEmpty(resourceGroupName)) ||
            (string.IsNullOrEmpty(accountName)) ||
            (string.IsNullOrEmpty(databaseName))
            )
            {
                logger.LogError("CosmosDB configuration error: a parameter is missing");
                return factory;
            }
            logger.LogInformation("Getting CosmosDB Keys");
            string key = GetCosmosDBKey(subscriptionId, resourceGroupName, accountName).ConfigureAwait(false).GetAwaiter().GetResult();
            if (string.IsNullOrEmpty(key))
            {
                logger.LogError("Error while getting CosmosDB Key");
                return factory;
            }
            logger.LogInformation("Adding CosmosClient...");
            if ((optionsTableClientVisit.Value.Endpoint != null) &&
                (optionsTableClientVisit.Value.TableName != null))
            {

                var container = CreateCosmosClient(
                        new Uri(optionsTableClientVisit.Value.Endpoint),
                        key, databaseName,
                        optionsTableClientVisit.Value.TableName
                        ).ConfigureAwait(false).GetAwaiter().GetResult();
                if (container != null)
                    factory.AddClient(
                            name: nameof(ITableStorageVisitService),
                            instance: container);
            }

            return factory;
        }))
        .AddScoped<ITableStorageVisitService, CosmosStorageVisitService>();
}


builder.Services.AddScoped<IAuthorizationDisabledService, AuthorizationDisabledService>();
builder.Services.AddAuthorization(options =>
    {
        // 1. This is how you redefine the default policy
        // By default, it requires the user to be authenticated
        //
        // See https://github.com/dotnet/aspnetcore/blob/30eec7d2ae99ad86cfd9fca8759bac0214de7b12/src/Security/Authorization/Core/src/AuthorizationOptions.cs#L22-L28
        options.DefaultPolicy = new AuthorizationPolicyBuilder()
            .AddRequirements(new AuthorizationDisabledOrAuthenticatedUserRequirement())
            .Build();

        // 2. Define a specific, named policy that you can reference from your [Authorize] attributes
        options.AddPolicy("AuthorizationDisabledOrAuthenticatedUser", builder => builder
            .AddRequirements(new AuthorizationDisabledOrAuthenticatedUserRequirement()));
    });
builder.Services.AddScoped<IAuthorizationHandler, AuthorizationDisabledOrAuthenticatedUserRequirementHandler>();


// Add services to the container.
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

// Add services HttpClient to call gridwich endpoint.
builder.Services.AddHttpClient();

builder.Services.AddControllers();

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(option =>
{
    option.SwaggerDoc("v1", new OpenApiInfo { Title = "Visit API", Version = "v1" });
    option.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "Please enter a valid token",
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        BearerFormat = "JWT",
        Scheme = "Bearer"
    });
    option.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type=ReferenceType.SecurityScheme,
                    Id="Bearer"
                }
            },
            new string[]{}
        }
    });
});
// The following line enables Application Insights telemetry collection.
builder.Services.AddApplicationInsightsTelemetry();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

//app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseDefaultFiles();
app.UseAuthentication();
app.UseAuthorization();



if (app.Environment.IsDevelopment())
    app.MapControllers().WithMetadata(new AllowAnonymousAttribute());
else
    app.MapControllers();

app.MapDefaultControllerRoute();
app.Run();

/// <summary>
/// Create a new TableClient
/// </summary>
static TableClient CreateTableClient(Uri endpoint, string tableName, TokenCredential tokenCredential)
{
    var client = new TableClient(endpoint, tableName, tokenCredential);
    client.CreateIfNotExists();

    return client;
}

/// <summary>
/// Get CosmosDB Account Key
/// </summary>
static async Task<string> GetCosmosDBKey(string subscriptionId, string resourceGroupName, string accountName)
{
    try
    {
        HttpClient httpClient = new HttpClient();
        // AzureServiceTokenProvider will help us to get the Service Managed token.
        var azureServiceTokenProvider = new AzureServiceTokenProvider();

        // Authenticate to the Azure Resource Manager to get the Service Managed token.
        string accessToken = await azureServiceTokenProvider.GetAccessTokenAsync("https://management.azure.com/");

        // Setup the List Keys API to get the Azure Cosmos DB keys.
        string endpoint = $"https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.DocumentDB/databaseAccounts/{accountName}/listKeys?api-version=2019-12-12";

        // Add the access token to request headers.
        httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        // Post to the endpoint to get the keys result.
        var result = await httpClient.PostAsync(endpoint, new StringContent(""));

        // Get the result back as a DatabaseAccountListKeysResult.
        DatabaseAccountListKeysResult? keys = await result.Content.ReadFromJsonAsync<DatabaseAccountListKeysResult>();
        if ((keys != null) && (keys.primaryMasterKey != null))
            return keys.primaryMasterKey;
    }
    catch (Exception)
    {

    }
    return "";
}

/// <summary>
/// Create a new Container
/// </summary>
static async Task<Container?> CreateCosmosClient(Uri endpoint, string key, string databaseName, string tableName, string partitionKey = "/PartitionKey")
{
    CosmosClient client = new CosmosClient(endpoint.ToString(), key);
    if (client != null)
    {
        await client.CreateDatabaseIfNotExistsAsync(databaseName);
        var database = client.GetDatabase(databaseName);
        if (database != null)
        {
            var container = await database.CreateContainerIfNotExistsAsync(tableName, partitionKey);
            if (container != null)
            {
                return container;
            }
        }
    }
    return null;
}
