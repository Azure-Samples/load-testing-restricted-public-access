using Microsoft.Azure.Cosmos;

namespace dotnet_web_api.Services
{
    /// <summary>
    /// Interface definition for a CosmosClient factory
    /// </summary>
    public interface ICosmosClientFactory
    {
        /// <summary>
        /// Get a client instance by name
        /// </summary>
        /// <param name="name">Get instance with this id</param>
        /// <returns></returns>
        Container? CreateClient(string name);
    }
}
