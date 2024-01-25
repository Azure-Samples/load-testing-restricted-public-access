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
using Microsoft.Azure.Services.AppAuthentication;
using Microsoft.OpenApi.Models;
using Microsoft.AspNetCore.Mvc.Authorization;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;
using dotnet_web_api.Controllers;

var builder = WebApplication.CreateBuilder(args);

using var loggerFactory = LoggerFactory.Create(loggingBuilder => loggingBuilder
    .SetMinimumLevel(LogLevel.Trace)
    .AddConsole());

ILogger logger = loggerFactory.CreateLogger<Program>();

logger.LogInformation("Reading configuration");

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
//builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
//    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));
    //.AddAzureAD(options => Configuration.Bind("AzureAD", options));
//builder.Services.Configure<OpenIdConnectOptions>(
//    AzureADDefaults.OpenIdScheme,
//    options =>{
//        options.Authority = options.Authority + "/v2.0/";
//        options.TokenValidationParameters.ValidateIssuer = true;
//    }
//);
// Remove default claim mapping. We want to use the claim names as they are returned by the Microsoft Identity Platform endpoint.
JwtSecurityTokenHandler.DefaultInboundClaimTypeMap.Clear();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(
        jwtOptions => {
            jwtOptions.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = false,
                ValidateAudience = false,
                //ValidAudiences = validAudiencesArray,
                IssuerValidator = (issuer, securityToken, validationParameters) =>
                {
                    // when no app_uri_id is configured will come from "https://sts.windows.net/"
                    // when a multitenant app is configured will come from "https://login.microsoftonline.com/ or "https://sts.windows.net/" depending on the tenant configuration" and target APPLICATION_URI_ID
                    if (issuer.StartsWith("https://sts.windows.net/") || issuer.StartsWith("https://login.microsoftonline.com/"))
                    {
                        return issuer; // The issuer is valid
                    }
                    else
                    {
                        throw new SecurityTokenInvalidIssuerException($"Invalid issuer {issuer}");
                    }
                }
            };
        },
        identityOptions => {
            identityOptions.Domain = "common";
            identityOptions.ClientId = "common";
            identityOptions.Instance = "https://login.microsoftonline.com/";
            identityOptions.TenantId = "common";
        },
        subscribeToJwtBearerMiddlewareDiagnosticsEvents: true);

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

