using Microsoft.AspNetCore.Authorization;
namespace dotnet_web_api.Services
{
    public class AuthorizationDisabledOrAuthenticatedUserRequirement : IAuthorizationRequirement
    {

    }
    public class AuthorizationDisabledOrAuthenticatedUserRequirementHandler : AuthorizationHandler<AuthorizationDisabledOrAuthenticatedUserRequirement>
    {
        private readonly IAuthorizationDisabledService _authorizationDisabledService;

        public AuthorizationDisabledOrAuthenticatedUserRequirementHandler(IAuthorizationDisabledService authorizationDisabledService)
        {
            _authorizationDisabledService = authorizationDisabledService;
        }

        protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, AuthorizationDisabledOrAuthenticatedUserRequirement requirement)
        {
            if (_authorizationDisabledService.IsAuthorizationDisabled() || context.User.Identities.Any(x => x.IsAuthenticated))
            {
                context.Succeed(requirement);
            }

            return Task.CompletedTask;
        }
    }

}