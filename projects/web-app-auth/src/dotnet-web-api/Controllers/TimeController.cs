using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using dotnet_web_api.Models;

namespace dotnet_web_api.Controllers;

/// <summary>
/// TimeController: 
/// Time controller used to return the current utc time on the server hosting the API. 
/// This method can be used by the CI/CD pipeline to check whether authorization is fully functionning.
/// </summary>

[Authorize]
[ApiController]
[Route("[controller]")]
public class TimeController : ControllerBase
{

    private readonly ILogger<TimeController> _logger;

    /// <summary>
    /// Constructor
    /// </summary>
    /// <param name="logger"></param>
    /// <exception cref="ArgumentNullException"></exception>
    public TimeController(ILogger<TimeController> logger)
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
    public async Task<IActionResult> GetTime()
    {
        try
        {
            LogInformation("Calling GetTime");

            DateTime t = DateTime.UtcNow;

            string tof = t.ToString("yy/MM/dd-HH:mm:ss");
            return await Task.FromResult<IActionResult>(Ok($"{{ \"time\": \"{tof}\"}}"));
        }
        catch (Exception ex)
        {
            return GenerateInternalError(ex);
        }
    }

}
