using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using dotnet_web_api.Services;
using dotnet_web_api.Models;

namespace dotnet_web_api.Controllers;

/// <summary>
/// VisitController: 
/// Visit controller used to create, update, get and delete visit
/// </summary>
[Authorize(Policy = "AuthorizationDisabledOrAuthenticatedUser")]
[ApiController]
[Route("[controller]")]
public class VisitController : ControllerBase
{
    private readonly ILogger<VisitController> _logger;
    private readonly ITableStorageVisitService _storageService;


    /// <summary>
    /// Constructor
    /// </summary>
    /// <param name="logger"></param>
    /// <param name="storageService"></param>
    /// <exception cref="ArgumentNullException"></exception>
    public VisitController(ILogger<VisitController> logger, ITableStorageVisitService storageService)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _storageService = storageService ?? throw new ArgumentNullException(nameof(storageService));
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
    private ObjectResult GenerateError(string message = "Error occured")
    {
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
    private string GetClientIPAddress(HttpContext context)
    {
        string ip = string.Empty;
        if (!string.IsNullOrEmpty(context.Request.Headers["X-Forwarded-For"]))
        {
            ip = context.Request.Headers["X-Forwarded-For"];
            if (!string.IsNullOrEmpty(ip))
                ip = ip.Split(':')[0];
        }
        else
        {
            ip = (context.Connection != null && context.Connection.LocalIpAddress != null ? context.Connection.LocalIpAddress.ToString() : "");
        }
        return ip;
    }
    private int GetClientPort(HttpContext context)
    {
        int port = 0;
        if (!string.IsNullOrEmpty(context.Request.Headers["X-Forwarded-For"]))
        {
            string header = context.Request.Headers["X-Forwarded-For"];
            if (!string.IsNullOrEmpty(header))
            {
                string[] array = header.Split(':');
                if (array?.Length > 0)
                    port = int.Parse(array[1]);
            }
        }
        else
        {
            port = (HttpContext.Connection != null ? HttpContext.Connection.RemotePort : 0);
        }
        return port;
    }
    /// <summary>
    /// Get all visit entries
    /// </summary>
    /// <returns>Task<IActionResult></returns>
    [HttpGet()]
    [ProducesResponseType(typeof(List<Visit>), 200)]
    [ProducesResponseType(typeof(String), 404)]
    [ProducesResponseType(typeof(Error), 500)]
    public async Task<IActionResult> GetAsync()
    {
        try
        {
            LogInformation("Calling GetAllVisits");
            List<Visit>? list = await _storageService.RetrieveAllVisitAsync();
            if (list != null)
            {
                return Ok(list);
            }
            else
                return NotFound();
        }
        catch (Exception ex)
        {
            return GenerateInternalError(ex);
        }
    }

    /// <summary>
    /// Get visit entry by id
    /// </summary>
    /// <param name="id">Visit id to retrieve</param>
    /// <returns>Task<IActionResult></returns>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Visit), 200)]
    [ProducesResponseType(typeof(String), 404)]
    [ProducesResponseType(typeof(Error), 500)]
    public async Task<IActionResult> GetAsync(string id)
    {
        try
        {
            LogInformation($"Calling GetVisit ${id}");
            Visit? ent = await _storageService.RetrieveVisitAsync(id);
            if (ent != null)
            {


                return Ok(ent);
            }
            else
                return NotFound();
        }
        catch (Exception ex)
        {
            return GenerateInternalError(ex);
        }
    }

    /// <summary>
    /// Create a new visit entry
    /// </summary>
    /// <param name="inputEntity">VisitCreateRequest object</param>
    /// <returns>Task<IActionResult></returns>
    [HttpPost()]
    [ProducesResponseType(typeof(Visit), 200)]
    [ProducesResponseType(typeof(Error), 500)]
    public async Task<IActionResult> PostAsync([FromBody] VisitRequest inputEntity)
    {
        try
        {
            LogInformation($"Calling CreateVisit");

            var entity = new Visit
            {
                id = Guid.NewGuid().ToString(),
                user = inputEntity.user,
                information = inputEntity.information,
                localIp = (HttpContext.Connection != null && HttpContext.Connection.LocalIpAddress != null ? HttpContext.Connection.LocalIpAddress.ToString() : ""),
                localPort = (HttpContext.Connection != null ? HttpContext.Connection.LocalPort : 0),
                remoteIp = GetClientIPAddress(HttpContext),
                remotePort = (HttpContext.Connection != null ? HttpContext.Connection.RemotePort : 0),
                creationDate = DateTime.UtcNow,
            };
            var createdEntity = await _storageService.InsertVisitAsync(entity);

            return CreatedAtAction(nameof(GetAsync), createdEntity);
        }
        catch (Exception ex)
        {
            return GenerateInternalError(ex);
        }
    }

    /// <summary>
    /// Update a visit entry
    /// </summary>
    /// <param name="entityRequest"></param>
    /// <param name="id">Visit id to update</param>
    /// <returns>Task<IActionResult></returns>
    [HttpPut("{id}")]
    [ProducesResponseType(typeof(Visit), 200)]
    [ProducesResponseType(typeof(String), 404)]
    [ProducesResponseType(typeof(Error), 500)]
    public async Task<IActionResult> PutAsync([FromBody] VisitRequest entityRequest, string id)
    {
        try
        {
            LogInformation($"Calling UpdateVisit ${id}");
            if (!string.IsNullOrEmpty(id))
            {
                var ent = await _storageService.RetrieveVisitAsync(id);
                if (ent == null)
                    return NotFound();

                var entity = new Visit
                {
                    id = id,
                    user = entityRequest.user,
                    information = entityRequest.information,
                    localIp = (HttpContext.Connection != null && HttpContext.Connection.LocalIpAddress != null ? HttpContext.Connection.LocalIpAddress.ToString() : ""),
                    localPort = (HttpContext.Connection != null ? HttpContext.Connection.LocalPort : 0),
                    remoteIp = (HttpContext.Connection != null && HttpContext.Connection.RemoteIpAddress != null ? HttpContext.Connection.RemoteIpAddress.ToString() : ""),
                    remotePort = (HttpContext.Connection != null ? HttpContext.Connection.RemotePort : 0),
                    creationDate = DateTime.UtcNow,

                };
                var entResult = await _storageService.UpdateVisitAsync(entity);
                if (entResult != null)
                    return Ok(entResult);
                else
                    return NotFound();
            }
            else
                return NotFound();
        }
        catch (Exception ex)
        {
            return GenerateInternalError(ex);
        }
    }

    /// <summary>
    /// Delete a visit entry
    /// </summary>
    /// <param name="id">Visit id to delete</param>
    /// <returns>Task<IActionResult></returns>
    [HttpDelete("{id}")]
    [ProducesResponseType(typeof(Visit), 200)]
    [ProducesResponseType(typeof(String), 404)]
    [ProducesResponseType(typeof(Error), 500)]
    public async Task<IActionResult> DeleteAsync(string id)
    {
        try
        {
            LogInformation($"Calling DeleteVisit ${id}");

            var entity = await _storageService.DeleteVisitAsync(id);
            if (entity != null)
                return Ok(entity);
            else
                return NotFound();
        }
        catch (Exception ex)
        {
            return GenerateInternalError(ex);
        }
    }
}
