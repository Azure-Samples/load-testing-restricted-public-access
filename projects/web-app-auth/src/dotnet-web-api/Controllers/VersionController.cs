using Microsoft.AspNetCore.Mvc;
using dotnet_web_api.Models;
namespace dotnet_web_api.Controllers;

/// <summary>
/// VersionController: 
/// Version controller used to return the current version of the API. 
/// This method can be used by the CI/CD pipeline to check whether the expected version has been deployed.
/// </summary>

[ApiController]
[Route("[controller]")]
public class VersionController : ControllerBase
{

    private readonly ILogger<VersionController> _logger;

    /// <summary>
    /// Constructor
    /// </summary>
    /// <param name="logger"></param>
    /// <exception cref="ArgumentNullException"></exception>
    public VersionController(ILogger<VersionController> logger)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    private ObjectResult GenerateInternalError(Exception ex, string message = "Exception occured")
    {
        _logger.LogError(ex, message);

        var error = new Error
        {
            code = (int)ErrorCode.Exception,
            message = "Internal server error: Exception",
            creationDate = DateTime.UtcNow,
            source = GetType().Name,
        };

        return StatusCode(500, error);
    }
    private void LogInformation(string message)
    {
        _logger.LogInformation(message);
    }

    [HttpGet()]
    public async Task<IActionResult> GetVersion()
    {

        try
        {
            LogInformation("Calling GetVersion");

            var appVersion = Environment.GetEnvironmentVariable("APP_VERSION");
            if (string.IsNullOrEmpty(appVersion))
                appVersion = "1.0.0.1";
            return await Task.FromResult<IActionResult>(Ok($"{{ \"version\": \"{appVersion}\"}}"));
        }
        catch (Exception ex)
        {
            return GenerateInternalError(ex);
        }
    }
}
