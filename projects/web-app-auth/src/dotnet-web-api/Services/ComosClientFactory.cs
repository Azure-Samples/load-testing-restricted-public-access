using Microsoft.Azure.Cosmos;

namespace dotnet_web_api.Services
{
    /// <summary>
    /// Factory class to create named CosmosClient instances
    /// </summary>
    internal class CosmosClientFactory : ICosmosClientFactory
    {
        private readonly IDictionary<string, Container> _tableClients =
            new Dictionary<string, Container>();

        /// <summary>
        /// Add a new CosmosClient instance
        /// </summary>
        /// <param name="name">Instance id</param>
        /// <param name="instance">CosmosClient Instance</param>
        /// <exception cref="ArgumentNullException"></exception>
        internal void AddClient(string name, Container instance)
        {
            _ = instance ?? throw new ArgumentNullException(nameof(instance));
            if (name == null || string.IsNullOrEmpty(name))
                throw new ArgumentNullException(nameof(name));

            _tableClients[name] = instance;
        }

        /// <summary>
        /// Get a client instance by name
        /// </summary>
        /// <param name="name">Get instance with this id</param>
        /// <returns></returns>
        public Container? CreateClient(string name)
        {
            return (name == null || string.IsNullOrEmpty(name)) ? null : _tableClients[name];
        }
    }
}
