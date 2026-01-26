
namespace dotnet_web_api.Services
{
    public class AuthorizationDisabledService : IAuthorizationDisabledService
    {
        private readonly IConfiguration? _configuration;
        bool _authorizationDisabled = false;
        private readonly ILogger<IAuthorizationDisabledService> _logger;
        public AuthorizationDisabledService(IConfiguration? configuration,ILogger<IAuthorizationDisabledService> logger)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            try
            {
                if(_configuration != null && _configuration.GetSection("Services") != null && _configuration.GetSection("Services")["AuthorizationDisabled"] != null)
                        _authorizationDisabled = bool.Parse(_configuration.GetSection("Services")["AuthorizationDisabled"]!);
                    else
                        _authorizationDisabled = false;

                _logger.LogInformation($"Authorization Disabled: {_authorizationDisabled}");
            }
            catch
            {
                _authorizationDisabled = false;
                _logger.LogError($"Authorization Disabled: {_authorizationDisabled}");
            }
        }

        public bool IsAuthorizationDisabled()
        {
            return _authorizationDisabled;
        }
    }
}