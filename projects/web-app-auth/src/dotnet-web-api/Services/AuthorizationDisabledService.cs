
namespace dotnet_web_api.Services
{
    public class AuthorizationDisabledService : IAuthorizationDisabledService
    {
        private readonly IConfiguration _configuration;
        bool _authorizationDisabled = false;
        public AuthorizationDisabledService(IConfiguration configuration)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            try
            {
                if(_configuration != null && _configuration.GetSection("Services") != null && _configuration.GetSection("Services")["AuthorizationDisabled"] != null)
                        _authorizationDisabled = bool.Parse(_configuration.GetSection("Services")["AuthorizationDisabled"]!);
                    else
                        _authorizationDisabled = false;
            }
            catch
            {
                _authorizationDisabled = false;
            }
        }

        public bool IsAuthorizationDisabled()
        {
            return _authorizationDisabled;
        }
    }
}