
namespace dotnet_web_api.Services
{
    public class AuthorizationDisabledService : IAuthorizationDisabledService
    {
        IConfiguration _configuration;
        bool _authorizationDisabled = false;
        public AuthorizationDisabledService(IConfiguration configuration)
        {
            _configuration = configuration;
            try
            {
                _authorizationDisabled = bool.Parse(_configuration.GetSection("Services")["AuthorizationDisabled"]);
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